// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../contracts/examples/MyAgentUpgradeable.sol";
import "../contracts/tools/NFA1Verifier.sol";

/// @title DeployUpgradeable — Deploy MyAgentUpgradeable via UUPS Proxy
/// @notice Usage:
///   # Local (anvil):
///   forge script script/DeployUpgradeable.s.sol --rpc-url http://localhost:8545 --broadcast
///
///   # BSC Testnet:
///   forge script script/DeployUpgradeable.s.sol --rpc-url https://data-seed-prebsc-1-s1.binance.org:8545 --broadcast
///
///   # BSC Mainnet:
///   forge script script/DeployUpgradeable.s.sol --rpc-url https://bsc-dataseed.binance.org --broadcast
///
/// @dev Set PRIVATE_KEY env var before running:
///   export PRIVATE_KEY=0x...
///
///   To upgrade later:
///   1. Deploy new implementation: forge create MyAgentUpgradeableV2 --rpc-url <RPC> --private-key <KEY>
///   2. Call: cast send <PROXY> "upgradeToAndCall(address,bytes)" <NEW_IMPL> 0x --rpc-url <RPC> --private-key <KEY>
contract DeployUpgradeableScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deployer:", deployer);
        console.log("Balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy implementation (logic contract — not used directly)
        MyAgentUpgradeable implementation = new MyAgentUpgradeable();
        console.log("Implementation deployed at:", address(implementation));

        // 2. Deploy ERC1967Proxy pointing to implementation
        bytes memory initData = abi.encodeCall(
            MyAgentUpgradeable.initializeMyAgent,
            (deployer)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        console.log("Proxy deployed at:", address(proxy));

        // 3. Interact via proxy
        MyAgentUpgradeable nfa = MyAgentUpgradeable(address(proxy));
        console.log("Collection name:", nfa.name());
        console.log("Owner:", nfa.owner());

        // 4. Deploy NFA1Verifier
        NFA1Verifier verifier = new NFA1Verifier();
        console.log("NFA1Verifier deployed at:", address(verifier));

        // 5. Self-verify proxy
        (bool isNFA, uint8 tier) = verifier.quickCheck(address(proxy));
        console.log("quickCheck.isNFA:", isNFA);
        console.log("quickCheck.tier:", tier);

        require(isNFA, "FATAL: Proxy failed NFA-1 self-check");
        require(tier == 3, "FATAL: Expected Tier 3 compliance");

        // 6. Open minting (optional)
        nfa.setMintOpen(true);
        console.log("Minting: OPEN");

        vm.stopBroadcast();

        console.log("");
        console.log("=== Deployment Summary (UUPS Upgradeable) ===");
        console.log("Implementation:", address(implementation));
        console.log("Proxy (use this):", address(proxy));
        console.log("NFA1Verifier:    ", address(verifier));
        console.log("Compliance:       Tier 3 (VERIFIED)");
        console.log("");
        console.log("IMPORTANT: All interactions go through the PROXY address.");
        console.log("The implementation address is only used internally by the proxy.");
        console.log("");
        console.log("To upgrade later:");
        console.log("  1. Deploy new implementation contract");
        console.log("  2. cast send <PROXY> 'upgradeToAndCall(address,bytes)' <NEW_IMPL> 0x");
    }
}
