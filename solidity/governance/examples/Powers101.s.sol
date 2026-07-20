// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// scripts
import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { Configurations } from "@script/Configurations.s.sol";
import { DeployHelpers } from "../DeployHelpers.s.sol";
import { IMandateRegistry } from "@src/core/helpers/MandateRegistry.sol";

// external protocols
import { Create2 } from "@lib/openzeppelin-contracts/contracts/utils/Create2.sol";
import { Nominees } from "@src/core/helpers/Nominees.sol";
import { Strings } from "@lib/openzeppelin-contracts/contracts/utils/Strings.sol";

// powers contracts
import { PowersTypes } from "@src/interfaces/PowersTypes.sol";
import { Powers } from "@src/Powers.sol";
import { IPowers } from "@src/interfaces/IPowers.sol";

// helper contracts
import { Nominees } from "@src/core/helpers/Nominees.sol";
import { SimpleErc20Votes } from "../../test/mocks/SimpleErc20Votes.sol";

/// @title Powers101 Deployment Script
contract Deploy is DeployHelpers {
    using Strings for address;

    Configurations helperConfig;
    PowersTypes.MandateInitData[] constitution;
    PowersTypes.Conditions conditions;
    PowersTypes.Flow[] flows;
    Powers powers;
    IMandateRegistry registry;

    Nominees nominees;
    SimpleErc20Votes simpleErc20Votes;

    address[] targets;
    uint256[] values;
    bytes[] calldatas;
    string[] dynamicParams;

    // Select version mandates to be used.
    uint16 constant MAJOR = 0;
    uint16 constant MINOR = 1;
    uint16 constant PATCH = 9;

    function run() external returns (Powers) {
        // step 0, setup.
        helperConfig = new Configurations();
        registry = IMandateRegistry(helperConfig.getMandateRegistry(block.chainid));

        // step 1: deploy Vanilla Powers
        vm.startBroadcast();
        simpleErc20Votes = new SimpleErc20Votes();
        nominees = new Nominees();
        powers = new Powers(
            "Powers 101", // name
            "https://aqua-famous-sailfish-288.mypinata.cloud/ipfs/bafybeiecp4sftsohsmaqqnzojxu5qlhs44qzhfb3ym7qoyormx36v2a77q/powers101.json", // uri
            helperConfig.getMaxCallDataLength(block.chainid), // max call data length
            helperConfig.getMaxReturnDataLength(block.chainid), // max return data length
            helperConfig.getMaxExecutionsLength(block.chainid), // max executions length
            address(registry)
        );
        vm.stopBroadcast();
        console2.log("Powers deployed at:", address(powers));

        // step 2: create constitution
        uint256 constitutionLength = createConstitution();
        console2.log("Constitution created with length:");
        console2.logUint(constitutionLength);

        // step 3: transfer ownership and run constitute.
        vm.startBroadcast();
        powers.constitute(constitution);
        powers.closeConstitute(msg.sender, flows);

        nominees.transferOwnership(address(powers));
        vm.stopBroadcast();
        console2.log("Powers successfully constituted.");

        return powers;
    }

    function createConstitution() internal returns (uint256 constitutionLength) {
        uint16 mandateCount = 0;
        //////////////////////////////////////////////////////////////////////
        //                              SETUP                               //
        //////////////////////////////////////////////////////////////////////
        targets = new address[](6);
        values = new uint256[](6);
        calldatas = new bytes[](6);
        for (uint256 i = 0; i < targets.length; i++) {
            targets[i] = address(powers);
        }
        calldatas[0] = abi.encodeWithSelector(IPowers.labelRole.selector, 0, "Admin", "");
        calldatas[1] = abi.encodeWithSelector(IPowers.labelRole.selector, type(uint256).max, "Public", "");
        calldatas[2] = abi.encodeWithSelector(IPowers.labelRole.selector, 1, "Member", "");
        calldatas[3] = abi.encodeWithSelector(IPowers.labelRole.selector, 2, "Delegate", "");
        calldatas[4] = abi.encodeWithSelector(IPowers.setTreasury.selector, address(powers));
        calldatas[5] = abi.encodeWithSelector(IPowers.revokeMandate.selector, mandateCount + 1); // revoke mandate after use.

        mandateCount++;
        conditions.allowedRole = type(uint256).max; // = public role.
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Initial Setup: Assign role labels and revokes itself after execution",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "PresetActions"),
                config: abi.encode(targets, values, calldatas),
                conditions: conditions
            })
        );
        delete conditions;


        //////////////////////////////////////////////////////////////////////
        //                      EXECUTIVE MANDATES                          //
        //////////////////////////////////////////////////////////////////////

        // MINT NEW TOKENS FLOW //
        uint16[] memory mandateIds = new uint16[](3);
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2;
        mandateIds[2] = mandateCount + 3;

        flows.push(PowersTypes.Flow({
            mandateIds: mandateIds,
            nameDescription: "Minting Flow: Propose a mint, veto a mint, execute a mint."
        }));

        // Anyone: propose minting tokens to an address.
        string[] memory inputParams = new string[](2);
        inputParams[0] = "address To";
        inputParams[1] = "uint256 Quantity";

        mandateCount++;
        conditions.allowedRole = type(uint256).max; // = anyone can call this mandate.
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: string(abi.encodePacked("Propose to Mint: Propose to mint tokens at ", address(simpleErc20Votes).toHexString(), ".")),
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        mandateCount++;
        conditions.allowedRole = 0; // = admin.
        conditions.needFulfilled = mandateCount - 1; // = mandate that must be completed before this one.
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: string(abi.encodePacked("Veto a mint: Veto a proposed token mint at ", address(simpleErc20Votes).toHexString(), ".")),
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        mandateCount++;
        conditions.allowedRole = 1; // = Member role.
        conditions.votingPeriod = minutesToBlocks(5, helperConfig.getBlocksPerHour(block.chainid)); // = number of blocks
        conditions.succeedAt = 66; // = 66% majority needed for executing an action.
        conditions.quorum = 20; // = 20% quorum needed
        conditions.needFulfilled = mandateCount - 2; // = mandate that must be completed before this one.
        conditions.needNotFulfilled = mandateCount - 1; // = mandate that must not be completed before this one.
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: string(abi.encodePacked("Execute a mint: Execute a mint at ", address(simpleErc20Votes).toHexString(), ". It must be proposed first and should not have been vetoed by an admin.")),
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple"),
                config: abi.encode(
                    address(simpleErc20Votes), // target contract
                    bytes4(keccak256("mint(address,uint256)")),
                    inputParams
                ),
                conditions: conditions
            })
        );
        delete conditions;


        //////////////////////////////////////////////////////////////////////
        //                     MEMBERSHIP MANDATES                          //
        //////////////////////////////////////////////////////////////////////

        // MEMBER MANAGEMENT FLOW //
        mandateIds = new uint16[](2);
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2;

        flows.push(PowersTypes.Flow({
            mandateIds: mandateIds,
            nameDescription: "Membership Management: Admin can assign or revoke the Member role."
        }));

        dynamicParams = new string[](2);
        dynamicParams[0] = "uint256 roleId";
        dynamicParams[1] = "address account";

        // Admin: assign Member role to an account.
        mandateCount++;
        conditions.allowedRole = 0; // = Admin
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Assign Member Role: Admin can assign the Member role (roleId 1) to an account.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple"),
                config: abi.encode(address(powers), IPowers.assignRole.selector, dynamicParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Admin: revoke Member role from an account.
        mandateCount++;
        conditions.allowedRole = 0; // = Admin
        conditions.needFulfilled = mandateCount - 1; // = Assign Member Role mandate.
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Revoke Member Role: Admin can revoke the Member role (roleId 1) from an account.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple"),
                config: abi.encode(address(powers), IPowers.revokeRole.selector, dynamicParams),
                conditions: conditions
            })
        );
        delete conditions;


        //////////////////////////////////////////////////////////////////////
        //                      ELECTORAL MANDATES                          //
        //////////////////////////////////////////////////////////////////////

        // ELECT DELEGATES FLOW //
        mandateIds = new uint16[](2);
        mandateIds[0] = mandateCount + 1;
        mandateIds[1] = mandateCount + 2;

        flows.push(PowersTypes.Flow({
            mandateIds: mandateIds,
            nameDescription: "Elect your delegates: Members nominate themselves and elect delegates by peer vote."
        }));

        // Members: nominate themselves as a delegate candidate.
        mandateCount++;
        conditions.allowedRole = 1; // = Member role.
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Nominate Me: Members nominate themselves for the delegate election. (Set nominateMe to false to revoke nomination)",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "Nominate"),
                config: abi.encode(address(nominees)),
                conditions: conditions
            })
        );
        delete conditions;

        // Members: vote to elect delegates via peer selection.
        mandateCount++;
        conditions.allowedRole = 1; // = Member role.
        conditions.votingPeriod = minutesToBlocks(5, helperConfig.getBlocksPerHour(block.chainid)); // = number of blocks
        conditions.succeedAt = 51; // = 51% simple majority needed.
        conditions.quorum = 20; // = 20% quorum needed.
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Elect Delegates: Members vote to select 3 delegates from the pool of nominees. This is a one-time election - the mandate revokes itself after execution.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "PeerSelect"),
                config: abi.encode(
                    uint8(3),          // numberToSelect
                    uint256(2),        // roleId for Delegate
                    address(nominees)  // nominees contract
                ),
                conditions: conditions
            })
        );
        delete conditions;

        return constitution.length;
    }
}
