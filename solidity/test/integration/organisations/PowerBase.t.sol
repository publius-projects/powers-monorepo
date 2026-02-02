// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

// import { Test, console, console2 } from "lib/forge-std/src/Test.sol";
// import { Powers } from "../../../src/Powers.sol";
// import { Mandate } from "../../../src/Mandate.sol";
// import { Erc20Taxed } from "@mocks/Erc20Taxed.sol";

// import { SafeL2 } from "lib/safe-smart-account/contracts/SafeL2.sol";

// contract PowerLabs_IntegrationTest is TestSetupPowerLabsSafes {
//     // IMPORTANT NOTE: These tests are meant to be executed on a forked mainnet (sepolia) anvil chain.
//     // They will not execute if the Allowance module address is empty on the chain.
//     // This also means that any test actions persist across tests, so be careful when re-running tests!
//     address safeProxy;
//     address mandate1;
//     address mandate2;
//     bool active1;
//     bool active2;

//     address safeL2Treasury;
//     address newDelegate;
//     bytes proposalCalldata;

//     bool ok;
//     bytes result;

//     function testPowerLabs_Deployment() public {
//         // Just verify setup completed successfully
//         assertTrue(address(daoMock) != address(0), "Powers contract not deployed");
//         assertTrue(config.safeAllowanceModule != address(0), "Allowance module address not set");

//         (mandate1,, active1) = daoMock.getAdoptedMandate(1);
//         (mandate2,, active2) = daoMock.getAdoptedMandate(2);
//         assertTrue(active1, "Mandate 1 not active");
//         assertTrue(active2, "Mandate 2 not active");
//         assertEq(mandate1, findMandateAddress("Safe_Setup"), "Mandate 1 target mismatch");
//         assertEq(mandate2, findMandateAddress("PowerLabsConfig"), "Mandate 2 target mismatch");
//     }

//     // £todo: Needs to migrate to unit/mandates/integrations.t.sol
//     // function testPowerLabs_InitialiseSafe() public {
//     //     // Deploy and initialise safe
//     //     vm.prank(alice);
//     //     daoMock.request(1, abi.encode(), nonce, "Create SafeProxy");

//     //     safeL2Treasury = daoMock.getTreasury();
//     //     assertTrue(safeL2Treasury != address(0), "Safe proxy not deployed");
//     // }

//     // £todo: Needs to migrate to unit/mandates/integrations.t.sol
//     // function testPowerLabs_SetupSafe() public {
//     //     testPowerLabs_InitialiseSafe();
//     //     safeL2Treasury = daoMock.getTreasury();

//     //     vm.prank(alice);
//     //     daoMock.request(2, abi.encode(safeL2Treasury, config.safeAllowanceModule), nonce, "Setup Safe");

//     //     assertTrue(daoMock.mandateCounter() > 1, "No new actions recorded");
//     //     assertTrue(
//     //         SafeL2(payable(safeL2Treasury)).isModuleEnabled(config.safeAllowanceModule), "Allowance module not enabled"
//     //     );
//     // }

//     // £todo: Needs to migrate to integration/integrations.t.sol
//     function testPowerLabs_AddDelegate() public {
//         // Setup: Initialize the safe and call PowerLabsConfig
//         testPowerLabs_SetupSafe();

//         // The user roles are set up in TestSetup.t.sol in TestSetupPowerLabsSafes
//         // ROLE_ONE (Funders): bob, charlotte, david, eve]
//         // Based on PowerLabsConfig.sol, we need roles 2, 3, 4, and 5 assigned.
//         vm.startPrank(address(daoMock));
//         // ROLE_TWO (Doc Contributors)
//         daoMock.assignRole(2, charlotte);
//         daoMock.assignRole(2, david);
//         // ROLE_THREE (Frontend Contributors)
//         daoMock.assignRole(3, frank);
//         daoMock.assignRole(3, gary);
//         // ROLE_FOUR (Protocol Contributors)
//         daoMock.assignRole(4, gary);
//         daoMock.assignRole(4, helen);
//         // ROLE_FIVE (Members)
//         daoMock.assignRole(5, helen);
//         daoMock.assignRole(5, ian);
//         vm.stopPrank();

//         newDelegate = alice; // making an EOA a delegate.

//         uint256 amountDocContribs = daoMock.getAmountRoleHolders(2); // Doc Contributors
//         console2.log("Doc Contributors:", amountDocContribs);

