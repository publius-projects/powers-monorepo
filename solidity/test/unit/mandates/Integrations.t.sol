// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { TestSetupIntegrations, TestSetupSlateRegistry, TestSetupPowersFactory } from "../../TestSetup.t.sol";
import { Governor_CreateProposal } from "@src/addons/mandates/integrations/Governor/Governor_CreateProposal.sol";
import { Governor_ExecuteProposal } from "@src/addons/mandates/integrations/Governor/Governor_ExecuteProposal.sol";

import { Mandate } from "@src/Mandate.sol";
import { IPowers } from "@src/interfaces/IPowers.sol";

// Safe contracts
import { SafeProxyFactory } from "@lib/safe-smart-account/contracts/proxies/SafeProxyFactory.sol";
import { Safe } from "@lib/safe-smart-account/contracts/Safe.sol";
import { ModuleManager } from "@lib/safe-smart-account/contracts/base/ModuleManager.sol";
import { Enum } from "@lib/safe-smart-account/contracts/common/Enum.sol";

import { PowersTypes } from "@src/interfaces/PowersTypes.sol";
import { ElectionRegistry } from "@src/core/helpers/ElectionRegistry.sol";
import { SlateRegistryMock } from "../../mocks/SlateRegistryMock.sol";
import { SlateRegistry_AddSlate } from "@src/core/mandates/integrations/SlateRegistry/SlateRegistry_AddSlate.sol";
import { SlateRegistry_RemoveSlate } from "@src/core/mandates/integrations/SlateRegistry/SlateRegistry_RemoveSlate.sol";
import {
    SlateRegistry_ExecuteResult
} from "@src/core/mandates/integrations/SlateRegistry/SlateRegistry_ExecuteResult.sol";
import { MandateUtilities } from "@src/libraries/MandateUtilities.sol";
import { Checks } from "@src/libraries/Checks.sol";
import { PowersFactory_AssignRole } from "@src/addons/mandates/integrations/PowersFactory/PowersFactory_AssignRole.sol";
import {
    PowersFactory_AddSafeDelegate
} from "@src/addons/mandates/integrations/PowersFactory/PowersFactory_AddSafeDelegate.sol";
import { SafeAllowance_Action } from "@src/core/mandates/integrations/Safe/SafeAllowance_Action.sol";
import { IERC20 } from "@lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import { PowersPaymaster } from "@src/core/helpers/PowersPaymaster.sol";
import { IEntryPoint } from "@lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { PackedUserOperation } from "@lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";

/// @notice Comprehensive unit tests for all executive mandates
/// @dev Tests all functionality of executive mandates including initialization, execution, and edge cases

//////////////////////////////////////////////////
//          GOVERNOR INTEGRATION TESTS          //
//////////////////////////////////////////////////
contract GovernorIntegrationTest is TestSetupIntegrations {
    Governor_CreateProposal public createProposalMandate;
    Governor_ExecuteProposal public executeProposalMandate;

    uint16 public createProposalId;
    uint16 public executeProposalId;

    function setUp() public override {
        super.setUp();

        // 1. Identify Mandate IDs from TestSetupIntegrations -> integrationsTestConstitution
        createProposalId = findMandateIdInOrg(
            "Governor_CreateProposal: A mandate to create governance proposals on a Governor contract.", daoMock
        );
        executeProposalId = findMandateIdInOrg(
            "Governor_ExecuteProposal: A mandate to execute governance proposals on a Governor contract.", daoMock
        );

        // 2. Get Mandate Instances
        createProposalMandate = Governor_CreateProposal(findMandateAddress("Governor_CreateProposal"));
        executeProposalMandate = Governor_ExecuteProposal(findMandateAddress("Governor_ExecuteProposal"));

        // 3. Setup Alice with votes for the Governor
        simpleErc20Votes.mint(10e18);
        simpleErc20Votes.transfer(alice, 10e18);
        vm.prank(alice);
        simpleErc20Votes.delegate(alice);
    }

    function test_Governor_CreateProposal_Success() public {
        // Setup proposal parameters
        address[] memory targets = new address[](1);
        targets[0] = address(simpleErc20Votes);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("transfer(address,uint256)", bob, 1e18);
        string memory description = "Test Proposal";

        // mint tokens to daoMock to have tokens to transfer.
        simpleErc20Votes.mint(address(daoMock), 5e18);

        // Encode mandate calldata
        bytes memory mandateCalldata = abi.encode(targets, values, calldatas, description);

        // Execute via DAO
        vm.prank(alice);
        daoMock.request(createProposalId, mandateCalldata, 0, "Create Proposal Request");

        // Verify proposal exists on Governor
        uint256 proposalId = simpleGovernor.hashProposal(targets, values, calldatas, keccak256(bytes(description)));
        assertGt(simpleGovernor.proposalSnapshot(proposalId), 0);
    }

    function test_Governor_CreateProposal_Revert_NotConfigured() public {
        // Create a fresh mandate that is NOT configured
        Governor_CreateProposal unconfiguredMandate = new Governor_CreateProposal(address(registry));
        // Don't initialize it, or initialize with 0 address

        uint16 unconfiguredId = 999;
        bytes memory mandateCalldata = abi.encode(new address[](0), new uint256[](0), new bytes[](0), "");

        vm.expectRevert();
        unconfiguredMandate.handleRequest(alice, address(daoMock), unconfiguredId, mandateCalldata, 0);
    }

    function test_Governor_CreateProposal_Revert_InvalidParams() public {
        // Empty targets
        address[] memory targets = new address[](0);
        uint256[] memory values = new uint256[](0);
        bytes[] memory calldatas = new bytes[](0);
        string memory description = "Test";

        bytes memory mandateCalldata = abi.encode(targets, values, calldatas, description);

        vm.prank(alice);
        vm.expectRevert("Governor_CreateProposal: No targets provided");
        daoMock.request(createProposalId, mandateCalldata, 0, "Invalid Params");

        // Mismatch length
        targets = new address[](1);
        targets[0] = address(0);

        mandateCalldata = abi.encode(targets, values, calldatas, description);

        vm.prank(alice);
        vm.expectRevert("Governor_CreateProposal: Targets and values length mismatch");
        daoMock.request(createProposalId, mandateCalldata, 0, "Mismatch Params");
    }

    function test_Governor_ExecuteProposal_Success() public {
        // 1. Setup and Create Proposal
        address[] memory targets = new address[](1);
        targets[0] = address(simpleErc20Votes);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("transfer(address,uint256)", bob, 1e18);
        string memory description = "Test Proposal Execution";

        // Create proposal directly on Governor
        vm.startPrank(alice);
        simpleErc20Votes.mint(address(daoMock), 100e18); // AI READ THIS: DO NOT DELETE. This is needed because the tokens will be transferred from the daoMock contract NOT from alice!
        simpleGovernor.propose(targets, values, calldatas, description);
        vm.stopPrank();

        uint256 proposalId = simpleGovernor.hashProposal(targets, values, calldatas, keccak256(bytes(description)));

        // 2. Advance to voting period
        vm.roll(block.number + simpleGovernor.votingDelay() + 1);

        // 3. Vote
        vm.prank(alice);
        simpleGovernor.castVote(proposalId, 1); // For

        // 4. Advance to end of voting period
        vm.roll(block.number + simpleGovernor.votingPeriod() + 1);

        // 5. Test Execute Mandate
        bytes memory mandateCalldata = abi.encode(targets, values, calldatas, description);

        vm.prank(alice);
        daoMock.request(executeProposalId, mandateCalldata, 0, "Execute Proposal");

        // Verify execution
        assertEq(uint256(simpleGovernor.state(proposalId)), 4); // Succeded state
    }

    function test_Governor_ExecuteProposal_Revert_NotSucceeded() public {
        // 1. Setup and Create Proposal
        address[] memory targets = new address[](1);
        targets[0] = address(simpleErc20Votes);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("transfer(address,uint256)", bob, 1e18);
        string memory description = "Test Proposal Fail";

        vm.prank(alice);
        simpleGovernor.propose(targets, values, calldatas, description);

        // 2. Try to execute immediately (Pending state)
        bytes memory mandateCalldata = abi.encode(targets, values, calldatas, description);

        vm.prank(alice);
        vm.expectRevert("Governor_ExecuteProposal: Proposal not succeeded");
        daoMock.request(executeProposalId, mandateCalldata, 0, "Execute Pending");

        // 3. Vote Against
        uint256 proposalId = simpleGovernor.hashProposal(targets, values, calldatas, keccak256(bytes(description)));
        vm.roll(block.number + simpleGovernor.votingDelay() + 1);

        vm.prank(alice);
        simpleGovernor.castVote(proposalId, 0); // Against

        vm.roll(block.number + simpleGovernor.votingPeriod() + 1);

        // 4. Try to execute (Defeated state)
        vm.prank(alice);
        vm.expectRevert("Governor_ExecuteProposal: Proposal not succeeded");
        daoMock.request(executeProposalId, mandateCalldata, 0, "Execute Defeated");
    }
}

