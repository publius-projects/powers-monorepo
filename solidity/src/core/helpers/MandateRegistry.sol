// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Ownable } from "@lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import { ERC165Checker } from "@lib/openzeppelin-contracts/contracts/utils/introspection/ERC165Checker.sol";
import { IMandate } from "@src/interfaces/IMandate.sol";

/// @title MandateRegistry - Whitelist Registry for Powers Protocol Mandates
/// @notice Maintains a version-controlled registry of approved mandate implementations
///         together with an optional paid-adoption tier.
/// @dev The registry serves two distinct purposes:
///
///      1. WHITELIST (registration logic). Powers orgs adopt governance logic by pointing at
///         external mandate contracts. To stop an org from adopting an arbitrary/malicious
///         contract, this registry keeps a canonical list of approved mandates. A mandate is
///         identified by a (name, version) pair, where the version is read on-chain from the
///         mandate itself via IMandate.version(). Registration is owner-gated; adopters check
///         registration status at adoption time (see onAdopt / isMandateAddressActive).
///
///      2. PAID TIER (paid tier logic). A registered mandate may optionally carry an adoption
///         price, declared by the mandate itself in credits (IMandate.priceInCredits) together with
///         its developer payees (IMandate.devs). The registry owner sets a single global credit -> wei
///         exchange rate (weiPerCredit); on adoption the credit price is converted to wei, charged
///         against the org's prepaid balance, and split between the developer payees and the protocol
///         fee. All accounting is ledger-based (pull-payments); ETH only leaves via withdrawEarnings.
///
///      Registration, deactivation, reactivation, the exchange rate and the protocol fee are all
///      owner-only. Per-mandate pricing is developer-controlled (on the mandate). Buying credits,
///      adoption charges, and withdrawals are permissionless.
/// @author 7Cedars

interface IMandateRegistry {
    struct MandateEntry {
        address mandateAddress;
        uint48 registeredAt;
        bool isActive;
    }

    function registerMandate(string calldata mandateName, address mandateAddress, bytes32 creationCodeHash) external;
    function deactivateMandate(uint16 major, uint16 minor, uint16 patch, string calldata mandateName) external;
    function reactivateMandate(uint16 major, uint16 minor, uint16 patch, string calldata mandateName) external;
    function batchRegisterMandates(
        string[] calldata mandateNames,
        address[] calldata mandateAddresses,
        bytes32[] calldata creationCodeHashes
    ) external;
    function getMandateEntry(uint16 major, uint16 minor, uint16 patch, string calldata mandateName)
        external
        view
        returns (MandateEntry memory);
    function getMandateAddress(uint16 major, uint16 minor, uint16 patch, string calldata mandateName)
        external
        view
        returns (address);
    function isMandateRegistered(bytes32 creationCodeHash) external view returns (bool);
    function isMandateAddressActive(address mandateAddress) external view returns (bool);
    function isVersionActive(uint16 major, uint16 minor, uint16 patch, string calldata mandateName)
        external
        view
        returns (bool);
    function getLatestVersion(string calldata mandateName)
        external
        view
        returns (uint16 major, uint16 minor, uint16 patch);
    function owner() external view returns (address);

    // --- Paid tier: exchange rate, credits, earnings ---
    function onAdopt(address org) external;
    function buyCredits(address org) external payable;
    function withdrawEarnings() external;
    function setWeiPerCredit(uint256 newWeiPerCredit) external;
    function setFeeBps(uint16 newFeeBps) external;
    function weiPerCredit() external view returns (uint256);
    function credits(address org) external view returns (uint256);
    function earnings(address dev) external view returns (uint256);
    function feeBps() external view returns (uint16);
}

