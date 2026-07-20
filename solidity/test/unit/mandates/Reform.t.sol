// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { TestSetupReform, TestSetupExecutive, TestSetupRevokeMandates } from "../../TestSetup.t.sol";

import { MandateUtilities } from "@src/libraries/MandateUtilities.sol";
import { Powers } from "@src/Powers.sol";
import { PowersTypes } from "@src/interfaces/PowersTypes.sol";
import { PowersErrors } from "@src/interfaces/PowersErrors.sol";
import { PowersMock } from "../../mocks/PowersMock.sol";
import { Mandate } from "@src/Mandate.sol";
import { Adopt_Mandates } from "@src/core/mandates/reform/Adopt_Mandates.sol";

// ─────────────────────────────────────────────
//               BASIC BEHAVIOUR
// ─────────────────────────────────────────────
contract PauseMandatesBasicTest is TestSetupReform {
    function setUp() public override {
        super.setUp();
        mandateId = findMandateIdInOrg("PauseMandates: pause or restart mandates in flow.", daoMock);
    }

    function testPauseMandatesWorks() public {
        // Verify SelfSelect (mandateId=1) is active before pause
        (,, bool activeBefore) = daoMock.getAdoptedMandate(1);
        assertTrue(activeBefore);

        mandateCalldata = abi.encode(true); // paused=true

        vm.prank(alice);
        daoMock.request(mandateId, mandateCalldata, nonce, "Pause SelfSelect");

        // SelfSelect should now be revoked (inactive)
        (,, bool activeAfter) = daoMock.getAdoptedMandate(1);
        assertFalse(activeAfter);

        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        assertEq(uint8(daoMock.getActionState(actionId)), uint8(PowersTypes.ActionState.Fulfilled));
    }

    function testRestartMandatesWorks() public {
        // Step 1: pause SelfSelect (nonce=123)
        mandateCalldata = abi.encode(true);
        vm.prank(alice);
        daoMock.request(mandateId, mandateCalldata, nonce, "Pause SelfSelect");

        (,, bool pausedState) = daoMock.getAdoptedMandate(1);
        assertFalse(pausedState);

        // Step 2: restart SelfSelect (nonce=456 to avoid ActionAlreadyInitiated)
        // After 4 mandates are constituted, mandateCounter=5; restart creates mandateId=5
        mandateCalldata = abi.encode(false); // paused=false
        nonce = 456;

        vm.prank(alice);
        daoMock.request(mandateId, mandateCalldata, nonce, "Restart SelfSelect");

        // A new SelfSelect should now be adopted at mandateId=5
        (,, bool restartedActive) = daoMock.getAdoptedMandate(5);
        assertTrue(restartedActive);

        // flow[0][0] should now point to the new mandateId=5
        uint16[] memory flowMandates = daoMock.getFlowMandatesAtIndex(0);
        assertEq(flowMandates[0], 5);

        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        assertEq(uint8(daoMock.getActionState(actionId)), uint8(PowersTypes.ActionState.Fulfilled));
    }

    function testInitializeMandateRevertsOnArrayLengthMismatch() public {
        // Use a fresh DAO to test constitute-time config validation
        PowersMock freshDao = new PowersMock();

        uint8[] memory indexFlow_ = new uint8[](2); // length 2
        uint8[] memory indexMandate_ = new uint8[](1); // length 1 — mismatch
        indexFlow_[0] = 0;
        indexFlow_[1] = 1;
        indexMandate_[0] = 0;

        PowersTypes.Conditions memory cond;
        cond.allowedRole = 1;

        PowersTypes.MandateInitData[] memory initData = new PowersTypes.MandateInitData[](1);
        initData[0] = PowersTypes.MandateInitData({
            nameDescription: "PauseMandates: mismatched arrays",
            targetMandate: findMandateAddress("PauseMandates"),
            config: abi.encode(indexFlow_, indexMandate_),
            conditions: cond
        });

        vm.expectRevert(bytes("Array length mismatch"));
        freshDao.constitute(initData);
    }
}