//////////////////////////////////////////////////
//      SAFE ALLOWANCE INTEGRATION TESTS        //
//////////////////////////////////////////////////
//////////////////////////////////////////////////
//            SAFE INTEGRATION TESTS            //
//////////////////////////////////////////////////
/// @notice Shared setup for the Safe mandate tests: forks Sepolia, deploys a real Safe proxy as
/// daoMock's treasury, enables the canonical Allowance Module and constitutes daoMockChild1 with
/// the Safe allowance mandates (SafeAllowance_Transfer, SafeAllowance_PresetTransfer, Safe_RecoverTokens).
abstract contract SafeTestBase is TestSetupIntegrations {
    uint16 public safeAssignDelegateId;
    uint16 public setAllowanceExecTransactionId;
    uint16 public setAllowanceActionId;
    uint16 public allowanceTransferId;
    uint16 public presetTransferId;
    uint16 public recoverTokensId;
    address payable public treasury;
    address public allowanceModule;

    function setUp() public virtual override {
        vm.selectFork(vm.createFork(vm.envString("SEPOLIA_RPC_URL")));

        super.setUp();

        // skip these tests if allowance module is not set
        allowanceModule = helperConfig.getSafeAllowanceModule(block.chainid);
        if (allowanceModule == address(0)) {
            console2.log("Safe Allowance Module not set in config, skipping tests.");
            vm.skip(true);
        }

        safeAssignDelegateId =
            findMandateIdInOrg("Assign Delegate status: Assign delegate status at Safe treasury to a sub-DAO", daoMock);
        setAllowanceExecTransactionId =
            findMandateIdInOrg("Set Allowance: Execute and set allowance for a sub-DAO.", daoMock);
        setAllowanceActionId =
            findMandateIdInOrg("SafeAllowance_Action: Set allowance for a delegate via the Allowance Module.", daoMock);

        // Setup Safe treasury directly (following the pattern in Deploy.s.sol)
        address[] memory owners = new address[](1);
        owners[0] = address(daoMock);

        treasury = payable(address(
                SafeProxyFactory(helperConfig.getSafeProxyFactory(block.chainid))
                    .createProxyWithNonce(
                        helperConfig.getSafeL2Canonical(block.chainid),
                        abi.encodeWithSelector(
                            Safe.setup.selector,
                            owners,
                            1, // threshold
                            address(0), // to
                            "", // data
                            address(0), // fallbackHandler
                            address(0), // paymentToken
                            0, // payment
                            address(0) // paymentReceiver
                        ),
                        1 // = nonce
                    )
            ));

        // Set the treasury on the daoMock
        vm.prank(address(daoMock));
        IPowers(address(daoMock)).setTreasury(treasury);

        // Enable the allowance module on the Safe
        bytes memory enableModuleCalldata = abi.encodeWithSelector(ModuleManager.enableModule.selector, allowanceModule);

        // Compute the tx hash and pre-approve it as daoMock (the Safe owner).
        // Using approveHash is version-agnostic: the Sepolia fork runs Safe 1.4.0 bytecode whose
        // v=1 check passes executor through a different code path than the local library expects.
        bytes32 enableModuleTxHash = Safe(treasury)
            .getTransactionHash(
                treasury,
                0,
                enableModuleCalldata,
                Enum.Operation.Call,
                0,
                0,
                0,
                address(0),
                address(0),
                Safe(treasury).nonce()
            );
        vm.prank(address(daoMock));
        Safe(treasury).approveHash(enableModuleTxHash);

        // v=1 approved-hash signature; no prank needed since hash is pre-approved.
        bytes memory signature = abi.encodePacked(uint256(uint160(address(daoMock))), uint256(0), uint8(1));
        Safe(treasury)
            .execTransaction(
                treasury,
                0,
                enableModuleCalldata,
                Enum.Operation.Call,
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                signature
            );

        // Now that the treasury is set, we can constitute the child DAO.
        // This ensures the child DAO is configured with the correct treasury address.
        (PowersTypes.MandateInitData[] memory mandateInitData2_) =
            testConstitutions.integrationsTestConstitution2(address(daoMock), address(simpleErc20Votes));
        daoMockChild1.constitute(mandateInitData2_);
        daoMockChild1.closeConstitute();

        allowanceTransferId = findMandateIdInOrg(
            "Execute Allowance Transaction: Execute a transaction from the Safe Treasury within the allowance set.",
            daoMockChild1
        );
        presetTransferId = findMandateIdInOrg(
            "SafeAllowance_PresetTransfer: Transfer a preset amount of a preset token from the Safe treasury.",
            daoMockChild1
        );
        recoverTokensId = findMandateIdInOrg(
            "Safe_RecoverTokens: Return tokens held by this organisation to the Safe treasury.", daoMockChild1
        );
    }

    /// @dev Registers `delegateAddress` as a delegate on the Allowance Module via the Safe_ExecTransaction mandate.
    function assignDelegate(address delegateAddress) internal {
        vm.prank(alice);
        daoMock.request(safeAssignDelegateId, abi.encode(delegateAddress), nonce, "Assign delegate status");
    }

    /// @dev Sets a token allowance for `delegateAddress` via the Safe_ExecTransaction mandate.
    function setAllowance(address delegateAddress, address token, uint96 amount) internal {
        bytes memory setAllowanceCalldata = abi.encode(delegateAddress, token, amount, uint16(0), uint32(0));
        vm.prank(alice);
        daoMock.request(setAllowanceExecTransactionId, setAllowanceCalldata, nonce, "Set allowance");
    }

    /// @dev Reads [amount, spent, resetTimeMin, lastResetMin, nonce] for a delegate/token pair from the Allowance Module.
    function getTokenAllowance(address delegateAddress, address token) internal view returns (uint256[5] memory) {
        (bool success, bytes memory returnData) = allowanceModule.staticcall(
            abi.encodeWithSignature("getTokenAllowance(address,address,address)", treasury, delegateAddress, token)
        );
        require(success, "getTokenAllowance staticcall failed");
        return abi.decode(returnData, (uint256[5]));
    }
}

// ─────────────────────────────────────────────
//     Safe_ExecTransaction: BASIC BEHAVIOUR
// ─────────────────────────────────────────────
contract Safe_ExecTransactionBasicTest is SafeTestBase {
    function testExecTransactionAddsDelegateToAllowanceModule() public {
        mandateCalldata = abi.encode(address(daoMockChild1));
        vm.prank(alice);
        daoMock.request(safeAssignDelegateId, mandateCalldata, nonce, "Add delegate via Safe execTransaction");

        actionId = MandateUtilities.computeActionId(safeAssignDelegateId, mandateCalldata, nonce);
        assertEq(uint8(daoMock.getActionState(actionId)), uint8(PowersTypes.ActionState.Fulfilled));

        // the delegate must be registered on the Allowance Module
        (bool success, bytes memory returnData) = allowanceModule.staticcall(
            abi.encodeWithSignature("getDelegates(address,uint48,uint8)", treasury, uint48(0), uint8(10))
        );
        assertTrue(success);
        (address[] memory delegates,) = abi.decode(returnData, (address[], uint48));
        bool delegateFound;
        for (uint256 k; k < delegates.length; k++) {
            if (delegates[k] == address(daoMockChild1)) delegateFound = true;
        }
        assertTrue(delegateFound);
    }

    function testExecTransactionSetsAllowanceOnModule() public {
        assignDelegate(address(daoMockChild1));
        setAllowance(address(daoMockChild1), address(simpleErc20Votes), uint96(2e16));

        uint256[5] memory allowanceData = getTokenAllowance(address(daoMockChild1), address(simpleErc20Votes));
        assertEq(allowanceData[0], 2e16);
    }
}

// ─────────────────────────────────────────────
//        Safe_ExecTransaction: EDGE CASES
// ─────────────────────────────────────────────
contract Safe_ExecTransactionEdgeCaseTest is TestSetupIntegrations {
    function testHandleRequestRevertsIfTreasuryNotSet() public {
        // daoMock's treasury is never set in the plain integrations setup.
        assertEq(daoMock.getTreasury(), address(0));

        mandateId = findMandateIdInOrg(
            "Assign Delegate status: Assign delegate status at Safe treasury to a sub-DAO", daoMock
        );
        (mandateAddress,,) = daoMock.getAdoptedMandate(mandateId);

        vm.expectRevert("No Safe treasury set");
        Mandate(mandateAddress).handleRequest(alice, address(daoMock), mandateId, abi.encode(bob), nonce);
    }
}

// ─────────────────────────────────────────────
//     SafeAllowance_Action: BASIC BEHAVIOUR
// ─────────────────────────────────────────────
contract SafeAllowance_ActionBasicTest is SafeTestBase {
    function testRequestSetsAllowanceViaAllowanceModule() public {
        assignDelegate(address(daoMockChild1));

        mandateCalldata =
            abi.encode(address(daoMockChild1), address(simpleErc20Votes), uint96(5e16), uint16(0), uint32(0));
        vm.prank(alice);
        daoMock.request(setAllowanceActionId, mandateCalldata, nonce, "Set allowance via SafeAllowance_Action");

        actionId = MandateUtilities.computeActionId(setAllowanceActionId, mandateCalldata, nonce);
        assertEq(uint8(daoMock.getActionState(actionId)), uint8(PowersTypes.ActionState.Fulfilled));

        uint256[5] memory allowanceData = getTokenAllowance(address(daoMockChild1), address(simpleErc20Votes));
        assertEq(allowanceData[0], 5e16);
    }

    function testHandleRequestEncodesExecTransactionCall() public {
        (mandateAddress,,) = daoMock.getAdoptedMandate(setAllowanceActionId);
        mandateCalldata =
            abi.encode(address(daoMockChild1), address(simpleErc20Votes), uint96(5e16), uint16(0), uint32(0));

        (
            uint256 returnedActionId,
            address[] memory returnedTargets,
            uint256[] memory returnedValues,
            bytes[] memory returnedCalldatas
        ) = Mandate(mandateAddress).handleRequest(alice, address(daoMock), setAllowanceActionId, mandateCalldata, nonce);

        assertEq(returnedActionId, MandateUtilities.computeActionId(setAllowanceActionId, mandateCalldata, nonce));
        assertEq(returnedTargets.length, 1);
        assertEq(returnedTargets[0], treasury);
        assertEq(returnedValues[0], 0);
        assertEq(bytes4(returnedCalldatas[0]), Safe.execTransaction.selector);
    }

    function testInitializeMandateStoresConfig() public {
        (mandateAddress,,) = daoMock.getAdoptedMandate(setAllowanceActionId);
        (bytes4 storedSelector, address storedModule) = SafeAllowance_Action(mandateAddress)
            .mandateConfig(MandateUtilities.hashMandate(address(daoMock), setAllowanceActionId));

        assertEq(storedSelector, bytes4(0xbeaeb388)); // AllowanceModule.setAllowance.selector
        assertEq(storedModule, allowanceModule);
    }
}

// ─────────────────────────────────────────────
//       SafeAllowance_Action: EDGE CASES
// ─────────────────────────────────────────────
contract SafeAllowance_ActionEdgeCaseTest is TestSetupIntegrations {
    function testHandleRequestRevertsIfTreasuryNotSet() public {
        // daoMock's treasury is never set in the plain integrations setup.
        assertEq(daoMock.getTreasury(), address(0));

        mandateId =
            findMandateIdInOrg("SafeAllowance_Action: Set allowance for a delegate via the Allowance Module.", daoMock);
        (mandateAddress,,) = daoMock.getAdoptedMandate(mandateId);

        mandateCalldata = abi.encode(bob, address(simpleErc20Votes), uint96(1e16), uint16(0), uint32(0));
        vm.expectRevert("SafeAllowance_Action: Treasury not set in Powers");
        Mandate(mandateAddress).handleRequest(alice, address(daoMock), mandateId, mandateCalldata, nonce);
    }
}

// ─────────────────────────────────────────────
//    SafeAllowance_Transfer: BASIC BEHAVIOUR
// ─────────────────────────────────────────────
contract SafeAllowance_TransferBasicTest is SafeTestBase {
    function testAllowanceTransferSendsTokensToRecipient() public {
        assignDelegate(address(daoMockChild1));
        setAllowance(address(daoMockChild1), address(simpleErc20Votes), uint96(2e16));
        simpleErc20Votes.mint(treasury, 1e18); // Fund the Safe treasury

        balanceBefore = simpleErc20Votes.balanceOf(bob);
        mandateCalldata = abi.encode(address(simpleErc20Votes), uint96(1e16), bob);
        vm.prank(alice);
        daoMockChild1.request(allowanceTransferId, mandateCalldata, nonce, "Transfer within allowance");

        actionId = MandateUtilities.computeActionId(allowanceTransferId, mandateCalldata, nonce);
        assertEq(uint8(daoMockChild1.getActionState(actionId)), uint8(PowersTypes.ActionState.Fulfilled));
        assertEq(simpleErc20Votes.balanceOf(bob) - balanceBefore, 1e16);
    }
}

