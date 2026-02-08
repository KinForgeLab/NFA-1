// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../interfaces/INFA1Core.sol";

/// @title MinimalNFA - Tier 1 Minimum Viable NFA Reference Implementation
/// @author NFA-1 Standard Authors
/// @notice Reference implementation of INFA1Core for educational and testing purposes
/// @dev Satisfies all Tier 1 (C-01 – C-12) compliance checklist items.
///      Also includes Tier 2 (Learning) and Tier 3 (Action Execution) for completeness.
///
///      This contract is intentionally minimal. Production implementations should add:
///      - Role-based access control (e.g. OpenZeppelin AccessControl)
///      - Upgradeability if desired (UUPS, Transparent Proxy, Diamond, etc.)
///      - Optional extensions (Lineage, Payment, Identity, Receipts, etc.)
///      - Gas-optimized storage packing
///
///      Data classification (per NFA-1 spec):
///      - On-Chain: State, Status, balance, logicAddress, learningRoot, learningVersion
///      - Verifiably On-Chain: vaultHash (hash on-chain, data off-chain)
///      - Off-Chain: vaultURI contents, persona details, animation assets
contract MinimalNFA is ERC721, ReentrancyGuard, INFA1Core {

    // ======================== STORAGE ========================

    mapping(uint256 => State) private _states;
    mapping(uint256 => AgentMetadata) private _agentMetadata;
    mapping(uint256 => LearningState) private _learningStates;
    mapping(uint256 => address) private _learningUpdaters;

    uint256 private _nextTokenId = 1;

    /// @notice Maximum gas forwarded to logic contracts during executeAction
    uint256 public constant ACTION_GAS_LIMIT = 500_000;

    // ======================== ERRORS ========================

    error NotOwnerOrApproved();
    error AgentNotActive();
    error AgentTerminated();
    error AgentDoesNotExist();
    error NoLogicContract();
    error ActionFailed();
    error NotActive();
    error NotPaused();
    error AlreadyTerminated();
    error LearningNotEnabled();
    error VersionMustIncrease();
    error NotLearningAuthorized();
    error ZeroFunding();
    error InsufficientGas();

    // ======================== MODIFIERS ========================

    modifier onlyOwnerOrApproved(uint256 tokenId) {
        if (!_isCallerOwnerOrApproved(tokenId)) revert NotOwnerOrApproved();
        _;
    }

    modifier whenActive(uint256 tokenId) {
        if (_states[tokenId].status != Status.Active) revert AgentNotActive();
        _;
    }

    modifier whenNotTerminated(uint256 tokenId) {
        if (_states[tokenId].status == Status.Terminated) revert AgentTerminated();
        _;
    }

    modifier exists(uint256 tokenId) {
        if (_ownerOf(tokenId) == address(0)) revert AgentDoesNotExist();
        _;
    }

    // ======================== CONSTRUCTOR ========================

    constructor() ERC721("MinimalNFA", "NFA") {}

    // ======================== MINTING ========================

    /// @notice Mint a new NFA agent
    /// @dev In production, add access control (onlyMinter, max supply, etc.)
    /// @param to Recipient address
    /// @param metadata Initial agent metadata (persona, experience, vault, etc.)
    /// @param enableLearning Whether to enable learning from mint
    /// @return tokenId The minted token ID
    function mint(
        address to,
        AgentMetadata calldata metadata,
        bool enableLearning
    ) external returns (uint256 tokenId) {
        tokenId = _nextTokenId++;
        _mint(to, tokenId);

        _states[tokenId] = State({
            balance: 0,
            status: Status.Active,
            owner: to,
            logicAddress: address(0),
            lastActionTimestamp: 0
        });

        _agentMetadata[tokenId] = metadata;
        _learningStates[tokenId].learningEnabled = enableLearning;

        emit StatusChanged(tokenId, Status.Active);
    }

    // ======================== ACTION EXECUTION (Tier 3) ========================

    /// @inheritdoc INFA1Core
    function executeAction(uint256 tokenId, bytes calldata data)
        external
        nonReentrant
        onlyOwnerOrApproved(tokenId)
        whenActive(tokenId)
        returns (bytes memory result)
    {
        address logic = _states[tokenId].logicAddress;
        if (logic == address(0)) revert NoLogicContract();

        _states[tokenId].lastActionTimestamp = block.timestamp;

        // Forward call with capped gas to prevent griefing
        if (gasleft() <= 10_000) revert InsufficientGas();
        uint256 gasToForward = gasleft() > ACTION_GAS_LIMIT + 10_000
            ? ACTION_GAS_LIMIT
            : gasleft() - 10_000;

        (bool success, bytes memory returnData) = logic.call{gas: gasToForward}(data);
        if (!success) revert ActionFailed();

        emit ActionExecuted(tokenId, returnData);
        return returnData;
    }

    /// @inheritdoc INFA1Core
    function setLogicAddress(uint256 tokenId, address newLogic)
        external
        onlyOwnerOrApproved(tokenId)
        whenNotTerminated(tokenId)
    {
        address oldLogic = _states[tokenId].logicAddress;
        _states[tokenId].logicAddress = newLogic;
        emit LogicUpgraded(tokenId, oldLogic, newLogic);
    }

    // ======================== FUNDING ========================

    /// @inheritdoc INFA1Core
    function fundAgent(uint256 tokenId) external payable exists(tokenId) {
        if (msg.value == 0) revert ZeroFunding();
        _states[tokenId].balance += msg.value;
        emit AgentFunded(tokenId, msg.sender, msg.value);
    }

    // ======================== LIFECYCLE ========================

    /// @inheritdoc INFA1Core
    function pause(uint256 tokenId)
        external
        onlyOwnerOrApproved(tokenId)
    {
        if (_states[tokenId].status != Status.Active) revert NotActive();
        _states[tokenId].status = Status.Paused;
        emit StatusChanged(tokenId, Status.Paused);
    }

    /// @inheritdoc INFA1Core
    function unpause(uint256 tokenId)
        external
        onlyOwnerOrApproved(tokenId)
    {
        if (_states[tokenId].status != Status.Paused) revert NotPaused();
        _states[tokenId].status = Status.Active;
        emit StatusChanged(tokenId, Status.Active);
    }

    /// @inheritdoc INFA1Core
    /// @dev Sets learningEnabled = false to prevent post-termination updates
    function terminate(uint256 tokenId)
        external
        onlyOwnerOrApproved(tokenId)
    {
        if (_states[tokenId].status == Status.Terminated) revert AlreadyTerminated();
        _states[tokenId].status = Status.Terminated;
        _learningStates[tokenId].learningEnabled = false;
        emit StatusChanged(tokenId, Status.Terminated);
    }

    // ======================== STATE QUERIES ========================

    /// @inheritdoc INFA1Core
    function getState(uint256 tokenId) external view exists(tokenId) returns (State memory) {
        State memory state = _states[tokenId];
        state.owner = ownerOf(tokenId); // Always reflect current ERC-721 owner
        return state;
    }

    /// @inheritdoc INFA1Core
    function getAgentMetadata(uint256 tokenId)
        external view exists(tokenId) returns (AgentMetadata memory)
    {
        return _agentMetadata[tokenId];
    }

    /// @inheritdoc INFA1Core
    function getLearningState(uint256 tokenId)
        external view exists(tokenId) returns (LearningState memory)
    {
        return _learningStates[tokenId];
    }

    // ======================== METADATA ========================

    /// @inheritdoc INFA1Core
    function updateAgentMetadata(
        uint256 tokenId,
        AgentMetadata calldata metadata
    )
        external
        onlyOwnerOrApproved(tokenId)
        whenNotTerminated(tokenId)
    {
        _agentMetadata[tokenId] = metadata;
        emit MetadataUpdated(tokenId, metadata.vaultURI);
    }

    // ======================== LEARNING ========================

    /// @notice Set the authorized learning updater for an agent
    /// @dev The learning updater role allows a backend/oracle to push learning updates
    ///      without the owner signing every transaction.
    /// @param tokenId The agent token ID
    /// @param updater Address authorized to call updateLearning (address(0) to revoke)
    function setLearningUpdater(uint256 tokenId, address updater)
        external
        onlyOwnerOrApproved(tokenId)
    {
        _learningUpdaters[tokenId] = updater;
    }

    /// @inheritdoc INFA1Core
    function updateLearning(
        uint256 tokenId,
        string calldata newVaultURI,
        bytes32 newVaultHash,
        bytes32 newLearningRoot,
        uint256 newVersion
    ) external whenNotTerminated(tokenId) {
        // Authorization: owner or designated learning updater
        address tokenOwner = ownerOf(tokenId);
        if (msg.sender != tokenOwner && msg.sender != _learningUpdaters[tokenId]) {
            revert NotLearningAuthorized();
        }

        LearningState storage ls = _learningStates[tokenId];
        if (!ls.learningEnabled) revert LearningNotEnabled();
        if (newVersion <= ls.learningVersion) revert VersionMustIncrease();

        bytes32 oldRoot = ls.learningRoot;
        ls.learningRoot = newLearningRoot;
        ls.learningVersion = newVersion;
        ls.lastLearningUpdate = block.timestamp;

        // Sync vault metadata
        _agentMetadata[tokenId].vaultURI = newVaultURI;
        _agentMetadata[tokenId].vaultHash = newVaultHash;

        emit LearningUpdated(tokenId, oldRoot, newLearningRoot, newVersion);
    }

    // ======================== LEARNING QUERIES ========================

    /// @inheritdoc INFA1Core
    function getLearningRoot(uint256 tokenId) external view returns (bytes32) {
        return _learningStates[tokenId].learningRoot;
    }

    /// @inheritdoc INFA1Core
    function isLearningEnabled(uint256 tokenId) external view returns (bool) {
        return _learningStates[tokenId].learningEnabled;
    }

    /// @inheritdoc INFA1Core
    function getLearningVersion(uint256 tokenId) external view returns (uint256) {
        return _learningStates[tokenId].learningVersion;
    }

    /// @inheritdoc INFA1Core
    function getLastLearningUpdate(uint256 tokenId) external view returns (uint256) {
        return _learningStates[tokenId].lastLearningUpdate;
    }

    // ======================== ERC-165 ========================

    /// @dev Advertise support for INFA1Core alongside ERC-721 and ERC-165
    function supportsInterface(bytes4 interfaceId)
        public view override(ERC721)
        returns (bool)
    {
        return
            interfaceId == type(INFA1Core).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    // ======================== INTERNAL ========================

    /// @dev Override ERC-721 transfer hook to keep State.owner in sync.
    ///      NFA-1 REQUIRES: Paused agents MUST be transferable.
    ///      This implementation does not add any transfer restrictions,
    ///      satisfying the requirement by default.
    function _update(address to, uint256 tokenId, address auth)
        internal override returns (address)
    {
        address from = super._update(to, tokenId, auth);

        // Sync owner in State struct (for non-burn transfers)
        if (to != address(0)) {
            _states[tokenId].owner = to;
        }

        return from;
    }

    /// @dev Check if caller is the token owner or approved operator
    function _isCallerOwnerOrApproved(uint256 tokenId) internal view returns (bool) {
        address tokenOwner = ownerOf(tokenId);
        return
            msg.sender == tokenOwner ||
            getApproved(tokenId) == msg.sender ||
            isApprovedForAll(tokenOwner, msg.sender);
    }
}
