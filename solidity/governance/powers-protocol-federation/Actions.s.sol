// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Powers } from "@src/Powers.sol";
import { IPowers } from "@src/interfaces/IPowers.sol";
import { ActionHelpers } from "@governance/examples/actions/ActionHelpers.s.sol";

/// @title PowersProtocolFederationActions
/// @notice Propose/execute helpers for the three interlocking organisations.
///         Each governance flow has a propose (vote) helper and an execute helper.
///         `nameDescription` strings must match Deploy.s.sol character-for-character.
///
/// Cross-organisation calls (Core → Endowment, Mandates → Core) are driven by the
/// requesting organisation firing an ExternalAction; the helpers below expose the
/// requesting side. The receiving organisation must have ratified its own side with
/// the SAME calldata + nonce for the receiving mandate's `needFulfilled` to pass.
contract PowersProtocolFederationActions is ActionHelpers {
    uint256 constant RANDOMISER = 4_242_424_242;

    // ── Generic building blocks ────────────────────────────────────────────────

    /// @notice Propose an action and have all provided role holders vote FOR it.
    function _proposeAndPass(address powers, string memory proposeName, bytes memory calldata_, uint256[] memory keys, uint256 nonce)
        internal
        returns (uint16 mandateId, uint256 actionId)
    {
        mandateId = findMandateIdInOrg(proposeName, Powers(payable(powers)));
        actionId = calculateActionId(mandateId, calldata_, nonce);
        vm.startBroadcast(keys[0]);
        IPowers(powers).propose(mandateId, calldata_, nonce, proposeName);
        vm.stopBroadcast();
        voteOnProposal(powers, mandateId, actionId, keys, RANDOMISER, 100); // 100% → all FOR
    }

    /// @notice Propose an action and have all provided role holders vote AGAINST it.
    function _proposeAndReject(address powers, string memory proposeName, bytes memory calldata_, uint256[] memory keys, uint256 nonce)
        internal
        returns (uint16 mandateId, uint256 actionId)
    {
        mandateId = findMandateIdInOrg(proposeName, Powers(payable(powers)));
        actionId = calculateActionId(mandateId, calldata_, nonce);
        vm.startBroadcast(keys[0]);
        IPowers(powers).propose(mandateId, calldata_, nonce, proposeName);
        vm.stopBroadcast();
        voteOnProposal(powers, mandateId, actionId, keys, RANDOMISER, 0); // 0% → all AGAINST
    }

    /// @notice Request execution of a (non-voting) mandate.
    function _request(address powers, string memory name, bytes memory calldata_, uint256 key, uint256 nonce) internal {
        uint16 mandateId = findMandateIdInOrg(name, Powers(payable(powers)));
        vm.startBroadcast(key);
        IPowers(powers).request(mandateId, calldata_, nonce, name);
        vm.stopBroadcast();
    }

    // ── CORE C1 - Pay Core-Development Invoice ─────────────────────────────────
    function proposeCoreInvoice(address core, address recipient, uint256 amount, uint256[] memory memberKeys, uint256 nonce) public returns (uint256) {
        (, uint256 actionId) = _proposeAndPass(core, "Propose Core Invoice: Members propose paying a core-development invoice (USDC).", abi.encode(recipient, amount), memberKeys, nonce);
        return actionId;
    }

    function executeCoreInvoice(address core, address recipient, uint256 amount, uint256[] memory memberKeys, uint256 nonce) public {
        _request(core, "Execute Core Invoice: Pay the approved core-development invoice in USDC.", abi.encode(recipient, amount), memberKeys[0], nonce);
    }

    // ── CORE C7 - Governance Reform (with Council veto) ────────────────────────
    function proposeCoreReform(address core, address[] memory mandates, uint256[] memory roleIds, uint256[] memory memberKeys, uint256 nonce) public returns (uint256) {
        (, uint256 actionId) = _proposeAndPass(core, "Propose Core Reform: Members vote to adopt new governance mandates.", abi.encode(mandates, roleIds), memberKeys, nonce);
        return actionId;
    }

    /// @notice Cast the Security Council veto against a proposed reform (blocks execution).
    function vetoCoreReform(address core, address[] memory mandates, uint256[] memory roleIds, uint256[] memory councilKeys, uint256 nonce) public {
        _request(core, "Veto Core Reform: The Security Council blocks a proposed governance reform.", abi.encode(mandates, roleIds), councilKeys[0], nonce);
    }

    function adoptCoreReform(address core, address[] memory mandates, uint256[] memory roleIds, uint256[] memory memberKeys, uint256 nonce) public {
        _request(core, "Adopt Core Reform: Execute an approved, un-vetoed governance reform.", abi.encode(mandates, roleIds), memberKeys[0], nonce);
    }

    // ── CORE C8 - Draw Endowment Income (cross-org) ────────────────────────────
    function drawEndowmentIncome(address core, uint256[] memory memberKeys, uint256 nonce) public {
        _request(core, "Draw Endowment Income: Core triggers the Endowment income stream into the Core treasury.", abi.encode(), memberKeys[0], nonce);
    }

    // ── ENDOWMENT E1 - Invest: Supply to Aave ──────────────────────────────────
    function proposeInvest(address endowment, address asset, uint256 amount, uint256[] memory investorKeys, uint256 nonce) public returns (uint256) {
        (, uint256 actionId) = _proposeAndPass(endowment, "Propose Aave Investment: Investors propose supplying an asset to the Aave v3 pool.", abi.encode(asset, amount), investorKeys, nonce);
        return actionId;
    }

    function executeInvest(address endowment, address asset, uint256 amount, uint256[] memory investorKeys, uint256 nonce) public {
        _request(endowment, "Execute Aave Investment: Supply the approved asset to the Aave v3 pool if not vetoed.", abi.encode(asset, amount), investorKeys[0], nonce);
    }

    // ── ENDOWMENT E2 - Divest: Withdraw from Aave ──────────────────────────────
    function proposeDivest(address endowment, address asset, uint256 amount, uint256[] memory investorKeys, uint256 nonce) public returns (uint256) {
        (, uint256 actionId) = _proposeAndPass(endowment, "Propose Aave Divestment: Investors propose withdrawing an asset from the Aave v3 pool.", abi.encode(asset, amount), investorKeys, nonce);
        return actionId;
    }

    function executeDivest(address endowment, address asset, uint256 amount, uint256[] memory investorKeys, uint256 nonce) public {
        _request(endowment, "Execute Aave Divestment: Withdraw the approved asset from the Aave v3 pool to the treasury.", abi.encode(asset, amount), investorKeys[0], nonce);
    }

    // ── MANDATES M1 - Pay Mandate-Development Invoice ──────────────────────────
    function proposeMandateInvoice(address mandates, address recipient, uint256 amount, uint256[] memory assessorKeys, uint256 nonce) public returns (uint256) {
        (, uint256 actionId) = _proposeAndPass(mandates, "Propose Mandate Invoice: Assessors propose paying a mandate-development invoice (USDC).", abi.encode(recipient, amount), assessorKeys, nonce);
        return actionId;
    }

    function executeMandateInvoice(address mandates, address recipient, uint256 amount, uint256[] memory assessorKeys, uint256 nonce) public {
        _request(mandates, "Execute Mandate Invoice: Pay the approved mandate-development invoice in USDC.", abi.encode(recipient, amount), assessorKeys[0], nonce);
    }

    // ── MANDATES M3 - Add a Mandate to the Registry ────────────────────────────
    function proposeRegistryAddition(address mandates, string memory name, address mandateAddr, bytes32 codeHash, uint256[] memory assessorKeys, uint256 nonce) public returns (uint256) {
        (, uint256 actionId) = _proposeAndPass(mandates, "Propose Registry Addition: Assessors propose listing a mandate in the registry.", abi.encode(name, mandateAddr, codeHash), assessorKeys, nonce);
        return actionId;
    }

    function vetoRegistryAddition(address mandates, string memory name, address mandateAddr, bytes32 codeHash, uint256[] memory councilKeys, uint256 nonce) public {
        _request(mandates, "Veto Registry Addition: The Security Council blocks a proposed registry listing.", abi.encode(name, mandateAddr, codeHash), councilKeys[0], nonce);
    }

    function executeRegistryAddition(address mandates, string memory name, address mandateAddr, bytes32 codeHash, uint256[] memory assessorKeys, uint256 nonce) public {
        _request(mandates, "Execute Registry Addition: Register the approved, un-vetoed mandate in the registry.", abi.encode(name, mandateAddr, codeHash), assessorKeys[0], nonce);
    }
}
