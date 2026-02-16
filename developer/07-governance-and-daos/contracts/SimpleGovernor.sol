// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {GovernanceToken} from "./GovernanceToken.sol";

/// @title SimpleGovernor
/// @notice Simplified on-chain governance contract with proposals, voting, and timelock
/// @dev Implements: propose -> vote -> execute (with timelock delay)
contract SimpleGovernor {
    // =========================================================================
    // Types
    // =========================================================================

    enum ProposalState {
        Pending,    // 0 - Created, waiting for voting delay
        Active,     // 1 - Voting is open
        Defeated,   // 2 - Failed (no quorum or more against)
        Succeeded,  // 3 - Passed, waiting for timelock
        Executed    // 4 - Executed
    }

    struct Proposal {
        address proposer;
        uint256 startBlock;       // Block when voting starts (creation + votingDelay)
        uint256 endBlock;         // Block when voting ends (startBlock + votingPeriod)
        uint256 timelockEnd;      // Block after which execution is allowed (endBlock + timelockDelay)
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        bool executed;
        // Execution data
        address[] targets;
        uint256[] values;
        bytes[] calldatas;
        string description;
        // Snapshot of total supply at proposal creation for quorum calculation
        uint256 snapshotTotalSupply;
    }

    // =========================================================================
    // State
    // =========================================================================

    GovernanceToken public immutable token;

    /// @notice Number of blocks to wait before voting starts
    uint256 public votingDelay;

    /// @notice Number of blocks the voting period lasts
    uint256 public votingPeriod;

    /// @notice Number of blocks to wait after voting ends before execution
    uint256 public timelockDelay;

    /// @notice Quorum percentage in basis points (e.g., 400 = 4%)
    uint256 public quorumBps;

    uint256 public proposalCount;

    mapping(uint256 => Proposal) public proposals;

    /// @notice proposalId => voter => hasVoted
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    // =========================================================================
    // Events
    // =========================================================================

    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        address[] targets,
        uint256[] values,
        bytes[] calldatas,
        string description,
        uint256 startBlock,
        uint256 endBlock
    );

    event VoteCast(
        address indexed voter,
        uint256 indexed proposalId,
        uint8 support,
        uint256 weight
    );

    event ProposalExecuted(uint256 indexed proposalId);

    // =========================================================================
    // Errors
    // =========================================================================

    error InvalidProposal();
    error ProposalNotActive();
    error ProposalNotSucceeded();
    error ProposalNotReady();
    error AlreadyVoted();
    error NoVotingPower();
    error InvalidVoteType();
    error ProposalAlreadyExecuted();
    error ExecutionFailed();
    error ArrayLengthMismatch();

    // =========================================================================
    // Constructor
    // =========================================================================

    /// @param _token Address of the GovernanceToken
    /// @param _votingDelay Blocks to wait before voting starts
    /// @param _votingPeriod Blocks the voting period lasts
    /// @param _timelockDelay Blocks to wait after voting before execution
    /// @param _quorumBps Quorum as basis points of total supply (e.g., 400 = 4%)
    constructor(
        address _token,
        uint256 _votingDelay,
        uint256 _votingPeriod,
        uint256 _timelockDelay,
        uint256 _quorumBps
    ) {
        token = GovernanceToken(_token);
        votingDelay = _votingDelay;
        votingPeriod = _votingPeriod;
        timelockDelay = _timelockDelay;
        quorumBps = _quorumBps;
    }

    // =========================================================================
    // Proposal Functions
    // =========================================================================

    /// @notice Create a new proposal
    /// @param targets Array of target addresses for calls
    /// @param values Array of ETH values for each call
    /// @param calldatas Array of calldata for each call
    /// @param description Human-readable description of the proposal
    /// @return proposalId The ID of the created proposal
    function propose(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas,
        string calldata description
    ) external returns (uint256 proposalId) {
        if (targets.length == 0) revert InvalidProposal();
        if (targets.length != values.length || targets.length != calldatas.length) {
            revert ArrayLengthMismatch();
        }

        proposalId = ++proposalCount;

        uint256 startBlock = block.number + votingDelay;
        uint256 endBlock = startBlock + votingPeriod;
        uint256 timelockEnd = endBlock + timelockDelay;

        Proposal storage p = proposals[proposalId];
        p.proposer = msg.sender;
        p.startBlock = startBlock;
        p.endBlock = endBlock;
        p.timelockEnd = timelockEnd;
        p.targets = targets;
        p.values = values;
        p.calldatas = calldatas;
        p.description = description;
        p.snapshotTotalSupply = token.totalSupply();

        emit ProposalCreated(
            proposalId,
            msg.sender,
            targets,
            values,
            calldatas,
            description,
            startBlock,
            endBlock
        );
    }

    /// @notice Cast a vote on a proposal
    /// @param proposalId The ID of the proposal
    /// @param support Vote type: 0 = Against, 1 = For, 2 = Abstain
    function vote(uint256 proposalId, uint8 support) external {
        if (state(proposalId) != ProposalState.Active) revert ProposalNotActive();
        if (hasVoted[proposalId][msg.sender]) revert AlreadyVoted();
        if (support > 2) revert InvalidVoteType();

        uint256 weight = token.getVotes(msg.sender);
        if (weight == 0) revert NoVotingPower();

        hasVoted[proposalId][msg.sender] = true;

        Proposal storage p = proposals[proposalId];
        if (support == 0) {
            p.againstVotes += weight;
        } else if (support == 1) {
            p.forVotes += weight;
        } else {
            p.abstainVotes += weight;
        }

        emit VoteCast(msg.sender, proposalId, support, weight);
    }

    /// @notice Execute a succeeded proposal after the timelock delay
    /// @param proposalId The ID of the proposal to execute
    function execute(uint256 proposalId) external {
        ProposalState currentState = state(proposalId);
        if (currentState != ProposalState.Succeeded) revert ProposalNotSucceeded();

        Proposal storage p = proposals[proposalId];
        if (block.number < p.timelockEnd) revert ProposalNotReady();

        p.executed = true;

        for (uint256 i = 0; i < p.targets.length; i++) {
            (bool success,) = p.targets[i].call{value: p.values[i]}(p.calldatas[i]);
            if (!success) revert ExecutionFailed();
        }

        emit ProposalExecuted(proposalId);
    }

    // =========================================================================
    // View Functions
    // =========================================================================

    /// @notice Get the current state of a proposal
    /// @param proposalId The ID of the proposal
    /// @return The current ProposalState
    function state(uint256 proposalId) public view returns (ProposalState) {
        Proposal storage p = proposals[proposalId];
        if (p.startBlock == 0) revert InvalidProposal();

        if (p.executed) return ProposalState.Executed;

        if (block.number < p.startBlock) return ProposalState.Pending;

        if (block.number <= p.endBlock) return ProposalState.Active;

        // Voting ended - check results
        uint256 quorumRequired = (p.snapshotTotalSupply * quorumBps) / 10000;
        uint256 totalVotes = p.forVotes + p.againstVotes + p.abstainVotes;

        if (totalVotes < quorumRequired || p.forVotes <= p.againstVotes) {
            return ProposalState.Defeated;
        }

        return ProposalState.Succeeded;
    }

    /// @notice Get the quorum required for a proposal
    /// @param proposalId The ID of the proposal
    /// @return The number of votes required for quorum
    function quorum(uint256 proposalId) external view returns (uint256) {
        return (proposals[proposalId].snapshotTotalSupply * quorumBps) / 10000;
    }

    /// @notice Get the vote counts for a proposal
    /// @param proposalId The ID of the proposal
    /// @return forVotes Number of votes in favor
    /// @return againstVotes Number of votes against
    /// @return abstainVotes Number of abstaining votes
    function proposalVotes(uint256 proposalId)
        external
        view
        returns (uint256 forVotes, uint256 againstVotes, uint256 abstainVotes)
    {
        Proposal storage p = proposals[proposalId];
        return (p.forVotes, p.againstVotes, p.abstainVotes);
    }
}
