// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

/// @notice Helper function to compute the address of a contract deployed via CREATE2
/// @param deployer The address of the contract deployer
/// @param salt The salt used for deterministic address computation
/// @param bytecodeHash The keccak256 hash of the contract creation code
/// @return The computed address
function computeAddress(address deployer, bytes32 salt, bytes32 bytecodeHash) pure returns (address) {
    return address(uint160(uint256(keccak256(abi.encodePacked(
        bytes1(0xff),
        deployer,
        salt,
        bytecodeHash
    )))));
}

// A: OnchainIdRegistryMock
/// @title OnchainIdRegistryMock
/// @notice Mock implementation of an OnChainID registry for testing purposes
/// @dev Stores identity data mapped by onChainId
contract OnchainIdRegistryMock {
    struct IdentityData {
        string name;
        uint16 countryId;
        bool kycVerified;
        bool isPoliticallyExposed;
    }

    /// @notice Mapping from onChainId to IdentityData
    mapping(uint256 => IdentityData) public identities;

    /// @notice Sets the identity data for a given onChainId
    /// @param onChainId The unique identifier for the identity
    /// @param name The name associated with the identity
    /// @param countryId The country ID
    /// @param kycVerified Boolean indicating if KYC is verified
    /// @param isPoliticallyExposed Boolean indicating if the identity is politically exposed
    function setIdentity(
        uint256 onChainId,
        string memory name,
        uint16 countryId,
        bool kycVerified,
        bool isPoliticallyExposed
    ) external {
        identities[onChainId] = IdentityData({
            name: name,
            countryId: countryId,
            kycVerified: kycVerified,
            isPoliticallyExposed: isPoliticallyExposed
        });
    }

    /// @notice Retrieves the identity data for a given onChainId
    /// @param onChainId The unique identifier to query
    /// @return The IdentityData struct
    function getIdentity(uint256 onChainId) external view returns (IdentityData memory) {
        return identities[onChainId];
    }
}

// B: IdentityRegistryMock
/// @title IdentityRegistryMock
/// @notice Mock implementation of an Identity Registry for testing purposes
/// @dev Manages wallet linkages and proposals for adding/removing wallets
contract IdentityRegistryMock {
    struct Proposal {
        address targetWallet;
        bool isAdding; // true for add, false for remove
        uint256 approvalCount;
        mapping(address => bool) hasApproved;
        bool executed;
    }

    // onChainId => list of wallets
    mapping(uint256 => address[]) private _wallets;
    // onChainId => threshold
    mapping(uint256 => uint256) public thresholds;
    // wallet => onChainId
    mapping(address => uint256) public walletToOnChainId;
    
    // onChainId => list of proposals
    mapping(uint256 => Proposal[]) public proposals;

    event WalletLinked(uint256 indexed onChainId, address indexed wallet);
    event WalletRemoved(uint256 indexed onChainId, address indexed wallet);
    event ProposalCreated(uint256 indexed onChainId, uint256 proposalId, address target, bool isAdding);
    event ProposalExecuted(uint256 indexed onChainId, uint256 proposalId);

    /// @notice Registers an identity with initial wallets and a threshold
    /// @param onChainId The unique identifier for the identity
    /// @param initialWallets The list of initial wallet addresses
    /// @param threshold The approval threshold for changes
    function registerIdentity(uint256 onChainId, address[] memory initialWallets, uint256 threshold) external {
        require(_wallets[onChainId].length == 0, "Already registered");
        require(initialWallets.length >= threshold, "Invalid threshold");
        require(threshold > 0, "Threshold must be > 0");

        thresholds[onChainId] = threshold;
        for (uint256 i = 0; i < initialWallets.length; i++) {
            _addWallet(onChainId, initialWallets[i]);
        }
    }

    function _addWallet(uint256 onChainId, address wallet) internal {
        require(walletToOnChainId[wallet] == 0, "Wallet already linked");
        walletToOnChainId[wallet] = onChainId;
        _wallets[onChainId].push(wallet);
        emit WalletLinked(onChainId, wallet);
    }

    function _removeWallet(uint256 onChainId, address wallet) internal {
        require(walletToOnChainId[wallet] == onChainId, "Wallet not linked to this ID");
        
        address[] storage wallets = _wallets[onChainId];
        for (uint256 i = 0; i < wallets.length; i++) {
            if (wallets[i] == wallet) {
                wallets[i] = wallets[wallets.length - 1];
                wallets.pop();
                break;
            }
        }
        delete walletToOnChainId[wallet];
        emit WalletRemoved(onChainId, wallet);
    }

    /// @notice Returns the list of wallets linked to an onChainId
    /// @param onChainId The identity identifier
    /// @return An array of wallet addresses
    function getWallets(uint256 onChainId) external view returns (address[] memory) {
        return _wallets[onChainId];
    }

    /// @notice Proposes adding or removing a wallet
    /// @param onChainId The identity identifier
    /// @param targetWallet The wallet to add or remove
    /// @param isAdding True to add, false to remove
    /// @return proposalId The ID of the created proposal
    function proposeWalletChange(uint256 onChainId, address targetWallet, bool isAdding) external returns (uint256) {
        require(walletToOnChainId[msg.sender] == onChainId, "Not a member");
        
        uint256 proposalId = proposals[onChainId].length;
        proposals[onChainId].push();
        Proposal storage p = proposals[onChainId][proposalId];
        p.targetWallet = targetWallet;
        p.isAdding = isAdding;
        p.approvalCount = 0; 
        
        // Auto-approve by proposer
        p.hasApproved[msg.sender] = true;
        p.approvalCount = 1;

        emit ProposalCreated(onChainId, proposalId, targetWallet, isAdding);
        
        // Try execute immediately if threshold met
        if (p.approvalCount >= thresholds[onChainId]) {
            _executeProposal(onChainId, p);
        }

        return proposalId;
    }

    /// @notice Approves an existing proposal
    /// @param onChainId The identity identifier
    /// @param proposalId The ID of the proposal to approve
    function approveProposal(uint256 onChainId, uint256 proposalId) external {
        require(walletToOnChainId[msg.sender] == onChainId, "Not a member");
        Proposal storage p = proposals[onChainId][proposalId];
        require(!p.executed, "Already executed");
        require(!p.hasApproved[msg.sender], "Already approved");

        p.hasApproved[msg.sender] = true;
        p.approvalCount++;

        if (p.approvalCount >= thresholds[onChainId]) {
            _executeProposal(onChainId, p);
        }
    }

    function _executeProposal(uint256 onChainId, Proposal storage p) internal {
        p.executed = true;
        if (p.isAdding) {
            _addWallet(onChainId, p.targetWallet);
        } else {
            require(_wallets[onChainId].length > thresholds[onChainId], "Cannot remove: threshold violation"); 
            _removeWallet(onChainId, p.targetWallet);
        }
        emit ProposalExecuted(onChainId, 0);
    }
}

