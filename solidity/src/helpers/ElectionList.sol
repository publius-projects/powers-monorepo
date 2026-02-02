// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

// import { console2 } from "forge-std/console2.sol"; // remove before deploying.

/// @title ElectionList
/// @notice A contract to manage multiple elections with nominee nominations and voting functionality.
/// @author 7Cedars
contract ElectionList {
    // Election storage
    struct Election {
        address owner;
        uint48 startBlock;
        uint48 endBlock;
        string title;
    }
    mapping(uint256 electionId => Election) public elections;
    mapping(uint256 electionId => address[]) nominees;
    mapping(uint256 electionId => mapping(address nominee => bool)) nominated;
    mapping(uint256 electionId => mapping(address nominee => uint256)) votesCount;
    mapping(uint256 electionId => mapping(address voter => bool)) hasVoted;

    // Events
    event NominationReceived(uint256 indexed electionId, address indexed nominee);
    event NominationRevoked(uint256 indexed electionId, address indexed nominee);
    event ElectionCreated(uint256 indexed electionId, string title, uint48 startBlock, uint48 endBlock);
    event VoteCast(address indexed voter, address indexed nominee, uint256 indexed electionId);

    // Modifier
    // Note that this modifier doubles as a check that the election exists.
    modifier onlyOwner(uint256 electionId) {
        if (elections[electionId].owner != msg.sender) revert("Only election owner can call this function");
        _;
    }

    // constructor
    constructor() { }

    // Functions
    /// Create a new election
    /// @param title Title of the election.
    /// @param startBlock Block number at which the election starts.
    /// @param endBlock Block number at which the election ends.
    function createElection(string memory title, uint48 startBlock, uint48 endBlock) external returns (uint256) {
        uint256 electionId = uint256(keccak256(abi.encodePacked(msg.sender, title, startBlock, endBlock)));

        if (elections[electionId].owner != address(0)) revert("election already exists");
        if (startBlock == 0 || endBlock <= startBlock) revert("invalid start or end block");

        // initialise election
        elections[electionId] =
            Election({ owner: msg.sender, startBlock: startBlock, endBlock: endBlock, title: title });

        emit ElectionCreated(electionId, title, startBlock, endBlock);
        return electionId;
    }

    /// Nominate oneself for an election
    /// @param electionId ID of the election.
    /// @param caller Address of the nominee.
    function nominate(uint256 electionId, address caller) external onlyOwner(electionId) {
        Election storage currentElection = elections[electionId];

        if (nominated[electionId][caller]) revert("already nominated");
        if (block.number > currentElection.startBlock) revert("nomination not possible after election start");

        nominated[electionId][caller] = true;
        nominees[electionId].push(caller);

        emit NominationReceived(electionId, caller);
    }

    /// Revoke one's nomination for an election
    /// @param electionId ID of the election.
    /// @param caller Address of the nominee.
    function revokeNomination(uint256 electionId, address caller) external onlyOwner(electionId) {
        Election storage currentElection = elections[electionId];

        if (!nominated[electionId][caller]) revert("not nominated");
        if (block.number > currentElection.startBlock) revert("revocation not possible after election start");

        nominated[electionId][caller] = false;
        // remove from nominees (swap-and-pop)
        uint256 len = nominees[electionId].length;
        for (uint256 i; i < len; i++) {
            if (nominees[electionId][i] == caller) {
                nominees[electionId][i] = nominees[electionId][len - 1];
                nominees[electionId].pop();
                break;
            }
        }

        emit NominationRevoked(electionId, caller);
    }

    /// Vote for nominees in an election
    /// @param electionId ID of the election.
    /// @param caller Address of the voter.
    /// @param votes Boolean array indicating which nominees to vote for.
    function vote(uint256 electionId, address caller, bool[] calldata votes) external onlyOwner(electionId) {
        Election storage currentElection = elections[electionId];
        if (block.number < currentElection.startBlock || block.number > currentElection.endBlock) {
            revert("election closed");
        }
        if (hasVoted[electionId][caller]) revert("already voted");

        address[] memory nomineesForElection = nominees[electionId];
        if (votes.length != nomineesForElection.length) revert("votes array length mismatch");

        hasVoted[electionId][caller] = true;
        // Cast votes for each nominee where the corresponding boolean is true
        for (uint256 i; i < votes.length; i++) {
            if (votes[i]) {
                address nominee = nomineesForElection[i];
                votesCount[electionId][nominee] += 1;
                emit VoteCast(caller, nominee, electionId);
            }
        }
    }

    // --- View helpers ---
    function isElectionOpen(uint256 electionId) external view returns (bool) {
        Election storage currentElection = elections[electionId];
        return block.number >= currentElection.startBlock && block.number <= currentElection.endBlock;
    }

    function getElectionInfo(uint256 electionId) external view returns (Election memory) {
        return elections[electionId];
    }

    function getNominees(uint256 electionId) public view returns (address[] memory) {
        return nominees[electionId];
    }

    function getNomineeCount(uint256 electionId) external view returns (uint256) {
        return nominees[electionId].length;
    }

    function getVoteCount(uint256 electionId, address nominee) external view returns (uint256) {
        Election storage currentElection = elections[electionId];
        return votesCount[electionId][nominee];
    }

    function hasUserVoted(address voter, uint256 electionId) external view returns (bool) {
        Election storage currentElection = elections[electionId];
        return hasVoted[electionId][voter];
    }

    function getNomineeRanking(uint256 electionId)
        public
        view
        returns (address[] memory rankedNominees, uint256[] memory votes)
    {
        Election storage currentElection = elections[electionId];
        if (block.number >= currentElection.startBlock && block.number <= currentElection.endBlock) {
            revert("election still active");
        }

        (rankedNominees, votes) = getRankingAnyTime(electionId);
    }

    function getRankingAnyTime(uint256 electionId)
        public
        view
        returns (address[] memory rankedNominees, uint256[] memory votes)
    {
        Election storage currentElection = elections[electionId];
        uint256 numNominees = getNominees(electionId).length;
        if (numNominees == 0) return (new address[](0), new uint256[](0));

        rankedNominees = new address[](numNominees);
        votes = new uint256[](numNominees);

        // Copy nominees and their votes
        for (uint256 i; i < numNominees; i++) {
            rankedNominees[i] = nominees[electionId][i];
            votes[i] = votesCount[electionId][nominees[electionId][i]];
        }

        // Simple bubble sort by vote count (descending)
        for (uint256 i; i < numNominees - 1; i++) {
            for (uint256 j; j < numNominees - i - 1; j++) {
                if (votes[j] < votes[j + 1]) {
                    // Swap votes
                    uint256 tempVotes = votes[j];
                    votes[j] = votes[j + 1];
                    votes[j + 1] = tempVotes;

                    // Swap nominees
                    address tempNominee = rankedNominees[j];
                    rankedNominees[j] = rankedNominees[j + 1];
                    rankedNominees[j + 1] = tempNominee;
                }
            }
        }

        return (rankedNominees, votes);
    }
}