// ─────────────────────────────────────────────
//               EDGE CASES
// ─────────────────────────────────────────────
contract PauseMandatesEdgeCaseTest is TestSetupReform {
    function testRestartAlreadyActiveMandateSkipsWithNoEffect() public {
        // Calling restart (paused=false) when the mandate is already active should produce 0 calls
        mandateId = findMandateIdInOrg("PauseMandates: pause or restart mandates in flow.", daoMock);
        mandateCalldata = abi.encode(false); // paused=false on an already-active mandate

        vm.prank(alice);
        daoMock.request(mandateId, mandateCalldata, nonce, "Restart already-active mandate");

        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        assertEq(uint8(daoMock.getActionState(actionId)), uint8(PowersTypes.ActionState.Fulfilled));

        // SelfSelect (mandateId=1) should still be active — no state change
        (,, bool active) = daoMock.getAdoptedMandate(1);
        assertTrue(active);

        // flow[0][0] should still point to mandateId=1 — no change
        uint16[] memory flowMandates = daoMock.getFlowMandatesAtIndex(0);
        assertEq(flowMandates[0], 1);
    }

    function testPauseWithInvalidFlowIndexSkipsGracefully() public {
        // PauseMandates configured with flow index 99 (does not exist) skips via try/catch
        mandateId = findMandateIdInOrg("PauseMandates: invalid flow index.", daoMock);
        mandateCalldata = abi.encode(true); // paused=true

        vm.prank(alice);
        daoMock.request(mandateId, mandateCalldata, nonce, "Pause with invalid flow index");

        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        assertEq(uint8(daoMock.getActionState(actionId)), uint8(PowersTypes.ActionState.Fulfilled));

        // SelfSelect is unaffected — still active
        (,, bool active) = daoMock.getAdoptedMandate(1);
        assertTrue(active);
    }

    function testPauseWithOutOfBoundsMandateIndexSkipsGracefully() public {
        // PauseMandates configured with valid flow[0] but mandate index 99 (flow has only 1 entry)
        mandateId = findMandateIdInOrg("PauseMandates: out-of-bounds mandate index.", daoMock);
        mandateCalldata = abi.encode(true); // paused=true

        vm.prank(alice);
        daoMock.request(mandateId, mandateCalldata, nonce, "Pause with OOB mandate index");

        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        assertEq(uint8(daoMock.getActionState(actionId)), uint8(PowersTypes.ActionState.Fulfilled));

        // SelfSelect is unaffected — still active
        (,, bool active) = daoMock.getAdoptedMandate(1);
        assertTrue(active);
    }
}

// ─────────────────────────────────────────────
//               ACCESS CONTROL
// ─────────────────────────────────────────────
contract PauseMandatesAccessTest is TestSetupReform {
    function setUp() public override {
        super.setUp();
        mandateId = findMandateIdInOrg("PauseMandates: pause or restart mandates in flow.", daoMock);
        mandateCalldata = abi.encode(true);
    }

    function testPauseMandatesRevertsForCallerWithWrongRole() public {
        // charlotte has ROLE_TWO; mandate requires ROLE_ONE
        vm.prank(charlotte);
        vm.expectRevert(Powers__CannotCallMandate.selector);
        daoMock.request(mandateId, mandateCalldata, nonce, "Charlotte attempts pause");
    }

    function testPauseMandatesRevertsForCallerWithNoRole() public {
        // eve has no roles at all
        vm.prank(eve);
        vm.expectRevert(Powers__CannotCallMandate.selector);
        daoMock.request(mandateId, mandateCalldata, nonce, "Eve attempts pause");
    }
}

/////////////////////////////////////////////////////////////////////
//                        ADOPT_MANDATES                           //
/////////////////////////////////////////////////////////////////////

