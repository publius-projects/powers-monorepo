# Testing Principles — Powers Protocol

## Purpose

Tests exist to find logical errors and bugs in existing contracts. Coverage metrics are a side effect of good testing, never the goal. A test that passes by masking a real problem is worse than no test at all.

---

## 1. Use the Existing Test Infrastructure — Do Not Reinvent It

All tests **must** inherit from the appropriate base setup in `TestSetup.t.sol`. Never declare a standalone test contract with its own `setUp()` logic.

```
TestVariables
  └─ TestHelperFunctions
       └─ BaseSetup
            ├─ TestSetupPowers          → use for Powers.sol core tests
            ├─ TestSetupMandate         → use for generic mandate behaviour
            ├─ TestSetupElectoral       → use for electoral mandates
            ├─ TestSetupExecutive       → use for executive mandates
            ├─ TestSetupIntegrations    → use for integration mandate tests
            ├─ TestSetupHelpers         → use for helper contract tests
            └─ TestSetup*Flow           → use for end-to-end governance flows
```

All state variables, mock addresses (`alice`, `bob`, `daoMock`, etc.), and helper functions (`voteOnProposal`, `findMandateIdInOrg`, `hashProposal`) are declared in `TestVariables` and `TestHelperFunctions`. Use them. Do not re-declare.

---

## 2. Use TestConstitutions.sol to Wire Up Mandates

Mandate configurations for tests are defined in `TestConstitutions.sol`. If an existing constitution covers your scenario, use it. If you need a new combination of mandates, add a new constitution function there — do not inline `MandateInitData` arrays inside individual test files.

The constitution functions provide:
- Correctly sequenced `mandateId` assignments (counting from 1)
- `needFulfilled` / `needNotFulfilled` dependency chains that mirror real governance flows
- Conditions (quorum, succeedAt, votingPeriod, timelock, throttle) that reflect realistic usage

When referencing a mandate in a test, resolve its `mandateId` from the deployed org, not from a hardcoded integer, unless the test explicitly concerns a known fixed position:

```solidity
// preferred
mandateId = findMandateIdInOrg("StatementOfIntent: Propose any kind of action.", daoMock);

// acceptable only when the test is about mandate ordering itself
mandateId = 3;
```

---

## 3. Never Create Mock Data to Make a Test Pass

If the correct inputs or state required to exercise a function are not available through the standard test setup, do not invent substitute values. Investigate why the inputs are unavailable. Either:

- the test setup is missing a prerequisite (fix the setup, not the assertion), or
- the protocol has a real constraint that prevents the scenario (see rule 4).

Mock contracts (`PowersMock`, `SimpleErc1155`, `ReturnDataMock`, etc.) exist in `test/mocks/` for structural isolation. Using them is fine. Fabricating return values or state to sidestep a protocol check is not.

---

## 4. Let Failing Tests Fail — Report, Do Not Fix

If a test fails because existing protocol code has a limitation, a bug, or an architectural gap: **leave the test failing**. Mark it clearly:

```solidity
// FAILING: Powers.sol reverts here because <reason>.
// The function requires X but the current implementation only supports Y.
// Possible solutions:
//   1. Add a Z parameter to function foo() to allow ...
//   2. Introduce a new mandate type that handles ...
// DO NOT implement a fix here. Report to protocol maintainers.
function testSomeScenario() public {
    // ...
    vm.expectRevert(...);   // or let it revert without expectation
}
```

A failing test with a clear explanation is a bug report. A passing test that was edited until it passed is noise.

---

## 5. Never Modify Protocol Code to Make Tests Pass

When writing tests, the scope is the `test/` directory only. The following are out of scope and must not be changed:

- `src/Powers.sol`
- `src/Mandate.sol`
- `src/AsyncMandate.sol`
- `src/core/**`
- `src/addons/**`
- `src/libraries/**`
- `script/**`