contract MandateRegistry is Ownable, ReentrancyGuard {
    //////////////////////////////////////////////////////////////
    //                        STORAGE                           //
    //////////////////////////////////////////////////////////////

    /// @notice Structure containing mandate registration details.
    /// @dev registeredAt doubles as an existence flag: a value of 0 means "no entry here"
    ///      (block 0 is never a real registration block), which every lookup relies on to
    ///      distinguish an unregistered slot from a deactivated one.
    struct MandateEntry {
        address mandateAddress;
        uint48 registeredAt; // Block number when registered; 0 == entry does not exist.
        bool isActive; // Soft-delete flag; false == deactivated but still on record.
    }

    /// @notice Registry keyed by mandate name and version: nameHash => packedVersion => entry.
    /// @dev nameHash is keccak256(name); packedVersion packs (major, minor, patch) into one
    ///      uint48 (see packVersion). This two-level mapping is the source of truth for the
    ///      whitelist — every (name, version) an org might adopt resolves through here.
    mapping(bytes32 nameHash => mapping(uint48 packedVersion => MandateEntry)) public registry;

    /// @notice Ordered list of packed versions registered under each mandate name.
    /// @dev Append-only and strictly increasing (enforced in _addVersion), so the last element
    ///      is always the latest version — used by getLatestVersion.
    mapping(bytes32 nameHash => uint48[]) public mandateVersions;

    /// @notice Whether a given mandate creation-code hash has ever been registered.
    /// @dev Lets callers verify that a deployed bytecode corresponds to an approved mandate,
    ///      independent of its name/version. Set true on registration and never cleared.
    mapping(bytes32 creationCodeHash => bool) public registeredCreationCodes;

    /// @notice Structure locating a mandate address's most recent registration entry
    struct AddressKey {
        bytes32 nameHash;
        uint48 packedVersion;
    }

    /// @notice Mapping from a deployed mandate's address to the registry entry it was last registered under
    /// @dev Used by isMandateAddressActive() so callers (e.g. Powers.sol) can check registration status by
    /// address alone, without needing to know the mandate's name/version in advance.
    /// Caveat: nothing prevents the same address from being registered under two different names — only
    /// (name, version) pairs are checked for uniqueness. If that ever happens, this mapping reflects only the
    /// most recent registration, so isMandateAddressActive() would not see an earlier name's deactivation.
    mapping(address mandateAddress => AddressKey) public addressKey;

    //////////////////////////////////////////////////////////////
    //                   PAID TIER STORAGE                      //
    //////////////////////////////////////////////////////////////

    /// @notice Global credit -> wei exchange rate: how many wei one credit is worth. Owner-settable.
    /// @dev Mandates declare their price in credits (IMandate.priceInCredits); the registry multiplies
    /// by this rate at adoption time to get the wei cost. Changing it reprices every priced mandate in a
    /// single action and never re-values existing prepaid balances (which are held in wei) — keeping the
    /// pool solvent regardless of rate changes.
    uint256 public weiPerCredit;

    /// @notice Prepaid balance per org (adopting Powers instance), in wei.
    mapping(address org => uint256 credits) public credits;

    /// @notice Withdrawable earnings per payee (devs and the owning org for the protocol fee), in wei.
    mapping(address payee => uint256 earnings) public earnings;

    /// @notice Protocol fee in basis points, taken from each charge. Owner-settable, capped at MAX_FEE_BPS.
    uint16 public feeBps;

    /// @notice Maximum allowed protocol fee (30%).
    uint16 public constant MAX_FEE_BPS = 3000;

    /// @notice Default protocol fee applied at deployment (10%).
    uint16 internal constant DEFAULT_FEE_BPS = 1000;

    /// @notice Default credit -> wei rate applied at deployment (1 wei per credit; owner should set a real rate).
    uint256 internal constant DEFAULT_WEI_PER_CREDIT = 1;

    //////////////////////////////////////////////////////////////
    //                        EVENTS                            //
    //////////////////////////////////////////////////////////////

    /// @notice Emitted when a new mandate is registered
    event MandateRegistered(
        uint16 major,
        uint16 minor,
        uint16 patch,
        address indexed mandateAddress,
        string mandateName,
        uint256 registeredAt
    );

    /// @notice Emitted when a mandate is updated
    event MandateUpdated(
        uint16 major,
        uint16 minor,
        uint16 patch,
        address indexed oldAddress,
        address indexed newAddress,
        string mandateName
    );

    /// @notice Emitted when a mandate is deactivated
    event MandateDeactivated(uint16 major, uint16 minor, uint16 patch, string mandateName, uint256 deactivatedAt);

    /// @notice Emitted when a mandate is reactivated
    event MandateReactivated(uint16 major, uint16 minor, uint16 patch, string mandateName, uint256 reactivatedAt);

    /// @notice Emitted when the global credit -> wei exchange rate is updated
    event WeiPerCreditSet(uint256 weiPerCredit);

    /// @notice Emitted when the protocol fee is updated
    event FeeBpsSet(uint16 feeBps);

    /// @notice Emitted when credits are purchased for an org
    event CreditsPurchased(address indexed org, address indexed payer, uint256 amount);

    /// @notice Emitted when a mandate adoption is charged
    event MandateCharged(address indexed mandate, address indexed org, uint256 price, uint256 fee);

    /// @notice Emitted when a payee withdraws earnings
    event EarningsWithdrawn(address indexed payee, uint256 amount);

    //////////////////////////////////////////////////////////////
    //                        ERRORS                            //
    //////////////////////////////////////////////////////////////

    error MandateAlreadyRegistered(uint16 major, uint16 minor, uint16 patch, string mandateName);
    error MandateNotFound(uint16 major, uint16 minor, uint16 patch, string mandateName);
    error MandateInactive(uint16 major, uint16 minor, uint16 patch, string mandateName);
    error InvalidMandateAddress();
    error InvalidMandateInterface(address mandateAddress);
    error InvalidNameLength();
    error InvalidVersionSequence(uint16 major, uint16 minor, uint16 patch, string mandateName);
    error NotRegistered(address mandate);
    error InsufficientCredits(address org, uint256 required, uint256 available);
    error NoDevs(address mandate);
    error ExchangeRateNotSet();
    error FeeTooHigh(uint16 feeBps, uint16 maxFeeBps);
    error NothingToWithdraw();
    error EthTransferFailed();

    //////////////////////////////////////////////////////////////
    //                      CONSTRUCTOR                         //
    //////////////////////////////////////////////////////////////

    /// @notice Initializes the registry with the deployer as owner
    constructor(address initialOwner) Ownable(initialOwner) {
        feeBps = DEFAULT_FEE_BPS;
        weiPerCredit = DEFAULT_WEI_PER_CREDIT;
    }

    //////////////////////////////////////////////////////////////
    //                   REGISTRATION LOGIC                     //
    //////////////////////////////////////////////////////////////

    /// @notice Registers a new mandate under the version reported by its own contract.
    /// @dev Owner-only. The version is not supplied by the caller — it is read on-chain from the
    ///      mandate via IMandate.version(), so the entry cannot claim a version the contract does
    ///      not actually declare. Reverts if the address is empty, does not implement IMandate, or
    ///      if this exact (name, version) pair is already on record (whether active or deactivated).
    /// @param mandateName Human-readable name for the mandate (1–255 bytes).
    /// @param mandateAddress Address of the deployed mandate contract.
    /// @param creationCodeHash Hash of the mandate's creation code, recorded for bytecode lookups.
    function registerMandate(string calldata mandateName, address mandateAddress, bytes32 creationCodeHash)
        public
        onlyOwner
    {
        // Validate the name is non-empty and fits the 255-byte bound implied by MandateEntry usage.
        if (bytes(mandateName).length == 0 || bytes(mandateName).length > 255) {
            revert InvalidNameLength();
        }
        if (mandateAddress == address(0)) revert InvalidMandateAddress();

        // Ensure the target actually is a mandate by requiring ERC165 support for IMandate.
        if (!ERC165Checker.supportsInterface(mandateAddress, type(IMandate).interfaceId)) {
            revert InvalidMandateInterface(mandateAddress);
        }

        // Derive the storage keys: version comes from the contract, nameHash from the given name.
        (uint16 major, uint16 minor, uint16 patch) = IMandate(mandateAddress).version();
        uint48 packedVersion = packVersion(major, minor, patch);
        bytes32 nameHash = keccak256(bytes(mandateName));

        // Reject duplicates. registeredAt != 0 means this (name, version) slot is already taken;
        // report whether it is currently active or was previously deactivated for a clearer error.
        if (registry[nameHash][packedVersion].registeredAt != 0) {
            if (registry[nameHash][packedVersion].isActive) {
                revert MandateAlreadyRegistered(major, minor, patch, mandateName);
            } else {
                revert MandateInactive(major, minor, patch, mandateName);
            }
        }

        // Write the entry and its three indexes: by (name, version), by creation code, and by address.
        registry[nameHash][packedVersion] =
            MandateEntry({ mandateAddress: mandateAddress, registeredAt: uint48(block.number), isActive: true });
        registeredCreationCodes[creationCodeHash] = true;
        addressKey[mandateAddress] = AddressKey({ nameHash: nameHash, packedVersion: packedVersion });

        // Append to the ordered version list, which also enforces strictly increasing versions.
        _addVersion(nameHash, packedVersion, major, minor, patch, mandateName);

        emit MandateRegistered(major, minor, patch, mandateAddress, mandateName, block.number);
    }

    /// @notice Deactivates a mandate (soft delete): the entry stays on record but is no longer
    ///         considered active, so future adoption checks against it fail.
    /// @dev Owner-only. Reverts if the (name, version) was never registered, or is already inactive.
    function deactivateMandate(uint16 major, uint16 minor, uint16 patch, string calldata mandateName)
        external
        onlyOwner
    {
        bytes32 nameHash = keccak256(bytes(mandateName));
        uint48 packedVersion = packVersion(major, minor, patch);

        if (registry[nameHash][packedVersion].registeredAt == 0) {
            revert MandateNotFound(major, minor, patch, mandateName);
        }

        MandateEntry storage entry = registry[nameHash][packedVersion];
        if (!entry.isActive) revert MandateInactive(major, minor, patch, mandateName);

        entry.isActive = false;

        emit MandateDeactivated(major, minor, patch, mandateName, block.number);
    }

    /// @notice Reactivates a previously deactivated mandate, restoring it to the whitelist.
    /// @dev Owner-only. Reverts if the (name, version) was never registered, or is already active.
    function reactivateMandate(uint16 major, uint16 minor, uint16 patch, string calldata mandateName)
        external
        onlyOwner
    {
        bytes32 nameHash = keccak256(bytes(mandateName));
        uint48 packedVersion = packVersion(major, minor, patch);

        if (registry[nameHash][packedVersion].registeredAt == 0) {
            revert MandateNotFound(major, minor, patch, mandateName);
        }

        MandateEntry storage entry = registry[nameHash][packedVersion];
        if (entry.isActive) revert MandateAlreadyRegistered(major, minor, patch, mandateName);

        entry.isActive = true;

        emit MandateReactivated(major, minor, patch, mandateName, block.number);
    }

    /// @notice Batch registers multiple mandates in a single transaction.
    /// @dev Owner-only. A thin loop over registerMandate — each element is validated and registered
    ///      exactly as a standalone call would be, so any single failure reverts the whole batch.
    /// @param mandateNames Array of mandate names (index-aligned with the other two arrays).
    /// @param mandateAddresses Array of mandate addresses.
    /// @param creationCodeHashes Array of creation-code hashes.
    function batchRegisterMandates(
        string[] calldata mandateNames,
        address[] calldata mandateAddresses,
        bytes32[] calldata creationCodeHashes
    ) external onlyOwner {
        if (mandateNames.length != mandateAddresses.length) {
            revert("Array lengths must match");
        }

        for (uint256 i = 0; i < mandateNames.length; i++) {
            registerMandate(mandateNames[i], mandateAddresses[i], creationCodeHashes[i]);
        }
    }

    //////////////////////////////////////////////////////////////
    //                   HELPERS                                //
    //////////////////////////////////////////////////////////////

    /// @notice Packs a semantic (major, minor, patch) version into a single uint48 storage key.
    /// @dev Layout: major in bits 32–47, minor in bits 16–31, patch in bits 0–15. Because the
    ///      fields keep their numeric ordering, comparing packed values compares versions directly
    ///      (a later version always packs to a larger number), which _addVersion relies on.
    function packVersion(uint16 major, uint16 minor, uint16 patch) public pure returns (uint48) {
        return (uint48(major) << 32) | (uint48(minor) << 16) | uint48(patch);
    }

    /// @dev Appends a packed version to a mandate name's ordered version list, enforcing that
    ///      versions are registered in strictly increasing order. This keeps mandateVersions sorted
    ///      so the last element is the latest version, and prevents re-adding or back-dating a version.
    function _addVersion(
        bytes32 nameHash,
        uint48 packedVersion,
        uint16 major,
        uint16 minor,
        uint16 patch,
        string calldata mandateName
    ) internal {
        uint48[] storage versions = mandateVersions[nameHash];
        uint256 len = versions.length;

        if (len > 0 && packedVersion <= versions[len - 1]) {
            revert InvalidVersionSequence(major, minor, patch, mandateName);
        }

        versions.push(packedVersion);
    }

    /// @dev Shared read path for the (name, version) view functions. Resolves the entry and reverts
    ///      with MandateNotFound if the slot was never registered (registeredAt == 0). Note it does
    ///      not check isActive — callers that care about active status inspect the returned flag.
    function _getMandateEntryInternal(uint16 major, uint16 minor, uint16 patch, string calldata mandateName)
        internal
        view
        returns (MandateEntry memory)
    {
        bytes32 nameHash = keccak256(bytes(mandateName));
        uint48 targetVersion = packVersion(major, minor, patch);

        MandateEntry memory entry = registry[nameHash][targetVersion];
        if (entry.registeredAt == 0) revert MandateNotFound(major, minor, patch, mandateName);
        return entry;
    }

    //////////////////////////////////////////////////////////////
    //                   VIEW FUNCTIONS                         //
    //////////////////////////////////////////////////////////////
    /// @notice Gets the complete mandate entry
    function getMandateEntry(uint16 major, uint16 minor, uint16 patch, string calldata mandateName)
        external
        view
        returns (MandateEntry memory)
    {
        return _getMandateEntryInternal(major, minor, patch, mandateName);
    }

    /// @notice Gets the mandate address
    function getMandateAddress(uint16 major, uint16 minor, uint16 patch, string calldata mandateName)
        external
        view
        returns (address)
    {
        return _getMandateEntryInternal(major, minor, patch, mandateName).mandateAddress;
    }

    /// @notice Checks whether a given creation-code hash belongs to a registered mandate.
    /// @dev Bytecode-based lookup: true if this hash was ever registered, regardless of the
    ///      mandate's current active status or version.
    function isMandateRegistered(bytes32 creationCodeHash) external view returns (bool) {
        return registeredCreationCodes[creationCodeHash];
    }

    /// @notice Checks if a mandate address is currently registered and active
    /// @dev Looks up the (name, version) the address was last registered under via addressKey, then
    /// checks the corresponding entry's isActive flag. Returns false for addresses never registered.
    function isMandateAddressActive(address mandateAddress) external view returns (bool) {
        return _isMandateAddressActive(mandateAddress);
    }

    /// @dev Internal variant of isMandateAddressActive, callable from within the contract (e.g. onAdopt).
    function _isMandateAddressActive(address mandateAddress) internal view returns (bool) {
        AddressKey memory key = addressKey[mandateAddress];
        MandateEntry storage entry = registry[key.nameHash][key.packedVersion];
        return entry.registeredAt != 0 && entry.isActive;
    }

    /// @notice Checks whether a specific (name, version) is registered and currently active.
    /// @dev Returns false for both never-registered and deactivated entries (no revert), unlike
    ///      the getMandate* views which revert on a missing entry.
    function isVersionActive(uint16 major, uint16 minor, uint16 patch, string calldata mandateName)
        external
        view
        returns (bool)
    {
        bytes32 nameHash = keccak256(bytes(mandateName));
        uint48 targetVersion = packVersion(major, minor, patch);
        if (registry[nameHash][targetVersion].registeredAt == 0) return false;
        return registry[nameHash][targetVersion].isActive;
    }

    /// @notice Returns the highest registered version for a mandate name as (major, minor, patch).
    /// @dev Reads the last element of the ordered version list (guaranteed to be the latest by
    ///      _addVersion's strictly-increasing invariant) and unpacks it — the inverse of packVersion.
    ///      Reverts if the name has no registered versions. Note this ignores active status: the
    ///      latest version may itself be deactivated.
    function getLatestVersion(string calldata mandateName)
        external
        view
        returns (uint16 major, uint16 minor, uint16 patch)
    {
        bytes32 nameHash = keccak256(bytes(mandateName));
        uint48[] storage versions = mandateVersions[nameHash];
        if (versions.length == 0) revert("No versions registered for this mandate");

        // Unpack the last (highest) version: reverse of packVersion's bit layout.
        uint48 latestPacked = versions[versions.length - 1];
        major = uint16(latestPacked >> 32);
        minor = uint16((latestPacked >> 16) & 0xFFFF);
        patch = uint16(latestPacked & 0xFFFF);
    }

    //////////////////////////////////////////////////////////////
    //                   PAID TIER LOGIC                        //
    //////////////////////////////////////////////////////////////

    /// @notice Sets the global credit -> wei exchange rate.
    /// @dev Owner-only. Reprices every priced mandate at once (each mandate declares its own price in
    ///      credits) without touching individual mandates or existing prepaid balances.
    /// @param newWeiPerCredit How many wei one credit is worth.
    function setWeiPerCredit(uint256 newWeiPerCredit) external onlyOwner {
        weiPerCredit = newWeiPerCredit;
        emit WeiPerCreditSet(newWeiPerCredit);
    }

    /// @notice Sets the protocol fee in basis points (capped at MAX_FEE_BPS).
    function setFeeBps(uint16 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_FEE_BPS) revert FeeTooHigh(newFeeBps, MAX_FEE_BPS);
        feeBps = newFeeBps;
        emit FeeBpsSet(newFeeBps);
    }

    /// @notice Tops up an org's prepaid credit balance. Anyone can fund any org.
    /// @dev The single "pay one address, once" entry point. ETH stays in the registry to pay devs.
    /// @param org The org (Powers instance) whose balance is topped up.
    function buyCredits(address org) external payable {
        credits[org] += msg.value;
        emit CreditsPurchased(org, msg.sender, msg.value);
    }

    /// @notice Called by a mandate during its initializeMandate to enforce the whitelist and charge the org.
    /// @dev msg.sender is the mandate itself (trustless identity). Mutates only ledger state; never calls back
    /// into the mandate or Powers. Reverts for unregistered mandates (the mandatory whitelist gate).
    /// @param org The adopting Powers org (passed by the mandate as its own caller).
    function onAdopt(address org) external {
        // The caller is the mandate itself: msg.sender is a trustless identity that cannot be
        // spoofed, so no separate authorization of `mandate` is needed.
        address mandate = msg.sender;

        // Whitelist gate. This runs for every adoption, free or paid: an unregistered (or
        // deactivated) mandate can never be adopted, which is the core security guarantee.
        if (!_isMandateAddressActive(mandate)) revert NotRegistered(mandate);

        // The price is declared by the mandate itself (developer-controlled), in credits.
        // Free mandates report 0 and stop here — nothing to charge.
        uint256 priceCredits = IMandate(mandate).priceInCredits();
        if (priceCredits == 0) return;

        // Convert the developer's credit price to wei via the owner-set global rate. Guard against an
        // unset rate so a priced mandate never silently charges (and pays devs) zero.
        uint256 rate = weiPerCredit;
        if (rate == 0) revert ExchangeRateNotSet();
        uint256 costWei = priceCredits * rate;

        // Debit the org's prepaid balance (in wei). Adoption is atomic with the charge: if the org has
        // not pre-funded enough via buyCredits, the whole adoption reverts.
        uint256 available = credits[org];
        if (available < costWei) revert InsufficientCredits(org, costWei, available);
        credits[org] = available - costWei;

        // Developer payees are declared by the mandate too. A priced mandate must name at least one.
        address[] memory devs = IMandate(mandate).devs();
        if (devs.length == 0) revert NoDevs(mandate);

        // Skim the protocol fee to the owner, then split the remainder among the developer payees.
        uint256 fee = (costWei * feeBps) / 10_000;
        earnings[owner()] += fee;

        uint256 devPortion = costWei - fee;
        uint256 share = devPortion / devs.length; // Equal integer share per dev.
        uint256 remainder = devPortion - (share * devs.length); // Wei lost to integer division.
        for (uint256 i = 0; i < devs.length; i++) {
            earnings[devs[i]] += share;
        }
        // Any indivisible remainder wei goes to the first dev, so the split is exact to the wei.
        if (remainder > 0) earnings[devs[0]] += remainder;

        // All funds are now credited to the earnings ledger; recipients pull via withdrawEarnings.
        emit MandateCharged(mandate, org, costWei, fee);
    }

    /// @notice Withdraws the caller's accumulated earnings in ETH (pull pattern).
    function withdrawEarnings() external nonReentrant {
        uint256 amount = earnings[msg.sender];
        if (amount == 0) revert NothingToWithdraw();
        earnings[msg.sender] = 0;

        (bool success,) = payable(msg.sender).call{ value: amount }("");
        if (!success) revert EthTransferFailed();

        emit EarningsWithdrawn(msg.sender, amount);
    }
}
