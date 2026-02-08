// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/examples/MinimalNFA.sol";
import "../contracts/tools/NFA1Verifier.sol";

/// @title Deploy — Deploy MinimalNFA + NFA1Verifier
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

        // 1. Deploy MinimalNFA
        MinimalNFA nfa = new MinimalNFA();
        console.log("MinimalNFA deployed at:", address(nfa));

        // 2. Deploy NFA1Verifier
        NFA1Verifier verifier = new NFA1Verifier();
        console.log("NFA1Verifier deployed at:", address(verifier));

        // 3. Self-verify: run quickCheck on the deployed NFA
        (bool isNFA, uint8 tier) = verifier.quickCheck(address(nfa));
        console.log("quickCheck.isNFA:", isNFA);
        console.log("quickCheck.tier:", tier);

        require(isNFA, "FATAL: Deployed contract failed NFA-1 self-check");
        require(tier == 3, "FATAL: Expected Tier 3 compliance");

        vm.stopBroadcast();

        console.log("");
        console.log("=== Deployment Summary ===");
        console.log("MinimalNFA:    ", address(nfa));
        console.log("NFA1Verifier:  ", address(verifier));
        console.log("INFA1Core ID:  ");
        console.logBytes4(verifier.INFA1CORE_ID());
        console.log("Compliance:     Tier 3 (VERIFIED)");
    }
}