// ─────────────────────────────────────────────
//               BASIC BEHAVIOUR
// ─────────────────────────────────────────────
contract AdoptMandatesBasicTest is TestSetupExecutive {
    function setUp() public override {
        super.setUp();
        mandateId = findMandateIdInOrg("Adopt_Mandates: A mandate to adopt new mandates into the DAO.", daoMock);
    }

    /// @dev Helper: one MandateInitData with the given target, name, config and role.
    function _initData(string memory name_, address target_, bytes memory config_, uint256 role_)
        internal
        pure
        returns (PowersTypes.MandateInitData memory)
    {
        PowersTypes.Conditions memory cond;
        cond.allowedRole = role_;
        return PowersTypes.MandateInitData({
            nameDescription: name_, targetMandate: target_, config: config_, conditions: cond
        });
    }

    function testAdoptMandatesAdoptsSingleMandate() public {
        PowersTypes.MandateInitData[] memory initData = new PowersTypes.MandateInitData[](1);
        initData[0] = _initData(
            "SelfSelect: adopted by reform.", findMandateAddress("SelfSelect"), abi.encode(ROLE_ONE), ROLE_ONE
        );

        mandateCalldata = abi.encode(initData);
        uint16 counterBefore = daoMock.mandateCounter();

        vm.prank(alice);
        daoMock.request(mandateId, mandateCalldata, nonce, "Adopt SelfSelect");

        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        assertEq(uint8(daoMock.getActionState(actionId)), uint8(PowersTypes.ActionState.Fulfilled));
        assertEq(daoMock.mandateCounter(), counterBefore + 1);

        (address adoptedAddr,, bool active) = daoMock.getAdoptedMandate(counterBefore);
        assertEq(adoptedAddr, initData[0].targetMandate);
        assertTrue(active);
    }

    /// @notice The v0.2.0 point: config survives adoption. Under v0.1.9 this was always empty.
    function testAdoptMandatesPreservesConfigAndName() public {
        bytes memory config = abi.encode(ROLE_TWO);
        PowersTypes.MandateInitData[] memory initData = new PowersTypes.MandateInitData[](1);
        initData[0] = _initData("SelfSelect: claim role two.", findMandateAddress("SelfSelect"), config, ROLE_ONE);

        mandateCalldata = abi.encode(initData);
        uint16 counterBefore = daoMock.mandateCounter();

        vm.prank(alice);
        daoMock.request(mandateId, mandateCalldata, nonce, "Adopt configured SelfSelect");

        (address adoptedAddr,,) = daoMock.getAdoptedMandate(counterBefore);
        assertEq(Mandate(adoptedAddr).getConfig(address(daoMock), counterBefore), config);
        assertEq(
            Mandate(adoptedAddr).getNameDescription(address(daoMock), counterBefore), "SelfSelect: claim role two."
        );
    }

    /// @notice Conditions survive adoption too — under v0.1.9 every field but allowedRole was zeroed.
    function testAdoptMandatesPreservesConditions() public {
        PowersTypes.Conditions memory cond;
        cond.allowedRole = ROLE_ONE;
        cond.votingPeriod = 1200;
        cond.timelock = 300;
        cond.quorum = 50;
        cond.succeedAt = 66;

        PowersTypes.MandateInitData[] memory initData = new PowersTypes.MandateInitData[](1);
        initData[0] = PowersTypes.MandateInitData({
            nameDescription: "SelfSelect: adopted with a vote.",
            targetMandate: findMandateAddress("SelfSelect"),
            config: abi.encode(ROLE_ONE),
            conditions: cond
        });

        mandateCalldata = abi.encode(initData);
        uint16 counterBefore = daoMock.mandateCounter();

        vm.prank(alice);
        daoMock.request(mandateId, mandateCalldata, nonce, "Adopt with conditions");

        PowersTypes.Conditions memory stored = daoMock.getConditions(counterBefore);
        assertEq(stored.allowedRole, ROLE_ONE);
        assertEq(stored.votingPeriod, 1200);
        assertEq(stored.timelock, 300);
        assertEq(stored.quorum, 50);
        assertEq(stored.succeedAt, 66);
    }

    function testAdoptMandatesAdoptsMultipleMandates() public {
        PowersTypes.MandateInitData[] memory initData = new PowersTypes.MandateInitData[](2);
        initData[0] = _initData(
            "SelfSelect: adopted by reform.", findMandateAddress("SelfSelect"), abi.encode(ROLE_ONE), ROLE_ONE
        );
        initData[1] = _initData(
            "RenounceRole: adopted by reform.",
            findMandateAddress("RenounceRole"),
            abi.encode(new uint256[](0)),
            ROLE_TWO
        );

        mandateCalldata = abi.encode(initData);
        uint16 counterBefore = daoMock.mandateCounter();

        vm.prank(alice);
        daoMock.request(mandateId, mandateCalldata, nonce, "Adopt two mandates");

        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        assertEq(uint8(daoMock.getActionState(actionId)), uint8(PowersTypes.ActionState.Fulfilled));
        assertEq(daoMock.mandateCounter(), counterBefore + 2);

        (address addr0,, bool active0) = daoMock.getAdoptedMandate(counterBefore);
        (address addr1,, bool active1) = daoMock.getAdoptedMandate(uint16(counterBefore + 1));
        assertEq(addr0, initData[0].targetMandate);
        assertTrue(active0);
        assertEq(addr1, initData[1].targetMandate);
        assertTrue(active1);
    }

    /// @notice Two mandates adopted in one call, the second chained to the first via needFulfilled.
    ///         The predicted id is counterBefore (the first adoption's slot).
    function testAdoptMandatesChainsNeedFulfilledWithinOneCall() public {
        uint16 counterBefore = daoMock.mandateCounter();

        PowersTypes.Conditions memory condA;
        condA.allowedRole = ROLE_ONE;

        PowersTypes.Conditions memory condB;
        condB.allowedRole = ROLE_ONE;
        condB.needFulfilled = counterBefore; // the mandate adopted immediately before this one

        PowersTypes.MandateInitData[] memory initData = new PowersTypes.MandateInitData[](2);
        initData[0] = PowersTypes.MandateInitData({
            nameDescription: "Step 1: propose.",
            targetMandate: findMandateAddress("StatementOfIntent"),
            config: abi.encode(new string[](0)),
            conditions: condA
        });
        initData[1] = PowersTypes.MandateInitData({
            nameDescription: "Step 2: execute after step 1.",
            targetMandate: findMandateAddress("StatementOfIntent"),
            config: abi.encode(new string[](0)),
            conditions: condB
        });

        mandateCalldata = abi.encode(initData);
        vm.prank(alice);
        daoMock.request(mandateId, mandateCalldata, nonce, "Adopt a two-step flow");

        PowersTypes.Conditions memory stored = daoMock.getConditions(uint16(counterBefore + 1));
        assertEq(stored.needFulfilled, counterBefore);
    }
}