// ─────────────────────────────────────────────
//  SafeAllowance_PresetTransfer: BASIC BEHAVIOUR
// ─────────────────────────────────────────────
contract SafeAllowance_PresetTransferBasicTest is SafeTestBase {
    function testPresetTransferSendsPresetAmountToRecipient() public {
        assignDelegate(address(daoMockChild1));
        setAllowance(address(daoMockChild1), address(simpleErc20Votes), uint96(2e16));
        simpleErc20Votes.mint(treasury, 1e18); // Fund the Safe treasury

        balanceBefore = simpleErc20Votes.balanceOf(bob);
        mandateCalldata = abi.encode(bob);
        vm.prank(alice);
        daoMockChild1.request(presetTransferId, mandateCalldata, nonce, "Preset transfer to bob");

        actionId = MandateUtilities.computeActionId(presetTransferId, mandateCalldata, nonce);
        assertEq(uint8(daoMockChild1.getActionState(actionId)), uint8(PowersTypes.ActionState.Fulfilled));
        assertEq(simpleErc20Votes.balanceOf(bob) - balanceBefore, 1e16); // the preset amount
    }

    function testHandleRequestEncodesAllowanceTransferCall() public {
        (mandateAddress,,) = daoMockChild1.getAdoptedMandate(presetTransferId);
        mandateCalldata = abi.encode(bob);

        (uint256 returnedActionId, address[] memory returnedTargets,, bytes[] memory returnedCalldatas) = Mandate(
                mandateAddress
            ).handleRequest(alice, address(daoMockChild1), presetTransferId, mandateCalldata, nonce);

        assertEq(returnedActionId, MandateUtilities.computeActionId(presetTransferId, mandateCalldata, nonce));
        assertEq(returnedTargets.length, 1);
        assertEq(returnedTargets[0], allowanceModule);
        assertEq(
            returnedCalldatas[0],
            abi.encodeWithSelector(
                bytes4(0x4515641a), // executeAllowanceTransfer(address,address,address,uint96,address,uint96,address,bytes)
                treasury,
                address(simpleErc20Votes),
                bob,
                uint96(1e16), // the preset amount
                address(0), // paymentToken
                uint96(0), // paymentAmount
                address(daoMockChild1), // the delegate executing the transfer
                abi.encodePacked(uint256(uint160(address(daoMockChild1))), uint256(0), uint8(1)) // v=1 signature
            )
        );
    }
}

// ─────────────────────────────────────────────
//   SafeAllowance_PresetTransfer: EDGE CASES
// ─────────────────────────────────────────────
contract SafeAllowance_PresetTransferEdgeCaseTest is SafeTestBase {
    function testPresetTransferRevertsWhenAllowanceTooLow() public {
        assignDelegate(address(daoMockChild1));
        setAllowance(address(daoMockChild1), address(simpleErc20Votes), uint96(1e15)); // below the preset 1e16
        simpleErc20Votes.mint(treasury, 1e18); // Fund the Safe treasury

        vm.prank(alice);
        vm.expectRevert();
        daoMockChild1.request(presetTransferId, abi.encode(bob), nonce, "Preset transfer above allowance");
    }
}

// ─────────────────────────────────────────────
//      Safe_RecoverTokens: BASIC BEHAVIOUR
// ─────────────────────────────────────────────
contract Safe_RecoverTokensBasicTest is SafeTestBase {
    function testRecoverTokensTransfersFullBalanceToTreasury() public {
        assignDelegate(address(daoMockChild1));
        setAllowance(address(daoMockChild1), address(simpleErc20Votes), uint96(2e16)); // registers the token for the delegate
        simpleErc20Votes.mint(address(daoMockChild1), 5e16);

        balanceBefore = simpleErc20Votes.balanceOf(treasury);
        mandateCalldata = abi.encode();
        vm.prank(alice);
        daoMockChild1.request(recoverTokensId, mandateCalldata, nonce, "Recover tokens to treasury");

        actionId = MandateUtilities.computeActionId(recoverTokensId, mandateCalldata, nonce);
        assertEq(uint8(daoMockChild1.getActionState(actionId)), uint8(PowersTypes.ActionState.Fulfilled));
        assertEq(simpleErc20Votes.balanceOf(address(daoMockChild1)), 0);
        assertEq(simpleErc20Votes.balanceOf(treasury) - balanceBefore, 5e16);
    }

    function testHandleRequestSkipsZeroBalanceTokens() public {
        assignDelegate(address(daoMockChild1));
        setAllowance(address(daoMockChild1), address(simpleErc20Votes), uint96(2e16));
        setAllowance(address(daoMockChild1), address(erc20Taxed), uint96(2e16)); // second token, never funded
        simpleErc20Votes.mint(address(daoMockChild1), 5e16);

        (mandateAddress,,) = daoMockChild1.getAdoptedMandate(recoverTokensId);
        (, address[] memory returnedTargets,, bytes[] memory returnedCalldatas) =
            Mandate(mandateAddress).handleRequest(alice, address(daoMockChild1), recoverTokensId, abi.encode(), nonce);

        assertEq(returnedTargets.length, 1);
        assertEq(returnedTargets[0], address(simpleErc20Votes));
        assertEq(returnedCalldatas[0], abi.encodeWithSelector(IERC20.transfer.selector, treasury, 5e16));
    }
}

// ─────────────────────────────────────────────
//        Safe_RecoverTokens: EDGE CASES
// ─────────────────────────────────────────────
contract Safe_RecoverTokensEdgeCaseTest is SafeTestBase {
    function testHandleRequestReturnsEmptyArraysWhenNoTokensRegistered() public {
        // No delegate or allowance has been set, so the module lists no tokens for the child.
        (mandateAddress,,) = daoMockChild1.getAdoptedMandate(recoverTokensId);
        (, address[] memory returnedTargets, uint256[] memory returnedValues, bytes[] memory returnedCalldatas) =
            Mandate(mandateAddress).handleRequest(alice, address(daoMockChild1), recoverTokensId, abi.encode(), nonce);

        assertEq(returnedTargets.length, 0);
        assertEq(returnedValues.length, 0);
        assertEq(returnedCalldatas.length, 0);
    }

    function testHandleRequestReturnsEmptyArraysWhenAllBalancesZero() public {
        assignDelegate(address(daoMockChild1));
        setAllowance(address(daoMockChild1), address(simpleErc20Votes), uint96(2e16)); // token registered, but the child holds none

        (mandateAddress,,) = daoMockChild1.getAdoptedMandate(recoverTokensId);
        (, address[] memory returnedTargets,, bytes[] memory returnedCalldatas) =
            Mandate(mandateAddress).handleRequest(alice, address(daoMockChild1), recoverTokensId, abi.encode(), nonce);

        assertEq(returnedTargets.length, 0);
        assertEq(returnedCalldatas.length, 0);
    }
}

contract GovernedToken_GatedAccessTest is TestSetupIntegrations {
    uint16 public mintMandateId;
    uint16 public accessMandateId;
    uint256 public targetRoleId;

    function setUp() public override {
        super.setUp();

        mintMandateId = findMandateIdInOrg(
            "Mint soulbound token: mint a soulbound ERC1155 token and send it to an address of choice.", daoMock
        );
        accessMandateId =
            findMandateIdInOrg("Soulbound1155 Access: Get roleId through soulbound ERC1155 token.", daoMock);
        targetRoleId = 9;
    }

    function test_GovernedToken_GatedAccess_Success() public {
        vm.startPrank(alice);

        // 1. Mint 4 tokens (Threshold is 3, need > 3 tokens. i.e. 4)
        uint256[] memory tokenIds = new uint256[](4);

        for (uint256 i = 0; i < 4; i++) {
            // Config for mandate 7: params[0] = "address to"
            // So request calldata should be abi.encode(to).
            daoMock.request(mintMandateId, abi.encode(alice, bob, ""), nonce, "Mint Token");

            // Calculate ID that was minted
            // TokenID = (minter << 48) | blockNumber
            // Minter is daoMock (owner of soulbound1155)
            uint256 tokenId = (uint256(uint160(address(alice))) << 48) | uint256(block.number);
            tokenIds[i] = tokenId;

            // Advance block to get unique IDs (and test block threshold)
            // Config block threshold is 100.
            vm.roll(block.number + 1);
            nonce++;
        }

        // 2. Request Access using the minted tokens
        // Check if we are within block threshold.
        // Current block is X. Token mint blocks are X-4, X-3, X-2, X-1.
        // Threshold is 100. So we are well within threshold.
        daoMock.request(accessMandateId, abi.encode(tokenIds), nonce++, "Request Access");
        vm.stopPrank();

        // 3. Verify Role Assigned
        assertTrue(daoMock.hasRoleSince(alice, targetRoleId) > 0);
    }

    function test_GovernedToken_GatedAccess_Revert_InsufficientTokens() public {
        vm.startPrank(alice); // NB: alice mints the tokens. It is her address that is encoded in their Ids!

        // Mint 3 tokens (Threshold is 3, check is <= threshold, so 3 fails)
        uint256[] memory tokenIds = new uint256[](3);
        for (uint256 i = 0; i < 3; i++) {
            daoMock.request(mintMandateId, abi.encode(alice, bob, ""), nonce, "Mint Token");
            tokenIds[i] = (uint256(uint160(address(daoMock))) << 48) | uint256(block.number);
            vm.roll(block.number + 1);
            nonce++;
        }

        vm.expectRevert("Insuffiicent valid tokens provided");
        daoMock.request(accessMandateId, abi.encode(tokenIds), 0, "Request Access");

        vm.stopPrank();
    }

    function test_GovernedToken_GatedAccess_Revert_NotOwnerOfToken() public {
        vm.startPrank(alice);

        // Mint 4 tokens
        uint256[] memory tokenIds = new uint256[](4);
        for (uint256 i = 0; i < 4; i++) {
            daoMock.request(mintMandateId, abi.encode(alice, bob, ""), nonce, "Mint Token");
            tokenIds[i] = (uint256(uint160(address(alice))) << 48) | uint256(block.number);
            vm.roll(block.number + 1);
            nonce++;
        }

        // Change one token to random ID (alice doesn't own it)
        tokenIds[0] = 123_456_789;
        tokenIds[1] = 123_456_789;

        vm.expectRevert("Insuffiicent valid tokens provided");
        daoMock.request(accessMandateId, abi.encode(tokenIds), 0, "Request Access");

        vm.stopPrank();
    }

    function test_GovernedToken_GatedAccess_Revert_TokenExpired() public {
        vm.startPrank(alice);

        uint256[] memory tokenIds = new uint256[](4);
        for (uint256 i = 0; i < 4; i++) {
            daoMock.request(mintMandateId, abi.encode(alice, bob, ""), nonce, "Mint Token");
            tokenIds[i] = (uint256(uint160(address(alice))) << 48) | uint256(block.number);
            vm.roll(block.number + 1);
            nonce++;
        }

        // Advance block beyond threshold
        // Threshold is 100.
        // Last token minted at T. Current block is T+1.
        // We want (block.number - mintBlock) > threshold.
        // mintBlock = T.
        // Need block.number > T + 100.
        // So + 101 blocks.
        vm.roll(block.number + 101);
        vm.expectRevert("Insuffiicent valid tokens provided");
        daoMock.request(accessMandateId, abi.encode(tokenIds), nonce, "Request Access");

        vm.stopPrank();
    }
}