//         // Step 1: Member proposes to add a new delegate.
//         // Mandate counter starts at 1, Safe_Setup is mandate 1, PowerLabsConfig is mandate 2. It adds 9(?) mandates.
//         mandateId = 3; // Mandate adopted by PowerLabsConfig
//         (address mandateTarget,,) = daoMock.getAdoptedMandate(mandateId);
//         assertEq(mandateTarget, findMandateAddress("StatementOfIntent"), "Proposal mandate should be StatementOfIntent");

//         console2.log("MEMBERS PROPOSE TO ADD DELEGATE");
//         vm.prank(helen); // Member
//         (actionId) = daoMock.propose(mandateId, abi.encode(newDelegate), nonce, "Add new delegate");

//         // Step 2: Members vote to pass the proposal.
//         vm.prank(helen);
//         daoMock.castVote(actionId, FOR);
//         vm.prank(ian);
//         daoMock.castVote(actionId, FOR);

//         // Fast forward time to end voting period
//         vm.roll(block.number + 1201);

//         // Execute the proposal
//         vm.prank(helen);
//         daoMock.request(mandateId, abi.encode(newDelegate), nonce, "Add new delegate");

//         // Step 3: Doc Contributors OK the proposal.
//         console2.log("DOC CONTRIBUTORS OK TO ADD DELEGATE");
//         mandateId = 5;
//         vm.prank(charlotte); // Doc Contributor
//         (actionId) = daoMock.propose(mandateId, abi.encode(newDelegate), nonce, "Doc OK");

//         vm.prank(charlotte);
//         daoMock.castVote(actionId, FOR);
//         vm.prank(david);
//         daoMock.castVote(actionId, FOR);
//         vm.roll(block.number + 1201);

//         vm.prank(charlotte);
//         daoMock.request(mandateId, abi.encode(newDelegate), nonce, "Doc OK");

//         // Step 4: Frontend Contributors OK the proposal.
//         console2.log("FRONTEND CONTRIBUTORS OK TO ADD DELEGATE");
//         mandateId = 6;
//         vm.prank(frank); // Frontend Contributor
//         (actionId) = daoMock.propose(mandateId, abi.encode(newDelegate), nonce, "Frontend OK");

//         vm.prank(frank);
//         daoMock.castVote(actionId, FOR);
//         vm.prank(gary);
//         daoMock.castVote(actionId, FOR);

//         vm.roll(block.number + 1201);

//         vm.prank(frank);
//         daoMock.request(mandateId, abi.encode(newDelegate), nonce, "Frontend OK");

//         // Step 5: Protocol Contributors execute the proposal.
//         console2.log("PROTOCOL CONTRIBUTORS EXECUTE TO ADD DELEGATE");
//         mandateId = 7;
//         vm.prank(gary); // Protocol Contributor
//         (actionId) = daoMock.propose(mandateId, abi.encode(newDelegate), nonce, "Execute add delegate");

//         vm.prank(gary);
//         daoMock.castVote(actionId, FOR);
//         vm.prank(helen);
//         daoMock.castVote(actionId, FOR);

//         vm.roll(block.number + 1201);

//         vm.deal(gary, 100 ether); // Fund the daoMock to pay for gas costs
//         vm.prank(gary);
//         daoMock.request(mandateId, abi.encode(newDelegate), nonce, "Execute add delegate");

//         // Verification
//         // We need to interact with the AllowanceModule to check if the delegate was added.
//         // The address of the allowance module is config.safeAllowanceModule
//         // getDelegates = 0xeb37abe0
//         safeL2Treasury = daoMock.getTreasury();
//         vm.prank(safeL2Treasury);
//         (ok, result) = config.safeAllowanceModule
//             .staticcall(abi.encodeWithSignature("getDelegates(address,uint48,uint8)", safeL2Treasury, 0, 10));

//         require(ok, "Static call to getDelegates failed");
//         (address[] memory delegates,) = abi.decode(result, (address[], uint48));
//         assertTrue(delegates.length > 0, "New delegate should be added to the allowance module");
//         assertTrue(delegates[0] == newDelegate, "New delegate address mismatch");
//     }

//     function testPowerLabs_AddAllowance() public {
//         // Setup: Initialize the safe and call PowerLabsConfig
//         testPowerLabs_AddDelegate();

