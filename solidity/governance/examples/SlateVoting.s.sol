// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// scripts
import { console2 } from "forge-std/console2.sol";
import { Configurations } from "@script/Configurations.s.sol";
import { DeployHelpers } from "../DeployHelpers.s.sol";
import { IMandateRegistry } from "@src/core/helpers/MandateRegistry.sol";

// powers contracts
import { PowersTypes } from "@src/interfaces/PowersTypes.sol";
import { Powers } from "@src/Powers.sol";
import { IPowers } from "@src/interfaces/IPowers.sol";

// helpers
import { SlateRegistry } from "@src/core/helpers/SlateRegistry.sol";

// SlateRegistry integration mandates
import { SlateRegistry_AddSlate } from "@src/core/mandates/integrations/SlateRegistry/SlateRegistry_AddSlate.sol";
import { SlateRegistry_RemoveSlate } from "@src/core/mandates/integrations/SlateRegistry/SlateRegistry_RemoveSlate.sol";
import { SlateRegistry_ExecuteResult } from "@src/core/mandates/integrations/SlateRegistry/SlateRegistry_ExecuteResult.sol";

/// @title Slate Voting DAO Deployment Script
/// @notice A grants DAO where community members elect funding programs by voting on competing
///         slates of on-chain actions. Grantees compose slates (bundles of executable calls),
///         community members vote, and the winning slates are executed automatically.
///
/// Roles:
///   0 — Admin          : manages role membership
///   1 — Community      : creates elections and casts votes
///   2 — Grantees       : submit and withdraw funding slates
///   3 — SlateRegistry  : assigned to the SlateRegistry contract so it can trigger slate execution
///
/// Flows:
///   Elections       : create an election → cast votes → execute results
///   Slate Submission: add a slate → (optionally) remove a slate
///   Role Management : admin assigns / revokes roles
contract Deploy is DeployHelpers {
    Configurations helperConfig;
    IMandateRegistry registry;
    PowersTypes.MandateInitData[] constitution;
    PowersTypes.Conditions conditions;
    PowersTypes.Flow[] flows;
    Powers powers;

    SlateRegistry slateRegistry;
    SlateRegistry_AddSlate addSlate;
    SlateRegistry_RemoveSlate removeSlate;
    SlateRegistry_ExecuteResult executeResult;

    address[] targets;
    uint256[] values;
    bytes[] calldatas;
    string[] dynamicParams;

    uint256 constant SLATE_REGISTRY_ROLE_ID = 3;

    uint16 constant MAJOR = 0;
    uint16 constant MINOR = 1;
    uint16 constant PATCH = 9;

    function run() external returns (Powers, SlateRegistry) {
        helperConfig = new Configurations();
        registry = IMandateRegistry(helperConfig.getMandateRegistry(block.chainid));

        // step 1: deploy Powers, SlateRegistry, and integration mandate contracts
        vm.startBroadcast();
        slateRegistry = new SlateRegistry(
            minutesToBlocks(5, helperConfig.getBlocksPerHour(block.chainid)),  // submitSlateDuration: 5 min
            minutesToBlocks(10, helperConfig.getBlocksPerHour(block.chainid)), // voteDuration: 10 min
            SLATE_REGISTRY_ROLE_ID
        );
        addSlate = new SlateRegistry_AddSlate();
        removeSlate = new SlateRegistry_RemoveSlate();
        executeResult = new SlateRegistry_ExecuteResult();
        powers = new Powers(
            "Slate Voting DAO",
            "https://aqua-famous-sailfish-288.mypinata.cloud/ipfs/bafybeiecp4sftsohsmaqqnzojxu5qlhs44qzhfb3ym7qoyormx36v2a77q/slateVoting.json",
            helperConfig.getMaxCallDataLength(block.chainid),
            helperConfig.getMaxReturnDataLength(block.chainid),
            helperConfig.getMaxExecutionsLength(block.chainid),
            address(registry)
        );
        vm.stopBroadcast();
        console2.log("Powers deployed at:", address(powers));

        // step 2: create constitution
        uint256 constitutionLength = createConstitution();
        console2.log("Constitution created with length:");
        console2.logUint(constitutionLength);

        // step 3: constitute and hand SlateRegistry ownership over to Powers
        vm.startBroadcast();
        powers.constitute(constitution);
        powers.closeConstitute(msg.sender, flows);
        slateRegistry.transferOwnership(address(powers));
        vm.stopBroadcast();
        console2.log("Powers successfully constituted.");

        return (powers, slateRegistry);
    }

    function createConstitution() internal returns (uint256 constitutionLength) {
        uint16 mandateCount = 0;

        //////////////////////////////////////////////////////////////////////
        //                              SETUP                               //
        //////////////////////////////////////////////////////////////////////

        targets = new address[](8);
        values = new uint256[](8);
        calldatas = new bytes[](8);
        for (uint256 i = 0; i < targets.length; i++) {
            targets[i] = address(powers);
        }
        calldatas[0] = abi.encodeWithSelector(IPowers.labelRole.selector, 0, "Admin", "");
        calldatas[1] = abi.encodeWithSelector(IPowers.labelRole.selector, type(uint256).max, "Public", "");
        calldatas[2] = abi.encodeWithSelector(IPowers.labelRole.selector, 1, "Community", "");
        calldatas[3] = abi.encodeWithSelector(IPowers.labelRole.selector, 2, "Grantees", "");
        calldatas[4] = abi.encodeWithSelector(IPowers.labelRole.selector, SLATE_REGISTRY_ROLE_ID, "SlateRegistry", "");
        calldatas[5] = abi.encodeWithSelector(IPowers.setTreasury.selector, address(powers));
        calldatas[6] = abi.encodeWithSelector(IPowers.assignRole.selector, SLATE_REGISTRY_ROLE_ID, address(slateRegistry));
        calldatas[7] = abi.encodeWithSelector(IPowers.revokeMandate.selector, mandateCount + 1);

        mandateCount++;
        conditions.allowedRole = 0; // Admin
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Initial Setup: Assign role labels, set treasury, give SlateRegistry its role, revoke this mandate",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "PresetActions"),
                config: abi.encode(targets, values, calldatas),
                conditions: conditions
            })
        );
        delete conditions;

        //////////////////////////////////////////////////////////////////////
        //                        ELECTIONS FLOW                            //
        //////////////////////////////////////////////////////////////////////

        uint16[] memory mandateIds = new uint16[](3);
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2;
        mandateIds[2] = mandateCount + 3;

        flows.push(PowersTypes.Flow({
            mandateIds: mandateIds,
            nameDescription: "Elections: Community members create grant elections, cast votes, and trigger execution of winning slates."
        }));

        // Mandate: Community opens a new grant election
        dynamicParams = new string[](4);
        dynamicParams[0] = "string ElectionTitle";
        dynamicParams[1] = "uint8 MaxSlates";
        dynamicParams[2] = "uint8 MaxVotes";
        dynamicParams[3] = "uint8 MaxWinners";

        mandateCount++;
        conditions.allowedRole = 1; // Community
        conditions.throttleExecution = minutesToBlocks(30, helperConfig.getBlocksPerHour(block.chainid));
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Create Election: A community member opens a new grant funding election in the SlateRegistry.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple"),
                config: abi.encode(address(slateRegistry), SlateRegistry.createElection.selector, dynamicParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Mandate: Community members cast votes for slates
        // Note: voters pass their own address as the second argument so SlateRegistry can track unique votes.
        dynamicParams = new string[](3);
        dynamicParams[0] = "uint256 ElectionId";
        dynamicParams[1] = "address Voter";
        dynamicParams[2] = "uint16[] SlateIndexes";

        mandateCount++;
        conditions.allowedRole = 1; // Community
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Cast Vote: Community members vote for their preferred grant funding slates during the voting window.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple"),
                config: abi.encode(address(slateRegistry), SlateRegistry.vote.selector, dynamicParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Mandate: Anyone triggers execution of winning slates after voting closes
        mandateCount++;
        conditions.allowedRole = type(uint256).max; // Public
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Execute Results: After voting has closed, execute the winning grant slates on-chain.",
                targetMandate: address(executeResult),
                config: abi.encode(address(slateRegistry)),
                conditions: conditions
            })
        );
        delete conditions;

        //////////////////////////////////////////////////////////////////////
        //                     SLATE SUBMISSION FLOW                        //
        //////////////////////////////////////////////////////////////////////

        mandateIds = new uint16[](2);
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2;

        flows.push(PowersTypes.Flow({
            mandateIds: mandateIds,
            nameDescription: "Slate Submission: Grantees propose bundles of funding actions as competing slates, and can withdraw them before voting opens."
        }));

        // Mandate: Grantees submit a funding slate for an election
        mandateCount++;
        conditions.allowedRole = 2; // Grantees
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Add Slate: Grantees propose a slate of funding actions to compete in an election.",
                targetMandate: address(addSlate),
                config: abi.encode(
                    address(slateRegistry),
                    registry.getMandateAddress(MAJOR, MINOR, PATCH, "PresetActions")
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Mandate: Grantees withdraw their slate before voting opens
        // needFulfilled links this to the Add Slate mandate: the same calldata + nonce used to add
        // the slate must be re-submitted here, ensuring only the original submitter can withdraw.
        mandateCount++;
        conditions.allowedRole = 2; // Grantees
        conditions.needFulfilled = mandateCount - 1; // AddSlate must have executed with matching calldata
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Remove Slate: Grantees withdraw their submitted slate before the voting window opens.",
                targetMandate: address(removeSlate),
                config: abi.encode(address(slateRegistry), uint16(mandateCount - 1)),
                conditions: conditions
            })
        );
        delete conditions;

        //////////////////////////////////////////////////////////////////////
        //                      ROLE MANAGEMENT FLOW                        //
        //////////////////////////////////////////////////////////////////////

        mandateIds = new uint16[](2);
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2;

        flows.push(PowersTypes.Flow({
            mandateIds: mandateIds,
            nameDescription: "Role Management: Admin assigns and revokes Community and Grantee roles."
        }));

        dynamicParams = new string[](2);
        dynamicParams[0] = "uint256 RoleId";
        dynamicParams[1] = "address Account";

        mandateCount++;
        conditions.allowedRole = 0; // Admin
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Assign Role: Admin grants Community (1) or Grantee (2) roles to accounts.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple"),
                config: abi.encode(address(powers), IPowers.assignRole.selector, dynamicParams),
                conditions: conditions
            })
        );
        delete conditions;

        mandateCount++;
        conditions.allowedRole = 0; // Admin
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Revoke Role: Admin removes Community (1) or Grantee (2) roles from accounts.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple"),
                config: abi.encode(address(powers), IPowers.revokeRole.selector, dynamicParams),
                conditions: conditions
            })
        );
        delete conditions;

        return constitution.length;
    }
}
