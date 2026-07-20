// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// Run with: forge script solidity/governance/claude/global-environmental-movement/Deploy.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { Configurations } from "@script/Configurations.s.sol";
import { DeployHelpers } from "../../DeployHelpers.s.sol";
import { IMandateRegistry } from "@src/core/helpers/MandateRegistry.sol";

import { PowersTypes } from "@src/interfaces/PowersTypes.sol";
import { Powers } from "@src/Powers.sol";
import { IPowers } from "@src/interfaces/IPowers.sol";
import { IPowersFactory } from "@src/core/helpers/PowersFactory.sol";
import { PowersFactory } from "@src/core/helpers/PowersFactory.sol";
import { PowersDeployer } from "@src/core/helpers/PowersDeployer.sol";
import { ElectionRegistry } from "@src/core/helpers/ElectionRegistry.sol";
import { Nominees } from "@src/core/helpers/Nominees.sol";

/// @title Global Environmental Movement.  Deploy Script
/// @notice Deploys the parent organisation and a pre-configured sub-org factory.
///
/// Roles:
///   0 = Admin  (deployer, no ongoing governance use)
///   1 = Leader (max 7, visible, elected annually)
///   2 = Parent Coordinator (assigned by leaders)
///   3 = Member (anonymous, ZK-passport verified at join)
///   4 = Recognised Sub-org (contract address of each spawned sub-movement)
contract Deploy is DeployHelpers {
    Configurations helperConfig;
    IMandateRegistry registry;

    PowersTypes.MandateInitData[] constitution;
    PowersTypes.MandateInitData[] subOrgConstitution;
    PowersTypes.Conditions conditions;
    PowersTypes.Flow[] flows;
    PowersTypes.Flow[] subOrgFlows;

    Powers public powers;
    PowersFactory public subOrgFactory;
    ElectionRegistry public leaderElectionRegistry;
    ElectionRegistry public subOrgElectionRegistry; // used inside sub-org template
    Nominees public coordinatorNominees;

    // Stored after _buildParentConstitution() so _fixSubOrgRatificationMandate() can read it.
    uint16 public subOrgRatifyMandateId;

    address[] targets;
    uint256[] values;
    bytes[] calldatas;
    string[] inputParams;

    uint16 constant MAJOR = 0;
    uint16 constant MINOR = 1;
    uint16 constant PATCH = 9;

    function run() external returns (address powersAddress, address factoryAddress, address leaderElectionRegistryAddress) {
        helperConfig = new Configurations();
        registry = IMandateRegistry(helperConfig.getMandateRegistry(block.chainid));

        // ── Step 1: deploy helper contracts ────────────────────────────────
        vm.startBroadcast();
        // Leader elections: 1-week nomination, 2-week voting
        leaderElectionRegistry = new ElectionRegistry(
            minutesToBlocks(7 * 24 * 60, helperConfig.getBlocksPerHour(block.chainid)),
            minutesToBlocks(14 * 24 * 60, helperConfig.getBlocksPerHour(block.chainid))
        );
        // Sub-org coordinator elections: 1-week nomination, 1-week voting
        subOrgElectionRegistry = new ElectionRegistry(
            minutesToBlocks(7 * 24 * 60, helperConfig.getBlocksPerHour(block.chainid)),
            minutesToBlocks(7 * 24 * 60, helperConfig.getBlocksPerHour(block.chainid))
        );
        coordinatorNominees = new Nominees();

        powers = new Powers(
            "Global Environmental Movement",
            "https://aqua-famous-sailfish-288.mypinata.cloud/ipfs/bafybeiecp4sftsohsmaqqnzojxu5qlhs44qzhfb3ym7qoyormx36v2a77q/globalEnvMovement.json",
            helperConfig.getMaxCallDataLength(block.chainid),
            helperConfig.getMaxReturnDataLength(block.chainid),
            helperConfig.getMaxExecutionsLength(block.chainid),
            address(registry)
        );
        vm.stopBroadcast();
        console2.log("Powers deployed at:", address(powers));

        // ── Step 2: build sub-org constitution (baked into factory) ────────
        _buildSubOrgConstitution();

        // ── Step 3: deploy and load the sub-org factory ────────────────────
        vm.startBroadcast();
        PowersDeployer deployer = new PowersDeployer();
        subOrgFactory = new PowersFactory(
            "https://aqua-famous-sailfish-288.mypinata.cloud/ipfs/bafybeiecp4sftsohsmaqqnzojxu5qlhs44qzhfb3ym7qoyormx36v2a77q/subOrgTemplate.json",
            helperConfig.getMaxCallDataLength(block.chainid),
            helperConfig.getMaxReturnDataLength(block.chainid),
            helperConfig.getMaxExecutionsLength(block.chainid),
            address(deployer),
            address(registry)
        );
        subOrgFactory.addMandates(subOrgConstitution);
        for (uint256 i = 0; i < subOrgFlows.length; i++) {
            PowersTypes.Flow[] memory singleFlow = new PowersTypes.Flow[](1);
            singleFlow[0] = subOrgFlows[i];
            subOrgFactory.addFlows(singleFlow);
        }
        vm.stopBroadcast();
        console2.log("SubOrg factory deployed at:", address(subOrgFactory));

        // ── Step 4: build parent constitution ──────────────────────────────
        // This sets subOrgRatifyMandateId as a side-effect.
        uint256 constitutionLength = _buildParentConstitution();
        console2.log("Parent constitution length:", constitutionLength);
        console2.log("Sub-org ratification mandate ID:", subOrgRatifyMandateId);

        // ── Step 4b: patch the factory — wire in real parent address + mandate ID ──
        // The deployer still owns the factory here; ownership transfers in step 5.
        // This replaces the placeholder (address(0), uint16(0)) in the sub-org
        // "Send Parent Ratification" mandate (array index 13) with the real values.
        _fixSubOrgRatificationMandate();
        console2.log("Sub-org factory patched with real parent address and mandate ID.");

        // ── Step 5: constitute and close ───────────────────────────────────
        vm.startBroadcast();
        powers.constitute(constitution);
        powers.closeConstitute(msg.sender, flows);
        // Transfer helper contract ownership to Powers
        coordinatorNominees.transferOwnership(address(powers));
        // Transfer factory ownership to Powers (so only governance can spawn sub-orgs)
        subOrgFactory.transferOwnership(address(powers));
        vm.stopBroadcast();
        console2.log("Powers successfully constituted.");

        return (address(powers), address(subOrgFactory), address(leaderElectionRegistry));
    }

    // ────────────────────────────────────────────────────────────────────────────
    //                         PARENT CONSTITUTION
    // ────────────────────────────────────────────────────────────────────────────
    function _buildParentConstitution() internal returns (uint256) {
        uint16 mandateCount = 0;

        ////////////////////////////////////////////////////////////////////////
        //                         SETUP (mandateId = 1)                      //
        // Labels all roles and revokes itself. Assigns the parent Powers as   //
        // its own treasury so Safe allowances route correctly.                //
        ////////////////////////////////////////////////////////////////////////
        targets = new address[](7);
        values  = new uint256[](7);
        calldatas = new bytes[](7);
        for (uint256 i = 0; i < 7; i++) targets[i] = address(powers);

        calldatas[0] = abi.encodeWithSelector(IPowers.labelRole.selector, 0, "Admin", "");
        calldatas[1] = abi.encodeWithSelector(IPowers.labelRole.selector, type(uint256).max, "Public", "");
        calldatas[2] = abi.encodeWithSelector(IPowers.labelRole.selector, 1, "Leader", "");
        calldatas[3] = abi.encodeWithSelector(IPowers.labelRole.selector, 2, "Parent Coordinator", "");
        calldatas[4] = abi.encodeWithSelector(IPowers.labelRole.selector, 3, "Member", "");
        calldatas[5] = abi.encodeWithSelector(IPowers.labelRole.selector, 4, "Recognised Sub-org", "");
        calldatas[6] = abi.encodeWithSelector(IPowers.revokeMandate.selector, mandateCount + 1);

        mandateCount++;
        conditions.allowedRole = type(uint256).max;
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Initial Setup: Assign role labels and revokes itself after execution",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "PresetActions"),
            config: abi.encode(targets, values, calldatas),
            conditions: conditions
        }));
        delete conditions;

        ////////////////////////////////////////////////////////////////////////
        //                    FLOW 1: Member Onboarding                       //
        // ZK-passport uniqueness check → SelfSelect as Member.               //
        // Members can also voluntarily leave.                                 //
        ////////////////////////////////////////////////////////////////////////
        {
            uint16[] memory flow1Ids = new uint16[](3);
            flow1Ids[0] = mandateCount + 1;
            flow1Ids[1] = mandateCount + 2;
            flow1Ids[2] = mandateCount + 3;
            flows.push(PowersTypes.Flow({
                mandateIds: flow1Ids,
                nameDescription: "Flow 1: Member Onboarding.  ZK-passport uniqueness check then self-select."
            }));
        }

        // Step 1: ZK-passport uniqueness check (proof must be <1 year old; isAgeAbove(0) passes everyone)
        inputParams = new string[](0);
        mandateCount++;
        conditions.allowedRole = type(uint256).max;
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Verify Unique Identity: ZK-passport proof of uniqueness required to join the movement.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "ZKPassport_Check"),
            config: abi.encode(
                inputParams,
                helperConfig.getZkPassportRegistry(block.chainid),
                uint256(365 * 24 * 3600), // proof valid for 1 year
                false,                     // facematch not required
                bytes4(keccak256("isAgeAbove(uint8)")),
                abi.encode(uint8(0))       // age > 0.  passes everyone, uniqueness enforced by registry
            ),
            conditions: conditions
        }));
        delete conditions;

        // Step 2: SelfSelect as Member (requires ZK check to have passed)
        uint16 zkCheckMandateId = mandateCount;
        mandateCount++;
        conditions.allowedRole = type(uint256).max;
        conditions.needFulfilled = zkCheckMandateId;
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Join as Member: Self-select as a movement member after passing the ZK-passport uniqueness check.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "SelfSelect"),
            config: abi.encode(uint256(3)), // roleId = 3 (Member)
            conditions: conditions
        }));
        delete conditions;

        // Step 3: RenounceRole.  voluntary exit
        mandateCount++;
        conditions.allowedRole = 3; // only Members can renounce their member role
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Leave Movement: A Member voluntarily renounces their membership.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "RenounceRole"),
            config: abi.encode(uint256(3)), // roleId = 3 (Member)
            conditions: conditions
        }));
        delete conditions;

        ////////////////////////////////////////////////////////////////////////
        //                  FLOW 2: Fund a Sub-organisation                   //
        // Member proposes → 2-day member veto window → coordinator approves  //
        // → execute treasury allowance via Safe Allowance Module.            //
        ////////////////////////////////////////////////////////////////////////
        {
            uint16[] memory flow2Ids = new uint16[](4);
            flow2Ids[0] = mandateCount + 1;
            flow2Ids[1] = mandateCount + 2;
            flow2Ids[2] = mandateCount + 3;
            flow2Ids[3] = mandateCount + 4;
            flows.push(PowersTypes.Flow({
                mandateIds: flow2Ids,
                nameDescription: "Flow 2: Fund Sub-org.  propose, member veto, coordinator approval, execute Safe allowance."
            }));
        }

        // Shared inputParams for funding proposal (sub-org address + amount)
        string[] memory fundingParams = new string[](5);
        fundingParams[0] = "address Sub-org";
        fundingParams[1] = "address Token";
        fundingParams[2] = "uint96 AllowanceAmount";
        fundingParams[3] = "uint16 ResetTimeMin";
        fundingParams[4] = "uint32 ResetBaseMin";

        // Step 1: Propose funding
        mandateCount++;
        conditions.allowedRole = 3; // Members propose
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Propose Funding: Members propose a treasury allowance for a sub-organisation.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
            config: abi.encode(fundingParams),
            conditions: conditions
        }));
        delete conditions;

        uint16 proposeFundingId = mandateCount;

        // Step 2: Member veto (2-day window; 20% quorum, 51% of votes cast to succeed)
        mandateCount++;
        conditions.allowedRole = 3; // Members veto
        conditions.needFulfilled = proposeFundingId;
        conditions.votingPeriod = minutesToBlocks(2 * 24 * 60, helperConfig.getBlocksPerHour(block.chainid));
        conditions.quorum = 20;
        conditions.succeedAt = 51;
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Veto Funding: Members vote to block a proposed sub-org funding allocation.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
            config: abi.encode(fundingParams),
            conditions: conditions
        }));
        delete conditions;

        uint16 vetoFundingId = mandateCount;

        // Step 3: Coordinator approval (opens at day 3, 4-day voting, 51% quorum/threshold)
        mandateCount++;
        conditions.allowedRole = 2; // Parent Coordinators approve
        conditions.needFulfilled = proposeFundingId;
        conditions.needNotFulfilled = vetoFundingId;
        conditions.timelock = minutesToBlocks(3 * 24 * 60, helperConfig.getBlocksPerHour(block.chainid));
        conditions.votingPeriod = minutesToBlocks(4 * 24 * 60, helperConfig.getBlocksPerHour(block.chainid));
        conditions.quorum = 51;
        conditions.succeedAt = 51;
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Approve Funding: Coordinators vote to approve a proposed sub-org funding allocation.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
            config: abi.encode(fundingParams),
            conditions: conditions
        }));
        delete conditions;

        uint16 approveFundingId = mandateCount;

        // Step 4: Execute.  set Safe allowance for sub-org (opens at day 8)
        mandateCount++;
        conditions.allowedRole = 2; // Coordinators execute
        conditions.needFulfilled = approveFundingId;
        conditions.timelock = minutesToBlocks(8 * 24 * 60, helperConfig.getBlocksPerHour(block.chainid));
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Execute Funding: Set a Safe treasury allowance for an approved sub-organisation.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "Safe_ExecTransaction"),
            config: abi.encode(
                fundingParams,
                bytes4(0xbeaeb388), // AllowanceModule.setAllowance.selector
                helperConfig.getSafeAllowanceModule(block.chainid)
            ),
            conditions: conditions
        }));
        delete conditions;

        ////////////////////////////////////////////////////////////////////////
        //                   FLOW 3: Spawn a Sub-movement                     //
        // Member proposes → 5-day member veto → coordinator approval (2wk) → //
        // createPowers() via factory → assign Recognised Sub-org role (4).   //
        ////////////////////////////////////////////////////////////////////////
        {
            uint16[] memory flow3Ids = new uint16[](5);
            flow3Ids[0] = mandateCount + 1;
            flow3Ids[1] = mandateCount + 2;
            flow3Ids[2] = mandateCount + 3;
            flow3Ids[3] = mandateCount + 4;
            flow3Ids[4] = mandateCount + 5;
            flows.push(PowersTypes.Flow({
                mandateIds: flow3Ids,
                nameDescription: "Flow 3: Spawn Sub-movement.  propose, veto, coordinator approval, create via factory, register."
            }));
        }

        string[] memory spawnParams = new string[](1);
        spawnParams[0] = "string SubOrgName";

        // Step 1: Propose new sub-movement
        mandateCount++;
        conditions.allowedRole = 3; // Members propose
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Propose Sub-movement: Members propose spawning a new autonomous sub-organisation.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
            config: abi.encode(spawnParams),
            conditions: conditions
        }));
        delete conditions;

        uint16 proposeSpawnId = mandateCount;

        // Step 2: Member veto (5-day window)
        mandateCount++;
        conditions.allowedRole = 3;
        conditions.needFulfilled = proposeSpawnId;
        conditions.votingPeriod = minutesToBlocks(5 * 24 * 60, helperConfig.getBlocksPerHour(block.chainid));
        conditions.quorum = 20;
        conditions.succeedAt = 51;
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Veto Sub-movement: Members vote to block a proposed sub-movement from being spawned.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
            config: abi.encode(spawnParams),
            conditions: conditions
        }));
        delete conditions;

        uint16 vetoSpawnId = mandateCount;

        // Step 3: Coordinator approval (opens at day 6, 2-week voting, 51% quorum, 66% threshold)
        mandateCount++;
        conditions.allowedRole = 2;
        conditions.needFulfilled = proposeSpawnId;
        conditions.needNotFulfilled = vetoSpawnId;
        conditions.timelock = minutesToBlocks(6 * 24 * 60, helperConfig.getBlocksPerHour(block.chainid));
        conditions.votingPeriod = minutesToBlocks(14 * 24 * 60, helperConfig.getBlocksPerHour(block.chainid));
        conditions.quorum = 51;
        conditions.succeedAt = 66;
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Approve Sub-movement: Coordinators vote to approve a new sub-movement proposal.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
            config: abi.encode(spawnParams),
            conditions: conditions
        }));
        delete conditions;

        uint16 approveSpawnId = mandateCount;

        // Step 4: Create sub-org via factory (opens at 3-week timelock)
        mandateCount++;
        conditions.allowedRole = 2;
        conditions.needFulfilled = approveSpawnId;
        conditions.timelock = minutesToBlocks(21 * 24 * 60, helperConfig.getBlocksPerHour(block.chainid));
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Create Sub-org: Deploy a fully-constituted sub-movement via the factory contract.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple"),
            config: abi.encode(
                address(subOrgFactory),
                IPowersFactory.createPowers.selector,
                spawnParams // ["string SubOrgName"]
            ),
            conditions: conditions
        }));
        delete conditions;

        uint16 createSubOrgId = mandateCount;

        // Step 5: Register new sub-org as Recognised Sub-org (role 4) at parent
        // Uses return value (new child address) from the factory call above.
        // staticPrefix = abi.encode(roleId=4), return value (address) is appended.
        mandateCount++;
        conditions.allowedRole = 2;
        conditions.needFulfilled = createSubOrgId;
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Register Sub-org: Assign the Recognised Sub-org role to the newly spawned sub-movement.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_OnReturnValue"),
            config: abi.encode(
                address(powers),
                IPowers.assignRole.selector,
                abi.encode(uint256(4)),  // staticPrefix: roleId = 4
                new string[](0),          // no additional dynamic params
                createSubOrgId,           // priorMandateId: factory call
                abi.encode()              // staticSuffix: empty
            ),
            conditions: conditions
        }));
        delete conditions;

        ////////////////////////////////////////////////////////////////////////
        //                    FLOW 4: Annual Leader Election                  //
        // Members open election (once/year) → nominate → open vote →         //
        // tally (top 7 elected) → cleanup.                                   //
        ////////////////////////////////////////////////////////////////////////
        {
            uint16[] memory flow4Ids = new uint16[](5);
            flow4Ids[0] = mandateCount + 1;
            flow4Ids[1] = mandateCount + 2;
            flow4Ids[2] = mandateCount + 3;
            flow4Ids[3] = mandateCount + 4;
            flow4Ids[4] = mandateCount + 5;
            flows.push(PowersTypes.Flow({
                mandateIds: flow4Ids,
                nameDescription: "Flow 4: Annual Leader Election.  open, nominate, vote, tally, cleanup."
            }));
        }

        string[] memory electionTitleParam = new string[](1);
        electionTitleParam[0] = "string ElectionTitle";

        // Step 1: Open annual election (throttled to once per year)
        mandateCount++;
        conditions.allowedRole = 3; // any Member can trigger the annual election
        conditions.throttleExecution = minutesToBlocks(365 * 24 * 60, helperConfig.getBlocksPerHour(block.chainid));
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Open Leader Election: Open the annual leader election. Can only be called once per year.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple"),
            config: abi.encode(
                address(leaderElectionRegistry),
                ElectionRegistry.createElection.selector,
                electionTitleParam
            ),
            conditions: conditions
        }));
        delete conditions;

        uint16 openLeaderElectionId = mandateCount;

        // Step 2: Nominate for leader
        mandateCount++;
        conditions.allowedRole = 3; // Members nominate themselves
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Nominate for Leader: A member nominates themselves as a candidate in the current leader election.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "ElectionRegistry_Nominate"),
            config: abi.encode(address(leaderElectionRegistry), true),
            conditions: conditions
        }));
        delete conditions;

        // Step 3: Open voting
        mandateCount++;
        conditions.allowedRole = 3;
        conditions.needFulfilled = openLeaderElectionId;
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Open Leader Vote: Open the voting phase of the annual leader election.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "ElectionRegistry_CreateVoteMandate"),
            config: abi.encode(
                address(leaderElectionRegistry),
                registry.getMandateAddress(MAJOR, MINOR, PATCH, "ElectionRegistry_Vote"),
                uint256(1),  // max 1 vote per voter (one-account-one-vote)
                uint256(3)   // roleId allowed to vote = 3 (Members)
            ),
            conditions: conditions
        }));
        delete conditions;

        uint16 openLeaderVoteId = mandateCount;

        // Step 4: Tally election.  assigns Leader role (1) to top 7 winners
        mandateCount++;
        conditions.allowedRole = 3;
        conditions.needFulfilled = openLeaderVoteId;
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Tally Leader Election: Assign the Leader role to the top 7 election winners.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "ElectionRegistry_Tally"),
            config: abi.encode(
                address(leaderElectionRegistry),
                uint256(1), // roleId to assign = 1 (Leader)
                uint256(7)  // max 7 role holders
            ),
            conditions: conditions
        }));
        delete conditions;

        // Step 5: Cleanup.  revoke the ephemeral vote mandate
        string[] memory cleanupParams = new string[](1);
        cleanupParams[0] = "string ElectionTitle";
        mandateCount++;
        conditions.allowedRole = 3;
        conditions.needFulfilled = openLeaderVoteId;
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Cleanup Leader Election: Remove the ephemeral vote mandate after the election completes.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_OnReturnValue"),
            config: abi.encode(
                address(powers),
                IPowers.revokeMandate.selector,
                abi.encode(),   // no static prefix
                cleanupParams,
                openLeaderVoteId,
                abi.encode()    // no static suffix
            ),
            conditions: conditions
        }));
        delete conditions;

        ////////////////////////////////////////////////////////////////////////
        //                   FLOW 5: Vote of No Confidence                    //
        // Members vote (50% quorum, 66% threshold, 1 week) then execute      //
        // revocation of the named leader after 8-day timelock.               //
        ////////////////////////////////////////////////////////////////////////
        {
            uint16[] memory flow5Ids = new uint16[](2);
            flow5Ids[0] = mandateCount + 1;
            flow5Ids[1] = mandateCount + 2;
            flows.push(PowersTypes.Flow({
                mandateIds: flow5Ids,
                nameDescription: "Flow 5: Vote of No Confidence.  members vote then revoke a specific leader."
            }));
        }

        string[] memory noConfidenceParams = new string[](1);
        noConfidenceParams[0] = "address Leader";

        // Step 1: Members propose and vote
        mandateCount++;
        conditions.allowedRole = 3;
        conditions.votingPeriod = minutesToBlocks(7 * 24 * 60, helperConfig.getBlocksPerHour(block.chainid));
        conditions.quorum = 50;
        conditions.succeedAt = 66;
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Propose No-Confidence: Members vote to remove a specific leader from office.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
            config: abi.encode(noConfidenceParams),
            conditions: conditions
        }));
        delete conditions;

        uint16 noConfidenceVoteId = mandateCount;

        // Step 2: Execute revocation after 8-day timelock
        mandateCount++;
        conditions.allowedRole = 3;
        conditions.needFulfilled = noConfidenceVoteId;
        conditions.timelock = minutesToBlocks(8 * 24 * 60, helperConfig.getBlocksPerHour(block.chainid));
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Execute No-Confidence: Revoke the Leader role from the named address after a successful vote.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple"),
            config: abi.encode(
                address(powers),
                IPowers.revokeRole.selector,
                noConfidenceParams // ["address Leader"]
            ),
            conditions: conditions
        }));
        delete conditions;

        ////////////////////////////////////////////////////////////////////////
        //                  FLOW 6: Assign Parent Coordinator                 //
        // Anyone nominates themselves via Nominees helper → Leaders assign.  //
        ////////////////////////////////////////////////////////////////////////
        {
            uint16[] memory flow6Ids = new uint16[](3);
            flow6Ids[0] = mandateCount + 1;
            flow6Ids[1] = mandateCount + 2;
            flow6Ids[2] = mandateCount + 3;
            flows.push(PowersTypes.Flow({
                mandateIds: flow6Ids,
                nameDescription: "Flow 6: Assign Parent Coordinator.  nominate, leaders assign, voluntary exit."
            }));
        }

        // Step 1: Self-nominate for Coordinator (public)
        mandateCount++;
        conditions.allowedRole = type(uint256).max;
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Nominate for Coordinator: Publicly register as a candidate for the Parent Coordinator role.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "Nominate"),
            config: abi.encode(address(coordinatorNominees)),
            conditions: conditions
        }));
        delete conditions;

        // Step 2: Leaders assign Coordinator role from nominees
        string[] memory assignCoordParams = new string[](1);
        assignCoordParams[0] = "address Nominee";
        mandateCount++;
        conditions.allowedRole = 1; // Leaders only
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Assign Coordinator: Leaders assign the Parent Coordinator role to a nominated candidate.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Advanced"),
            config: abi.encode(
                address(powers),
                IPowers.assignRole.selector,
                abi.encode(uint256(2)), // staticPrefix: roleId = 2 (Parent Coordinator)
                assignCoordParams,      // dynamic: ["address Nominee"]
                abi.encode()            // staticSuffix: empty
            ),
            conditions: conditions
        }));
        delete conditions;

        // Step 3: Coordinators can resign
        mandateCount++;
        conditions.allowedRole = 2; // Coordinators only
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Resign as Coordinator: A Parent Coordinator voluntarily gives up their role.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "RenounceRole"),
            config: abi.encode(uint256(2)), // roleId = 2 (Parent Coordinator)
            conditions: conditions
        }));
        delete conditions;

        ////////////////////////////////////////////////////////////////////////
        //                   FLOW 7: Parent Governance Reform                 //
        // Leaders propose (supermajority) → Recognised Sub-orgs ratify →    //
        // 8-week timelock → Adopt_Mandates.                                  //
        ////////////////////////////////////////////////////////////////////////
        {
            uint16[] memory flow7Ids = new uint16[](3);
            flow7Ids[0] = mandateCount + 1;
            flow7Ids[1] = mandateCount + 2;
            flow7Ids[2] = mandateCount + 3;
            flows.push(PowersTypes.Flow({
                mandateIds: flow7Ids,
                nameDescription: "Flow 7: Parent Governance Reform.  leaders propose, sub-orgs ratify, execute."
            }));
        }

        // Adopt_Mandates v0.2.0 takes one full MandateInitData[]. The propose/veto/ratify
        // steps are matched to the execute step by hashing the *same* mandateCalldata, so this
        // must mirror the executor exactly or an approved proposal cannot be executed.
        string[] memory reformParams = new string[](1);
        reformParams[0] =
            "(string,address,bytes,(uint256,uint32,uint32,uint32,uint16,uint16,uint8,uint8,uint32))[] mandateInitData";

        // Step 1: Leaders propose reform (50% quorum, 66% supermajority, 2-week vote)
        mandateCount++;
        conditions.allowedRole = 1; // Leaders only
        conditions.votingPeriod = minutesToBlocks(14 * 24 * 60, helperConfig.getBlocksPerHour(block.chainid));
        conditions.quorum = 50;
        conditions.succeedAt = 66;
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Leaders Propose Reform: Leaders vote to propose a governance reform to the parent organisation.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
            config: abi.encode(reformParams),
            conditions: conditions
        }));
        delete conditions;

        uint16 leaderProposeReformId = mandateCount;

        // Step 2: Sub-org ratification (role 4 = Recognised Sub-orgs; opens 3 weeks after proposal)
        // Each sub-org calls ExternalAction_Simple from within its own governance to cast this vote.
        mandateCount++;
        conditions.allowedRole = 4; // Recognised Sub-orgs vote
        conditions.needFulfilled = leaderProposeReformId;
        conditions.timelock = minutesToBlocks(21 * 24 * 60, helperConfig.getBlocksPerHour(block.chainid));
        conditions.votingPeriod = minutesToBlocks(14 * 24 * 60, helperConfig.getBlocksPerHour(block.chainid));
        conditions.quorum = 50;
        conditions.succeedAt = 51;
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Sub-org Ratification: Recognised sub-orgs vote to ratify a proposed parent governance reform.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
            config: abi.encode(reformParams),
            conditions: conditions
        }));
        delete conditions;

        uint16 subOrgRatifyId = mandateCount;
        subOrgRatifyMandateId = subOrgRatifyId; // expose for _fixSubOrgRatificationMandate()

        // Step 3: Execute reform.  adopt new mandates (8-week timelock)
        mandateCount++;
        conditions.allowedRole = 1; // Leaders execute
        conditions.needFulfilled = subOrgRatifyId;
        conditions.timelock = minutesToBlocks(56 * 24 * 60, helperConfig.getBlocksPerHour(block.chainid));
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Execute Governance Reform: Adopt new mandates after successful leader proposal and sub-org ratification.",
            targetMandate: _latestAdoptMandates(),
            config: abi.encode(),
            conditions: conditions
        }));
        delete conditions;

        ////////////////////////////////////////////////////////////////////////
        //                  FLOW 8: Emergency Pause / Restart                 //
        // Leaders pause or restart specific execution mandates instantly.    //
        // Configured to target the funding executor and spawn executor.      //
        ////////////////////////////////////////////////////////////////////////
        {
            uint16[] memory flow8Ids = new uint16[](1);
            flow8Ids[0] = mandateCount + 1;
            flows.push(PowersTypes.Flow({
                mandateIds: flow8Ids,
                nameDescription: "Flow 8: Emergency Pause/Restart.  leaders suspend or restore key execution mandates."
            }));
        }

        // Targets: flow index 1 (funding flow), mandate index 3 (execute funding = step 4)
        //          flow index 2 (spawn flow),   mandate index 3 (create sub-org  = step 4)
        uint8[] memory pauseFlowIndexes   = new uint8[](2);
        uint8[] memory pauseMandateIndexes = new uint8[](2);
        pauseFlowIndexes[0] = 1; pauseMandateIndexes[0] = 3; // Execute Funding
        pauseFlowIndexes[1] = 2; pauseMandateIndexes[1] = 3; // Create Sub-org

        mandateCount++;
        conditions.allowedRole = 1; // Leaders only.  no voting, no timelock
        constitution.push(PowersTypes.MandateInitData({
            nameDescription: "Emergency Pause Restart: Leaders instantly pause or restart the funding and spawn execution mandates.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "PauseMandates"),
            config: abi.encode(pauseFlowIndexes, pauseMandateIndexes),
            conditions: conditions
        }));
        delete conditions;

        return constitution.length;
    }

    // ────────────────────────────────────────────────────────────────────────────
    //            PATCH: wire real parent address into sub-org factory template
    // ────────────────────────────────────────────────────────────────────────────
    // The sub-org "Send Parent Ratification" mandate (factory array index 13) was
    // built with address(0) / uint16(0) placeholders because the parent address and
    // mandate ID were not yet known when _buildSubOrgConstitution() ran.
    // This function replaces it with the real values — called after
    // _buildParentConstitution() sets subOrgRatifyMandateId and before the factory
    // ownership is transferred to the parent Powers contract.
    function _fixSubOrgRatificationMandate() internal {
        // Adopt_Mandates v0.2.0 takes one full MandateInitData[]. The propose/veto/ratify
        // steps are matched to the execute step by hashing the *same* mandateCalldata, so this
        // must mirror the executor exactly or an approved proposal cannot be executed.
        string[] memory ratifyParams = new string[](1);
        ratifyParams[0] =
            "(string,address,bytes,(uint256,uint32,uint32,uint32,uint16,uint16,uint8,uint8,uint32))[] mandateInitData";

        // Replicate the exact conditions from _buildSubOrgConstitution() Flow D step 2.
        // proposeRatifyId in the sub-org constitution is always 13 (fixed by the template).
        PowersTypes.Conditions memory c;
        c.allowedRole   = 1; // Sub-org Coordinator
        c.needFulfilled = 13; // proposeRatifyId — always index 13 in the sub-org template
        c.timelock      = minutesToBlocks(1 * 24 * 60, helperConfig.getBlocksPerHour(block.chainid));

        vm.startBroadcast();
        subOrgFactory.replaceMandate(13, PowersTypes.MandateInitData({
            nameDescription: "Sub-org: Send Parent Ratification. sub-org sends ratification vote to parent governance reform.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "ExternalAction_Simple"),
            config: abi.encode(
                address(powers),       // real parent Powers address
                subOrgRatifyMandateId, // real Sub-org Ratification mandate ID at parent
                "Sub-org ratification signal for parent governance reform.",
                ratifyParams
            ),
            conditions: c
        }));
        vm.stopBroadcast();
    }

    // ────────────────────────────────────────────────────────────────────────────
    //                      SUB-ORG CONSTITUTION (factory template)
    // ────────────────────────────────────────────────────────────────────────────
    function _buildSubOrgConstitution() internal {
        uint16 mandateCount = 0;

        ////////////////////////////////////////////////////////////////////////
        //                      SUB-ORG SETUP (mandateId = 1)                 //
        ////////////////////////////////////////////////////////////////////////
        address placeholder = address(0xDEAD); // replaced at factory deploy time with actual address
        targets = new address[](4);
        values  = new uint256[](4);
        calldatas = new bytes[](4);
        for (uint256 i = 0; i < 4; i++) targets[i] = placeholder;

        calldatas[0] = abi.encodeWithSelector(IPowers.labelRole.selector, 0, "Admin", "");
        calldatas[1] = abi.encodeWithSelector(IPowers.labelRole.selector, type(uint256).max, "Public", "");
        calldatas[2] = abi.encodeWithSelector(IPowers.labelRole.selector, 1, "Sub-org Coordinator", "");
        calldatas[3] = abi.encodeWithSelector(IPowers.labelRole.selector, 2, "Sub-org Member", "");
        // Note: revokeMandate(1) would need the actual mandate ID; factory wires this correctly.

        mandateCount++;
        conditions.allowedRole = type(uint256).max;
        subOrgConstitution.push(PowersTypes.MandateInitData({
            nameDescription: "Sub-org Setup: Assign role labels at sub-organisation initialisation.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "PresetActions"),
            config: abi.encode(targets, values, calldatas),
            conditions: conditions
        }));
        delete conditions;

        ////////////////////////////////////////////////////////////////////////
        //                   SUB-ORG FLOW A: Member Join                      //
        ////////////////////////////////////////////////////////////////////////
        {
            uint16[] memory flowAIds = new uint16[](3);
            flowAIds[0] = mandateCount + 1;
            flowAIds[1] = mandateCount + 2;
            flowAIds[2] = mandateCount + 3;
            subOrgFlows.push(PowersTypes.Flow({
                mandateIds: flowAIds,
                nameDescription: "Sub-org Flow A: Member Join.  ZK uniqueness check, self-select, voluntary exit."
            }));
        }

        string[] memory emptyParams = new string[](0);
        mandateCount++;
        conditions.allowedRole = type(uint256).max;
        subOrgConstitution.push(PowersTypes.MandateInitData({
            nameDescription: "Sub-org: Verify Unique Identity.  ZK-passport proof of uniqueness required to join.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "ZKPassport_Check"),
            config: abi.encode(
                emptyParams,
                helperConfig.getZkPassportRegistry(block.chainid),
                uint256(365 * 24 * 3600),
                false,
                bytes4(keccak256("isAgeAbove(uint8)")),
                abi.encode(uint8(0))
            ),
            conditions: conditions
        }));
        delete conditions;

        uint16 subZkCheckId = mandateCount;

        mandateCount++;
        conditions.allowedRole = type(uint256).max;
        conditions.needFulfilled = subZkCheckId;
        subOrgConstitution.push(PowersTypes.MandateInitData({
            nameDescription: "Sub-org: Join as Member.  self-select after passing ZK-passport uniqueness check.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "SelfSelect"),
            config: abi.encode(uint256(2)), // roleId = 2 (Sub-org Member)
            conditions: conditions
        }));
        delete conditions;

        mandateCount++;
        conditions.allowedRole = 2;
        subOrgConstitution.push(PowersTypes.MandateInitData({
            nameDescription: "Sub-org: Leave Sub-org.  a Sub-org Member voluntarily renounces their membership.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "RenounceRole"),
            config: abi.encode(uint256(2)),
            conditions: conditions
        }));
        delete conditions;

        ////////////////////////////////////////////////////////////////////////
        //               SUB-ORG FLOW B: Local Spending                       //
        ////////////////////////////////////////////////////////////////////////
        {
            uint16[] memory flowBIds = new uint16[](3);
            flowBIds[0] = mandateCount + 1;
            flowBIds[1] = mandateCount + 2;
            flowBIds[2] = mandateCount + 3;
            subOrgFlows.push(PowersTypes.Flow({
                mandateIds: flowBIds,
                nameDescription: "Sub-org Flow B: Local Spending.  member proposes, coordinator approves, execute transfer."
            }));
        }

        string[] memory spendingParams = new string[](3);
        spendingParams[0] = "address Token";
        spendingParams[1] = "uint256 Amount";
        spendingParams[2] = "address PayableTo";

        mandateCount++;
        conditions.allowedRole = 2; // Sub-org Members propose
        subOrgConstitution.push(PowersTypes.MandateInitData({
            nameDescription: "Sub-org: Propose Spending.  members propose spending from the sub-org treasury allowance.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
            config: abi.encode(spendingParams),
            conditions: conditions
        }));
        delete conditions;

        uint16 proposeSpendingId = mandateCount;

        mandateCount++;
        conditions.allowedRole = 1; // Sub-org Coordinators approve
        conditions.needFulfilled = proposeSpendingId;
        conditions.votingPeriod = minutesToBlocks(7 * 24 * 60, helperConfig.getBlocksPerHour(block.chainid));
        conditions.quorum = 51;
        conditions.succeedAt = 51;
        subOrgConstitution.push(PowersTypes.MandateInitData({
            nameDescription: "Sub-org: Approve Spending.  coordinators vote to approve a local spending proposal.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
            config: abi.encode(spendingParams),
            conditions: conditions
        }));
        delete conditions;

        uint16 approveSpendingId = mandateCount;

        mandateCount++;
        conditions.allowedRole = 1;
        conditions.needFulfilled = approveSpendingId;
        conditions.timelock = minutesToBlocks(2 * 24 * 60, helperConfig.getBlocksPerHour(block.chainid));
        subOrgConstitution.push(PowersTypes.MandateInitData({
            nameDescription: "Sub-org: Execute Spending.  transfer tokens from Safe allowance to approved recipient.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "SafeAllowance_Transfer"),
            config: abi.encode(
                helperConfig.getSafeAllowanceModule(block.chainid),
                address(0) // Safe proxy address.  set at sub-org deployment time
            ),
            conditions: conditions
        }));
        delete conditions;

        ////////////////////////////////////////////////////////////////////////
        //              SUB-ORG FLOW C: Coordinator Election                  //
        ////////////////////////////////////////////////////////////////////////
        {
            uint16[] memory flowCIds = new uint16[](5);
            flowCIds[0] = mandateCount + 1;
            flowCIds[1] = mandateCount + 2;
            flowCIds[2] = mandateCount + 3;
            flowCIds[3] = mandateCount + 4;
            flowCIds[4] = mandateCount + 5;
            subOrgFlows.push(PowersTypes.Flow({
                mandateIds: flowCIds,
                nameDescription: "Sub-org Flow C: Coordinator Election.  open, nominate, vote, tally, cleanup."
            }));
        }

        string[] memory subElectionParam = new string[](1);
        subElectionParam[0] = "string ElectionTitle";

        mandateCount++;
        conditions.allowedRole = 2;
        conditions.throttleExecution = minutesToBlocks(180 * 24 * 60, helperConfig.getBlocksPerHour(block.chainid));
        subOrgConstitution.push(PowersTypes.MandateInitData({
            nameDescription: "Sub-org: Open Coordinator Election.  open the bi-annual coordinator election.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple"),
            config: abi.encode(
                address(subOrgElectionRegistry),
                ElectionRegistry.createElection.selector,
                subElectionParam
            ),
            conditions: conditions
        }));
        delete conditions;

        uint16 openSubElectionId = mandateCount;

        mandateCount++;
        conditions.allowedRole = 2;
        subOrgConstitution.push(PowersTypes.MandateInitData({
            nameDescription: "Sub-org: Nominate for Coordinator.  self-nominate as a coordinator candidate.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "ElectionRegistry_Nominate"),
            config: abi.encode(address(subOrgElectionRegistry), true),
            conditions: conditions
        }));
        delete conditions;

        mandateCount++;
        conditions.allowedRole = 2;
        conditions.needFulfilled = openSubElectionId;
        subOrgConstitution.push(PowersTypes.MandateInitData({
            nameDescription: "Sub-org: Open Coordinator Vote.  open the voting phase for the coordinator election.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "ElectionRegistry_CreateVoteMandate"),
            config: abi.encode(
                address(subOrgElectionRegistry),
                registry.getMandateAddress(MAJOR, MINOR, PATCH, "ElectionRegistry_Vote"),
                uint256(1), // max 1 vote per voter
                uint256(2)  // roleId to vote = 2 (Sub-org Members)
            ),
            conditions: conditions
        }));
        delete conditions;

        uint16 openSubVoteId = mandateCount;

        mandateCount++;
        conditions.allowedRole = 2;
        conditions.needFulfilled = openSubVoteId;
        subOrgConstitution.push(PowersTypes.MandateInitData({
            nameDescription: "Sub-org: Tally Coordinator Election.  assign Sub-org Coordinator role to election winners.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "ElectionRegistry_Tally"),
            config: abi.encode(
                address(subOrgElectionRegistry),
                uint256(1), // roleId = 1 (Sub-org Coordinator)
                uint256(5)  // max 5 coordinators per sub-org
            ),
            conditions: conditions
        }));
        delete conditions;

        string[] memory cleanupSubParams = new string[](1);
        cleanupSubParams[0] = "string ElectionTitle";
        mandateCount++;
        conditions.allowedRole = 2;
        conditions.needFulfilled = openSubVoteId;
        subOrgConstitution.push(PowersTypes.MandateInitData({
            nameDescription: "Sub-org: Cleanup Coordinator Election.  remove ephemeral vote mandate after election.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_OnReturnValue"),
            config: abi.encode(
                address(0), // placeholder.  actual sub-org address at deployment
                IPowers.revokeMandate.selector,
                abi.encode(),
                cleanupSubParams,
                openSubVoteId,
                abi.encode()
            ),
            conditions: conditions
        }));
        delete conditions;

        ////////////////////////////////////////////////////////////////////////
        //              SUB-ORG FLOW D: Ratify Parent Reform                  //
        // Coordinators vote internally → ExternalAction sends ratification   //
        // signal to parent org's Sub-org Ratification mandate.               //
        ////////////////////////////////////////////////////////////////////////
        {
            uint16[] memory flowDIds = new uint16[](2);
            flowDIds[0] = mandateCount + 1;
            flowDIds[1] = mandateCount + 2;
            subOrgFlows.push(PowersTypes.Flow({
                mandateIds: flowDIds,
                nameDescription: "Sub-org Flow D: Ratify Parent Reform.  coordinators vote, then signal ratification to parent."
            }));
        }

        // Adopt_Mandates v0.2.0 takes one full MandateInitData[]. The propose/veto/ratify
        // steps are matched to the execute step by hashing the *same* mandateCalldata, so this
        // must mirror the executor exactly or an approved proposal cannot be executed.
        string[] memory ratifyParams = new string[](1);
        ratifyParams[0] =
            "(string,address,bytes,(uint256,uint32,uint32,uint32,uint16,uint16,uint8,uint8,uint32))[] mandateInitData";

        mandateCount++;
        conditions.allowedRole = 1; // Sub-org Coordinators
        conditions.votingPeriod = minutesToBlocks(7 * 24 * 60, helperConfig.getBlocksPerHour(block.chainid));
        conditions.quorum = 51;
        conditions.succeedAt = 51;
        subOrgConstitution.push(PowersTypes.MandateInitData({
            nameDescription: "Sub-org: Propose Parent Ratification.  coordinators vote to authorise ratifying a parent reform.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
            config: abi.encode(ratifyParams),
            conditions: conditions
        }));
        delete conditions;

        uint16 proposeRatifyId = mandateCount;

        // ExternalAction_Simple targets the parent's Sub-org Ratification mandate.
        // The parent Powers address and mandateId are baked in at factory pre-load time.
        // Here we use address(0) as placeholder.  the factory owner must update this
        // before the factory is used in production via replaceMandate().
        mandateCount++;
        conditions.allowedRole = 1;
        conditions.needFulfilled = proposeRatifyId;
        conditions.timelock = minutesToBlocks(1 * 24 * 60, helperConfig.getBlocksPerHour(block.chainid));
        subOrgConstitution.push(PowersTypes.MandateInitData({
            nameDescription: "Sub-org: Send Parent Ratification.  sub-org sends ratification vote to parent governance reform.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "ExternalAction_Simple"),
            config: abi.encode(
                address(0),   // placeholder: parent Powers address (set before factory goes live)
                uint16(0),    // placeholder: parent sub-org ratification mandate ID (set before factory goes live)
                "Sub-org ratification signal for parent governance reform.",
                ratifyParams
            ),
            conditions: conditions
        }));
        delete conditions;

        ////////////////////////////////////////////////////////////////////////
        //              SUB-ORG FLOW E: Local Governance Reform               //
        ////////////////////////////////////////////////////////////////////////
        {
            uint16[] memory flowEIds = new uint16[](2);
            flowEIds[0] = mandateCount + 1;
            flowEIds[1] = mandateCount + 2;
            subOrgFlows.push(PowersTypes.Flow({
                mandateIds: flowEIds,
                nameDescription: "Sub-org Flow E: Local Governance Reform.  coordinators propose and adopt new mandates."
            }));
        }

        // Adopt_Mandates v0.2.0 takes one full MandateInitData[]. The propose/veto/ratify
        // steps are matched to the execute step by hashing the *same* mandateCalldata, so this
        // must mirror the executor exactly or an approved proposal cannot be executed.
        string[] memory localReformParams = new string[](1);
        localReformParams[0] =
            "(string,address,bytes,(uint256,uint32,uint32,uint32,uint16,uint16,uint8,uint8,uint32))[] mandateInitData";

        mandateCount++;
        conditions.allowedRole = 1; // Coordinators propose
        conditions.votingPeriod = minutesToBlocks(14 * 24 * 60, helperConfig.getBlocksPerHour(block.chainid));
        conditions.quorum = 51;
        conditions.succeedAt = 66;
        subOrgConstitution.push(PowersTypes.MandateInitData({
            nameDescription: "Sub-org: Propose Local Reform.  coordinators vote to propose a local governance change.",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
            config: abi.encode(localReformParams),
            conditions: conditions
        }));
        delete conditions;

        uint16 proposeLocalReformId = mandateCount;

        mandateCount++;
        conditions.allowedRole = 1;
        conditions.needFulfilled = proposeLocalReformId;
        conditions.timelock = minutesToBlocks(21 * 24 * 60, helperConfig.getBlocksPerHour(block.chainid));
        subOrgConstitution.push(PowersTypes.MandateInitData({
            nameDescription: "Sub-org: Execute Local Reform.  adopt new mandates after a successful coordinator vote.",
            targetMandate: _latestAdoptMandates(),
            config: abi.encode(),
            conditions: conditions
        }));
        delete conditions;
    }

    /// @notice Adopt_Mandates is at version 0.2.0 (full MandateInitData payload), not the
    /// repo-wide (MAJOR, MINOR, PATCH) pin used for the other mandates.
    function _latestAdoptMandates() internal view returns (address) {
        (uint16 major, uint16 minor, uint16 patch) = registry.getLatestVersion("Adopt_Mandates");
        return registry.getMandateAddress(major, minor, patch, "Adopt_Mandates");
    }
}