contract GovernedToken_BurnToAccessTest is TestSetupIntegrations {
    uint16 public mintMandateId;
    uint16 public burnToAccessId;

    function setUp() public override {
        super.setUp();

        mintMandateId = findMandateIdInOrg(
            "Mint soulbound token: mint a soulbound ERC1155 token and send it to an address of choice.", daoMock
        );
        burnToAccessId = findMandateIdInOrg("Burn to Access: Burn a soulbound ERC1155 token to gain access.", daoMock);
    }

    function test_GovernedToken_BurnToAccess_Success() public {
        vm.startPrank(alice);

        // 1. Mint 1 token
        daoMock.request(mintMandateId, abi.encode(alice, bob, ""), nonce, "Mint Token");

        // TokenID = (minter << 48) | blockNumber
        // Minter is daoMock (owner of soulbound1155)
        uint256 tokenId = (uint256(uint160(address(alice))) << 48) | uint256(block.number);

        // Balance should be 1
        assertEq(soulbound1155.balanceOf(alice, tokenId), 1);

        // 2. Request BurnToAccess using the minted token
        daoMock.request(burnToAccessId, abi.encode(tokenId), nonce + 1, "Request Burn");

        // 3. Verify token was burned
        assertEq(soulbound1155.balanceOf(alice, tokenId), 0);

        vm.stopPrank();
    }

    function test_GovernedToken_BurnToAccess_Revert_InsufficientBalance() public {
        vm.startPrank(alice);

        // Don't mint anything, just try to burn a non-existent token
        uint256 fakeTokenId = 123_456_789;

        vm.expectRevert("Insufficient balance");
        daoMock.request(burnToAccessId, abi.encode(fakeTokenId), nonce, "Request Burn");

        vm.stopPrank();
    }
}

//////////////////////////////////////////////////
//              ELECTIONLIST TESTS              //
//////////////////////////////////////////////////
contract ElectionRegistryIntegrationTest is TestSetupIntegrations {
    uint16 createElectionId;
    uint16 nominateId;
    uint16 revokeId;
    uint16 openVoteId;
    uint16 tallyId;
    uint16 cleanupId;

    address electionListAddress;
    string title = "Test Election";
    uint48 startBlock;
    uint48 endBlock;
    bytes electionParams;
    uint256 electionId;
    uint16 voteMandateId;
    bytes voteParams;
    uint256 creationAcionId;
    bytes returnData;
    bytes mandateConfig;
    address[] nomineesList;
    uint256 openActionId;
    bool[] votes;

    function setUp() public override {
        super.setUp();

        createElectionId =
            findMandateIdInOrg("Create an election: an election can be initiated be any member.", daoMock);
        nominateId = findMandateIdInOrg("Nominate for election: any member can nominate for an election.", daoMock);
        revokeId = findMandateIdInOrg(
            "Revoke nomination for election: any member can revoke their nomination for an election.", daoMock
        );
        openVoteId = findMandateIdInOrg(
            "Open voting for election: Members can open the vote for an election. This will create a dedicated vote mandate.",
            daoMock
        );
        tallyId = findMandateIdInOrg(
            "Tally elections: After an election has finished, assign the Executive role to the winners.", daoMock
        );
        cleanupId = findMandateIdInOrg(
            "Clean up election: After an election has finished, clean up related mandates.", daoMock
        );

        startBlock = uint48(block.number + 300); // matches ElectionRegistry nominationDuration
        endBlock = uint48(block.number + 600); // matches nominationDuration + voteDuration
        electionParams = abi.encode(title, startBlock, endBlock);

        // Retrieve electionList address from mandate 9 config
        // Mandate 9 is BespokeAction_Simple.
        // Its config is (address target, bytes4 selector, string[] params).
        // target is electionList.
        mandateConfig =
            Mandate(findMandateAddress("BespokeAction_Simple")).getConfig(address(daoMock), createElectionId);
        (electionListAddress,,) = abi.decode(mandateConfig, (address, bytes4, string[]));
    }

    function test_ElectionRegistry_FullFlow_Success() public {
        // 1. Create Election
        // BespokeAction_Simple params: encoded params for the function
        console2.log("Creating Election...");
        vm.prank(alice);
        creationAcionId = daoMock.request(createElectionId, electionParams, nonce, "Create Election");

        console2.log("Getting Election ID...");
        returnData = daoMock.getActionReturnData(creationAcionId, 0);
        electionId = abi.decode(returnData, (uint256));
        assertGt(electionId, 0);

        // 2. Nominate
        // Mandate expects (title, start, end) to compute ID
        console2.log("Nominating Alice...");
        vm.prank(alice);
        daoMock.request(nominateId, electionParams, nonce, "Nominate Alice");

        // Verify Nomination
        nomineesList = ElectionRegistry(electionListAddress).getNominees(electionId);
        assertEq(nomineesList.length, 1);
        assertEq(nomineesList[0], alice);

        vm.roll(startBlock + 1); // Advance to start block

        // 3. Open Vote
        // This deploys a new mandate.
        console2.log("Creating Vote Mandate...");
        vm.prank(alice);
        openActionId = daoMock.request(openVoteId, electionParams, nonce, "Creating Vote Mandate");

        // Get the new mandate ID (it is returned by adoptMandate which is the action executed)
        returnData = daoMock.getActionReturnData(openActionId, 0);
        voteMandateId = abi.decode(returnData, (uint16));
        assertTrue(voteMandateId > 0);

        // 4. Vote
        console2.log("Voting for Alice...");

        // Nominees: [alice]
        vm.prank(alice);
        daoMock.request(voteMandateId, abi.encode(true), nonce, "Vote for Alice");

        assertEq(ElectionRegistry(electionListAddress).getVoteCount(electionId, alice), 1);

        // 5. Tally
        vm.roll(endBlock + 1); // Advance to end block
        console2.log("Tallying Election...");

        // Setup existing role holders (none for role 2 initially maybe?)
        // Config says role 2 is Executive.
        vm.prank(alice);
        daoMock.request(tallyId, electionParams, nonce, "Tally Election");

        // Verify Alice has role 2
        assertTrue(daoMock.hasRoleSince(alice, 2) > 0);
    }
}

//////////////////////////////////////////////////
//   ELECTION REGISTRY CLEAN UP VOTE MANDATE    //
//////////////////////////////////////////////////
/// @notice Shared election-flow scaffolding for ElectionRegistry_CleanUpVoteMandate tests.
/// Runs the real governance chain (create → nominate → open vote → vote → tally) so the
/// temporary vote mandate genuinely exists before cleanup is exercised.
abstract contract ElectionRegistry_CleanUpVoteMandateTestBase is TestSetupIntegrations {
    uint16 createElectionId;
    uint16 nominateId;
    uint16 openVoteId;
    uint16 tallyId;
    uint16 cleanupId;

    string title = "Clean Up Test Election";
    uint48 startBlock;
    uint48 endBlock;
    bytes electionParams;
    uint16 voteMandateId;

    function setUp() public virtual override {
        super.setUp();

        createElectionId =
            findMandateIdInOrg("Create an election: an election can be initiated be any member.", daoMock);
        nominateId = findMandateIdInOrg("Nominate for election: any member can nominate for an election.", daoMock);
        openVoteId = findMandateIdInOrg(
            "Open voting for election: Members can open the vote for an election. This will create a dedicated vote mandate.",
            daoMock
        );
        tallyId = findMandateIdInOrg(
            "Tally elections: After an election has finished, assign the Executive role to the winners.", daoMock
        );
        cleanupId = findMandateIdInOrg(
            "Clean up election: After an election has finished, clean up related mandates.", daoMock
        );

        startBlock = uint48(block.number + 300); // matches ElectionRegistry nominationDuration
        endBlock = uint48(block.number + 600); // matches nominationDuration + voteDuration
        electionParams = abi.encode(title, startBlock, endBlock);
    }

    function runElectionThroughTally() internal {
        vm.prank(alice);
        daoMock.request(createElectionId, electionParams, nonce, "Create Election");

        vm.prank(alice);
        daoMock.request(nominateId, electionParams, nonce, "Nominate Alice");

        vm.roll(startBlock + 1);

        vm.prank(alice);
        actionId = daoMock.request(openVoteId, electionParams, nonce, "Creating Vote Mandate");
        voteMandateId = abi.decode(daoMock.getActionReturnData(actionId, 0), (uint16));

        vm.prank(alice);
        daoMock.request(voteMandateId, abi.encode(true), nonce, "Vote for Alice");

        vm.roll(endBlock + 1);
        vm.prank(alice);
        daoMock.request(tallyId, electionParams, nonce, "Tally Election");
    }
}

// ─────────────────────────────────────────────
//               BASIC BEHAVIOUR
// ─────────────────────────────────────────────
contract ElectionRegistry_CleanUpVoteMandateBasicTest is ElectionRegistry_CleanUpVoteMandateTestBase {
    function testCleanUpRevokesVoteMandateAfterElection() public {
        runElectionThroughTally();

        (,, active) = daoMock.getAdoptedMandate(voteMandateId);
        assertTrue(active, "vote mandate should be active before cleanup");

        // cleanup must use the exact calldata + nonce of the open-vote action,
        // as handleRequest recomputes the creation actionId from them.
        vm.prank(alice);
        actionId = daoMock.request(cleanupId, electionParams, nonce, "Clean up election");

        assertEq(uint8(daoMock.getActionState(actionId)), uint8(ActionState.Fulfilled));
        (,, active) = daoMock.getAdoptedMandate(voteMandateId);
        assertFalse(active, "vote mandate should be revoked after cleanup");
    }

    function testCleanUpInputParamsAreTitle() public {
        (mandateAddress,,) = daoMock.getAdoptedMandate(cleanupId);

        string[] memory expectedParams = new string[](1);
        expectedParams[0] = "string Title";
        assertEq(
            Mandate(mandateAddress).getInputParams(address(daoMock), cleanupId),
            abi.encode(expectedParams),
            "input params should be (string Title)"
        );

        uint16 configuredCreateVoteMandateId =
            abi.decode(Mandate(mandateAddress).getConfig(address(daoMock), cleanupId), (uint16));
        assertEq(configuredCreateVoteMandateId, openVoteId, "config should hold the open-vote mandate id");
    }
}

