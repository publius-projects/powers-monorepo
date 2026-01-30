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
import { Nominees } from "@src/helpers/Nominees.sol";

// powers contracts
import { PowersTypes } from "@src/interfaces/PowersTypes.sol";
import { Powers } from "@src/Powers.sol";
import { IPowers } from "@src/interfaces/IPowers.sol";

// helper contracts
import { SimpleErc20Votes } from "@mocks/SimpleErc20Votes.sol";
import { Erc20DelegateElection } from "@mocks/Erc20DelegateElection.sol";

/// @title Powers101 Deployment Script
contract Powers101 is DeploySetup {
    Configurations helperConfig;
    Configurations.NetworkConfig config;
    PowersTypes.MandateInitData[] constitution;
    InitialisePowers initialisePowers;
    PowersTypes.Conditions conditions;
    Powers powers;

    SimpleErc20Votes simpleErc20Votes;
    Erc20DelegateElection erc20DelegateElection;

    address[] targets;
    uint256[] values;
    bytes[] calldatas;
    string[] dynamicParams;

    function run() external returns (Powers) {
        // step 0, setup.
        initialisePowers = new InitialisePowers();
        initialisePowers.run();
        helperConfig = new Configurations();
        config = helperConfig.getConfig();

        // step 1: deploy Vanilla Powers
        vm.startBroadcast();
        simpleErc20Votes = new SimpleErc20Votes();
        erc20DelegateElection = new Erc20DelegateElection(address(simpleErc20Votes));
        powers = new Powers(
            "Powers 101", // name
            "https://aqua-famous-sailfish-288.mypinata.cloud/ipfs/bafkreicbh6txnypkoy6ivngl3l2k6m646hruupqspyo7naf2jpiumn2jqe", // uri
            config.maxCallDataLength, // max call data length
            config.maxReturnDataLength, // max return data length
            config.maxExecutionsLength // max executions length
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
        powers.closeConstitute();
        vm.stopBroadcast();
        console2.log("Powers successfully constituted.");
    }

    function createConstitution() internal returns (uint256 constitutionLength) {
        string[] memory dynamicParamsSimple = new string[](1);
        dynamicParamsSimple[0] = "bool NominateMe";

        conditions.allowedRole = type(uint256).max;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Nominate Me: Nominate yourself for a delegate election. (Set nominateMe to false to revoke nomination)",
                targetMandate: initialisePowers.getInitialisedAddress("BespokeAction_Simple"),
                config: abi.encode(address(erc20DelegateElection), Nominees.nominate.selector, dynamicParamsSimple),
                conditions: conditions
            })
        );
        delete conditions;

        // delegateSelect
        conditions.allowedRole = type(uint256).max; // = role that can call this mandate.
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Delegate Nominees: Call a delegate election. This can be done at any time. Nominations are elected on the amount of delegated tokens they have received. For",
                targetMandate: initialisePowers.getInitialisedAddress("ElectionList_Tally"),
                config: abi.encode(
                    address(erc20DelegateElection),
                    2, // role to be elected.
                    3 // max number role holders
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // proposalOnly
        string[] memory inputParams = new string[](3);
        inputParams[0] = "targets address[]";
        inputParams[1] = "values uint256[]";
        inputParams[2] = "calldatas bytes[]";

        conditions.allowedRole = 1; // = role that can call this mandate.
        conditions.quorum = 20; // = 30% quorum needed
        conditions.succeedAt = 66; // = 51% simple majority needed for assigning and revoking members.
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // = number of blocks
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "StatementOfIntent: Propose any kind of action.",
                targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        conditions.allowedRole = 0; // = admin.
        conditions.needFulfilled = 3; // = mandate that must be completed before this one.
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Veto an action: Veto an action that has been proposed by the community.",
                targetMandate: initialisePowers.getInitialisedAddress("StatementOfIntent"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        conditions.allowedRole = 2; // = role that can call this mandate.
        conditions.votingPeriod = minutesToBlocks(5, config.BLOCKS_PER_HOUR); // = number of blocks
        conditions.succeedAt = 66; // = 51% simple majority needed for executing an action.
        conditions.quorum = 20; // = 30% quorum needed
        conditions.needFulfilled = 3; // = mandate that must be completed before this one.
        conditions.needNotFulfilled = 4; // = mandate that must not be completed before this one.
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Execute an action: Execute an action that has been proposed by the community and should not have been vetoed by an admin.",
                targetMandate: initialisePowers.getInitialisedAddress("OpenAction"), // openAction.
                config: abi.encode(), // empty config.
                conditions: conditions
            })
        );
        delete conditions;

        // PresetActions_Single
        // Set config
        targets = new address[](3);
        values = new uint256[](3);
        calldatas = new bytes[](3);
        for (uint256 i = 0; i < targets.length; i++) {
            targets[i] = address(powers);
        }
        calldatas[0] = abi.encodeWithSelector(IPowers.labelRole.selector, 1, "Member");
        calldatas[1] = abi.encodeWithSelector(IPowers.labelRole.selector, 2, "Delegate");
        calldatas[2] = abi.encodeWithSelector(IPowers.revokeMandate.selector, 6); // revoke mandate after use.

        // set conditions
        conditions.allowedRole = type(uint256).max; // = public role. .
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "A Single Action: to assign labels to roles. It self-destructs after execution.",
                targetMandate: initialisePowers.getInitialisedAddress("PresetActions_Single"), // presetSingleAction
                config: abi.encode(targets, values, calldatas),
                conditions: conditions
            })
        );
        delete conditions;

        return constitution.length;
    }
}
