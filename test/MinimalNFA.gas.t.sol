// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/examples/MinimalNFA.sol";
import "../contracts/interfaces/INFA1Core.sol";
import "../contracts/tools/NFA1Verifier.sol";
import "./mocks/MockLogic.sol";

/// @title MinimalNFA Gas Benchmarks
/// @notice Measures gas costs for all core NFA-1 operations.
///         Run with `forge test --match-contract MinimalNFAGasTest --gas-report`
contract MinimalNFAGasTest is Test {
    MinimalNFA public nfa;
    MockLogic public logic;

    address public owner = address(0xA11CE);

    INFA1Core.AgentMetadata internal defaultMeta;
    INFA1Core.AgentMetadata internal fullMeta;

    function setUp() public {
        nfa = new MinimalNFA();
        logic = new MockLogic();

        defaultMeta = INFA1Core.AgentMetadata({
            persona: '{"calm":0.8}',
            experience: "Gas test",
            voiceHash: "",
            animationURI: "",
            vaultURI: "https://vault.example.com/gas",
            vaultHash: keccak256("gas-vault")
        });

        // Full metadata with realistic string lengths
        fullMeta = INFA1Core.AgentMetadata({
            persona: '{"calm":0.82,"curious":0.65,"bold":0.45,"social":0.70,"disciplined":0.55}',
            experience: "Senior Research Agent specializing in DeFi protocol analysis and risk assessment",
            voiceHash: "QmT5NvUtoM5nWFfrQdVrFtvGfKFmG7AHE8P34isapyhCxX",
            animationURI: "ipfs://QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG/avatar.glb",
            vaultURI: "https://vault.kinforge.xyz/agents/42/data.json",
            vaultHash: keccak256("vault-content-with-persona-and-memory-tree-v3")
        });
    }

    // ============================================================
    //                    MINTING
    // ============================================================

    function test_gas_mint_minimal() public {
        nfa.mint(owner, defaultMeta, false);
    }

    function test_gas_mint_withLearning() public {
        nfa.mint(owner, defaultMeta, true);
    }

    function test_gas_mint_fullMetadata() public {
        nfa.mint(owner, fullMeta, true);
    }

    // ============================================================
    //                    STATE QUERIES (reads)
    // ============================================================

    function test_gas_getState() public {
        uint256 id = nfa.mint(owner, defaultMeta, true);
        nfa.getState(id);
    }

    function test_gas_getAgentMetadata() public {
        uint256 id = nfa.mint(owner, fullMeta, true);
        nfa.getAgentMetadata(id);
    }

    function test_gas_getLearningState() public {
        uint256 id = nfa.mint(owner, defaultMeta, true);
        nfa.getLearningState(id);
    }

    function test_gas_getLearningRoot() public {
        uint256 id = nfa.mint(owner, defaultMeta, true);
        nfa.getLearningRoot(id);
    }

    function test_gas_isLearningEnabled() public {
        uint256 id = nfa.mint(owner, defaultMeta, true);
        nfa.isLearningEnabled(id);
    }

    function test_gas_getLearningVersion() public {
        uint256 id = nfa.mint(owner, defaultMeta, true);
        nfa.getLearningVersion(id);
    }

    function test_gas_supportsInterface() public view {
        nfa.supportsInterface(type(INFA1Core).interfaceId);
    }

    // ============================================================
    //                    LIFECYCLE
    // ============================================================

    function test_gas_pause() public {
        uint256 id = nfa.mint(owner, defaultMeta, false);
        vm.prank(owner);
        nfa.pause(id);
    }

    function test_gas_unpause() public {
        uint256 id = nfa.mint(owner, defaultMeta, false);
        vm.prank(owner);
        nfa.pause(id);
        vm.prank(owner);
        nfa.unpause(id);
    }

    function test_gas_terminate() public {
        uint256 id = nfa.mint(owner, defaultMeta, true);
        vm.prank(owner);
        nfa.terminate(id);
    }

    // ============================================================
    //                    FUNDING
    // ============================================================

    function test_gas_fundAgent() public {
        uint256 id = nfa.mint(owner, defaultMeta, false);
        nfa.fundAgent{value: 1 ether}(id);
    }

    // ============================================================
    //                    METADATA UPDATE
    // ============================================================

    function test_gas_updateAgentMetadata() public {
        uint256 id = nfa.mint(owner, defaultMeta, false);
        vm.prank(owner);
        nfa.updateAgentMetadata(id, fullMeta);
    }

    // ============================================================
    //                    LEARNING UPDATE
    // ============================================================

    function test_gas_updateLearning_first() public {
        uint256 id = nfa.mint(owner, defaultMeta, true);
        vm.prank(owner);
        nfa.updateLearning(
            id,
            "https://vault.example.com/v1",
            keccak256("vault-v1"),
            keccak256("learning-root-v1"),
            1
        );
    }

    function test_gas_updateLearning_subsequent() public {
        uint256 id = nfa.mint(owner, defaultMeta, true);
        vm.startPrank(owner);
        nfa.updateLearning(id, "uri1", keccak256("h1"), keccak256("r1"), 1);
        // Measure second update (warm storage)
        nfa.updateLearning(id, "uri2", keccak256("h2"), keccak256("r2"), 2);
        vm.stopPrank();
    }

    function test_gas_setLearningUpdater() public {
        uint256 id = nfa.mint(owner, defaultMeta, true);
        vm.prank(owner);
        nfa.setLearningUpdater(id, address(0xD00D));
    }

    // ============================================================
    //                    LOGIC / ACTION EXECUTION
    // ============================================================

    function test_gas_setLogicAddress() public {
        uint256 id = nfa.mint(owner, defaultMeta, false);
        vm.prank(owner);
        nfa.setLogicAddress(id, address(logic));
    }

    function test_gas_executeAction() public {
        uint256 id = nfa.mint(owner, defaultMeta, false);
        vm.prank(owner);
        nfa.setLogicAddress(id, address(logic));

        vm.prank(owner);
        nfa.executeAction(id, abi.encodeWithSelector(MockLogic.doSomething.selector, uint256(42)));
    }

    // ============================================================
    //                    TRANSFER
    // ============================================================

    function test_gas_transfer() public {
        uint256 id = nfa.mint(owner, defaultMeta, false);
        vm.prank(owner);
        nfa.transferFrom(owner, address(0xBEEF), id);
    }

    function test_gas_transfer_paused() public {
        uint256 id = nfa.mint(owner, defaultMeta, false);
        vm.prank(owner);
        nfa.pause(id);
        vm.prank(owner);
        nfa.transferFrom(owner, address(0xBEEF), id);
    }

    // ============================================================
    //                    VERIFIER GAS COST
    // ============================================================

    function test_gas_verifier_quickCheck() public {
        NFA1Verifier v = new NFA1Verifier();
        v.quickCheck(address(nfa));
    }

    function test_gas_verifier_fullAudit() public {
        NFA1Verifier v = new NFA1Verifier();
        v.fullAudit(address(nfa));
    }
}