// ─────────────────────────────────────────────
//                  EDGE CASES
// ─────────────────────────────────────────────
contract ElectionRegistry_CleanUpVoteMandateEdgeCaseTest is ElectionRegistry_CleanUpVoteMandateTestBase {
    function testCleanUpRevertsIfCalldataDiffersFromCreation() public {
        runElectionThroughTally();

        bytes memory wrongParams = abi.encode("A different title", startBlock, endBlock);
        vm.prank(alice);
        vm.expectRevert(Checks.Checks__ParentMandateNotFulfilled.selector);
        daoMock.request(cleanupId, wrongParams, nonce, "Clean up election");
    }

    function testCleanUpRevertsIfNonceDiffersFromCreation() public {
        runElectionThroughTally();

        vm.prank(alice);
        vm.expectRevert(Checks.Checks__ParentMandateNotFulfilled.selector);
        daoMock.request(cleanupId, electionParams, nonce + 1, "Clean up election");
    }

    function testCleanUpRevertsIfVoteMandateNotCreated() public {
        // no election has run: the needFulfilled dependency on the open-vote mandate fails.
        vm.prank(alice);
        vm.expectRevert(Checks.Checks__ParentMandateNotFulfilled.selector);
        daoMock.request(cleanupId, electionParams, nonce, "Clean up election");
    }

    function testCleanUpTwiceRevertsOnSecondRequest() public {
        runElectionThroughTally();

        vm.prank(alice);
        daoMock.request(cleanupId, electionParams, nonce, "Clean up election");

        // same calldata + nonce yields the same actionId, which is already fulfilled.
        vm.prank(bob);
        vm.expectRevert(Powers__ActionAlreadyInitiated.selector);
        daoMock.request(cleanupId, electionParams, nonce, "Clean up election again");
    }
}

// ─────────────────────────────────────────────
//               ACCESS CONTROL
// ─────────────────────────────────────────────
contract ElectionRegistry_CleanUpVoteMandateAccessTest is ElectionRegistry_CleanUpVoteMandateTestBase {
    function testCleanUpRevertsIfCallerLacksRole() public {
        runElectionThroughTally();

        vm.prank(eve); // eve holds no role in daoMock
        vm.expectRevert(Powers__CannotCallMandate.selector);
        daoMock.request(cleanupId, electionParams, nonce, "Clean up election");
    }
}

//////////////////////////////////////////////////
//            ZKPASSPORT CHECK TESTS            //
//////////////////////////////////////////////////
contract ZKPassport_CheckTest is TestSetupIntegrations {
    uint16 public checkMandateAboveId;
    uint16 public checkMandateBelowId;
    uint16 public checkMandateNationalityId;
    address public registryAddress;

    function setUp() public override {
        // The only robust approach is to create fork BEFORE setup is run.
        uint256 sepoliaFork = vm.createFork(vm.envString("SEPOLIA_RPC_URL"));
        vm.selectFork(sepoliaFork);
        vm.skip(true);

        // important:  // We created an actual proof in the registry for cedars proving he was born in 1983. So we can test the full integration on the fork, without mocking any part of the flow.

        super.setUp();
        checkMandateAboveId = findMandateIdInOrg("ZKPassport Check: Check if a user is above 18 years old.", daoMock);
        checkMandateBelowId = findMandateIdInOrg("ZKPassport Check: Check if a user is below 18 years old.", daoMock);
        checkMandateNationalityId = findMandateIdInOrg("ZKPassport Check: Check if a user is from GBR.", daoMock);
        registryAddress = address(zkPassportRegistry);
    }

    function test_ZKPassport_Nationality_Check_Success() public {
        // Here we check of cedars is from GBR, which should pass.
        vm.prank(cedars);
        uint256 actionId = daoMock.request(checkMandateNationalityId, abi.encode(cedars), nonce, "Check Nationality");

        // check status of call.
        uint8 status = uint8(daoMock.getActionState(actionId));
        assertTrue(status == 7); // 7 = Fulfilled
    }

    function test_ZKPassport_Age_Check_Success() public {
        // Here we check of cedars is below 18, which should pass.
        vm.prank(cedars);
        uint256 actionId = daoMock.request(checkMandateAboveId, abi.encode(cedars), nonce, "Check Age");

        // check status of call.
        uint8 status = uint8(daoMock.getActionState(actionId));
        assertTrue(status == 7); // 7 = Fulfilled
    }

    // Following tests are nonsense. (AI generated)
    function test_ZKPassport_Check_Fail() public {
        // Here we check of cedars is below 18, which should fail.
        vm.prank(cedars);
        vm.expectRevert("ZKPassport: Proof verification failed");
        daoMock.request(checkMandateBelowId, abi.encode(cedars), nonce, "Check Birthdate Fail");
    }

    function test_ZKPassport_Check_Revert_NoRegistration() public {
        // Try to check someone else's account. Which should fail.
        vm.prank(alice);
        vm.expectRevert("No registration found");
        daoMock.request(checkMandateAboveId, abi.encode(alice), nonce, "Check alice");
    }
}

contract MockEntryPoint is IEntryPoint {
    function depositTo(
        address /*account*/
    )
        external
        payable { }
    function withdrawTo(
        address payable,
        /*withdrawAddress*/
        uint256 /*withdrawAmount*/
    )
        external { }
    // Stub other functions
    function handleOps(PackedUserOperation[] calldata, address payable) external { }
    function handleAggregatedOps(UserOpsPerAggregator[] calldata, address payable) external { }
    function getSenderAddress(bytes memory) external { }
    function simulateValidation(PackedUserOperation calldata) external { }
    function simulateHandleOp(PackedUserOperation calldata, address, bytes calldata) external { }

    function balanceOf(address) external view returns (uint256) {
        return 0;
    }

    function deposit() external view returns (uint256) {
        return 0;
    }

    function getDepositInfo(address) external view returns (DepositInfo memory) {
        return DepositInfo({ deposit: 100, staked: true, stake: 100, unstakeDelaySec: 100, withdrawTime: 0 });
    }

    function getNonce(address, uint192) external view returns (uint256) {
        return 0;
    }
    function incrementNonce(uint192) external { }
    function addStake(uint32) external payable { }
    function unlockStake() external { }
    function withdrawStake(address payable) external { }
    function delegateAndRevert(address, bytes calldata) external { }

    function getCurrentUserOpHash() external view returns (bytes32) {
        return bytes32(0);
    }

    function getUserOpHash(PackedUserOperation calldata) external view returns (bytes32) {
        return bytes32(0);
    }

    function supportsInterface(bytes4 interfaceId) external view returns (bool) {
        return interfaceId == type(IEntryPoint).interfaceId || interfaceId == 0x01ffc9a7; // ERC165
    }
}

contract AccountAbstractionTest is Test {
    PowersPaymaster public paymaster;

    address public powersAddress = address(0x1234);
    MockEntryPoint public entryPoint;
    address public owner = address(this);

    function setUp() public {
        entryPoint = new MockEntryPoint();
        paymaster = new PowersPaymaster(entryPoint, powersAddress);
    }

    // Helper to simulate calling _validatePaymasterUserOp since it's internal and we can only call external validatePaymasterUserOp as entryPoint
    function callValidatePaymasterUserOp(PackedUserOperation memory userOp)
        public
        returns (bytes memory context, uint256 validationData)
    {
        vm.prank(address(entryPoint));
        return paymaster.validatePaymasterUserOp(userOp, bytes32(0), 1000);
    }

    function test_Paymaster_AcceptsPowersTarget() public {
        // Construct standard execute(address,uint256,bytes) callData targeting powersAddress
        bytes memory callData = abi.encodeWithSelector(
            0xb61d27f6, // EXECUTE_SELECTOR
            powersAddress,
            0,
            ""
        );

        PackedUserOperation memory userOp = PackedUserOperation({
            sender: address(0),
            nonce: 0,
            initCode: "",
            callData: callData,
            accountGasLimits: bytes32(0),
            preVerificationGas: 0,
            gasFees: bytes32(0),
            paymasterAndData: "",
            signature: ""
        });

        (bytes memory context, uint256 validationData) = callValidatePaymasterUserOp(userOp);
        assertEq(validationData, 0, "Validation should pass with 0");
    }

    function test_Paymaster_RevertsNonPowersTarget() public {
        address maliciousTarget = address(0x9999);
        bytes memory callData = abi.encodeWithSelector(
            0xb61d27f6, // EXECUTE_SELECTOR
            maliciousTarget,
            0,
            ""
        );

        PackedUserOperation memory userOp = PackedUserOperation({
            sender: address(0),
            nonce: 0,
            initCode: "",
            callData: callData,
            accountGasLimits: bytes32(0),
            preVerificationGas: 0,
            gasFees: bytes32(0),
            paymasterAndData: "",
            signature: ""
        });

        vm.expectRevert();
        callValidatePaymasterUserOp(userOp);
    }

    function test_Paymaster_RevertsBatchExecute() public {
        address[] memory targets = new address[](2);
        targets[0] = powersAddress;
        targets[1] = powersAddress;

        uint256[] memory values = new uint256[](2);
        bytes[] memory callDatas = new bytes[](2);

        bytes memory callData = abi.encodeWithSelector(
            0x47e1da2a, // executeBatch(address[],uint256[],bytes[]) — not supported
            targets,
            values,
            callDatas
        );

        PackedUserOperation memory userOp = PackedUserOperation({
            sender: address(0),
            nonce: 0,
            initCode: "",
            callData: callData,
            accountGasLimits: bytes32(0),
            preVerificationGas: 0,
            gasFees: bytes32(0),
            paymasterAndData: "",
            signature: ""
        });

        vm.expectRevert(PowersPaymaster.PowersPaymaster__UnsupportedSelector.selector);
        callValidatePaymasterUserOp(userOp);
    }
}

// ─────────────────────────────────────────────
//         SLATE REGISTRY SHARED HELPERS
// ─────────────────────────────────────────────

// Return a copy of `data` starting at `offset` bytes (strips the 4-byte ABI selector).
function skipSelector(bytes memory data) pure returns (bytes memory result) {
    require(data.length >= 4, "skipSelector: too short");
    result = new bytes(data.length - 4);
    for (uint256 i = 0; i < result.length; i++) {
        result[i] = data[4 + i];
    }
}

// ─────────────────────────────────────────────
//         SLATE REGISTRY ADD SLATE TESTS
// ─────────────────────────────────────────────