// C: ComplianceRegistryMock
/// @title ComplianceRegistryMock
/// @notice Mock implementation of a Compliance Registry for testing purposes
/// @dev Enforces rules such as KYC, country restrictions, and supply limits
contract ComplianceRegistryMock {
    struct ComplianceChecks {
        uint256 maxTotalSupply; // 0 for unlimited
        uint256 maxPerAccount;  // 0 for unlimited
        bool kycRequired;
        bool noPoliticallyExposed;
        bool useCountryAllowlist;
        bool useCountryBlocklist;
    }

    mapping(uint256 => ComplianceChecks) public tokenChecks;
    mapping(uint256 => mapping(uint16 => bool)) public countryAllowlist;
    mapping(uint256 => mapping(uint16 => bool)) public countryBlocklist;

    IdentityRegistryMock public identityRegistry;
    OnchainIdRegistryMock public onchainIdRegistry;

    /// @notice Constructor locates dependencies based on the deployer's address and deterministic salts
    /// @dev Assumes IdentityRegistryMock and OnchainIdRegistryMock are deployed by the same factory/deployer
    constructor() {
        address deployer = msg.sender;

        // IdentityRegistryMock
        bytes32 saltIdentity = keccak256(bytes("IdentityRegistryMock"));
        address identityAddress = computeAddress(deployer, saltIdentity, keccak256(type(IdentityRegistryMock).creationCode));
        // Note: We expect the deployer to have deployed this already. We do not self-deploy to ensure correct address linkage.
        identityRegistry = IdentityRegistryMock(identityAddress);

        // OnchainIdRegistryMock
        bytes32 saltOnchain = keccak256(bytes("OnchainIdRegistryMock"));
        address onchainAddress = computeAddress(deployer, saltOnchain, keccak256(type(OnchainIdRegistryMock).creationCode));
        onchainIdRegistry = OnchainIdRegistryMock(onchainAddress);
    }

    /// @notice Configures compliance checks for a specific token
    /// @param tokenId The token identifier
    /// @param maxTotalSupply Maximum total supply (0 for unlimited)
    /// @param maxPerAccount Maximum balance per account (0 for unlimited)
    /// @param kycRequired True if KYC is required
    /// @param noPoliticallyExposed True if politically exposed persons are banned
    /// @param useCountryAllowlist True to enforce country allowlist
    /// @param useCountryBlocklist True to enforce country blocklist
    function setComplianceChecks(
        uint256 tokenId, 
        uint256 maxTotalSupply, 
        uint256 maxPerAccount, 
        bool kycRequired, 
        bool noPoliticallyExposed,
        bool useCountryAllowlist,
        bool useCountryBlocklist
    ) external {
        tokenChecks[tokenId] = ComplianceChecks({
            maxTotalSupply: maxTotalSupply,
            maxPerAccount: maxPerAccount,
            kycRequired: kycRequired,
            noPoliticallyExposed: noPoliticallyExposed,
            useCountryAllowlist: useCountryAllowlist,
            useCountryBlocklist: useCountryBlocklist
        });
    }

    /// @notice Sets the status of countries in the allowlist for a token
    /// @param tokenId The token identifier
    /// @param countries Array of country IDs
    /// @param status The status to set (true for allowed)
    function setCountryAllowlist(uint256 tokenId, uint16[] memory countries, bool status) external {
        for (uint256 i = 0; i < countries.length; i++) {
            countryAllowlist[tokenId][countries[i]] = status;
        }
    }

    /// @notice Sets the status of countries in the blocklist for a token
    /// @param tokenId The token identifier
    /// @param countries Array of country IDs
    /// @param status The status to set (true for blocked)
    function setCountryBlocklist(uint256 tokenId, uint16[] memory countries, bool status) external {
        for (uint256 i = 0; i < countries.length; i++) {
            countryBlocklist[tokenId][countries[i]] = status;
        }
    }

    /// @notice Checks if a transfer complies with the configured rules
    /// @param tokenId The token identifier
    /// @param from The sender address
    /// @param to The recipient address
    /// @param amount The amount being transferred
    /// @param currentToBalance The current balance of the recipient
    /// @param currentTotalSupply The current total supply of the token
    /// @return True if the transfer is allowed, false otherwise
    function checkTransfer(
        uint256 tokenId,
        address from,
        address to,
        uint256 amount,
        uint256 currentToBalance,
        uint256 currentTotalSupply
    ) external view returns (bool) {
        ComplianceChecks memory checks = tokenChecks[tokenId];

        // 1. Max Total Supply (only on mint)
        if (from == address(0)) {
            if (checks.maxTotalSupply > 0 && currentTotalSupply + amount > checks.maxTotalSupply) {
                return false;
            }
        }

        // 2. Max Per Account
        if (to != address(0)) {
            if (checks.maxPerAccount > 0 && currentToBalance + amount > checks.maxPerAccount) {
                return false;
            }
            
            // Check Identity
            uint256 onChainId = identityRegistry.walletToOnChainId(to);
            
            bool needsIdentity = checks.kycRequired || checks.noPoliticallyExposed || checks.useCountryAllowlist || checks.useCountryBlocklist;
            
            if (needsIdentity) {
                if (onChainId == 0) return false; // Must have identity
                
                OnchainIdRegistryMock.IdentityData memory data = onchainIdRegistry.getIdentity(onChainId);

                if (checks.kycRequired && !data.kycVerified) return false;
                if (checks.noPoliticallyExposed && data.isPoliticallyExposed) return false;
                if (checks.useCountryAllowlist && !countryAllowlist[tokenId][data.countryId]) return false;
                if (checks.useCountryBlocklist && countryBlocklist[tokenId][data.countryId]) return false;
            }
        }
        return true;
    }
}