// ─────────────────────────────────────────────
//               EDGE CASES
// ─────────────────────────────────────────────
contract AdoptMandatesEdgeCaseTest is TestSetupExecutive {
    function setUp() public override {
        super.setUp();
        mandateId = findMandateIdInOrg("Adopt_Mandates: A mandate to adopt new mandates into the DAO.", daoMock);
    }

    /// @notice v0.2.0 rejects an empty array outright — a no-op adoption is a caller mistake.
    ///         (v0.1.9 fulfilled it silently.)
    function testAdoptMandatesWithEmptyArrayReverts() public {
        PowersTypes.MandateInitData[] memory initData = new PowersTypes.MandateInitData[](0);
        mandateCalldata = abi.encode(initData);

        vm.prank(alice);
        vm.expectRevert(Adopt_Mandates.Adopt_Mandates__NoMandates.selector);
        daoMock.request(mandateId, mandateCalldata, nonce, "Adopt zero mandates");
    }
}

// ─────────────────────────────────────────────
//               ACCESS CONTROL
// ─────────────────────────────────────────────
contract AdoptMandatesAccessTest is TestSetupExecutive {
    function _selfSelectInitData(uint256 role_) internal view returns (bytes memory) {
        PowersTypes.Conditions memory cond;
        cond.allowedRole = role_;
        PowersTypes.MandateInitData[] memory initData = new PowersTypes.MandateInitData[](1);
        initData[0] = PowersTypes.MandateInitData({
            nameDescription: "SelfSelect: adopted by reform.",
            targetMandate: findMandateAddress("SelfSelect"),
            config: abi.encode(ROLE_ONE),
            conditions: cond
        });
        return abi.encode(initData);
    }

    function testAdoptMandatesRevertsIfCallerLacksRole() public {
        // Deploy a fresh DAO with Adopt_Mandates restricted to ROLE_ONE
        PowersMock freshDao = new PowersMock();

        PowersTypes.Conditions memory cond;
        cond.allowedRole = ROLE_ONE;

        PowersTypes.MandateInitData[] memory initData = new PowersTypes.MandateInitData[](1);
        initData[0] = PowersTypes.MandateInitData({
            nameDescription: "Adopt_Mandates: restricted to role 1.",
            targetMandate: findMandateAddress("Adopt_Mandates"),
            config: abi.encode(),
            conditions: cond
        });

        freshDao.constitute(initData);
        freshDao.closeConstitute();

        vm.prank(address(freshDao));
        freshDao.assignRole(ROLE_ONE, alice);

        mandateCalldata = _selfSelectInitData(type(uint256).max);

        uint16 restrictedId =
            findMandateIdInOrg("Adopt_Mandates: restricted to role 1.", Powers(payable(address(freshDao))));

        // charlotte has no roles in freshDao — must be rejected
        vm.prank(charlotte);
        vm.expectRevert(Powers__CannotCallMandate.selector);
        freshDao.request(restrictedId, mandateCalldata, nonce, "Charlotte attempts adoption");
    }

    function testAdoptMandatesSucceedsForCallerWithPublicRole() public {
        // In the executive constitution, Adopt_Mandates has allowedRole = type(uint256).max — any caller passes
        mandateId = findMandateIdInOrg("Adopt_Mandates: A mandate to adopt new mandates into the DAO.", daoMock);

        mandateCalldata = _selfSelectInitData(type(uint256).max);

        // eve has no assigned roles — public mandate must still let her through
        vm.prank(eve);
        daoMock.request(mandateId, mandateCalldata, nonce, "Eve adopts a mandate");

        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        assertEq(uint8(daoMock.getActionState(actionId)), uint8(PowersTypes.ActionState.Fulfilled));
    }
}