If a test requires behaviour that does not exist in the protocol, the test should document that gap (see rule 4) and stop there.

---

## 6. Test Structure

Group related tests into separate contracts inheriting the same base setup. Use section comments to separate concern blocks within a contract.

```solidity
// ─────────────────────────────────────────────
//               BASIC BEHAVIOUR
// ─────────────────────────────────────────────
contract MyMandateBasicTest is TestSetupExecutive { ... }

// ─────────────────────────────────────────────
//               EDGE CASES
// ─────────────────────────────────────────────
contract MyMandateEdgeCaseTest is TestSetupExecutive { ... }

// ─────────────────────────────────────────────
//               ACCESS CONTROL
// ─────────────────────────────────────────────
contract MyMandateAccessTest is TestSetupExecutive { ... }
```

Test function names must describe the scenario and expected outcome:

```
test<Subject><Condition>()          → testRequestRevertsIfCallerLacksRole()
test<Subject><Condition>Works()     → testVotePassesWithQuorumReached()
testFuzz<Subject>(<param>)          → testFuzzProposalHashIsUnique(uint256 nonce)
```

---

## 7. Governance Flow Tests Follow the Three-Phase Pattern

Synchronous mandates (no voting) — single `request()` call:

```solidity
vm.prank(alice);
daoMock.request(mandateId, mandateCalldata, nonce, description);
actionId = MandateUtilities.computeActionId(mandateId, mandateCalldata, nonce);
assertEq(uint8(daoMock.getActionState(actionId)), uint8(PowersTypes.ActionState.Fulfilled));
```

Voting mandates — propose → vote → request:

```solidity
// 1. Propose
vm.prank(alice);
actionId = daoMock.propose(mandateId, mandateCalldata, nonce, description);

// 2. Vote
vm.roll(block.number + 1);
(roleCount, againstVote, forVote, abstainVote) =
    voteOnProposal(payable(address(daoMock)), mandateId, actionId, users, randomiser, 66);

// 3. Execute (after voting period + timelock)
vm.roll(block.number + conditions.votingPeriod + conditions.timelock + 1);
vm.prank(charlotte); // role that can execute
daoMock.request(mandateId, mandateCalldata, nonce, description);
```

Use `voteOnProposal()` from `TestHelperFunctions` rather than manually looping voters.

---

## 8. Dependency Chain Tests

When testing mandates with `needFulfilled` or `needNotFulfilled` conditions, the test must fully execute the prerequisite mandate first — not simulate or skip it. The dependency exists to test a real governance constraint; bypassing it defeats the purpose.

```solidity
// Wrong: skipping the prerequisite
// Just calling the dependent mandate directly

// Right: run the full chain
// 1. Execute parent mandate (mandateId 3)
// 2. Verify its ActionState == Fulfilled
// 3. Then attempt dependent mandate (mandateId 5)
```

Use `check_inputParamsDependencies()` from `TestHelperFunctions` after constituting a DAO to verify that parent/child mandates share compatible input parameters before writing the flow tests.

---

## 9. Versioning

The minimum mandate version used in tests is declared as constants in both `TestConstitutions.sol` and `TestSetup.t.sol`:

```solidity
uint16 constant MAJOR = 0;
uint16 constant MINOR = 1;
uint16 constant PATCH = 9;
```

Always look up mandate addresses via `registry.getMandateAddress(MAJOR, MINOR, PATCH, "MandateName")`. Never hardcode mandate contract addresses.

---

## 10. What Good Tests Look Like

A good test:
- Exercises one specific behaviour or invariant
- Uses real state transitions (not fabricated preconditions)
- Asserts the exact outcome — state changes, events, reverts — not just "did not revert"
- Would catch a regression if the relevant logic were deleted or inverted

A bad test:
- Passes because the assertion is too weak (`assertTrue(true)`)
- Works around a protocol restriction rather than testing it
- Requires changes to non-test code to compile or pass
- Mocks the thing it is supposed to be testing
