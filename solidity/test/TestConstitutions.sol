// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
import { IPowers } from "@src/interfaces/IPowers.sol";
import { PowersTypes } from "@src/interfaces/PowersTypes.sol";
import { Configurations } from "@script/Configurations.s.sol";
import { DeployMandates } from "@script/DeployMandates.s.sol";
import { IMandateRegistry } from "@src/core/helpers/MandateRegistry.sol";

import { ReturnDataMock } from "./mocks/ReturnDataMock.sol";
import { IPowersFactory } from "@src/core/helpers/PowersFactory.sol";
import { ElectionRegistry } from "@src/core/helpers/ElectionRegistry.sol";
import { IERC20 } from "@lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract TestConstitutions is Test {
    uint256[] milestoneDisbursements;

    bytes[] staticParams;
    string[] dynamicParams;
    uint8[] indexDynamicParams;
    string[] dynamicParamsSimple;

    // State variables to avoid stack too deep errors
    PowersTypes.Conditions conditions;

    address[] targets;
    uint256[] values;
    bytes[] calldatas;
    string[] inputParams;
    address[] tokens;
    uint256[] tokensPerBlock;
    uint256[] roles;
    uint256[] roleIds;
    uint256[] roleIdsNeeded;
    address[] mandatesToAdopt;
    bytes[] mandateInitDatas;
    PowersTypes.MandateInitData[] constitution;
    PowersTypes.MandateInitData[] primaryConstitution;
    PowersTypes.MandateInitData[] childConstitution;

    string[] mandateNames;
    address[] mandateAddresses;
    uint16 mandateCounter;

    string[] descriptions;
    string[] params;

    // minimum mandate version to be used in testing.
    uint16 constant MAJOR = 0;
    uint16 constant MINOR = 1;
    uint16 constant PATCH = 9;

    // function setUp() public {
    // Set up any common state or variables needed for the tests
    Configurations helperConfig = new Configurations();
    DeployMandates deployMandates = new DeployMandates();
    IMandateRegistry public registry = IMandateRegistry(deployMandates.run());

    /// @notice Resolves a mandate at its latest registered version, for mandates that have moved
    /// off the repo-wide (MAJOR, MINOR, PATCH) pin.
    function _latestMandateAddress(string memory name) internal view returns (address) {
        (uint16 major, uint16 minor, uint16 patch) = registry.getLatestVersion(name);
        return registry.getMandateAddress(major, minor, patch, name);
    }

    // }

    /////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////
    //                                    CORE PROTOCOL TESTS                                          //
    /////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////

    //////////////////////////////////////////////////////////////
    //                 POWERS CONSTITUTION                      //
    //////////////////////////////////////////////////////////////
    /// @notice initiate the powers constitution. Follows the Powers101 governance structure.
    function powersTestConstitution(address daoMock)
        external
        returns (PowersTypes.MandateInitData[] memory mandateInitData)
    {
        delete constitution; // restart constitution array.

        // dummy call.
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        targets[0] = address(123);
        calldatas[0] = abi.encode("mockCall");

        // Note: I leave the first slot empty, so that numbering is equal to how mandates are registered in IPowers.sol.
        // Counting starts at 1, so the first mandate is mandateId = 1.

        // slef select as communtiy member
        conditions.allowedRole = type(uint256).max;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Self select as community member: Self select as a community member. Anyone can call this mandate.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "SelfSelect"), // selfSelct
                config: abi.encode(
                    1 // community member role ID
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // self Select as delegate
        conditions.allowedRole = type(uint256).max;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Self select as delegate: Self select as a delegate. Only community members can call this mandate.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "SelfSelect"), // selfSelct
                config: abi.encode(
                    2 // delegeate member role ID
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // proposalOnly
        inputParams = new string[](3);
        inputParams[0] = "targets address[]";
        inputParams[1] = "values uint256[]";
        inputParams[2] = "calldatas bytes[]";

        conditions.allowedRole = 1; // = role that can call this mandate.
        conditions.quorum = 20; // = 30% quorum needed
        conditions.succeedAt = 66; // = 51% simple majority needed for assigning and revoking members.
        conditions.votingPeriod = 1200; // = number of blocks
        conditions.throttleExecution = 5000;
        // NOTE: the timelock starts counting after proposal has been made, NOT after vote has passed!
        conditions.timelock = 2500; // = 2500 blocks to wait after success before execution
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "StatementOfIntent: Propose any kind of action.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"), // statementOfIntent
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
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        conditions.allowedRole = 2; // = role that can call this mandate.
        conditions.needFulfilled = 3; // = mandate that must be completed before this one.
        conditions.needNotFulfilled = 4; // = mandate that must not be completed before this one.
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Execute an action: Execute an action that has been proposed by the community and should not have been vetoed by an admin.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "OpenAction"), // openAction.
                config: abi.encode(), // empty config.
                conditions: conditions
            })
        );
        delete conditions;

        // PresetActions
        // Set config
        targets = new address[](4);
        values = new uint256[](4);
        calldatas = new bytes[](4);
        for (uint256 i = 0; i < targets.length; i++) {
            targets[i] = daoMock; // = Powers contract.
        }
        calldatas[0] = abi.encodeWithSelector(IPowers.labelRole.selector, 1, "Member", "");
        calldatas[1] = abi.encodeWithSelector(IPowers.labelRole.selector, 2, "Delegate", "");
        calldatas[2] = abi.encodeWithSelector(IPowers.assignRole.selector, 5, makeAddr("alice"));
        calldatas[3] = abi.encodeWithSelector(IPowers.revokeMandate.selector, 6); // revoke mandate after use.

        // set conditions
        conditions.allowedRole = type(uint256).max; // = public role. .
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "A Single Action: to assign labels to roles. It self-destructs after execution.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "PresetActions"), // presetSingleAction
                config: abi.encode(targets, values, calldatas),
                conditions: conditions
            })
        );
        delete conditions;

        return constitution;
    }

    //////////////////////////////////////////////////////////////
    //                  LAW CONSTITUTION                     //
    //////////////////////////////////////////////////////////////
    function mandateTestConstitution(address daoMock, address simpleErc1155)
        public
        returns (PowersTypes.MandateInitData[] memory mandateInitData)
    {
        delete constitution;

        // dummy call: mint coins at mock1155 contract.
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        targets[0] = simpleErc1155;
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature("mint(uint256)", 123);

        // setting up config file
        conditions.quorum = 20; // = 30% quorum needed
        conditions.succeedAt = 66; // = 51% simple majority needed for assigning and revoking members.
        conditions.votingPeriod = 1200; // = number of blocks
        conditions.allowedRole = 1;
        // initiating mandate.
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "StatementOfIntent: Needs Proposal Vote to pass",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"), // statementOfIntent
                config: abi.encode(),
                conditions: conditions
            })
        );
        delete conditions;

        // setting up config file
        conditions.needFulfilled = 1;
        conditions.allowedRole = 1;
        // initiating mandate.
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "PresetActionss: Needs Parent Completed to pass",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "PresetActions"), // presetAction
                config: abi.encode(targets, values, calldatas),
                conditions: conditions
            })
        );
        delete conditions;

        // setting up config file
        conditions.needNotFulfilled = 1;
        conditions.allowedRole = 1;
        // initiating mandate.
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "PresetActionss: Parent can block a mandate, making it impossible to pass",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "PresetActions"), // presetAction
                config: abi.encode(targets, values, calldatas),
                conditions: conditions
            })
        );
        delete conditions;

        // setting up config file
        conditions.quorum = 30; // = 30% quorum needed
        conditions.succeedAt = 51; // = 51% simple majority needed for assigning and revoking members.
        conditions.votingPeriod = 1200; // = number of blocks
        conditions.timelock = 5000;
        conditions.allowedRole = 1;
        // initiating mandate.
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "PresetActionss: Delay execution of a mandate, by a preset number of blocks",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "PresetActions"), // presetAction
                config: abi.encode(targets, values, calldatas),
                conditions: conditions
            })
        );
        delete conditions;

        // setting up config file
        conditions.allowedRole = 1;
        conditions.throttleExecution = 5000;
        // initiating mandate.
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "PresetActionss: Throttle the number of executions of a mandate.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "PresetActions"), // presetAction
                config: abi.encode(targets, values, calldatas),
                conditions: conditions
            })
        );
        delete conditions;

        // PresetActions
        // Set config
        targets = new address[](3);
        values = new uint256[](3);
        calldatas = new bytes[](3);
        for (uint256 i = 0; i < targets.length; i++) {
            targets[i] = daoMock; // = Powers contract.
        }
        calldatas[0] = abi.encodeWithSelector(IPowers.labelRole.selector, 1, "Member", "");
        calldatas[1] = abi.encodeWithSelector(IPowers.labelRole.selector, 2, "Delegate", "");
        calldatas[2] = abi.encodeWithSelector(IPowers.revokeMandate.selector, 7); // revoke mandate after use.

        // set conditions
        conditions.allowedRole = type(uint256).max; // = public role. .
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "A Single Action: to assign labels to roles. It self-destructs after execution.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "PresetActions"), // presetSingleAction
                config: abi.encode(targets, values, calldatas),
                conditions: conditions
            })
        );
        delete conditions;

        return constitution;
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////
    //                                          UNIT TESTS                                             //
    /////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////

    //////////////////////////////////////////////////////////////
    //                    ASYNC CONSTITUTION                    //
    //////////////////////////////////////////////////////////////
    function asyncTestConstitution() external returns (PowersTypes.MandateInitData[] memory mandateInitData) {
        delete constitution; // restart constitution array.

        // todo
        // need to include the get role by git commit.
        // need to use dummy return calls.

        return constitution;
    }

    ////////////////////////////////////////////////////////////
    //                ELECTORAL CONSTITUTION                  //
    ////////////////////////////////////////////////////////////
    function electoralTestConstitution(
        address daoMock,
        address nominees,
        address, /*openElection*/
        address, /*erc20DelegateElection*/
        address /*erc20Taxed*/
    )
        external
        returns (PowersTypes.MandateInitData[] memory mandateInitData)
    {
        delete constitution; // restart constitution array.

        // Nominate - for self-nomination
        conditions.allowedRole = type(uint256).max;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Nominate: Nominate yourself for a role.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "Nominate"), // Nominate (electoral mandate)
                config: abi.encode(nominees),
                conditions: conditions
            })
        );
        delete conditions;

        // PeerSelect
        conditions.allowedRole = 1; // e.g. members vote
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "PeerSelect: A mandate to select roles by peer votes from nominees.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "PeerSelect"), // PeerSelect (electoral mandate)
                config: abi.encode(
                    uint8(2), // numberToSelect
                    uint256(4), // roleId to assign (e.g. 4)
                    nominees // Nominees contract
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // SelfSelect - for self-assignment
        conditions.allowedRole = type(uint256).max;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "SelfSelect: A mandate to self-assign a role.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "SelfSelect"), // SelfSelect (electoral mandate)
                config: abi.encode(4), // roleId to be assigned
                conditions: conditions
            })
        );
        delete conditions;

        // RenounceRole - for renouncing roles
        roles = new uint256[](2);
        roles[0] = 1;
        roles[1] = 2;
        conditions.allowedRole = type(uint256).max;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "RenounceRole: A mandate to renounce specific roles.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "RenounceRole"), // RenounceRole (electoral mandate)
                config: abi.encode(roles), // roles that can be renounced
                conditions: conditions
            })
        );
        delete conditions;

        // RoleByRoles - for role-based role assignment
        roleIdsNeeded = new uint256[](2);
        roleIdsNeeded[0] = 1;
        roleIdsNeeded[1] = 2;
        conditions.allowedRole = type(uint256).max;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "RoleByRoles: A mandate to assign roles based on existing role holders.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "RoleByRoles"), // RoleByRoles (electoral mandate)
                config: abi.encode(
                    4, // target role (what gets assigned)
                    roleIdsNeeded // roles that are needed to be assigned
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // PresetActions
        // Set config
        targets = new address[](3);
        values = new uint256[](3);
        calldatas = new bytes[](3);
        for (uint256 i = 0; i < targets.length; i++) {
            targets[i] = daoMock; // = Powers contract.
        }
        calldatas[0] = abi.encodeWithSelector(IPowers.labelRole.selector, 1, "Member", "");
        calldatas[1] = abi.encodeWithSelector(IPowers.labelRole.selector, 2, "Delegate", "");
        calldatas[2] = abi.encodeWithSelector(IPowers.revokeMandate.selector, 7); // revoke mandate after use.

        // set conditions
        conditions.allowedRole = type(uint256).max; // = public role. .
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "A Single Action: to assign labels to roles. It self-destructs after execution.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "PresetActions"), // presetSingleAction
                config: abi.encode(targets, values, calldatas),
                conditions: conditions
            })
        );
        delete conditions;

        conditions.allowedRole = type(uint256).max; // = public role. .
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "RevokeInactiveAccounts: A mandate to revoke roles from inactive accounts.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "RevokeInactiveAccounts"), // presetSingleAction
                config: abi.encode(
                    3, // roleId to monitor
                    1, // minimum actions in period
                    5 // number of latest actions to check
                ),
                conditions: conditions
            })
        );
        delete conditions;

        return constitution;
    }

    //////////////////////////////////////////////////////////////
    //       REVOKE INACTIVE ACCOUNTS CONSTITUTION              //
    //////////////////////////////////////////////////////////////
    // Three mandates:
    // 1. SelfSelect role 5, restricted to role 3  → caller-tracked actions
    // 2. StatementOfIntent, voteable by role 3    → voter-tracked actions
    // 3. RevokeInactiveAccounts monitoring role 3
    function revokeInactiveAccountsTestConstitution(
        address /*daoMock*/
    )
        external
        returns (PowersTypes.MandateInitData[] memory)
    {
        delete constitution;

        conditions.allowedRole = 3;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "SelfSelect: self-assign role 5 (role 3 required).",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "SelfSelect"),
                config: abi.encode(uint256(5)),
                conditions: conditions
            })
        );
        delete conditions;

        conditions.allowedRole = 3;
        conditions.votingPeriod = 100;
        conditions.succeedAt = 51;
        conditions.quorum = 20;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "StatementOfIntent: proposal voteable by role 3.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
                config: abi.encode(),
                conditions: conditions
            })
        );
        delete conditions;

        conditions.allowedRole = type(uint256).max;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "RevokeInactiveAccounts: monitor role 3.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "RevokeInactiveAccounts"),
                config: abi.encode(
                    uint256(3), // roleId to monitor
                    uint256(1), // minimumActionsNeeded
                    uint256(5) // numberActionsToCheck
                ),
                conditions: conditions
            })
        );
        delete conditions;

        return constitution;
    }

    //////////////////////////////////////////////////////////////
    //        REVOKE ACCOUNTS ROLE ID CONSTITUTION              //
    //////////////////////////////////////////////////////////////
    // Three mandates:
    // 1. SelfSelect — public, assigns role 3 (lets tests populate holders)
    // 2. RevokeAccountsRoleId — public, targets role 3
    // 3. RevokeAccountsRoleId — restricted to role 1, targets role 3 (access control test)
    function revokeAccountsRoleIdTestConstitution(
        address /*daoMock*/
    )
        external
        returns (PowersTypes.MandateInitData[] memory)
    {
        delete constitution;

        string[] memory emptyInputParams = new string[](0);

        conditions.allowedRole = type(uint256).max;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "SelfSelect: self-assign role 3.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "SelfSelect"),
                config: abi.encode(uint256(3)),
                conditions: conditions
            })
        );
        delete conditions;

        conditions.allowedRole = type(uint256).max;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "RevokeAccountsRoleId: revoke all holders of role 3.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "RevokeAccountsRoleId"),
                config: abi.encode(uint256(3), emptyInputParams),
                conditions: conditions
            })
        );
        delete conditions;

        conditions.allowedRole = 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "RevokeAccountsRoleId: restricted to role 1.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "RevokeAccountsRoleId"),
                config: abi.encode(uint256(3), emptyInputParams),
                conditions: conditions
            })
        );
        delete conditions;

        return constitution;
    }

    //////////////////////////////////////////////////////////////
    //                  EXECUTIVE CONSTITUTION                  //
    //////////////////////////////////////////////////////////////
    function executiveTestConstitution(address daoMock, address simpleErc1155, address returnDataMock)
        external
        returns (PowersTypes.MandateInitData[] memory mandateInitData)
    {
        delete constitution; // restart constitution array.

        // StatementOfIntent - for proposing actions
        conditions.allowedRole = type(uint256).max;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "StatementOfIntent: A mandate to propose actions without execution.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"), // StatementOfIntent (multi mandate)
                config: abi.encode(), // empty config
                conditions: conditions
            })
        );
        delete conditions;

        // OpenAction - allows any action to be executed
        conditions.allowedRole = type(uint256).max;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "OpenAction: A mandate to execute any action with full power.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "OpenAction"), // OpenAction (multi mandate)
                config: abi.encode(), // empty config
                conditions: conditions
            })
        );
        delete conditions;

        // BespokeAction_Simple - for simple function calls
        params = new string[](2);
        params[0] = "uint256 Quantity";
        params[1] = "address To";
        conditions.allowedRole = 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "BespokeAction_Simple: A mandate to execute a simple function call.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple"), // BespokeAction_Simple (multi mandate)
                config: abi.encode(
                    simpleErc1155, // SimpleErc1155 mock
                    bytes4(keccak256("mint(uint256,address)")),
                    params
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // BespokeAction_Advanced - for complex function calls with mixed parameters
        dynamicParams = new string[](1);
        dynamicParams[0] = "address Account";

        conditions.allowedRole = 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "BespokeAction_Advanced: A mandate to execute complex function calls with mixed parameters.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Advanced"), // BespokeAction_Advanced (multi mandate)
                config: abi.encode(
                    daoMock, // Powers contract
                    IPowers.assignRole.selector,
                    abi.encode(1), // Role Id that will be assigned
                    dynamicParams,
                    abi.encode(2212) // static params after -- should be ignored by assign role function.
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // PresetActions - for executing preset actions
        targets = new address[](2);
        values = new uint256[](2);
        calldatas = new bytes[](2);

        targets[0] = daoMock;
        targets[1] = daoMock;
        values[0] = 0;
        values[1] = 0;
        calldatas[0] = abi.encodeWithSelector(IPowers.labelRole.selector, 1, "Member", "");
        calldatas[1] = abi.encodeWithSelector(IPowers.labelRole.selector, 2, "Delegate", "");

        conditions.allowedRole = 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "PresetActions: A mandate to execute preset actions.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "PresetActions"), // PresetActions (multi mandate)
                config: abi.encode(targets, values, calldatas),
                conditions: conditions
            })
        );
        delete conditions;

        // CheckExternalActionState
        inputParams = new string[](3);
        inputParams[0] = "targets address[]";
        inputParams[1] = "values uint256[]";
        inputParams[2] = "calldatas bytes[]";

        conditions.allowedRole = type(uint256).max;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "CheckExternalActionState: Checks if an action is fulfilled on a parent contract.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "CheckExternalActionState"), // CheckExternalActionState
                config: abi.encode(
                    daoMock, // parentPowers (self for test)
                    1, // mandateId on parent (OpenAction)
                    inputParams
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Adopt_Mandates - for adopting new mandates
        mandatesToAdopt = new address[](1);
        mandateInitDatas = new bytes[](1);

        // Create a simple mandate init data for adoption
        PowersTypes.MandateInitData({
            nameDescription: "Test Adopted Mandate",
            targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "PresetActions"), // PresetActions
            config: abi.encode(
                new address[](1), // empty targets
                new uint256[](1), // empty values
                new bytes[](1) // empty calldatas
            ),
            conditions: PowersTypes.Conditions({
                allowedRole: type(uint256).max,
                quorum: 0,
                succeedAt: 0,
                votingPeriod: 0,
                timelock: 0,
                throttleExecution: 0,
                needFulfilled: 0,
                needNotFulfilled: 0,
                maxExecutionDelay: 0
            })
        });

        conditions.allowedRole = type(uint256).max; // public role can adopt mandates
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Adopt_Mandates: A mandate to adopt new mandates into the DAO.",
                targetMandate: _latestMandateAddress("Adopt_Mandates"), // Adopt_Mandates — resolved at latest version (0.2.0)
                config: abi.encode(),
                conditions: conditions
            })
        );
        delete conditions;

        // BespokeActionReturner (BespokeAction_Simple) - returns a value
        conditions.allowedRole = type(uint256).max;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "BespokeActionReturner: Returns a value for testing.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple"),
                config: abi.encode(returnDataMock, ReturnDataMock.getValue.selector, new string[](0)),
                conditions: conditions
            })
        );
        delete conditions;

        // BespokeAction_OnReturnValue - for using return values from previous mandates
        params = new string[](1);
        params[0] = "uint256 Value";

        conditions.allowedRole = type(uint256).max; // public role can adopt mandates
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "BespokeAction_OnReturnValue: Execute a call using return value of previous mandate call.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_OnReturnValue"), // BespokeAction_OnReturnValue (executive mandate)
                config: abi.encode(
                    returnDataMock,
                    ReturnDataMock.consume.selector,
                    abi.encode(), // no data after
                    params,
                    uint16(constitution.length), // mandateId of BespokeActionReturner (the one just added)
                    abi.encode() // no data before
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // ExternalAction_Flexible - flexible execution at another Powers instance
        params = new string[](0); // mandate auto-prepends PowersTarget and MandateIdTarget
        conditions.allowedRole = 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "ExternalAction_Flexible: A mandate to flexibly execute actions on another Powers instance.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "ExternalAction_Flexible"),
                config: abi.encode(params),
                conditions: conditions
            })
        );
        delete conditions;

        // PresetActions_OnOwnPowers — one call baked in: labelRole(3, "Council", "")
        bytes[] memory ownPowersCalls = new bytes[](1);
        ownPowersCalls[0] = abi.encodeWithSelector(IPowers.labelRole.selector, uint256(3), "Council", "");

        conditions.allowedRole = 1; // ROLE_ONE
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "PresetActions_OnOwnPowers: A mandate to execute preset calls on the DAO itself.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "PresetActions_OnOwnPowers"),
                config: abi.encode(ownPowersCalls),
                conditions: conditions
            })
        );
        delete conditions;

        // PresetActions_OnOwnPowers — empty callDatas (public access, for edge case tests)
        bytes[] memory ownPowersCallsEmpty = new bytes[](0);

        conditions.allowedRole = type(uint256).max;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "PresetActions_OnOwnPowers: empty callDatas.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "PresetActions_OnOwnPowers"),
                config: abi.encode(ownPowersCallsEmpty),
                conditions: conditions
            })
        );
        delete conditions;

        // ExternalAction_OnReturnValue — forward parent return value to an external Powers instance
        params = new string[](1);
        params[0] = "uint256 Value";

        conditions.allowedRole = 1; // ROLE_ONE
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "ExternalAction_OnReturnValue: Forward parent return value to an external Powers instance.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "ExternalAction_OnReturnValue"),
                config: abi.encode(
                    bytes(""), // paramsBefore: empty
                    params, // params_: ["uint256 Value"]
                    uint16(8), // parentMandateId = BespokeActionReturner (mandateId 8)
                    bytes("") // paramsAfter: empty
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // ExternalAction_Simple — forward calldata to a preset mandate on a preset Powers instance
        params = new string[](1);
        params[0] = "bool Confirm";

        conditions.allowedRole = 1; // ROLE_ONE
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "ExternalAction_Simple: Forward calldata to a preset mandate on another Powers instance.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "ExternalAction_Simple"),
                config: abi.encode(
                    daoMock, // PowersTarget (self for test)
                    uint16(1), // MandateIdTarget = StatementOfIntent (public role)
                    "Forwarded by ExternalAction_Simple", // Description for the inner request
                    params
                ),
                conditions: conditions
            })
        );
        delete conditions;

        return constitution;
    }

    //////////////////////////////////////////////////////////////
    //               INTEGRATIONS CONSTITUTION                  //
    //////////////////////////////////////////////////////////////
    function integrationsTestConstitution(
        address daoMock,
        address simpleGovernor,
        address powersFactory,
        address soulbound1155,
        address electionList,
        address erc20Taxed,
        address zkPassportRegistry
    ) external returns (PowersTypes.MandateInitData[] memory mandateInitData) {
        delete constitution; // restart constitution array
        mandateCounter = 0;

        // Governor Integration //
        // Governor_CreateProposal - for creating governance proposals
        mandateCounter++;
        conditions.allowedRole = 1; // role 1 can create proposals
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Governor_CreateProposal: A mandate to create governance proposals on a Governor contract.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "Governor_CreateProposal"), // Governor_CreateProposal (executive mandate)
                config: abi.encode(simpleGovernor), // SimpleGovernor mock address
                conditions: conditions
            })
        );
        delete conditions;

        // Governor_ExecuteProposal - for executing governance proposals
        mandateCounter++;
        conditions.allowedRole = 1; // role 1 can execute proposals
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Governor_ExecuteProposal: A mandate to execute governance proposals on a Governor contract.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "Governor_ExecuteProposal"), // Governor_ExecuteProposal (executive mandate)
                config: abi.encode(simpleGovernor), // SimpleGovernor mock address
                conditions: conditions
            })
        );
        delete conditions;

        // set sub-DAO as delegate of safe.
        inputParams = new string[](1);
        inputParams[0] = "address sub-DAO";

        mandateCounter++;
        conditions.allowedRole = type(uint256).max; // Public
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Assign Delegate status: Assign delegate status at Safe treasury to a sub-DAO",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "Safe_ExecTransaction"),
                config: abi.encode(
                    inputParams,
                    bytes4(0xe71bdf41), // addDelegate(address)
                    helperConfig.getSafeAllowanceModule(block.chainid)
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // setup allowance for an erc20 token.
        inputParams = new string[](5);
        inputParams[0] = "address Sub-DAO";
        inputParams[1] = "address Token";
        inputParams[2] = "uint96 allowanceAmount";
        inputParams[3] = "uint16 resetTimeMin";
        inputParams[4] = "uint32 resetBaseMin";

        mandateCounter++;
        conditions.allowedRole = type(uint256).max; // Public
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Set Allowance: Execute and set allowance for a sub-DAO.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "Safe_ExecTransaction"),
                config: abi.encode(
                    inputParams,
                    bytes4(0xbeaeb388), // == AllowanceModule.setAllowance.selector (because the contracts are compiled with different solidity versions we cannot reference the contract directly here)
                    helperConfig.getSafeAllowanceModule(block.chainid)
                ),
                conditions: conditions // everythign zero == Only admin can call directly
            })
        );
        delete conditions;

        // execute action from safe.
        inputParams = new string[](2);
        inputParams[0] = "address To";
        inputParams[1] = "uint256 Value";

        mandateCounter++;
        conditions.allowedRole = 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Transfer tokens from the Safe treasury.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "Safe_ExecTransaction"),
                config: abi.encode(inputParams, IERC20.transfer.selector, erc20Taxed),
                conditions: conditions
            })
        );
        delete conditions;

        // Powers Factory Integration //
        // create new org
        inputParams = new string[](3);
        inputParams[0] = "string OrgName";
        inputParams[1] = "string OrgUri";
        inputParams[2] = "uint256 Allowance";

        uint256 roleIdnewOrg = 9; // roleId for the new organisation.

        mandateCounter++;
        conditions.allowedRole = 1; //
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Create new Powers: call Powers Factory to spawn new powers.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple"),
                config: abi.encode(powersFactory, IPowersFactory.createPowers.selector, inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        mandateCounter++;
        conditions.allowedRole = 1; //
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Execute and set allowance for a Powers Child at the Safe Treasury.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "PowersFactory_AssignRole"),
                config: abi.encode(
                    5, // mandateId of the createPowers action above.
                    roleIdnewOrg,
                    inputParams // the input params from above are passed to extract the new org address.
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Soulbound1155 integration //
        // minting mandate //
        mandateCounter++;
        conditions.allowedRole = 1; //
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Mint soulbound token: mint a soulbound ERC1155 token and send it to an address of choice.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "GovernedToken_MintEncodedToken"),
                config: abi.encode(soulbound1155),
                conditions: conditions
            })
        );
        delete conditions;

        // access mandate //
        mandateCounter++;
        conditions.allowedRole = 1; //
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Soulbound1155 Access: Get roleId through soulbound ERC1155 token.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "GovernedToken_GatedAccess"),
                config: abi.encode(
                    soulbound1155,
                    9, // roleId to be assigned upon holding the soulbound token.
                    42, // roleId to be checked for in encoded address. Alice mints the token and has been given role 42.
                    100, // epoch of blocks within which the tokens must have been held.
                    3 // number of tokens that need to be held.
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // burn to access mandate //
        inputParams = new string[](2);
        inputParams[0] = "uint256 TokenId";
        inputParams[1] = "uint256 Amount";

        mandateCounter++;
        conditions.allowedRole = 1; //
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Burn to Access: Burn a soulbound ERC1155 token to gain access.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "GovernedToken_BurnToAccess"),
                config: abi.encode(inputParams, soulbound1155),
                conditions: conditions
            })
        );
        delete conditions;

        // ElectionRegistry Integration //
        // create election mandate //
        inputParams = new string[](3);
        inputParams[0] = "string Title";
        inputParams[1] = "uint48 StartBlock";
        inputParams[2] = "uint48 EndBlock";

        // Members: create election (ID 9)
        mandateCounter++;
        conditions.allowedRole = 1; // = Members (should be Executives according to MD, but code says Members)
        conditions.throttleExecution = 600; // = once every 2 hours approx (120 mins)
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Create an election: an election can be initiated be any member.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple"),
                config: abi.encode(
                    address(electionList), // election list contract
                    ElectionRegistry.createElection.selector, // selector
                    inputParams
                ),
                conditions: conditions
            })
        );
        delete conditions;
        uint16 createElectionId = mandateCounter;

        // Members: Nominate for Executive election (ID 10)
        mandateCounter++;
        conditions.allowedRole = 1; // = Members (should be Executives according to MD, but code says Members)
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Nominate for election: any member can nominate for an election.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "ElectionRegistry_Nominate"),
                config: abi.encode(
                    address(electionList), // election list contract
                    true // nominate as candidate
                ),
                conditions: conditions
            })
        );
        delete conditions;
        uint16 nominateId = mandateCounter;

        // Members revoke nomination for Executive election. (ID 11)
        mandateCounter++;
        conditions.allowedRole = 1; // = Members (should be Executives according to MD, but code says Members)
        conditions.needFulfilled = nominateId; // = Nominate for election
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Revoke nomination for election: any member can revoke their nomination for an election.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "ElectionRegistry_Nominate"),
                config: abi.encode(
                    address(electionList), // election list contract
                    false // revoke nomination
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Members: Open Vote for election (ID 12)
        mandateCounter++;
        conditions.allowedRole = 1; // = Members
        conditions.needFulfilled = createElectionId; // = Create election
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Open voting for election: Members can open the vote for an election. This will create a dedicated vote mandate.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "ElectionRegistry_CreateVoteMandate"),
                config: abi.encode(
                    address(electionList), // election list contract
                    registry.getMandateAddress(MAJOR, MINOR, PATCH, "ElectionRegistry_Vote"), // the vote mandate address
                    1, // the max number of votes a voter can cast
                    1 // the role Id allowed to vote (Members)
                ),
                conditions: conditions
            })
        );
        delete conditions;
        uint16 openVoteId = mandateCounter;

        // Members: Tally election (ID 13)
        mandateCounter++;
        conditions.allowedRole = 1;
        conditions.needFulfilled = openVoteId; // = Open Vote election
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Tally elections: After an election has finished, assign the Executive role to the winners.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "ElectionRegistry_Tally"),
                config: abi.encode(
                    address(electionList),
                    2, // RoleId for Executives
                    5 // Max role holders
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Members: clean up election (ID 14)
        mandateCounter++;
        conditions.allowedRole = 1;
        conditions.needFulfilled = openVoteId; // = Open Vote election
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Clean up election: After an election has finished, clean up related mandates.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "ElectionRegistry_CleanUpVoteMandate"),
                config: abi.encode(
                    openVoteId // mandateId of the ElectionRegistry_CreateVoteMandate that spawned the vote mandate
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // ZKPassport Check Above 18
        mandateCounter++;
        inputParams = new string[](1);
        inputParams[0] = "address AccountToCheck";
        conditions.allowedRole = type(uint256).max; // Public
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "ZKPassport Check: Check if a user is above 18 years old.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "ZKPassport_Check"),
                config: abi.encode(
                    inputParams,
                    zkPassportRegistry, // Registry address
                    5 * 60 * 60, // stale after five hours (input in seconds).
                    false, // facematch not required
                    bytes4(keccak256("isAgeAbove(uint8)")), // isAgeAbove(uint8)
                    abi.encode(18) // age to check
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // ZKPassport Check below 18
        mandateCounter++;
        conditions.allowedRole = type(uint256).max; // Public
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "ZKPassport Check: Check if a user is below 18 years old.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "ZKPassport_Check"),
                config: abi.encode(
                    inputParams,
                    zkPassportRegistry, // Registry address
                    5 * 60 * 60, // stale after five hours (input in seconds)
                    false, // facematch not required
                    bytes4(keccak256("isAgeBelow(uint8)")), // isAgeBelow(uint8)
                    abi.encode(18) // age to check
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // ZKPassport Check Above 18
        string[] memory nationalitiesToCheck = new string[](2);
        nationalitiesToCheck[0] = "GBR";
        nationalitiesToCheck[1] = "ABW";

        mandateCounter++;
        inputParams = new string[](1);
        inputParams[0] = "address AccountToCheck";
        conditions.allowedRole = type(uint256).max; // Public
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "ZKPassport Check: Check if a user is from GBR.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "ZKPassport_Check"),
                config: abi.encode(
                    inputParams,
                    zkPassportRegistry, // Registry address
                    5 * 60 * 60, // stale after five hours (input in seconds).
                    false, // facematch not required
                    bytes4(keccak256("isNationalityIn(string[])")), // isNationalityIn(string[],bytes)
                    abi.encode(nationalitiesToCheck) // nationality to check
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // SafeAllowance_Action: set an allowance on the Allowance Module through the Safe treasury.
        inputParams = new string[](5);
        inputParams[0] = "address Delegate";
        inputParams[1] = "address Token";
        inputParams[2] = "uint96 allowanceAmount";
        inputParams[3] = "uint16 resetTimeMin";
        inputParams[4] = "uint32 resetBaseMin";

        mandateCounter++;
        conditions.allowedRole = 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "SafeAllowance_Action: Set allowance for a delegate via the Allowance Module.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "SafeAllowance_Action"),
                config: abi.encode(
                    inputParams,
                    bytes4(0xbeaeb388), // == AllowanceModule.setAllowance.selector (because the contracts are compiled with different solidity versions we cannot reference the contract directly here)
                    helperConfig.getSafeAllowanceModule(block.chainid)
                ),
                conditions: conditions
            })
        );
        delete conditions;

        return constitution;
    }

    function integrationsTestConstitution2(address daoMock, address token)
        external
        returns (PowersTypes.MandateInitData[] memory mandateInitData)
    {
        delete constitution; // restart constitution array

        // Safe Allowance Integration //
        // Mandate: Execute Allowance Transaction
        conditions.allowedRole = type(uint256).max;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Execute Allowance Transaction: Execute a transaction from the Safe Treasury within the allowance set.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "SafeAllowance_Transfer"),
                config: abi.encode(
                    helperConfig.getSafeAllowanceModule(block.chainid),
                    IPowers(daoMock).getTreasury() // This is the SafeProxyTreasury!
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Mandate: Preset Allowance Transfer — token and amount are fixed at adoption, only the recipient is dynamic.
        conditions.allowedRole = type(uint256).max;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "SafeAllowance_PresetTransfer: Transfer a preset amount of a preset token from the Safe treasury.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "SafeAllowance_PresetTransfer"),
                config: abi.encode(
                    token,
                    uint256(1e16), // preset amount
                    helperConfig.getSafeAllowanceModule(block.chainid),
                    IPowers(daoMock).getTreasury() // This is the SafeProxyTreasury!
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Mandate: Recover Tokens — return any allowance-listed tokens held by this organisation to the treasury.
        conditions.allowedRole = type(uint256).max;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Safe_RecoverTokens: Return tokens held by this organisation to the Safe treasury.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "Safe_RecoverTokens"),
                config: abi.encode(
                    IPowers(daoMock).getTreasury(), // safeTreasury
                    helperConfig.getSafeAllowanceModule(block.chainid)
                ),
                conditions: conditions
            })
        );
        delete conditions;

        return constitution;
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////
    //                                      INTEGRATION TESTS                                          //
    /////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////
    // Note: test constitutions created per governance flow to be tested.
    // NB2: leaving async tests out for now. Due to use of oracles, they are better tested directly on actual test nets.

    //////////////////////////////////////////////////////////////
    //               INTEGRATION TEST: ELECTORAL                //
    //////////////////////////////////////////////////////////////
    // Delegate Token election flow
    function delegateToken_IntegrationTestConstitution(
        address nominees,
        address,
        /*openElection*/
        address simpleErc20Votes
    )
        external
        returns (PowersTypes.MandateInitData[] memory mandateInitData)
    {
        delete constitution; // restart constitution array.

        // Mandate 1: Nominate for Delegates
        conditions.allowedRole = 1; // = Voters
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Nominate for Delegates: Members can nominate themselves for the Token Delegate role.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "Nominate"),
                config: abi.encode(nominees),
                conditions: conditions
            })
        );
        delete conditions;

        // Mandate 2: Elect Delegates
        conditions.allowedRole = type(uint256).max; // = Public Role
        conditions.throttleExecution = 600;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Elect Delegates: Run the election for delegates. In this demo, the top 3 nominees by token delegation of token VOTES_TOKEN become Delegates.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "DelegateTokenSelect"),
                config: abi.encode(
                    simpleErc20Votes,
                    nominees,
                    2, // RoleId
                    3 // MaxRoleHolders
                ),
                conditions: conditions
            })
        );
        delete conditions;

        return constitution;
    }

    // Open Election flow
    function openElection_IntegrationTestConstitution(address openElection)
        external
        returns (PowersTypes.MandateInitData[] memory mandateInitData)
    {
        delete constitution; // restart constitution array.

        // Mandate 1: Nominate for Delegates
        conditions.allowedRole = 1; // = Voters
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Nominate for Delegates: Members can nominate themselves for the Token Delegate role.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "Nominate"),
                config: abi.encode(openElection),
                conditions: conditions
            })
        );
        delete conditions;

        // Mandate 2: Start an election
        conditions.allowedRole = 1; // = Voters
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Start an election: an election can be initiated be voters once every 2 hours. The election will last 10 minutes.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "ElectionRegistry_Create"),
                config: abi.encode(
                    openElection,
                    registry.getMandateAddress(MAJOR, MINOR, PATCH, "ElectionRegistry_Vote"), // Voting mandate
                    600, // 10 minutes in blocks (approx)
                    1 // Voter role id
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // Mandate 3: End and Tally elections
        conditions.allowedRole = 1; // = Voters
        conditions.needFulfilled = 2; // = Mandate 2 (Start election)
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "End and Tally elections: After an election has finished, assign the Delegate role to the winners.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "ElectionRegistry_Tally"),
                config: abi.encode(
                    openElection,
                    2, // RoleId for Delegates
                    5 // Max role holders
                ),
                conditions: conditions
            })
        );
        delete conditions;

        return constitution;
    }

    // Assign external role flow (= 2 constitutions, parent & child)
    function assignExternalRole_parent_IntegrationTestConstitution(address daoMock)
        external
        returns (PowersTypes.MandateInitData[] memory mandateInitData)
    {
        delete constitution; // restart constitution array.

        // Mandate: Admin assigns role
        dynamicParams = new string[](2);
        dynamicParams[0] = "uint256 roleId";
        dynamicParams[1] = "address account";

        conditions.allowedRole = 0; // = Admin
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Admin can assign any role: For this demo, the admin can assign any role to an account.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple"),
                config: abi.encode(daoMock, IPowers.assignRole.selector, dynamicParams),
                conditions: conditions
            })
        );
        delete conditions;

        return constitution;
    }

    function assignExternalRole_child_IntegrationTestConstitution(
        address,
        /*daoMock*/
        address parent
    )
        external
        returns (PowersTypes.MandateInitData[] memory mandateInitData)
    {
        delete childConstitution; // restart childConstitution array.

        conditions.allowedRole = type(uint256).max; // Public
        childConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Adopt Role 1: Anyone that has role 1 at the parent organization can adopt the same role here.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "AssignExternalRole"),
                config: abi.encode(
                    parent,
                    1 //
                ),
                conditions: conditions
            })
        );
        delete conditions;

        return childConstitution;
    }

    //////////////////////////////////////////////////////////////
    //             INTEGRATION TEST: EXECUTIVE                  //
    //////////////////////////////////////////////////////////////
    // Open Action flow: The most classic governance flows of all. This is the base to test if needFulfilled and needNotFulfilled actually work.
    function openAction_IntegrationTestConstitution()
        external
        returns (PowersTypes.MandateInitData[] memory mandateInitData)
    {
        delete constitution; // restart constitution array.

        // proposalOnly
        inputParams = new string[](3);
        inputParams[0] = "targets address[]";
        inputParams[1] = "values uint256[]";
        inputParams[2] = "calldatas bytes[]";

        conditions.allowedRole = 1; // = role that can call this mandate.
        conditions.quorum = 20; // = 30% quorum needed
        conditions.succeedAt = 66; // = 51% simple majority needed for assigning and revoking members.
        conditions.votingPeriod = 300; // = number of blocks
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "StatementOfIntent: Propose any kind of action.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
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
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
                config: abi.encode(inputParams),
                conditions: conditions
            })
        );
        delete conditions;

        conditions.allowedRole = 2; // = role that can call this mandate.
        conditions.votingPeriod = 300; // = number of blocks
        conditions.succeedAt = 66; // = 51% simple majority needed for executing an action.
        conditions.quorum = 20; // = 30% quorum needed
        conditions.needFulfilled = 3; // = mandate that must be completed before this one.
        conditions.needNotFulfilled = 4; // = mandate that must not be completed before this one.
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Execute an action: Execute an action that has been proposed by the community and should not have been vetoed by an admin.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "OpenAction"), // openAction.
                config: abi.encode(), // empty config.
                conditions: conditions
            })
        );
        delete conditions;

        return constitution;
    }

    // Check External Action State flow (= 2 constitutions, parent & child)
    function checkExternalActionState_Parent_IntegrationTestConstitution(
        address /*daoMock*/
    )
        external
        returns (PowersTypes.MandateInitData[] memory mandateInitData)
    {
        delete primaryConstitution; // restart primaryConstitution array.

        // Mandate: Adopt a Child Mandate
        conditions.allowedRole = 0; // Admin
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Adopt a Child Mandate: Admin adopts the new mandate for a Powers' child",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
                config: abi.encode(),
                conditions: conditions
            })
        );
        delete conditions;

        return primaryConstitution;
    }

    function checkExternalActionState_Child_IntegrationTestConstitution(
        address, /*daoMock*/
        address /*parent*/
    )
        external
        returns (PowersTypes.MandateInitData[] memory mandateInitData)
    {
        delete childConstitution; // restart childConstitution array.

        // Mandate: Adopt a Child Mandate
        // conditions.allowedRole = 0; // Admin
        // childConstitution.push(PowersTypes.MandateInitData({
        //     nameDescription: "Adopt a Child Mandate: Admin adopts the new mandate for a Powers' child",
        //     targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "StatementOfIntent"),
        //     config: abi.encode(),
        //     conditions: conditions
        // }));
        // delete conditions;

        return childConstitution;
    }

    //////////////////////////////////////////////////////////////
    //               INTEGRATION TEST: INTEGRATIONS              //
    //////////////////////////////////////////////////////////////
    // Governor protocol flow
    function governorProtocol_IntegrationTestConstitution(address simpleGovernor)
        external
        returns (PowersTypes.MandateInitData[] memory mandateInitData)
    {
        delete constitution; // restart constitution array.

        // Governor_CreateProposal - for creating governance proposals
        conditions.allowedRole = 1; // role 1 can create proposals
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Governor_CreateProposal: A mandate to create governance proposals on a Governor contract.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "Governor_CreateProposal"), // Governor_CreateProposal (executive mandate)
                config: abi.encode(simpleGovernor), // SimpleGovernor mock address
                conditions: conditions
            })
        );
        delete conditions;

        // Governor_ExecuteProposal - for executing governance proposals
        conditions.allowedRole = 1; // role 1 can execute proposals
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Governor_ExecuteProposal: A mandate to execute governance proposals on a Governor contract.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "Governor_ExecuteProposal"), // Governor_ExecuteProposal (executive mandate)
                config: abi.encode(simpleGovernor), // SimpleGovernor mock address
                conditions: conditions
            })
        );
        delete conditions;

        return constitution;
    }

    // Safe protocol flow
    function safeProtocol_Parent_IntegrationTestConstitution(address allowanceModule)
        external
        returns (PowersTypes.MandateInitData[] memory mandateInitData)
    {
        delete primaryConstitution; // restart primaryConstitution array.

        // Allow for child to be set as delegate
        inputParams = new string[](1);
        inputParams[0] = "address NewChildPowers";
        conditions.allowedRole = type(uint256).max; // Public
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Assign Delegate status: Assign delegate status at Safe treasury to the sub-DAO",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "Safe_ExecTransaction"),
                config: abi.encode(
                    inputParams,
                    bytes4(0xe71bdf41), // == AllowanceModule.addDelegate.selector (because the contracts are compiled with different solidity versions we cannot reference the contract directly here)
                    allowanceModule
                ),
                conditions: conditions
            })
        );
        delete conditions;

        // setting allowance for child powers
        inputParams = new string[](5);
        inputParams[0] = "address Sub-DAO";
        inputParams[1] = "address Token";
        inputParams[2] = "uint96 allowanceAmount";
        inputParams[3] = "uint16 resetTimeMin";
        inputParams[4] = "uint32 resetBaseMin";

        conditions.allowedRole = type(uint256).max; // Public
        primaryConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Set Allowance: Set allowance for sub-DAO.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "SafeAllowance_Action"),
                config: abi.encode(
                    inputParams,
                    bytes4(0xbeaeb388), // == AllowanceModule.setAllowance.selector (because the contracts are compiled with different solidity versions we cannot reference the contract directly here)
                    allowanceModule
                ),
                conditions: conditions // everythign zero == Only admin can call directly
            })
        );
        delete conditions;

        return primaryConstitution;
    }

    function safeProtocol_Child_IntegrationTestConstitution(address treasury, address allowanceModule)
        external
        returns (PowersTypes.MandateInitData[] memory mandateInitData)
    {
        delete childConstitution; // restart childConstitution array.

        // Mandate: Execute Allowance Transaction
        conditions.allowedRole = type(uint256).max; // Public
        childConstitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Execute Allowance Transaction: Execute a transaction from the Safe Treasury within the allowance set.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "SafeAllowance_Transfer"),
                config: abi.encode(
                    allowanceModule,
                    treasury // This is the SafeProxyTreasury!
                ),
                conditions: conditions
            })
        );
        delete conditions;

        return childConstitution;
    }

    //////////////////////////////////////////////////////////////
    //                  REFORM CONSTITUTION                     //
    //////////////////////////////////////////////////////////////
    function pauseMandatesTestConstitution()
        external
        returns (PowersTypes.MandateInitData[] memory mandateInitData, PowersTypes.Flow[] memory flows_)
    {
        delete constitution;

        // Mandate 1: SelfSelect — target mandate to be paused and restarted
        conditions.allowedRole = type(uint256).max;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "SelfSelect: self-assign as a member.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "SelfSelect"),
                config: abi.encode(1), // roleId to assign
                conditions: conditions
            })
        );
        delete conditions;

        // Mandate 2: PauseMandates — valid config, targets flow[0][0]
        uint8[] memory indexFlow1 = new uint8[](1);
        uint8[] memory indexMandate1 = new uint8[](1);
        indexFlow1[0] = 0;
        indexMandate1[0] = 0;
        conditions.allowedRole = 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "PauseMandates: pause or restart mandates in flow.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "PauseMandates"),
                config: abi.encode(indexFlow1, indexMandate1),
                conditions: conditions
            })
        );
        delete conditions;

        // Mandate 3: PauseMandates — invalid flow index (99), should skip silently
        uint8[] memory indexFlow2 = new uint8[](1);
        uint8[] memory indexMandate2 = new uint8[](1);
        indexFlow2[0] = 99;
        indexMandate2[0] = 0;
        conditions.allowedRole = 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "PauseMandates: invalid flow index.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "PauseMandates"),
                config: abi.encode(indexFlow2, indexMandate2),
                conditions: conditions
            })
        );
        delete conditions;

        // Mandate 4: PauseMandates — valid flow[0], out-of-bounds mandate index (99)
        uint8[] memory indexFlow3 = new uint8[](1);
        uint8[] memory indexMandate3 = new uint8[](1);
        indexFlow3[0] = 0;
        indexMandate3[0] = 99;
        conditions.allowedRole = 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "PauseMandates: out-of-bounds mandate index.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "PauseMandates"),
                config: abi.encode(indexFlow3, indexMandate3),
                conditions: conditions
            })
        );
        delete conditions;

        // Flow 0: contains SelfSelect (mandateId=1) at position 0
        flows_ = new PowersTypes.Flow[](1);
        uint16[] memory flowMandates_ = new uint16[](1);
        flowMandates_[0] = 1;
        flows_[0] = PowersTypes.Flow({ mandateIds: flowMandates_, nameDescription: "Test Flow: governance mandates" });

        return (constitution, flows_);
    }

    //////////////////////////////////////////////////////////////
    //               REVOKE MANDATES CONSTITUTION               //
    //////////////////////////////////////////////////////////////
    // Three mandates:
    // 1. SelfSelect — public, assigns role 1 (target to revoke)
    // 2. SelfSelect — public, assigns role 2 (second target to revoke)
    // 3. Revoke_Mandates — restricted to role 1
    function revokeMandatesTestConstitution(
        address /*daoMock*/
    )
        external
        returns (PowersTypes.MandateInitData[] memory)
    {
        delete constitution;

        conditions.allowedRole = type(uint256).max;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "SelfSelect: self-assign as member.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "SelfSelect"),
                config: abi.encode(uint256(1)),
                conditions: conditions
            })
        );
        delete conditions;

        conditions.allowedRole = type(uint256).max;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "SelfSelect: self-assign as delegate.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "SelfSelect"),
                config: abi.encode(uint256(2)),
                conditions: conditions
            })
        );
        delete conditions;

        conditions.allowedRole = 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Revoke_Mandates: revoke a list of mandates.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "Revoke_Mandates"),
                config: abi.encode(),
                conditions: conditions
            })
        );
        delete conditions;

        return constitution;
    }

    //////////////////////////////////////////////////////////////
    //                 HELPERS CONSTITUTION                     //
    //////////////////////////////////////////////////////////////
    function helpersTestConstitution() external returns (PowersTypes.MandateInitData[] memory mandateInitData) {
        delete constitution; // restart constitution array.

        // dummy call.
        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);
        targets[0] = address(123);
        calldatas[0] = abi.encode("mockCall");

        // Note: I leave the first slot empty, so that numbering is equal to how mandates are registered in IPowers.sol.
        // Counting starts at 1, so the first mandate is mandateId = 1.

        // openAction
        conditions.allowedRole = type(uint256).max;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "Open Action: Execute any action.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "OpenAction"), // openAction
                config: abi.encode(),
                conditions: conditions
            })
        );
        delete conditions;

        return constitution;
    }

    //////////////////////////////////////////////////////////////
    //            SLATE REGISTRY ADD SLATE CONSTITUTION         //
    //////////////////////////////////////////////////////////////
    // Two mandates:
    //   1. SlateRegistry_AddSlate — restricted to role 1, uses slateRegistryMock + presetActions
    //   2. SlateRegistry_RemoveSlate — restricted to role 1, links back to mandate 1
    // Two flows set at closeConstitute time:
    //   flow[0] — 3 empty slots (all zero), used for the happy-path test
    //   flow[1] — 1 occupied slot (mandateId=1), used for the no-empty-slot revert test
    function slateRegistryAddSlateTestConstitution(address slateRegistryMock, address presetActions)
        external
        returns (PowersTypes.MandateInitData[] memory mandateInitData, PowersTypes.Flow[] memory flows_)
    {
        delete constitution;

        // Mandate 1: SlateRegistry_AddSlate
        conditions.allowedRole = 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "SlateRegistry_AddSlate: add a slate to a SlateRegistry election.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "SlateRegistry_AddSlate"),
                config: abi.encode(slateRegistryMock, presetActions),
                conditions: conditions
            })
        );
        delete conditions;

        // Mandate 2: SlateRegistry_RemoveSlate (links to mandate 1 as addSlateMandateId)
        conditions.allowedRole = 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "SlateRegistry_RemoveSlate: remove a slate from a SlateRegistry election.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "SlateRegistry_RemoveSlate"),
                config: abi.encode(slateRegistryMock, uint16(1)), // addSlateMandateId = 1
                conditions: conditions
            })
        );
        delete conditions;

        // Mandate 3: SlateRegistry_ExecuteResult
        conditions.allowedRole = 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "SlateRegistry_ExecuteResult: execute the results of a SlateRegistry election.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "SlateRegistry_ExecuteResult"),
                config: abi.encode(slateRegistryMock),
                conditions: conditions
            })
        );
        delete conditions;

        // Flow 0: 3 empty slots — happy path (findEmptySlot returns index 0)
        flows_ = new PowersTypes.Flow[](2);
        uint16[] memory emptyFlow = new uint16[](3);
        flows_[0] = PowersTypes.Flow({ mandateIds: emptyFlow, nameDescription: "Slate election flow: 3 empty slots" });

        // Flow 1: 1 occupied slot (mandateId=1) — triggers "No empty slot in flow" revert
        uint16[] memory fullFlow = new uint16[](1);
        fullFlow[0] = 1;
        flows_[1] =
            PowersTypes.Flow({ mandateIds: fullFlow, nameDescription: "Slate election flow: all slots occupied" });

        return (constitution, flows_);
    }

    //////////////////////////////////////////////////////////////
    //          POWERS FACTORY TEST CONSTITUTION               //
    //////////////////////////////////////////////////////////////
    // Three mandates:
    // 1. BespokeAction_Simple calling returnDataMock.getValue() (returns uint256(42))
    // 2. PowersFactory_AssignRole — factoryMandateId=1, roleIdNewOrg=2
    // 3. PowersFactory_AddSafeDelegate — factoryMandateId=1, allowanceModule=address(1)
    function powersFactoryTestConstitution(address returnDataMockAddr)
        external
        returns (PowersTypes.MandateInitData[] memory)
    {
        delete constitution;

        string[] memory emptyParams = new string[](0);

        // Mandate 1: BespokeAction_Simple returning uint256(42), decodable as address(42)
        conditions.allowedRole = 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "BespokeActionReturner: returns address-decodable value for testing.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "BespokeAction_Simple"),
                config: abi.encode(returnDataMockAddr, ReturnDataMock.getValue.selector, emptyParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Mandate 2: PowersFactory_AssignRole using mandate 1 as the factory action
        conditions.allowedRole = 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "PowersFactory_AssignRole: assign role in new org.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "PowersFactory_AssignRole"),
                config: abi.encode(uint16(1), uint256(2), emptyParams),
                conditions: conditions
            })
        );
        delete conditions;

        // Mandate 3: PowersFactory_AddSafeDelegate using mandate 1 as the factory action
        conditions.allowedRole = 1;
        constitution.push(
            PowersTypes.MandateInitData({
                nameDescription: "PowersFactory_AddSafeDelegate: add safe delegate.",
                targetMandate: registry.getMandateAddress(MAJOR, MINOR, PATCH, "PowersFactory_AddSafeDelegate"),
                config: abi.encode(uint16(1), address(1), emptyParams),
                conditions: conditions
            })
        );
        delete conditions;

        return constitution;
    }
}