/////////////////////////////////////////////////////////////////////
//                       REVOKE_MANDATES                           //
/////////////////////////////////////////////////////////////////////

// ─────────────────────────────────────────────
//               BASIC BEHAVIOUR
// ─────────────────────────────────────────────
contract RevokeMandatesBasicTest is TestSetupRevokeMandates {
    function setUp() public override {
        super.setUp();
        mandateId = findMandateIdInOrg("Revoke_Mandates: revoke a list of mandates.", daoMock);
    }

    function testRevokeMandatesRevokesSingleMandate() public {
        uint16 targetId = findMandateIdInOrg("SelfSelect: self-assign as member.", daoMock);

        (,, bool activeBefore) = daoMock.getAdoptedMandate(targetId);
        assertTrue(activeBefore);

        uint16[] memory toRevoke = new uint16[](1);
        toRevoke[0] = targetId;
        mandateCalldata = abi.encode(toRevoke);

        vm.prank(alice);
        daoMock.request(mandateId, mandateCalldata, nonce, "Revoke SelfSelect member");

        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        assertEq(uint8(daoMock.getActionState(actionId)), uint8(PowersTypes.ActionState.Fulfilled));

        (,, bool activeAfter) = daoMock.getAdoptedMandate(targetId);
        assertFalse(activeAfter);
    }

    function testRevokeMandatesRevokesMultipleMandates() public {
        uint16 targetId1 = findMandateIdInOrg("SelfSelect: self-assign as member.", daoMock);
        uint16 targetId2 = findMandateIdInOrg("SelfSelect: self-assign as delegate.", daoMock);

        uint16[] memory toRevoke = new uint16[](2);
        toRevoke[0] = targetId1;
        toRevoke[1] = targetId2;
        mandateCalldata = abi.encode(toRevoke);

        vm.prank(alice);
        daoMock.request(mandateId, mandateCalldata, nonce, "Revoke two mandates");

        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        assertEq(uint8(daoMock.getActionState(actionId)), uint8(PowersTypes.ActionState.Fulfilled));

        (,, bool active1) = daoMock.getAdoptedMandate(targetId1);
        (,, bool active2) = daoMock.getAdoptedMandate(targetId2);
        assertFalse(active1);
        assertFalse(active2);
    }
}

// ─────────────────────────────────────────────
//               EDGE CASES
// ─────────────────────────────────────────────
contract RevokeMandatesEdgeCaseTest is TestSetupRevokeMandates {
    function setUp() public override {
        super.setUp();
        mandateId = findMandateIdInOrg("Revoke_Mandates: revoke a list of mandates.", daoMock);
    }

    function testRevokeMandatesWithEmptyArrayFulfills() public {
        uint16[] memory toRevoke = new uint16[](0);
        mandateCalldata = abi.encode(toRevoke);

        vm.prank(alice);
        daoMock.request(mandateId, mandateCalldata, nonce, "Revoke empty list");

        actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
        assertEq(uint8(daoMock.getActionState(actionId)), uint8(PowersTypes.ActionState.Fulfilled));

        // Both other mandates remain active — no state change
        uint16 id1 = findMandateIdInOrg("SelfSelect: self-assign as member.", daoMock);
        uint16 id2 = findMandateIdInOrg("SelfSelect: self-assign as delegate.", daoMock);
        (,, bool still1) = daoMock.getAdoptedMandate(id1);
        (,, bool still2) = daoMock.getAdoptedMandate(id2);
        assertTrue(still1);
        assertTrue(still2);
    }
}

// ─────────────────────────────────────────────
//               ACCESS CONTROL
// ─────────────────────────────────────────────
contract RevokeMandatesAccessTest is TestSetupRevokeMandates {
    function setUp() public override {
        super.setUp();
        mandateId = findMandateIdInOrg("Revoke_Mandates: revoke a list of mandates.", daoMock);
        uint16[] memory toRevoke = new uint16[](1);
        toRevoke[0] = 1;
        mandateCalldata = abi.encode(toRevoke);
    }

    function testRevokeMandatesRevertsForCallerWithWrongRole() public {
        // charlotte holds ROLE_TWO; mandate requires ROLE_ONE
        vm.prank(charlotte);
        vm.expectRevert(Powers__CannotCallMandate.selector);
        daoMock.request(mandateId, mandateCalldata, nonce, "Charlotte attempts revoke");
    }

    function testRevokeMandatesRevertsForCallerWithNoRole() public {
        // eve has no roles
        vm.prank(eve);
        vm.expectRevert(Powers__CannotCallMandate.selector);
        daoMock.request(mandateId, mandateCalldata, nonce, "Eve attempts revoke");
    }
}
