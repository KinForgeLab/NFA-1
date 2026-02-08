// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/examples/MyAgent.sol";
import "../contracts/tools/NFA1Verifier.sol";

/// @title Deploy — Deploy MyAgent + NFA1Verifier
/// @notice Usage:
///   # Testnet (BSC Testnet):
///   forge script script/Deploy.s.sol --rpc-url https://data-seed-prebsc-1-s1.binance.org:8545 --broadcast --verify
///
///   # Local (anvil):
///   forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast
///
///   # Mainnet (BSC):
///   forge script script/Deploy.s.sol --rpc-url https://bsc-dataseed.binance.org --broadcast --verify
///
/// @dev Set PRIVATE_KEY env var before running:
///   export PRIVATE_KEY=0x...
contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deployer:", deployer);
        console.log("Balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy MyAgent (inherits MinimalNFA — Tier 1-3 compliant)
        MyAgent nfa = new MyAgent();
        console.log("MyAgent deployed at:", address(nfa));

        // 2. Deploy NFA1Verifier
        NFA1Verifier verifier = new NFA1Verifier();
        console.log("NFA1Verifier deployed at:", address(verifier));

        // 3. Self-verify: run quickCheck on the deployed NFA
        (bool isNFA, uint8 tier) = verifier.quickCheck(address(nfa));
        console.log("quickCheck.isNFA:", isNFA);
        console.log("quickCheck.tier:", tier);

        require(isNFA, "FATAL: Deployed contract failed NFA-1 self-check");
        require(tier == 3, "FATAL: Expected Tier 3 compliance");

        // 4. Open minting (optional — remove if you want to open later)
        nfa.setMintOpen(true);
        console.log("Minting: OPEN");

        vm.stopBroadcast();

        console.log("");
        console.log("=== Deployment Summary ===");
        console.log("MyAgent:       ", address(nfa));
        console.log("NFA1Verifier:  ", address(verifier));
        console.log("INFA1Core ID:  ");
        console.logBytes4(verifier.INFA1CORE_ID());
        console.log("Compliance:     Tier 3 (VERIFIED)");
        console.log("");
        console.log("Next steps:");
        console.log("  1. Verify on BscScan: forge verify-contract <ADDRESS> MyAgent --chain bsc");
        console.log("  2. Mint your first agent via publicMint() or ownerMint()");
        console.log("  3. Set up your off-chain vault and learning backend");
    }
}