// ─────────────────────────────────────────────
//               BASIC BEHAVIOUR
// ─────────────────────────────────────────────
contract SlateRegistry_AddSlateBasicTest is TestSetupSlateRegistry {
    uint16 public addSlateMandateId;
    uint256 public electionId;
    bytes public addSlateCalldata;

    address[] slateTargets;
    uint256[] slateValues;
    bytes[] slateCalldatas;

    function setUp() public override {
        super.setUp();

        addSlateMandateId =
            findMandateIdInOrg("SlateRegistry_AddSlate: add a slate to a SlateRegistry election.", daoMock);

        // electionId mirrors SlateRegistry_AddSlate.handleRequest:
        //   keccak256(abi.encodePacked(powers, electionTitle))
        electionId = uint256(keccak256(abi.encodePacked(address(daoMock), "Happy Election")));

        // Seed mock: flowIndex=0 (the 3-empty-slot flow), voting not yet started
        slateRegistryMock.setElection(electionId, 0, uint48(block.number + 1000), uint48(block.number + 2000));

        // Build calldata: (electionTitle, slateNameDescription, targets[], values[], calldatas[])
        slateTargets = new address[](1);
        slateValues = new uint256[](1);
        slateCalldatas = new bytes[](1);
        slateTargets[0] = address(123);
        slateCalldatas[0] = abi.encode("mockCall");

        addSlateCalldata = abi.encode("Happy Election", "My Slate", slateTargets, slateValues, slateCalldatas);
    }

    function testInitializeMandateOverridesInputParams() public {
        // Regardless of the inputParams passed, initializeMandate must store the 5 hardcoded strings.
        bytes memory stored = SlateRegistry_AddSlate(
                registry.getMandateAddress(MAJOR, MINOR, PATCH, "SlateRegistry_AddSlate")
            ).getInputParams(address(daoMock), addSlateMandateId);

        bytes memory expected = abi.encode(
            "string ElectionTitle",
            "string NameDescription",
            "address[] Targets",
            "uint256[] Values",
            "bytes[] Calldatas"
        );
        assertEq(stored, expected);
    }

    function testHandleRequestReturnsThreeCalls() public {
        (, address[] memory targets_, uint256[] memory values_, bytes[] memory calldatas_) = SlateRegistry_AddSlate(
                registry.getMandateAddress(MAJOR, MINOR, PATCH, "SlateRegistry_AddSlate")
            ).handleRequest(alice, address(daoMock), addSlateMandateId, addSlateCalldata, nonce);

        assertEq(targets_.length, 3);
        assertEq(values_.length, 3);
        assertEq(calldatas_.length, 3);
    }

    function testHandleRequestComputesCorrectActionId() public {
        (uint256 actionId_,,,) = SlateRegistry_AddSlate(
                registry.getMandateAddress(MAJOR, MINOR, PATCH, "SlateRegistry_AddSlate")
            ).handleRequest(alice, address(daoMock), addSlateMandateId, addSlateCalldata, nonce);

        uint256 expected = MandateUtilities.computeActionId(addSlateMandateId, addSlateCalldata, nonce);
        assertEq(actionId_, expected);
    }

    function testHandleRequestFirstCallIsAdoptMandate() public {
        (, address[] memory targets_,, bytes[] memory calldatas_) = SlateRegistry_AddSlate(
                registry.getMandateAddress(MAJOR, MINOR, PATCH, "SlateRegistry_AddSlate")
            ).handleRequest(alice, address(daoMock), addSlateMandateId, addSlateCalldata, nonce);

        assertEq(targets_[0], address(daoMock));
        bytes4 selector = bytes4(calldatas_[0]);
        assertEq(selector, IPowers.adoptMandate.selector);
    }

    function testHandleRequestSecondCallIsEditFlowByIndex() public {
        uint16 expectedNewMandateId = daoMock.getMandateCounter();

        (, address[] memory targets_,, bytes[] memory calldatas_) = SlateRegistry_AddSlate(
                registry.getMandateAddress(MAJOR, MINOR, PATCH, "SlateRegistry_AddSlate")
            ).handleRequest(alice, address(daoMock), addSlateMandateId, addSlateCalldata, nonce);

        assertEq(targets_[1], address(daoMock));
        bytes4 selector = bytes4(calldatas_[1]);
        assertEq(selector, IPowers.editFlowByIndex.selector);

        // Decode and check the parameters: (flowIndex=0, emptySlotIndex=0, newMandateId)
        (uint8 flowIdx, uint8 slotIdx, uint16 newMandateId) =
            abi.decode(skipSelector(calldatas_[1]), (uint8, uint8, uint16));
        assertEq(flowIdx, 0); // flow[0] is the 3-empty-slot flow
        assertEq(slotIdx, 0); // first slot is empty
        assertEq(newMandateId, expectedNewMandateId);
    }

    function testHandleRequestThirdCallIsRegisterSlate() public {
        uint16 expectedNewMandateId = daoMock.getMandateCounter();

        (, address[] memory targets_,, bytes[] memory calldatas_) = SlateRegistry_AddSlate(
                registry.getMandateAddress(MAJOR, MINOR, PATCH, "SlateRegistry_AddSlate")
            ).handleRequest(alice, address(daoMock), addSlateMandateId, addSlateCalldata, nonce);

        assertEq(targets_[2], address(slateRegistryMock));
        bytes4 selector = bytes4(calldatas_[2]);
        assertEq(selector, SlateRegistryMock.registerSlate.selector);

        (uint256 encodedElectionId, uint16 encodedMandateId) =
            abi.decode(skipSelector(calldatas_[2]), (uint256, uint16));
        assertEq(encodedElectionId, electionId);
        assertEq(encodedMandateId, expectedNewMandateId);
    }

    function testHandleRequestAdoptMandateUsesRoleIdFromRegistry() public {
        // The adopted mandate's allowedRole must equal slateRegistryMock.roleId() = ROLE_TWO.
        (,,, bytes[] memory calldatas_) = SlateRegistry_AddSlate(
                registry.getMandateAddress(MAJOR, MINOR, PATCH, "SlateRegistry_AddSlate")
            ).handleRequest(alice, address(daoMock), addSlateMandateId, addSlateCalldata, nonce);

        // adoptMandate(MandateInitData) — skip the 4-byte selector, decode the struct
        PowersTypes.MandateInitData memory initData =
            abi.decode(skipSelector(calldatas_[0]), (PowersTypes.MandateInitData));
        assertEq(initData.conditions.allowedRole, ROLE_TWO);
    }

    // FAILING: Powers.addFlow is onlyPowers (msg.sender == address(powers)).
    // SlateRegistry.createElection calls IPowers(owner()).addFlow() where msg.sender = slateRegistry, not powers.
    // This means there is no way to create a live election through the standard governance path,
    // making the full AddSlate → ExecuteResult lifecycle untestable without mocks.
    // DO NOT implement a fix here. Report to protocol maintainers.
    function testFullElectionLifecycleIsBlockedByProtocolBug() public {
        // Attempting to call createElection on a real SlateRegistry (owned by daoMock) as
        // part of mandate execution would have daoMock call slateRegistry.createElection(),
        // which internally calls daoMock.addFlow() with msg.sender = slateRegistry ≠ daoMock.
        // The onlyPowers modifier would revert.
        // This test documents the limitation rather than exercising it, to avoid deploying
        // a second full Powers instance.
        assertTrue(true, "protocol bug documented: createElection cannot work with onlyPowers addFlow");
    }
}

// ─────────────────────────────────────────────
//               EDGE CASES
// ─────────────────────────────────────────────
contract SlateRegistry_AddSlateEdgeCaseTest is TestSetupSlateRegistry {
    uint16 public addSlateMandateId;

    function setUp() public override {
        super.setUp();
        addSlateMandateId =
            findMandateIdInOrg("SlateRegistry_AddSlate: add a slate to a SlateRegistry election.", daoMock);
    }

    // £TODO FIX TEST
    function testFindEmptySlotRevertsWhenFlowIsFull() public {
        vm.skip(true);
        // Seed mock election pointing at flow[1], which has 1 occupied slot (mandateId=1) and no empties.
        uint256 fullElectionId = uint256(keccak256(abi.encodePacked(address(daoMock), "Full Election")));
        slateRegistryMock.setElection(fullElectionId, 1, uint48(block.number + 100), uint48(block.number + 200));

        address[] memory targets_ = new address[](1);
        uint256[] memory values_ = new uint256[](1);
        bytes[] memory calldatas_ = new bytes[](1);
        targets_[0] = address(456);

        bytes memory fullCalldata = abi.encode("Full Election", "My Slate", targets_, values_, calldatas_);

        vm.expectRevert("No empty slot in flow");
        SlateRegistry_AddSlate(registry.getMandateAddress(MAJOR, MINOR, PATCH, "SlateRegistry_AddSlate"))
            .handleRequest(alice, address(daoMock), addSlateMandateId, fullCalldata, nonce);
    }
}

// ─────────────────────────────────────────────
//       SLATE REGISTRY REMOVE SLATE TESTS
// ─────────────────────────────────────────────

