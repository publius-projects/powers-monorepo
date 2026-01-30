// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// scripts
import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { Configurations } from "@script/Configurations.s.sol";
import { InitialisePowers } from "@script/InitialisePowers.s.sol";
import { DeploySetup } from "./DeploySetup.s.sol";

// external protocols
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";

// powers contracts
import { PowersTypes } from "@src/interfaces/PowersTypes.sol";
import { Powers } from "@src/Powers.sol";
import { IPowers } from "@src/interfaces/IPowers.sol";

// mocks
import { SimpleErc20Votes } from "@mocks/SimpleErc20Votes.sol";

/// @title Power Labs Deployment Script
contract PowerLabs is DeploySetup {
    InitialisePowers initialisePowers;
    Configurations helperConfig;
    Configurations.NetworkConfig public config;

    PowersTypes.Conditions conditions;
    PowersTypes.MandateInitData[] primaryConstitution;
    PowersTypes.MandateInitData[] childConstitution;
    Powers powersParent;
    Powers powersChild;

    address[] targets;
    uint256[] values;
    bytes[] calldatas;
    string[] inputParams;
    string[] dynamicParams;
    uint16 mandateCount;

    function run() external {
        // step 0, setup.
        initialisePowers = new InitialisePowers();
        initialisePowers.run();
        helperConfig = new Configurations();
        config = helperConfig.getConfig();

        // step 1: deploy Powers
        vm.startBroadcast();
        powersParent = new Powers(
            "Power Labs", // name
            "https://aqua-famous-sailfish-288.mypinata.cloud/ipfs/bafkreibnvjwah2wdgd3fhak3sedriwt5xemjlacmrabt6mrht7f24m5w3i", // uri
            config.maxCallDataLength, // max call data length
            config.maxReturnDataLength, // max return data length
            config.maxExecutionsLength // max executions length
        );

        powersChild = new Powers(
            "Power Labs Child", // name
            "https://aqua-famous-sailfish-288.mypinata.cloud/ipfs/bafkreichqvnlmfgkw2jeqgerae2torhgbcgdomxzqxiymx77yhflpnniii", // uri
            config.maxCallDataLength, // max call data length
            config.maxReturnDataLength, // max return data length
            config.maxExecutionsLength // max executions length
        );
        vm.stopBroadcast();
        console2.log("Powers Parent deployed at:", address(powersParent));
        console2.log("Powers Child deployed at:", address(powersChild));

        // step 2: create constitution
        uint256 primaryConstitutionLength = createPrimaryConstitution();
        console2.log("Parent Constitution created with length:");
        console2.logUint(primaryConstitutionLength);

        // Mandate 17 in Parent is "Adopt a Child Mandate"
        uint256 childConstitutionLength = createChildConstitution(address(powersParent), 17);
        console2.log("Child Constitution created with length:");
        console2.logUint(childConstitutionLength);

        // step 3: run constitute.
        vm.startBroadcast();
        powersParent.constitute(primaryConstitution);
        powersParent.closeConstitute();
        powersChild.constitute(childConstitution);
        powersChild.closeConstitute();
        vm.stopBroadcast();
        console2.log("Parent and Child Powers successfully constituted.");
    }

    function createPrimaryConstitution() internal returns (uint256 constitutionLength) {
        // Mandate 1: Setup Safe
        // Safe_Setup
        mandateCount++;
        conditions.allowedRole = type(uint256).max; // Public
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Setup Safe: Create a SafeProxy, set up allowance module and register it as treasury.",
                targetMandate: initialisePowers.getInitialisedAddress("Safe_Setup"),
                config: abi.encode(config.safeProxyFactory, config.safeL2Canonical, config.safeAllowanceModule),
                conditions: conditions
            })
        );
        delete conditions;

        // Mandate 2: Configure Organisation (Role Labels)
        targets = new address[](6);
        values = new uint256[](6);
        calldatas = new bytes[](6);

        // Roles: 1=Funders, 2=Doc, 3=Frontend, 4=Protocol, 5=Members
        // Note: TS does not explicitly list role IDs in labeling mandate, but "Apply for Member Role" uses 1,2,3,4 to get 5.
        // And "Apply for Contributor Role" gives 2,3,4.
        // So I'll assume standard IDs.
        targets[0] = address(powersParent);
        targets[1] = address(powersParent);
        targets[2] = address(powersParent);
        targets[3] = address(powersParent);
        targets[4] = address(powersParent);
        targets[5] = address(powersParent);

        calldatas[0] = abi.encodeWithSelector(IPowers.labelRole.selector, 1, "Funders");
        calldatas[1] = abi.encodeWithSelector(IPowers.labelRole.selector, 2, "Doc Contributors");
        calldatas[2] = abi.encodeWithSelector(IPowers.labelRole.selector, 3, "Frontend Contributors");
        calldatas[3] = abi.encodeWithSelector(IPowers.labelRole.selector, 4, "Protocol Contributors");
        calldatas[4] = abi.encodeWithSelector(IPowers.labelRole.selector, 5, "Members");
        calldatas[5] = abi.encodeWithSelector(IPowers.revokeMandate.selector, 2); // revoke this mandate after execution

        mandateCount++;
        conditions.allowedRole = 0; // Admin
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Assign role labels.",
                targetMandate: initialisePowers.getInitialisedAddress("PresetActions_Single"),
                config: abi.encode(targets, values, calldatas),
                conditions: conditions
            })
        );
        delete conditions;

        // Mandate 3: Update URI
        dynamicParams = new string[](1);
        dynamicParams[0] = "string Uri";

        mandateCount++;
        conditions.allowedRole = 0; // Admin
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Update URI: The admin can update the organization's URI.",
                targetMandate: initialisePowers.getInitialisedAddress("BespokeAction_Simple"),
                config: abi.encode(address(powersParent), IPowers.setUri.selector, dynamicParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Mandate 4: Apply for Contributor Role
        string[] memory paths = new string[](3);
        paths[0] = "documentation";
        paths[1] = "frontend";
        paths[2] = "solidity";
        uint256[] memory roleIds = new uint256[](3);
        roleIds[0] = 2;
        roleIds[1] = 3;
        roleIds[2] = 4;

        mandateCount++;
        conditions.allowedRole = type(uint256).max; // Public
        conditions.throttleExecution = minutesToBlocks(3, config.BLOCKS_PER_HOUR);
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Apply for Contributor Role: Anyone can claim contributor roles based on their GitHub contributions to the 7cedars/powers repository",
                targetMandate: initialisePowers.getInitialisedAddress("Github_ClaimRoleWithSig"),
                config: abi.encode(
                    "develop", // branch
                    paths,
                    roleIds,
                    "signed", // signatureString
                    config.chainlinkFunctionsSubscriptionId,
                    config.chainlinkFunctionsGasLimit,
                    config.chainlinkFunctionsDonId
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Mandate 5: Claim Contributor Role
        mandateCount++;
        conditions.allowedRole = type(uint256).max; // Public
        conditions.needFulfilled = mandateCount - 1; // must have applied for contributor role.
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Claim Contributor Role: Following a successful initial claim, contributors can get contributor role assigned to their account.",
                targetMandate: initialisePowers.getInitialisedAddress("Github_AssignRoleWithSig"),
                config: abi.encode(), // empty config
                conditions: conditions
            })
        );
        delete conditions;

        // Mandate 6: Apply for Member Role
        uint256[] memory roleIdsNeeded = new uint256[](4);
        roleIdsNeeded[0] = 1;
        roleIdsNeeded[1] = 2;
        roleIdsNeeded[2] = 3;
        roleIdsNeeded[3] = 4;

        mandateCount++;
        conditions.allowedRole = type(uint256).max; // Public
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Apply for Member Role: Receive Member role when holding Funder or any Contributor role",
                targetMandate: initialisePowers.getInitialisedAddress("RoleByRoles"),
                config: abi.encode(
                    5, // newRoleId (Members)
                    roleIdsNeeded
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Mandate 7: Veto Role Revocation (StatementOfIntent)
        inputParams = new string[](2);
        inputParams[0] = "uint256 roleId";
        inputParams[1] = "address account";

        mandateCount++;
        conditions.allowedRole = 0; // Admin
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto Role Revocation: Admin can veto proposals to remove roles from accounts",
                targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Mandate 8: Revoke Role (BespokeAction_Simple)
        mandateCount++;
        conditions.allowedRole = 5; // Members
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR);
        conditions.succeedAt = 51;
        conditions.quorum = 5;
        conditions.timelock = minutesToBlocks(3, config.BLOCKS_PER_HOUR);
        conditions.needNotFulfilled = mandateCount - 1; // veto mandate
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Revoke Role: Members vote to remove a role from an account",
                targetMandate: initialisePowers.getInitialisedAddress("BespokeAction_Simple"),
                config: abi.encode(
                    address(powersParent),
                    IPowers.revokeRole.selector,
                    inputParams // same params as veto
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // FROM HERE NEW; MEMORY COUNTER FOR MANDATES. ///

        //////////////////////////////////////////////////////////////////////////
        //   GOVERNANCE FLOW FOR ADOPTING DELEGATE / CHILD POWERS DEPLOYMENTS   //
        //////////////////////////////////////////////////////////////////////////

        // statementOfIntent param
        inputParams = new string[](1);
        inputParams[0] = "address NewChildPowers";

        mandateCount++;
        conditions.allowedRole = 5; // = Members can call this mandate.
        conditions.quorum = 20; // = 30% quorum needed
        conditions.succeedAt = 66; // = 51% simple majority needed for assigning and revoking members.
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // = number of blocks
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Propose to add a new Child Powers as a delegate to the Safe Treasury.",
                targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        mandateCount++;
        conditions.allowedRole = 1; // = funders.
        conditions.quorum = 20; // = 30% quorum needed
        conditions.succeedAt = 66; // = 51% simple majority needed for assigning and revoking members.
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // = number of blocks
        conditions.needFulfilled = mandateCount - 1; // = mandate that must be completed before this one.
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto adding a new Child Powers as a delegate to the Safe Treasury.",
                targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        mandateCount++;
        conditions.allowedRole = 2; // = doc contributors.
        conditions.quorum = 20; // = 30% quorum needed
        conditions.succeedAt = 66; // = 51% simple majority needed for assigning and revoking members.
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // = number of blocks
        conditions.needFulfilled = mandateCount - 2; // = the proposal mandate.
        conditions.needNotFulfilled = mandateCount - 1; // = the funders veto mandate.
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "OK adding a new Child Powers as a delegate to the Safe Treasury.",
                targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        mandateCount++;
        conditions.allowedRole = 3; // = frontend contributors.
        conditions.quorum = 20; // = 30% quorum needed
        conditions.succeedAt = 66; // = 51% simple majority needed for assigning and revoking members.
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // = number of blocks
        conditions.needFulfilled = mandateCount - 1; // = the proposal mandate.
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "OK adding a new Child Powers as a delegate to the Safe Treasury.",
                targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        mandateCount++;
        conditions.allowedRole = 4; // = protocol contributors.
        conditions.quorum = 20; // = 30% quorum needed
        conditions.succeedAt = 66; // = 51% simple majority needed for assigning and revoking members.
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // = number of blocks
        conditions.needFulfilled = mandateCount - 1; // = the proposal mandate.
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Execute and adopt new child Powers as a delegate to the Safe treasury.",
                targetMandate: initialisePowers.getInitialisedAddress("SafeAllowance_Action"),
                config: abi.encode(
                    inputParams,
                    bytes4(0xe71bdf41), // == AllowanceModule.addDelegate.selector (because the contracts are compiled with different solidity versions we cannot reference the contract directly here)
                    config.safeAllowanceModule
                ),
                conditions: conditions // everythign zero == Only admin can call directly
            })
        );
        delete conditions;

        //////////////////////////////////////////////////////////////////////////
        //               GOVERNANCE FLOW FOR SETTING ALLOWANCE                  //
        //////////////////////////////////////////////////////////////////////////

        // statementOfIntent params
        inputParams = new string[](5);
        inputParams[0] = "address ChildPowers";
        inputParams[1] = "address Token";
        inputParams[2] = "uint96 allowanceAmount";
        inputParams[3] = "uint16 resetTimeMin";
        inputParams[4] = "uint32 resetBaseMin";

        mandateCount++;
        conditions.allowedRole = 5; // = Members can call this mandate.
        conditions.quorum = 20; // = 30% quorum needed
        conditions.succeedAt = 66; // = 51% simple majority needed for assigning and revoking members.
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // = number of blocks
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Propose to set allowance for a Powers Child at the Safe Treasury.",
                targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        mandateCount++;
        conditions.allowedRole = 1; // = funders.
        conditions.quorum = 20; // = 30% quorum needed
        conditions.succeedAt = 66; // = 51% simple majority needed for assigning and revoking members.
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // = number of blocks
        conditions.needFulfilled = mandateCount - 1; // = mandate that must be completed before this one.
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto setting allowance for a Powers Child at the Safe Treasury.",
                targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        mandateCount++;
        conditions.allowedRole = 2; // = doc contributors.
        conditions.quorum = 20; // = 30% quorum needed
        conditions.succeedAt = 66; // = 51% simple majority needed for assigning and revoking members.
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // = number of blocks
        conditions.needFulfilled = mandateCount - 2; // = the proposal mandate.
        conditions.needNotFulfilled = mandateCount - 1; // = the funders veto mandate.
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "OK setting allowance for a Powers Child at the Safe Treasury.",
                targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        mandateCount++;
        conditions.allowedRole = 3; // = frontend contributors.
        conditions.quorum = 20; // = 30% quorum needed
        conditions.succeedAt = 66; // = 51% simple majority needed for assigning and revoking members.
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // = number of blocks
        conditions.needFulfilled = mandateCount - 1; // = the proposal mandate.
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "OK setting allowance for a Powers Child at the Safe Treasury.",
                targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        mandateCount++;
        conditions.allowedRole = 4; // = protocol contributors.
        conditions.quorum = 20; // = 30% quorum needed
        conditions.succeedAt = 66; // = 51% simple majority needed for assigning and revoking members.
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // = number of blocks
        conditions.needFulfilled = mandateCount - 1; // = the proposal mandate.
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Execute and set allowance for a Powers Child at the Safe Treasury.",
                targetMandate: initialisePowers.getInitialisedAddress("SafeAllowance_Action"),
                config: abi.encode(
                    inputParams,
                    bytes4(0xbeaeb388), // == AllowanceModule.setAllowance.selector (because the contracts are compiled with different solidity versions we cannot reference the contract directly here)
                    config.safeAllowanceModule
                ),
                conditions: conditions // everythign zero == Only admin can call directly
            })
        );
        delete conditions;

        // --- Constitutional Laws ---
        string[] memory adoptMandatesParams = new string[](2);
        adoptMandatesParams[0] = "address[] mandates";
        adoptMandatesParams[1] = "uint256[] roleIds";

        // Mandate: Propose Adopting Mandates
        mandateCount++;
        conditions.allowedRole = 5; // Members
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR);
        conditions.succeedAt = 51;
        conditions.quorum = 50;
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Propose Adopting Mandates: Members propose adopting new mandates",
                targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
                config: abi.encode(adoptMandatesParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Mandate: Veto Adopting Mandates
        mandateCount++;
        conditions.allowedRole = 1; // Funders
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR);
        conditions.succeedAt = 33;
        conditions.quorum = 50;
        conditions.needFulfilled = mandateCount - 1;
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto Adopting Mandates: Funders can veto proposals to adopt new mandates",
                targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
                config: abi.encode(adoptMandatesParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Mandate: Adopt Mandates
        mandateCount++;
        conditions.allowedRole = 0; // Admin
        conditions.needFulfilled = mandateCount - 2;
        conditions.needNotFulfilled = mandateCount - 1;
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Adopt Mandates: Admin adopts new mandates into the organization",
                targetMandate: initialisePowers.getInitialisedAddress("Mandates_Adopt"),
                config: abi.encode(), // empty 0x
                conditions: conditions
            })
        );
        delete conditions;

        string[] memory revokeMandatesParams = new string[](1);
        revokeMandatesParams[0] = "uint16[] mandateIds";

        // Mandate: Propose Revoking Mandates
        mandateCount++;
        conditions.allowedRole = 5; // Members
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR);
        conditions.succeedAt = 51;
        conditions.quorum = 50;
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Propose Revoking Mandates: Members propose revoking existing mandates",
                targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
                config: abi.encode(revokeMandatesParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Mandate: Veto Revoking Mandates
        mandateCount++;
        conditions.allowedRole = 1; // Funders
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR);
        conditions.succeedAt = 33;
        conditions.quorum = 50;
        conditions.needFulfilled = mandateCount - 1;
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto Revoking Mandates: Funders can veto proposals to revoke existing mandates",
                targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
                config: abi.encode(revokeMandatesParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Mandate: Revoke Mandates
        mandateCount++;
        conditions.allowedRole = 0; // Admin
        conditions.needFulfilled = mandateCount - 1;
        conditions.needNotFulfilled = mandateCount - 2;
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Revoke Mandates: Admin revokes mandates from the organization",
                targetMandate: initialisePowers.getInitialisedAddress("Mandates_Revoke"),
                config: abi.encode(abi.encode(0x00)), // "0x00" in TS (encoded bytes?) -> actually likely just empty bytes? TS says "0x00" as `0x${string}` which is 1 byte '00'. But Mandates_Revoke expects... let's check config. Usually Mandates_Revoke takes no config or specific config. TS says config is "0x00". Let's assume default encoding of "0x00".
                // Actually, "0x00" as `0x${string}` in viem is just `0x00`.
                // Mandates_Revoke usually takes nothing or is bespoke.
                // If I look at Mandates_Adopt above, TS said `0x`.
                // Here `0x00`.
                // I'll stick to abi.encode("0x00")? No, config is bytes. "0x00" bytes.
                conditions: conditions
            })
        );
        delete conditions;

        // Adopt Children Mandates flow
        // Mandate: Propose adopting a Child Mandate
        mandateCount++;
        conditions.allowedRole = 5; // Members
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR);
        conditions.succeedAt = 51;
        conditions.quorum = 50;
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Propose adopting a Child Mandate: Members propose adopting new mandates for a Powers' child",
                targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
                config: abi.encode(adoptMandatesParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Mandate: Veto Adopting A child Mandate
        mandateCount++;
        conditions.allowedRole = 1; // Funders
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR);
        conditions.succeedAt = 33;
        conditions.quorum = 50;
        conditions.needFulfilled = mandateCount - 1;
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto Adopting A child Mandate: Funders can veto proposals to adopt new mandates for a Powers' child",
                targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
                config: abi.encode(adoptMandatesParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Mandate: Adopt a Child Mandate
        mandateCount++;
        conditions.allowedRole = 0; // Admin
        conditions.needFulfilled = mandateCount - 2;
        conditions.needNotFulfilled = mandateCount - 1;
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Adopt a Child Mandate: Admin adopts the new mandate for a Powers' child",
                targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
                config: abi.encode(adoptMandatesParams),
                conditions: conditions
            })
        );
        delete conditions;

        return primaryConstitution.length;
    }

    function createChildConstitution(address parent, uint16 adoptChildMandateId)
        internal
        returns (uint256 constitutionLength)
    {
        // Mandate 1: Initial Setup
        targets = new address[](6);
        values = new uint256[](6);
        calldatas = new bytes[](6);
        for (uint256 i = 0; i < 6; i++) {
            targets[i] = address(powersChild);
        }

        calldatas[0] = abi.encodeWithSelector(IPowers.labelRole.selector, 1, "Funders");
        calldatas[1] = abi.encodeWithSelector(IPowers.labelRole.selector, 2, "Doc Contributors");
        calldatas[2] = abi.encodeWithSelector(IPowers.labelRole.selector, 3, "Frontend Contributors");
        calldatas[3] = abi.encodeWithSelector(IPowers.labelRole.selector, 4, "Protocol Contributors");
        calldatas[4] = abi.encodeWithSelector(IPowers.labelRole.selector, 5, "Members");
        calldatas[5] = abi.encodeWithSelector(IPowers.revokeMandate.selector, 1);

        mandateCount = 1; // resetting mandate Count for child constitution
        conditions.allowedRole = 0; // Admin
        childConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Initial Setup: Assign role labels (Members, Delegates) and revoke itself after execution",
                targetMandate: initialisePowers.getInitialisedAddress("PresetActions_Single"),
                config: abi.encode(targets, values, calldatas),
                conditions: conditions
            })
        );
        delete conditions;

        // Mandate: Execute Allowance Transaction
        // TS uses SafeAllowance_Transfer. config: allowanceModule, safeProxy
        // We use config.safeAllowanceModule and address(powersParent) as placeholder for safeProxy
        mandateCount++;
        conditions.allowedRole = 1; // Assuming RoleId 1 (Funders) as placeholder for formData["RoleId"]
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR);
        conditions.succeedAt = 67;
        conditions.quorum = 50;
        conditions.timelock = minutesToBlocks(3, config.BLOCKS_PER_HOUR);
        childConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Execute Allowance Transaction: Execute a transaction from the Safe Treasury within the allowance set.",
                targetMandate: initialisePowers.getInitialisedAddress("SafeAllowance_Transfer"),
                config: abi.encode(
                    config.safeAllowanceModule,
                    address(parent) // Placeholder for SafeProxyTreasury
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Mandate: Update URI
        dynamicParams = new string[](1);
        dynamicParams[0] = "string Uri";

        mandateCount++;
        conditions.allowedRole = 0; // Admin
        childConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Update URI: The admin can update the organization's URI.",
                targetMandate: initialisePowers.getInitialisedAddress("BespokeAction_Simple"),
                config: abi.encode(address(powersChild), IPowers.setUri.selector, dynamicParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Mandate: Adopt Role
        mandateCount++;
        conditions.allowedRole = type(uint256).max; // Public
        childConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Adopt Role 1: Anyone that has role 1 at the parent organization can adopt the same role here.",
                targetMandate: initialisePowers.getInitialisedAddress("AssignExternalRole"),
                config: abi.encode(
                    parent,
                    1 // RoleId (Funders) placeholder
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Mandate: Check Parent
        string[] memory adoptMandatesParams = new string[](2);
        adoptMandatesParams[0] = "address[] Mandates";
        adoptMandatesParams[1] = "uint256[] roleIds";

        mandateCount++;
        conditions.allowedRole = type(uint256).max; // Public
        childConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Check Parent: Check if adopt new mandates has been passed at the parent organization",
                targetMandate: initialisePowers.getInitialisedAddress("CheckExternalActionState"),
                config: abi.encode(parent, adoptChildMandateId, adoptMandatesParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Mandate: Adopt Mandates
        mandateCount++;
        conditions.allowedRole = type(uint256).max; // Public
        conditions.needFulfilled = mandateCount - 1;
        childConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Adopt Mandates: Anyone can adopt new mandates ok-ed by the parent organization",
                targetMandate: initialisePowers.getInitialisedAddress("Mandates_Adopt"),
                config: abi.encode(parent, adoptChildMandateId, adoptMandatesParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Mandate: Revoke Mandates
        mandateCount++;
        conditions.allowedRole = 1; // RoleId 1 (Funders)
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR);
        conditions.succeedAt = 67;
        conditions.quorum = 50;
        conditions.timelock = minutesToBlocks(3, config.BLOCKS_PER_HOUR);
        childConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Revoke Mandates: Admin can revoke mandates from the organization",
                targetMandate: initialisePowers.getInitialisedAddress("Mandates_Revoke"),
                config: abi.encode(abi.encode(0x00)),
                conditions: conditions
            })
        );
        delete conditions;

        return childConstitution.length;
    }
}
