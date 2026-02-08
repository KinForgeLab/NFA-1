// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MinimalNFAUpgradeable.sol";

/// @title MyAgentUpgradeable — UUPS Upgradeable NFA-1 Deployment Template
/// @notice Fork this file and customize the sections marked with "TODO".
///         This is the UPGRADEABLE version — the owner can upgrade the contract
///         logic after deployment without migrating tokens or state.
///
///         Quick start:
///         1. Rename the contract (MyAgentUpgradeable → YourProjectAgent)
///         2. Change NAME, SYMBOL, MAX_SUPPLY, MINT_PRICE, MAX_PER_WALLET
///         3. Deploy via DeployUpgradeable.s.sol (deploys proxy + implementation)
///         4. To upgrade later: deploy new implementation, call upgradeTo(newImpl)
///
/// @dev Inherits MinimalNFAUpgradeable (UUPS + Tier 1-3 compliant).
///      The proxy owner can upgrade the contract to add features or fix bugs.
contract MyAgentUpgradeable is MinimalNFAUpgradeable {

    // ====================== TODO: CUSTOMIZE THESE ======================

    /// @notice Collection name (shown on explorers and marketplaces)
    string private constant NAME = "My NFA Collection";  // TODO: Change this

    /// @notice Collection symbol (ticker)
    string private constant SYMBOL = "MNFA";  // TODO: Change this

    /// @notice Maximum number of agents that can be minted (0 = unlimited)
    uint256 public constant MAX_SUPPLY = 10_000;  // TODO: Change this

    /// @notice Price per mint in native token (set to 0 for free mint)
    uint256 public constant MINT_PRICE = 0.01 ether;  // TODO: Change this

    /// @notice Maximum mints per wallet (0 = unlimited)
    uint256 public constant MAX_PER_WALLET = 5;  // TODO: Change this

    // ====================== STATE ======================

    bool public mintOpen;
    uint256 public totalMinted;
    mapping(address => uint256) public mintCount;

    /// @dev Reserved storage gap for future upgrades
    uint256[47] private __gap_myagent;

    // ====================== ERRORS ======================

    error MintNotOpen();
    error MaxSupplyReached();
    error InsufficientPayment();
    error MaxPerWalletReached();
    error WithdrawFailed();

    // ====================== INITIALIZER ======================

    /// @notice Initialize the contract (called once via proxy)
    /// @param owner_ The initial owner (can upgrade, toggle mint, withdraw)
    function initializeMyAgent(address owner_) external initializer {
        __MinimalNFAUpgradeable_init(owner_);
    }

    /// @notice Override ERC-721 name with your project name
    function name() public pure override returns (string memory) {
        return NAME;
    }

    /// @notice Override ERC-721 symbol with your ticker
    function symbol() public pure override returns (string memory) {
        return SYMBOL;
    }

    // ====================== MINT CONTROL ======================

    /// @notice Toggle public minting on/off
    function setMintOpen(bool open) external onlyOwner {
        mintOpen = open;
    }

    // ====================== PUBLIC MINT ======================

    /// @notice Mint a new NFA agent (public, payable)
    /// @param metadata Agent metadata (persona, experience, vault, etc.)
    /// @param enableLearning Whether to enable the learning system from mint
    /// @return tokenId The minted token ID
    function publicMint(
        AgentMetadata calldata metadata,
        bool enableLearning
    ) external payable returns (uint256 tokenId) {
        if (!mintOpen) revert MintNotOpen();
        if (MAX_SUPPLY > 0 && totalMinted >= MAX_SUPPLY) revert MaxSupplyReached();
        if (msg.value < MINT_PRICE) revert InsufficientPayment();
        if (MAX_PER_WALLET > 0 && mintCount[msg.sender] >= MAX_PER_WALLET) {
            revert MaxPerWalletReached();
        }

        totalMinted++;
        mintCount[msg.sender]++;

        tokenId = this.mint(msg.sender, metadata, enableLearning);
    }

    // ====================== OWNER MINT ======================

    /// @notice Owner can mint for free (airdrops, team allocation)
    function ownerMint(
        address to,
        AgentMetadata calldata metadata,
        bool enableLearning
    ) external onlyOwner returns (uint256) {
        if (MAX_SUPPLY > 0 && totalMinted >= MAX_SUPPLY) revert MaxSupplyReached();
        totalMinted++;
        return this.mint(to, metadata, enableLearning);
    }

    // ====================== WITHDRAW ======================

    /// @notice Withdraw mint revenue to owner
    function withdraw() external onlyOwner {
        (bool ok,) = payable(owner()).call{value: address(this).balance}("");
        if (!ok) revert WithdrawFailed();
    }
}