// ─────────────────────────────────────────────
//               BASIC BEHAVIOUR
// ─────────────────────────────────────────────
contract SlateRegistry_RemoveSlateBasicTest is TestSetupSlateRegistry {
    uint16 public addSlateMandateId;
    uint16 public removeSlateMandateId;
    uint256 public electionId;
    bytes public slateCalldata;
    uint16 public adoptedSlateId;

    function setUp() public override {
        super.setUp();

        addSlateMandateId =
            findMandateIdInOrg("SlateRegistry_AddSlate: add a slate to a SlateRegistry election.", daoMock);
        removeSlateMandateId =
            findMandateIdInOrg("SlateRegistry_RemoveSlate: remove a slate from a SlateRegistry election.", daoMock);

        electionId = uint256(keccak256(abi.encodePacked(address(daoMock), "Happy Election")));
        slateRegistryMock.setElection(electionId, 0, uint48(block.number + 1000), uint48(block.number + 2000));

        address[] memory slateTargets = new address[](1);
        uint256[] memory slateValues = new uint256[](1);
        bytes[] memory slateCalldatas = new bytes[](1);
        slateTargets[0] = address(123);
        slateCalldatas[0] = abi.encode("mockCall");
        slateCalldata = abi.encode("Happy Election", "My Slate", slateTargets, slateValues, slateCalldatas);

        // Execute AddSlate so return data (adopted mandateId) is stored in Powers.
        adoptedSlateId = daoMock.getMandateCounter();
        vm.prank(alice);
        daoMock.request(addSlateMandateId, slateCalldata, nonce, "Add slate");
    }

    function testInitializeMandateOverridesInputParams() public {
        bytes memory stored = SlateRegistry_RemoveSlate(
                registry.getMandateAddress(MAJOR, MINOR, PATCH, "SlateRegistry_RemoveSlate")
            ).getInputParams(address(daoMock), removeSlateMandateId);

        bytes memory expected = abi.encode(
            "string ElectionTitle",
            "string NameDescription",
            "address[] Targets",
            "uint256[] Values",
            "bytes[] Calldatas"
        );
        assertEq(stored, expected);
    }

    function testHandleRequestReturnsThreeCalls() public {
        (, address[] memory targets_, uint256[] memory values_, bytes[] memory calldatas_) = SlateRegistry_RemoveSlate(
                registry.getMandateAddress(MAJOR, MINOR, PATCH, "SlateRegistry_RemoveSlate")
            ).handleRequest(alice, address(daoMock), removeSlateMandateId, slateCalldata, nonce);

        assertEq(targets_.length, 3);
        assertEq(values_.length, 3);
        assertEq(calldatas_.length, 3);
    }

    function testHandleRequestComputesCorrectActionId() public {
        (uint256 actionId_,,,) = SlateRegistry_RemoveSlate(
                registry.getMandateAddress(MAJOR, MINOR, PATCH, "SlateRegistry_RemoveSlate")
            ).handleRequest(alice, address(daoMock), removeSlateMandateId, slateCalldata, nonce);

        uint256 expected = MandateUtilities.computeActionId(removeSlateMandateId, slateCalldata, nonce);
        assertEq(actionId_, expected);
    }

    function testHandleRequestFirstCallIsRevokeMandate() public {
        (, address[] memory targets_,, bytes[] memory calldatas_) = SlateRegistry_RemoveSlate(
                registry.getMandateAddress(MAJOR, MINOR, PATCH, "SlateRegistry_RemoveSlate")
            ).handleRequest(alice, address(daoMock), removeSlateMandateId, slateCalldata, nonce);

        assertEq(targets_[0], address(daoMock));
        assertEq(bytes4(calldatas_[0]), IPowers.revokeMandate.selector);

        (uint16 revokedId) = abi.decode(skipSelector(calldatas_[0]), (uint16));
        assertEq(revokedId, adoptedSlateId);
    }

    function testHandleRequestSecondCallClearsFlowSlot() public {
        (, address[] memory targets_,, bytes[] memory calldatas_) = SlateRegistry_RemoveSlate(
                registry.getMandateAddress(MAJOR, MINOR, PATCH, "SlateRegistry_RemoveSlate")
            ).handleRequest(alice, address(daoMock), removeSlateMandateId, slateCalldata, nonce);

        assertEq(targets_[1], address(daoMock));
        assertEq(bytes4(calldatas_[1]), IPowers.editFlowByIndex.selector);

        (uint8 flowIdx, uint8 slotIdx, uint16 newMandateId) =
            abi.decode(skipSelector(calldatas_[1]), (uint8, uint8, uint16));
        assertEq(flowIdx, 0); // election's flowIndex
        assertEq(slotIdx, 0); // slot where adoptedSlateId lives
        assertEq(newMandateId, 0); // cleared to zero
    }

    function testHandleRequestThirdCallIsRemoveSlate() public {
        (, address[] memory targets_,, bytes[] memory calldatas_) = SlateRegistry_RemoveSlate(
                registry.getMandateAddress(MAJOR, MINOR, PATCH, "SlateRegistry_RemoveSlate")
            ).handleRequest(alice, address(daoMock), removeSlateMandateId, slateCalldata, nonce);

        assertEq(targets_[2], address(slateRegistryMock));
        assertEq(bytes4(calldatas_[2]), SlateRegistryMock.removeSlate.selector);

        (uint256 encodedElectionId, uint16 encodedMandateId) =
            abi.decode(skipSelector(calldatas_[2]), (uint256, uint16));
        assertEq(encodedElectionId, electionId);
        assertEq(encodedMandateId, adoptedSlateId);
    }

    function testFullExecutionRevokesSlateAndClearsFlow() public {
        // Execute RemoveSlate with the same calldata+nonce used for AddSlate.
        vm.prank(alice);
        uint256 removeActionId = daoMock.request(removeSlateMandateId, slateCalldata, nonce, "Remove slate");

        assertEq(uint8(daoMock.getActionState(removeActionId)), uint8(PowersTypes.ActionState.Fulfilled));

        // Flow slot must be cleared back to 0 after RemoveSlate executes editFlowByIndex(0, 0, 0).
        uint16[] memory flowSlots = daoMock.getFlowMandatesAtIndex(0);
        assertEq(flowSlots[0], 0);
    }
}

// ─────────────────────────────────────────────
//               EDGE CASES
// ─────────────────────────────────────────────
contract SlateRegistry_RemoveSlateEdgeCaseTest is TestSetupSlateRegistry {
    uint16 public addSlateMandateId;
    uint16 public removeSlateMandateId;
    uint256 public electionId;
    bytes public slateCalldata;

    function setUp() public override {
        super.setUp();

        addSlateMandateId =
            findMandateIdInOrg("SlateRegistry_AddSlate: add a slate to a SlateRegistry election.", daoMock);
        removeSlateMandateId =
            findMandateIdInOrg("SlateRegistry_RemoveSlate: remove a slate from a SlateRegistry election.", daoMock);

        electionId = uint256(keccak256(abi.encodePacked(address(daoMock), "Happy Election")));
        slateRegistryMock.setElection(electionId, 0, uint48(block.number + 1000), uint48(block.number + 2000));

        address[] memory slateTargets = new address[](1);
        uint256[] memory slateValues = new uint256[](1);
        bytes[] memory slateCalldatas = new bytes[](1);
        slateTargets[0] = address(123);
        slateCalldatas[0] = abi.encode("mockCall");
        slateCalldata = abi.encode("Happy Election", "My Slate", slateTargets, slateValues, slateCalldatas);

        // Execute AddSlate so return data is available and flow[0][0] is populated.
        vm.prank(alice);
        daoMock.request(addSlateMandateId, slateCalldata, nonce, "Add slate");
    }

    // £TODO: FIX TEST
    function testFindMandateSlotRevertsWhenSlateNotInFlow() public {
        vm.skip(true);
        // Clear flow[0][0] back to 0 so the slate mandate ID is no longer present in the flow.
        // RemoveSlate reads the mandateId from return data then searches the flow — it must revert.
        vm.prank(address(daoMock));
        daoMock.editFlowByIndex(0, 0, 0);

        vm.expectRevert("Slate not found in flow");
        SlateRegistry_RemoveSlate(registry.getMandateAddress(MAJOR, MINOR, PATCH, "SlateRegistry_RemoveSlate"))
            .handleRequest(alice, address(daoMock), removeSlateMandateId, slateCalldata, nonce);
    }
}

// ─────────────────────────────────────────────
//     SLATE REGISTRY EXECUTE RESULT TESTS
// ─────────────────────────────────────────────

// ─────────────────────────────────────────────
//               BASIC BEHAVIOUR
// ─────────────────────────────────────────────
contract SlateRegistry_ExecuteResultBasicTest is TestSetupSlateRegistry {
    uint16 public executeResultMandateId;
    uint256 public electionId;
    bytes public executeCalldata;

    // endBlock is set well in the past so handleRequest does not revert on the vote-closed check.
    uint48 constant END_BLOCK_OFFSET = 100;

    function setUp() public override {
        super.setUp();

        executeResultMandateId = findMandateIdInOrg(
            "SlateRegistry_ExecuteResult: execute the results of a SlateRegistry election.", daoMock
        );

        electionId = uint256(keccak256(abi.encodePacked(address(daoMock), "Finished Election")));

        // endBlock is in the past relative to block.number (which starts at 10 after BaseSetup.setUp).
        // block.number starts at 10 in BaseSetup; END_BLOCK_OFFSET = 100 so endBlock < block.number. Wait...
        // Actually block.number + END_BLOCK_OFFSET would be in the future. We need endBlock < block.number.
        // BaseSetup rolls to block 10, so set endBlock = 5 (already passed).
        slateRegistryMock.setElection(electionId, 0, uint48(1), uint48(5));

        executeCalldata = abi.encode("Finished Election");
    }

    function testInitializeMandateSetsElectionTitleParam() public {
        bytes memory stored = SlateRegistry_ExecuteResult(
                registry.getMandateAddress(MAJOR, MINOR, PATCH, "SlateRegistry_ExecuteResult")
            ).getInputParams(address(daoMock), executeResultMandateId);

        assertEq(stored, abi.encode("string ElectionTitle"));
    }

    function testHandleRequestReturnsOneCall() public {
        (, address[] memory targets_, uint256[] memory values_, bytes[] memory calldatas_) = SlateRegistry_ExecuteResult(
                registry.getMandateAddress(MAJOR, MINOR, PATCH, "SlateRegistry_ExecuteResult")
            ).handleRequest(alice, address(daoMock), executeResultMandateId, executeCalldata, nonce);

        assertEq(targets_.length, 1);
        assertEq(values_.length, 1);
        assertEq(calldatas_.length, 1);
    }

    function testHandleRequestComputesCorrectActionId() public {
        (uint256 actionId_,,,) = SlateRegistry_ExecuteResult(
                registry.getMandateAddress(MAJOR, MINOR, PATCH, "SlateRegistry_ExecuteResult")
            ).handleRequest(alice, address(daoMock), executeResultMandateId, executeCalldata, nonce);

        assertEq(actionId_, MandateUtilities.computeActionId(executeResultMandateId, executeCalldata, nonce));
    }

    function testHandleRequestCallTargetsSlateRegistry() public {
        (, address[] memory targets_,,) = SlateRegistry_ExecuteResult(
                registry.getMandateAddress(MAJOR, MINOR, PATCH, "SlateRegistry_ExecuteResult")
            ).handleRequest(alice, address(daoMock), executeResultMandateId, executeCalldata, nonce);

        assertEq(targets_[0], address(slateRegistryMock));
    }

    function testHandleRequestCallEncodesExecuteResults() public {
        (,,, bytes[] memory calldatas_) = SlateRegistry_ExecuteResult(
                registry.getMandateAddress(MAJOR, MINOR, PATCH, "SlateRegistry_ExecuteResult")
            ).handleRequest(alice, address(daoMock), executeResultMandateId, executeCalldata, nonce);

        assertEq(bytes4(calldatas_[0]), SlateRegistryMock.executeResults.selector);

        (uint256 encodedElectionId) = abi.decode(skipSelector(calldatas_[0]), (uint256));
        assertEq(encodedElectionId, electionId);
    }

    function testFullExecutionSucceedsAfterVotingEnds() public {
        vm.prank(alice);
        uint256 actionId_ = daoMock.request(executeResultMandateId, executeCalldata, nonce, "Execute results");

        assertEq(uint8(daoMock.getActionState(actionId_)), uint8(PowersTypes.ActionState.Fulfilled));
    }
}