// D: RwaMock
/// @title RwaMock
/// @notice Mock implementation of an RWA token (ERC1155) for testing purposes
/// @dev Integrates with Compliance, Identity, and OnChainID registries
contract RwaMock is ERC1155 {
    OnchainIdRegistryMock public onchainIdRegistry;
    IdentityRegistryMock public identityRegistry;
    ComplianceRegistryMock public complianceRegistry;

    mapping(string => uint256) public nameToId;
    mapping(uint256 => string) public idToName;
    mapping(uint256 => uint256) public totalSupply;

    /// @notice Constructor locates dependencies based on the deployer's address and deterministic salts
    /// @dev Assumes all registries are deployed by the same factory/deployer
    constructor() ERC1155("") {
        address deployer = msg.sender;

        // OnchainIdRegistryMock
        bytes32 saltOnchain = keccak256(bytes("OnchainIdRegistryMock"));
        address onchainAddress = computeAddress(deployer, saltOnchain, keccak256(type(OnchainIdRegistryMock).creationCode));
        onchainIdRegistry = OnchainIdRegistryMock(onchainAddress);

        // IdentityRegistryMock
        bytes32 saltIdentity = keccak256(bytes("IdentityRegistryMock"));
        address identityAddress = computeAddress(deployer, saltIdentity, keccak256(type(IdentityRegistryMock).creationCode));
        identityRegistry = IdentityRegistryMock(identityAddress);

        // ComplianceRegistryMock
        bytes32 saltCompliance = keccak256(bytes("ComplianceRegistryMock"));
        address complianceAddress = computeAddress(deployer, saltCompliance, keccak256(type(ComplianceRegistryMock).creationCode));
        complianceRegistry = ComplianceRegistryMock(complianceAddress);
    }

    /// @notice Creates a new token ID for a given name
    /// @param name The name of the token
    /// @return tokenId The generated token ID
    function createToken(string memory name) external returns (uint256) {
        uint256 tokenId = uint256(keccak256(abi.encodePacked(name)));
        if (bytes(idToName[tokenId]).length == 0) {
            nameToId[name] = tokenId;
            idToName[tokenId] = name;
        } else {
            revert("Token already exists");
        }
        return tokenId;
    }

    /// @notice Mints tokens to a recipient, subject to compliance checks
    /// @param to The recipient address
    /// @param tokenId The token ID to mint
    /// @param amount The amount to mint
    function mint(address to, uint256 tokenId, uint256 amount) external {
        require(bytes(idToName[tokenId]).length > 0, "Token not created");

        require(complianceRegistry.checkTransfer(
            tokenId, 
            address(0), 
            to, 
            amount, 
            balanceOf(to, tokenId), 
            totalSupply[tokenId]
        ), "Compliance check failed");

        totalSupply[tokenId] += amount;
        _mint(to, tokenId, amount, "");
    }

    /// @notice Forces a transfer between addresses (bypassing some sender checks but simulating intervention)
    /// @param from The sender address
    /// @param to The recipient address
    /// @param tokenId The token ID
    /// @param amount The amount to transfer
    function forceTransfer(address from, address to, uint256 tokenId, uint256 amount) external {
        // Force transfer bypasses sender checks, but could still perform checks on receiver.
        // For this mock, we skip compliance checks to simulate intervention.
        _safeTransferFrom(from, to, tokenId, amount, "");
    }

    /// @notice Safely transfers tokens, enforcing compliance checks
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data) public override {
        require(complianceRegistry.checkTransfer(
            id, 
            from, 
            to, 
            amount, 
            balanceOf(to, id), 
            totalSupply[id]
        ), "Compliance check failed");
        
        super.safeTransferFrom(from, to, id, amount, data);
    }

    /// @notice Safely batch transfers tokens, enforcing compliance checks
    function safeBatchTransferFrom(address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) public override {
        for (uint256 i = 0; i < ids.length; i++) {
             require(complianceRegistry.checkTransfer(
                ids[i], 
                from, 
                to, 
                amounts[i], 
                balanceOf(to, ids[i]), 
                totalSupply[ids[i]]
            ), "Compliance check failed");
        }
        super.safeBatchTransferFrom(from, to, ids, amounts, data);
    }
}

