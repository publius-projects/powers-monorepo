// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { TestSetupSafeProtocolFlow } from "../../TestSetup.t.sol";
import { PowersTypes } from "../../../src/interfaces/PowersTypes.sol";
import { IPowers } from "../../../src/interfaces/IPowers.sol";
import { IMandate } from "../../../src/interfaces/IMandate.sol";
import { console2 } from "forge-std/console2.sol";
import { SimpleErc20Votes } from "@mocks/SimpleErc20Votes.sol";

contract SafeProtocolFlowTest is TestSetupSafeProtocolFlow {
    function testSafeProtocolFlow() public {
        // Check skip condition from setup (Safe Allowance Module must be configured)
        console2.log("Chain Id: ", block.chainid);
        console2.log("Safe Allowance @", config.safeAllowanceModule);
        console2.log("Safe Allowance code length: ", address(config.safeAllowanceModule).code.length);

        vm.startPrank(alice);

        // ---------------------------------------------------------
        // 1. Setup Safe on Parent (Mandate 1)
        // ---------------------------------------------------------
        // Mandate 1 in SafeProtocol_Parent constitution is "Setup Safe".
        // It uses Safe_Setup mandate which requires no input params in execution as everything is in config.
        nonce = 123;
        console2.log("Executing Safe Setup...");
        daoMock.request(1, "", nonce, "");
        vm.stopPrank();

        // Use getTreasury() from IPowers interface
        safeTreasury = daoMock.getTreasury();
        console2.log("Safe Treasury deployed at:", safeTreasury);
        assertTrue(safeTreasury != address(0), "Safe treasury should be set");
        assertTrue(safeTreasury.code.length > 0, "Safe treasury should have code");

        // ---------------------------------------------------------
        // 2. Setup Sub-DAO (Child Powers) using newly created Safe as Treasury
        // ---------------------------------------------------------
        console2.log("Constituting Child Powers...");
        // Constitute Child DAO with Safe as Treasury
        (PowersTypes.MandateInitData[] memory mandateInitData1_) =
            testConstitutions.safeProtocol_Child_IntegrationTestConstitution(safeTreasury, config.safeAllowanceModule);
        daoMockChild1.constitute(mandateInitData1_);

        // ---------------------------------------------------------
        // 3. Add Child as Delegate on Parent (Mandate 2)
        // ---------------------------------------------------------
        // Mandate 2: Add Delegate. Input: address NewChildPowers
        console2.log("Adding Child as Delegate on Parent...");
        bytes memory params = abi.encode(address(daoMockChild1));
        daoMock.request(2, params, nonce, "");

        // ---------------------------------------------------------
        // 4. Set Allowance for Child on Parent (Mandate 3)
        // ---------------------------------------------------------

        // Deploy a token and mint to Safe
        SimpleErc20Votes token = new SimpleErc20Votes();
        token.mint(safeTreasury, 10 ether);

        uint96 allowanceAmount = 2 ether;
        // Mandate 3: Set Allowance. Input: Child, Token, Amount, ResetTime, ResetBase
        console2.log("Setting Allowance for Child on Parent...");
        params = abi.encode(
            address(daoMockChild1), // ChildPowers
            address(token), // Token
            allowanceAmount, // allowanceAmount
            uint16(30), // resetTimeMin (30 mins)
            uint32(0) // resetBaseMin
        );
        daoMock.request(3, params, nonce, "");

        vm.stopPrank();

        // ---------------------------------------------------------
        // 5. Child executes transaction using Allowance (Child Mandate 2)
        // ---------------------------------------------------------
        // Alice has Role 1 in Child.
        vm.startPrank(alice);

        // Prepare execution
        address payableTo = makeAddr("recipient");
        uint256 transferAmount = 1 ether;

        // Input params for SafeAllowance_Transfer: Token, PayableTo, Amount
        console2.log("Executing Child proposal...");
        bytes memory executionParams = abi.encode(address(token), transferAmount, payableTo);
        daoMockChild1.request(1, executionParams, nonce, ""); // Using request to trigger execution

        // Verify transfer
        console2.log("Verifying transfer...");
        assertEq(token.balanceOf(payableTo), transferAmount, "Recipient should receive tokens");
        assertEq(token.balanceOf(safeTreasury), 10 ether - transferAmount, "Safe should have sent tokens");

        vm.stopPrank();
    }
}