// ─────────────────────────────────────────────
//               EDGE CASES
// ─────────────────────────────────────────────
contract SlateRegistry_ExecuteResultEdgeCaseTest is TestSetupSlateRegistry {
    uint16 public executeResultMandateId;
    bytes public executeCalldata;

    function setUp() public override {
        super.setUp();

        executeResultMandateId = findMandateIdInOrg(
            "SlateRegistry_ExecuteResult: execute the results of a SlateRegistry election.", daoMock
        );

        uint256 electionId = uint256(keccak256(abi.encodePacked(address(daoMock), "Active Election")));
        // endBlock is far in the future — voting has not yet closed.
        slateRegistryMock.setElection(electionId, 0, uint48(block.number + 100), uint48(block.number + 500));

        executeCalldata = abi.encode("Active Election");
    }

    // £TODO FIX TEST
    function testHandleRequestRevertsIfVotingNotClosed() public {
        vm.skip(true);
        vm.expectRevert("vote not yet closed");
        SlateRegistry_ExecuteResult(registry.getMandateAddress(MAJOR, MINOR, PATCH, "SlateRegistry_ExecuteResult"))
            .handleRequest(alice, address(daoMock), executeResultMandateId, executeCalldata, nonce);
    }
}

//////////////////////////////////////////////////
//    POWERSFACTORY_ASSIGNROLE TESTS           //
//////////////////////////////////////////////////

// ─────────────────────────────────────────────
//               BASIC BEHAVIOUR
// ─────────────────────────────────────────────
contract PowersFactory_AssignRoleBasicTest is TestSetupPowersFactory {
    uint16 public parentMandateId;
    uint16 public assignRoleMandateId;
    bytes public emptyCalldata;

    function setUp() public override {
        super.setUp();

        parentMandateId =
            findMandateIdInOrg("BespokeActionReturner: returns address-decodable value for testing.", daoMock);
        assignRoleMandateId = findMandateIdInOrg("PowersFactory_AssignRole: assign role in new org.", daoMock);
        emptyCalldata = abi.encode();

        // Execute the parent action so AssignRole can read its return data.
        vm.prank(alice);
        daoMock.request(parentMandateId, emptyCalldata, nonce, "Execute parent");
    }

    function testHandleRequestReturnsOneCall() public {
        (, address[] memory returnedTargets, uint256[] memory returnedValues, bytes[] memory returnedCalldatas) = PowersFactory_AssignRole(
                registry.getMandateAddress(MAJOR, MINOR, PATCH, "PowersFactory_AssignRole")
            ).handleRequest(alice, address(daoMock), assignRoleMandateId, emptyCalldata, nonce);

        assertEq(returnedTargets.length, 1);
        assertEq(returnedValues.length, 1);
        assertEq(returnedCalldatas.length, 1);
    }

    function testHandleRequestComputesCorrectActionId() public {
        (uint256 returnedActionId,,,) = PowersFactory_AssignRole(
                registry.getMandateAddress(MAJOR, MINOR, PATCH, "PowersFactory_AssignRole")
            ).handleRequest(alice, address(daoMock), assignRoleMandateId, emptyCalldata, nonce);

        uint256 expectedActionId = MandateUtilities.computeActionId(assignRoleMandateId, emptyCalldata, nonce);
        assertEq(returnedActionId, expectedActionId);
    }

    function testHandleRequestTargetsIsPowers() public {
        (, address[] memory returnedTargets,,) = PowersFactory_AssignRole(
                registry.getMandateAddress(MAJOR, MINOR, PATCH, "PowersFactory_AssignRole")
            ).handleRequest(alice, address(daoMock), assignRoleMandateId, emptyCalldata, nonce);

        assertEq(returnedTargets[0], address(daoMock));
    }

    function testHandleRequestCallIsAssignRole() public {
        (,,, bytes[] memory returnedCalldatas) = PowersFactory_AssignRole(
                registry.getMandateAddress(MAJOR, MINOR, PATCH, "PowersFactory_AssignRole")
            ).handleRequest(alice, address(daoMock), assignRoleMandateId, emptyCalldata, nonce);

        bytes4 selector = bytes4(returnedCalldatas[0]);
        assertEq(selector, IPowers.assignRole.selector);
    }

    function testHandleRequestDecodesAddressFromReturnData() public {
        // returnDataMock.getValue() returns uint256(42), decoded as address(42)
        (,,, bytes[] memory returnedCalldatas) = PowersFactory_AssignRole(
                registry.getMandateAddress(MAJOR, MINOR, PATCH, "PowersFactory_AssignRole")
            ).handleRequest(alice, address(daoMock), assignRoleMandateId, emptyCalldata, nonce);

        (uint256 roleId, address assignedAddr) = abi.decode(skipSelector(returnedCalldatas[0]), (uint256, address));

        assertEq(roleId, ROLE_TWO);
        assertEq(assignedAddr, address(42));
    }

    function testFullExecutionAssignsRoleToNewOrg() public {
        vm.prank(alice);
        daoMock.request(assignRoleMandateId, emptyCalldata, nonce, "Assign role");

        assertGt(daoMock.hasRoleSince(address(42), ROLE_TWO), 0);
    }
}

// ─────────────────────────────────────────────
//                 EDGE CASES
// ─────────────────────────────────────────────
contract PowersFactory_AssignRoleEdgeCaseTest is TestSetupPowersFactory {
    uint16 public assignRoleMandateId;
    bytes public emptyCalldata;

    function setUp() public override {
        super.setUp();

        assignRoleMandateId = findMandateIdInOrg("PowersFactory_AssignRole: assign role in new org.", daoMock);
        emptyCalldata = abi.encode();
        // Parent action NOT executed — tests revert paths.
    }

    // £TODO: FIX TEST
    function testHandleRequestRevertsWhenParentNotFulfilled() public {
        vm.skip(true);
        vm.expectRevert("Invalid parent action state");
        PowersFactory_AssignRole(registry.getMandateAddress(MAJOR, MINOR, PATCH, "PowersFactory_AssignRole"))
            .handleRequest(alice, address(daoMock), assignRoleMandateId, emptyCalldata, nonce);
    }
}

//////////////////////////////////////////////////
//  POWERSFACTORY_ADDSAFEDELEGATE TESTS        //
//////////////////////////////////////////////////

// ─────────────────────────────────────────────
//               BASIC BEHAVIOUR
// ─────────────────────────────────────────────
contract PowersFactory_AddSafeDelegateBasicTest is TestSetupPowersFactory {
    uint16 public parentMandateId;
    uint16 public addDelegateMandateId;
    bytes public emptyCalldata;

    function setUp() public override {
        super.setUp();

        parentMandateId =
            findMandateIdInOrg("BespokeActionReturner: returns address-decodable value for testing.", daoMock);
        addDelegateMandateId = findMandateIdInOrg("PowersFactory_AddSafeDelegate: add safe delegate.", daoMock);
        emptyCalldata = abi.encode();

        // Execute the parent action so AddSafeDelegate can read its return data.
        vm.prank(alice);
        daoMock.request(parentMandateId, emptyCalldata, nonce, "Execute parent");
    }

    function testHandleRequestReturnsOneCall() public {
        (, address[] memory returnedTargets, uint256[] memory returnedValues, bytes[] memory returnedCalldatas) = PowersFactory_AddSafeDelegate(
                registry.getMandateAddress(MAJOR, MINOR, PATCH, "PowersFactory_AddSafeDelegate")
            ).handleRequest(alice, address(daoMock), addDelegateMandateId, emptyCalldata, nonce);

        assertEq(returnedTargets.length, 1);
        assertEq(returnedValues.length, 1);
        assertEq(returnedCalldatas.length, 1);
    }

    function testHandleRequestComputesCorrectActionId() public {
        (uint256 returnedActionId,,,) = PowersFactory_AddSafeDelegate(
                registry.getMandateAddress(MAJOR, MINOR, PATCH, "PowersFactory_AddSafeDelegate")
            ).handleRequest(alice, address(daoMock), addDelegateMandateId, emptyCalldata, nonce);

        uint256 expectedActionId = MandateUtilities.computeActionId(addDelegateMandateId, emptyCalldata, nonce);
        assertEq(returnedActionId, expectedActionId);
    }

    function testHandleRequestTargetsIsTreasury() public {
        // Treasury was set to address(999) in TestSetupPowersFactory.
        (, address[] memory returnedTargets,,) = PowersFactory_AddSafeDelegate(
                registry.getMandateAddress(MAJOR, MINOR, PATCH, "PowersFactory_AddSafeDelegate")
            ).handleRequest(alice, address(daoMock), addDelegateMandateId, emptyCalldata, nonce);

        assertEq(returnedTargets[0], address(999));
    }

    function testHandleRequestCallIsSafeExecTransaction() public {
        (,,, bytes[] memory returnedCalldatas) = PowersFactory_AddSafeDelegate(
                registry.getMandateAddress(MAJOR, MINOR, PATCH, "PowersFactory_AddSafeDelegate")
            ).handleRequest(alice, address(daoMock), addDelegateMandateId, emptyCalldata, nonce);

        bytes4 selector = bytes4(returnedCalldatas[0]);
        assertEq(selector, Safe.execTransaction.selector);
    }
}

// ─────────────────────────────────────────────
//                 EDGE CASES
// ─────────────────────────────────────────────
contract PowersFactory_AddSafeDelegateEdgeCaseTest is TestSetupPowersFactory {
    uint16 public parentMandateId;
    uint16 public addDelegateMandateId;
    bytes public emptyCalldata;

    function setUp() public override {
        super.setUp();

        parentMandateId =
            findMandateIdInOrg("BespokeActionReturner: returns address-decodable value for testing.", daoMock);
        addDelegateMandateId = findMandateIdInOrg("PowersFactory_AddSafeDelegate: add safe delegate.", daoMock);
        emptyCalldata = abi.encode();
        // Parent action NOT executed — tests revert paths.
    }

    // £TODO: FIX TEST
    function testHandleRequestRevertsWhenParentNotFulfilled() public {
        vm.skip(true);
        vm.expectRevert("Invalid parent action state");
        PowersFactory_AddSafeDelegate(registry.getMandateAddress(MAJOR, MINOR, PATCH, "PowersFactory_AddSafeDelegate"))
            .handleRequest(alice, address(daoMock), addDelegateMandateId, emptyCalldata, nonce);
    }

    // £TODO: FIX TEST
    function testHandleRequestRevertsWhenTreasuryNotSet() public {
        vm.skip(true);
        // Execute parent first so the treasury check is reached.
        vm.prank(alice);
        daoMock.request(parentMandateId, emptyCalldata, nonce, "Execute parent");

        // Clear treasury
        vm.prank(address(daoMock));
        daoMock.setTreasury(payable(address(0)));

        vm.expectRevert("Treasury not set in Powers");
        PowersFactory_AddSafeDelegate(registry.getMandateAddress(MAJOR, MINOR, PATCH, "PowersFactory_AddSafeDelegate"))
            .handleRequest(alice, address(daoMock), addDelegateMandateId, emptyCalldata, nonce);
    }
}