// E: FactoryRwaMock
/// @title FactoryRwaMock
/// @notice Factory contract to deploy the RWA mock ecosystem in the correct order using CREATE2
contract FactoryRwaMock {
    event Deployed(string name, address addr);

    /// @notice Deploys all mock contracts in the correct dependency order
    function deploy() external {
        address addr;
        bytes32 salt;
        
        // 1. OnchainIdRegistryMock
        salt = keccak256(bytes("OnchainIdRegistryMock"));
        addr = computeAddress(address(this), salt, keccak256(type(OnchainIdRegistryMock).creationCode));
        if (addr.code.length == 0) {
            new OnchainIdRegistryMock{salt: salt}();
            emit Deployed("OnchainIdRegistryMock", addr);
        }

        // 2. IdentityRegistryMock
        salt = keccak256(bytes("IdentityRegistryMock"));
        addr = computeAddress(address(this), salt, keccak256(type(IdentityRegistryMock).creationCode));
        if (addr.code.length == 0) {
            new IdentityRegistryMock{salt: salt}();
            emit Deployed("IdentityRegistryMock", addr);
        }

        // 3. ComplianceRegistryMock
        salt = keccak256(bytes("ComplianceRegistryMock"));
        addr = computeAddress(address(this), salt, keccak256(type(ComplianceRegistryMock).creationCode));
        if (addr.code.length == 0) {
            new ComplianceRegistryMock{salt: salt}();
            emit Deployed("ComplianceRegistryMock", addr);
        }

        // 4. RwaMock
        salt = keccak256(bytes("RwaMock"));
        addr = computeAddress(address(this), salt, keccak256(type(RwaMock).creationCode));
        if (addr.code.length == 0) {
            new RwaMock{salt: salt}();
            emit Deployed("RwaMock", addr);
        }
    }
}
