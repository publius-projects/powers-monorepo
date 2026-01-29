// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

// A: OnchainIdRegistryMock
contract OnchainIdRegistryMock {
    struct IdentityData {
        string name;
        uint16 countryId;
        bool kycVerified;
        bool isPoliticallyExposed;
    }

    mapping(uint256 => IdentityData) public identities;

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

    function getIdentity(uint256 onChainId) external view returns (IdentityData memory) {
        return identities[onChainId];
    }
}

// B: IdentityRegistryMock
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

    function getWallets(uint256 onChainId) external view returns (address[] memory) {
        return _wallets[onChainId];
    }

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

    constructor(address _identityRegistry, address _onchainIdRegistry) {
        identityRegistry = IdentityRegistryMock(_identityRegistry);
        onchainIdRegistry = OnchainIdRegistryMock(_onchainIdRegistry);
    }

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

    function setCountryAllowlist(uint256 tokenId, uint16[] memory countries, bool status) external {
        for (uint256 i = 0; i < countries.length; i++) {
            countryAllowlist[tokenId][countries[i]] = status;
        }
    }

    function setCountryBlocklist(uint256 tokenId, uint16[] memory countries, bool status) external {
        for (uint256 i = 0; i < countries.length; i++) {
            countryBlocklist[tokenId][countries[i]] = status;
        }
    }

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
contract RwaMock is ERC1155 {
    OnchainIdRegistryMock public onchainIdRegistry;
    IdentityRegistryMock public identityRegistry;
    ComplianceRegistryMock public complianceRegistry;

    mapping(string => uint256) public nameToId;
    mapping(uint256 => string) public idToName;
    mapping(uint256 => uint256) public totalSupply;

    constructor(address _onchainIdRegistry, address _identityRegistry, address _complianceRegistry) ERC1155("") {
        onchainIdRegistry = OnchainIdRegistryMock(_onchainIdRegistry);
        identityRegistry = IdentityRegistryMock(_identityRegistry);
        complianceRegistry = ComplianceRegistryMock(_complianceRegistry);
    }

    function createToken(string memory name) external returns (uint256) {
        uint256 tokenId = uint256(keccak256(abi.encodePacked(name)));
        if (bytes(idToName[tokenId]).length == 0) {
            nameToId[name] = tokenId;
            idToName[tokenId] = name;
        }
        return tokenId;
    }

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

    function forceTransfer(address from, address to, uint256 tokenId, uint256 amount) external {
        // Force transfer bypasses sender checks, but could still perform checks on receiver.
        // For this mock, we skip compliance checks to simulate intervention.
        _safeTransferFrom(from, to, tokenId, amount, "");
    }

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