//         // The user roles are set up in TestSetup.t.sol in TestSetupPowerLabsSafes
//         vm.startPrank(address(daoMock));
//         daoMock.assignRole(2, charlotte);
//         daoMock.assignRole(2, david);
//         daoMock.assignRole(3, frank);
//         daoMock.assignRole(3, gary);
//         daoMock.assignRole(4, gary);
//         daoMock.assignRole(4, helen);
//         daoMock.assignRole(5, helen);
//         daoMock.assignRole(5, ian);
//         vm.stopPrank();

//         safeL2Treasury = daoMock.getTreasury();

//         // Fund the treasury with tokens
//         address token = findMandateAddress("Erc20Taxed");
//         Erc20Taxed(token).faucet();

//         // Step 1: Member proposes to add an allowance.
//         mandateId = 8;
//         proposalCalldata = abi.encode(
//             alice, // has been set as delegate in previous test
//             token,
//             11_111, // allowanceAmount,
//             22_222, // resetTimeMin,
//             33_333 // resetBaseMin
//         );

//         console2.log("MEMBERS PROPOSE TO ADD ALLOWANCE");
//         vm.prank(helen); // Member
//         (actionId) = daoMock.propose(mandateId, proposalCalldata, nonce, "Add new allowance");

//         // Step 2: Members vote to pass the proposal.
//         vm.prank(helen);
//         daoMock.castVote(actionId, FOR);
//         vm.prank(ian);
//         daoMock.castVote(actionId, FOR);

//         vm.roll(block.number + 1201);

//         vm.prank(helen);
//         daoMock.request(mandateId, proposalCalldata, nonce, "Add new allowance");

//         // Step 3: Doc Contributors OK the proposal.
//         console2.log("DOC CONTRIBUTORS OK TO ADD ALLOWANCE");
//         mandateId = 10;
//         vm.prank(charlotte); // Doc Contributor
//         (actionId) = daoMock.propose(mandateId, proposalCalldata, nonce, "Doc OK");

//         vm.prank(charlotte);
//         daoMock.castVote(actionId, FOR);
//         vm.prank(david);
//         daoMock.castVote(actionId, FOR);
//         vm.roll(block.number + 1201);

//         vm.prank(charlotte);
//         daoMock.request(mandateId, proposalCalldata, nonce, "Doc OK");

//         // Step 4: Frontend Contributors OK the proposal.
//         console2.log("FRONTEND CONTRIBUTORS OK TO ADD ALLOWANCE");
//         mandateId = 11;
//         vm.prank(frank); // Frontend Contributor
//         (actionId) = daoMock.propose(mandateId, proposalCalldata, nonce, "Frontend OK");

//         vm.prank(frank);
//         daoMock.castVote(actionId, FOR);
//         vm.prank(gary);
//         daoMock.castVote(actionId, FOR);

//         vm.roll(block.number + 1201);

//         vm.prank(frank);
//         daoMock.request(mandateId, proposalCalldata, nonce, "Frontend OK");

//         // Step 5: Protocol Contributors execute the proposal.
//         console2.log("PROTOCOL CONTRIBUTORS EXECUTE TO ADD ALLOWANCE");
//         mandateId = 12;
//         vm.prank(gary); // Protocol Contributor
//         (actionId) = daoMock.propose(mandateId, proposalCalldata, nonce, "Execute add allowance");

//         vm.prank(gary);
//         daoMock.castVote(actionId, FOR);
//         vm.prank(helen);
//         daoMock.castVote(actionId, FOR);

//         vm.roll(block.number + 1201);

//         vm.deal(gary, 100 ether); // Fund the daoMock to pay for gas costs
//         vm.prank(gary);
//         daoMock.request(mandateId, proposalCalldata, nonce, "Execute add allowance");

//         // Verification
//         (ok, result) = config.safeAllowanceModule
//             .staticcall(
//                 abi.encodeWithSignature("getTokenAllowance(address,address,address)", safeL2Treasury, alice, token)
//             );

//         require(ok, "Static call to getTokenAllowance failed");
//         (uint256 amount,, uint256 resetTime,,) = abi.decode(result, (uint256, uint256, uint256, uint256, uint256));

//         assertEq(amount, 11_111, "Allowance amount mismatch");
//         assertEq(resetTime, 22_222, "Reset time mismatch");
//     }
// }
