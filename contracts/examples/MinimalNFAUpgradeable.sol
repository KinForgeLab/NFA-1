// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../interfaces/INFA1Core.sol";

/// @title MinimalNFAUpgradeable — UUPS Upgradeable NFA-1 Reference Implementation
/// @notice Upgradeable version of MinimalNFA using UUPS proxy pattern.
///         Satisfies Tier 1-3 compliance. Owner can upgrade the implementation.
///
///         Deploy via ERC1967Proxy:
///           1. Deploy MinimalNFAUpgradeable (implementation)
///           2. Deploy ERC1967Proxy(implementation, abi.encodeCall(initialize, (owner)))
///           3. Interact with proxy address
///
/// @dev Storage layout:
///      - Slots 0-49: ERC721Upgradeable
///      - Slots 50-99: OwnableUpgradeable
///      - Slots 100-149: UUPSUpgradeable
///      - ReentrancyGuard: uses EIP-7201 named storage slot (no init needed)
///      - Custom storage: _states, _agentMetadata, _learningStates, _learningUpdaters, _nextTokenId
///      - __gap: 50 slots reserved for future upgrades
contract MinimalNFAUpgradeable is
    ERC721Upgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuard,
    INFA1Core
{
    // ======================== STORAGE ========================

    mapping(uint256 => State) private _states;
    mapping(uint256 => AgentMetadata) private _agentMetadata;
    mapping(uint256 => LearningState) private _learningStates;
    mapping(uint256 => address) private _learningUpdaters;

    uint256 internal _nextTokenId;

    /// @notice Maximum gas forwarded to logic contracts during executeAction
    uint256 public constant ACTION_GAS_LIMIT = 500_000;

    /// @dev Reserved storage gap for future upgrades (50 slots)
    uint256[50] private __gap;

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

    // ======================== INITIALIZER ========================

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the contract (replaces constructor for proxy pattern)
    /// @param owner_ The initial owner who can upgrade the contract
    function initialize(address owner_) public initializer {
        __MinimalNFAUpgradeable_init(owner_);
    }

    /// @dev Internal initializer — called by subclass initializers via inheritance chain
    function __MinimalNFAUpgradeable_init(address owner_) internal onlyInitializing {
        __ERC721_init("MinimalNFA", "NFA");
        __Ownable_init(owner_);
        _nextTokenId = 1;
    }

    // ======================== UUPS ========================

    /// @dev Only owner can authorize upgrades
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // ======================== MINTING ========================

    /// @notice Mint a new NFA agent
    /// @param to Recipient address
    /// @param metadata Initial agent metadata
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
    function pause(uint256 tokenId) external onlyOwnerOrApproved(tokenId) {
        if (_states[tokenId].status != Status.Active) revert NotActive();
        _states[tokenId].status = Status.Paused;
        emit StatusChanged(tokenId, Status.Paused);
    }

    /// @inheritdoc INFA1Core
    function unpause(uint256 tokenId) external onlyOwnerOrApproved(tokenId) {
        if (_states[tokenId].status != Status.Paused) revert NotPaused();
        _states[tokenId].status = Status.Active;
        emit StatusChanged(tokenId, Status.Active);
    }

    /// @inheritdoc INFA1Core
    function terminate(uint256 tokenId) external onlyOwnerOrApproved(tokenId) {
        if (_states[tokenId].status == Status.Terminated) revert AlreadyTerminated();
        _states[tokenId].status = Status.Terminated;
        _learningStates[tokenId].learningEnabled = false;
        emit StatusChanged(tokenId, Status.Terminated);
    }

    // ======================== STATE QUERIES ========================

    /// @inheritdoc INFA1Core
    function getState(uint256 tokenId) external view exists(tokenId) returns (State memory) {
        State memory state = _states[tokenId];
        state.owner = ownerOf(tokenId);
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
    function updateAgentMetadata(uint256 tokenId, AgentMetadata calldata metadata)
        external
        onlyOwnerOrApproved(tokenId)
        whenNotTerminated(tokenId)
    {
        _agentMetadata[tokenId] = metadata;
        emit MetadataUpdated(tokenId, metadata.vaultURI);
    }

    // ======================== LEARNING ========================

    /// @notice Set the authorized learning updater for an agent
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

    function supportsInterface(bytes4 interfaceId)
        public view override(ERC721Upgradeable)
        returns (bool)
    {
        return
            interfaceId == type(INFA1Core).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    // ======================== INTERNAL ========================

    function _update(address to, uint256 tokenId, address auth)
        internal override returns (address)
    {
        address from = super._update(to, tokenId, auth);
        if (to != address(0)) {
            _states[tokenId].owner = to;
        }
        return from;
    }

    function _isCallerOwnerOrApproved(uint256 tokenId) internal view returns (bool) {
        address tokenOwner = ownerOf(tokenId);
        return
            msg.sender == tokenOwner ||
            getApproved(tokenId) == msg.sender ||
            isApprovedForAll(tokenOwner, msg.sender);
    }
}
