// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/examples/MinimalNFA.sol";
import "../contracts/interfaces/INFA1Core.sol";

/// @title MinimalNFA Fuzz & Invariant Tests
/// @notice Property-based tests for state machine correctness
contract MinimalNFAFuzzTest is Test {
    MinimalNFA public nfa;

    address public owner = address(0xA11CE);
    address public alice = address(0xBEEF);

    INFA1Core.AgentMetadata internal defaultMeta;

    function setUp() public {
        nfa = new MinimalNFA();
        defaultMeta = INFA1Core.AgentMetadata({
            persona: '{"calm":0.8}',
            experience: "Fuzz test agent",
            voiceHash: "",
            animationURI: "",
            vaultURI: "https://vault.example.com/fuzz",
            vaultHash: keccak256("fuzz-vault")
        });
    }

    // ============================================================
    //                    FUZZ: STATE TRANSITIONS
    // ============================================================

    /// @notice Once terminated, status MUST remain Terminated regardless of operations
    function testFuzz_terminateIsIrreversible(uint8 actionSeed) public {
        uint256 id = nfa.mint(owner, defaultMeta, true);
        vm.prank(owner);
        nfa.terminate(id);

        // Try random state-changing operations — all should revert or leave Terminated
        uint8 action = actionSeed % 4;
        vm.startPrank(owner);

        if (action == 0) {
            vm.expectRevert();
            nfa.pause(id);
        } else if (action == 1) {
            vm.expectRevert();
            nfa.unpause(id);
        } else if (action == 2) {
            vm.expectRevert();
            nfa.terminate(id);
        } else {
            vm.expectRevert();
            nfa.updateLearning(id, "x", bytes32(0), bytes32(0), 1);
        }
        vm.stopPrank();

        // Invariant: still terminated
        assertEq(uint8(nfa.getState(id).status), uint8(INFA1Core.Status.Terminated));
    }

    /// @notice Paused agents MUST be transferable to any non-zero address
    function testFuzz_pausedTransferable(address to) public {
        vm.assume(to != address(0));
        vm.assume(to.code.length == 0 || to == owner); // Avoid ERC721Receiver issues

        uint256 id = nfa.mint(owner, defaultMeta, false);
        vm.prank(owner);
        nfa.pause(id);

        vm.prank(owner);
        nfa.transferFrom(owner, to, id);
        assertEq(nfa.ownerOf(id), to);
        assertEq(nfa.getState(id).owner, to);
    }

    // ============================================================
    //                    FUZZ: VERSION MONOTONICITY
    // ============================================================

    /// @notice Version MUST always increase; equal or lower values MUST revert
    function testFuzz_versionMonotonicity(uint256 v1, uint256 v2) public {
        // Bound to reasonable values to avoid overflow
        v1 = bound(v1, 1, type(uint128).max);
        v2 = bound(v2, 0, type(uint128).max);

        uint256 id = nfa.mint(owner, defaultMeta, true);

        vm.prank(owner);
        nfa.updateLearning(id, "uri", keccak256("v"), keccak256("r"), v1);
        assertEq(nfa.getLearningVersion(id), v1);

        if (v2 <= v1) {
            vm.prank(owner);
            vm.expectRevert(MinimalNFA.VersionMustIncrease.selector);
            nfa.updateLearning(id, "uri2", keccak256("v2"), keccak256("r2"), v2);
        } else {
            vm.prank(owner);
            nfa.updateLearning(id, "uri2", keccak256("v2"), keccak256("r2"), v2);
            assertEq(nfa.getLearningVersion(id), v2);
        }
    }

    /// @notice Three sequential updates — version must be strictly increasing
    function testFuzz_threeSequentialUpdates(uint256 v1, uint256 v2, uint256 v3) public {
        v1 = bound(v1, 1, type(uint64).max);
        v2 = bound(v2, v1 + 1, uint256(type(uint64).max) + v1);
        v3 = bound(v3, v2 + 1, uint256(type(uint64).max) + v2);

        uint256 id = nfa.mint(owner, defaultMeta, true);
        vm.startPrank(owner);
        nfa.updateLearning(id, "u1", keccak256("h1"), keccak256("r1"), v1);
        nfa.updateLearning(id, "u2", keccak256("h2"), keccak256("r2"), v2);
        nfa.updateLearning(id, "u3", keccak256("h3"), keccak256("r3"), v3);
        vm.stopPrank();

        assertEq(nfa.getLearningVersion(id), v3);
        assertTrue(v3 > v2);
        assertTrue(v2 > v1);
    }

    // ============================================================
    //                    FUZZ: PERMISSIONS
    // ============================================================

    /// @notice Only owner/approved can call auth-gated functions
    function testFuzz_unauthorizedCannotPause(address caller) public {
        vm.assume(caller != owner);
        vm.assume(caller != address(0));

        uint256 id = nfa.mint(owner, defaultMeta, false);

        vm.prank(caller);
        vm.expectRevert(MinimalNFA.NotOwnerOrApproved.selector);
        nfa.pause(id);
    }

    /// @notice Only owner/approved can call terminate
    function testFuzz_unauthorizedCannotTerminate(address caller) public {
        vm.assume(caller != owner);
        vm.assume(caller != address(0));

        uint256 id = nfa.mint(owner, defaultMeta, false);

        vm.prank(caller);
        vm.expectRevert(MinimalNFA.NotOwnerOrApproved.selector);
        nfa.terminate(id);
    }

    /// @notice Only owner or designated updater can update learning
    function testFuzz_unauthorizedCannotUpdateLearning(address caller) public {
        vm.assume(caller != owner);
        vm.assume(caller != address(0));

        uint256 id = nfa.mint(owner, defaultMeta, true);

        vm.prank(caller);
        vm.expectRevert(MinimalNFA.NotLearningAuthorized.selector);
        nfa.updateLearning(id, "uri", keccak256("v"), keccak256("r"), 1);
    }

    // ============================================================
    //                    FUZZ: FUNDING
    // ============================================================

    /// @notice Fund amount MUST be exactly reflected in balance
    function testFuzz_fundingAccumulates(uint96 amount1, uint96 amount2) public {
        vm.assume(amount1 > 0);
        vm.assume(amount2 > 0);

        uint256 id = nfa.mint(owner, defaultMeta, false);

        vm.deal(alice, uint256(amount1) + uint256(amount2));
        vm.startPrank(alice);
        nfa.fundAgent{value: amount1}(id);
        nfa.fundAgent{value: amount2}(id);
        vm.stopPrank();

        assertEq(nfa.getState(id).balance, uint256(amount1) + uint256(amount2));
    }

    // ============================================================
    //                    FUZZ: METADATA
    // ============================================================

    /// @notice Metadata round-trips correctly with arbitrary string data
    function testFuzz_metadataRoundtrip(string memory persona, string memory experience) public {
        INFA1Core.AgentMetadata memory meta = INFA1Core.AgentMetadata({
            persona: persona,
            experience: experience,
            voiceHash: "voice",
            animationURI: "anim",
            vaultURI: "vault",
            vaultHash: keccak256(bytes(persona))
        });

        uint256 id = nfa.mint(owner, meta, false);
        INFA1Core.AgentMetadata memory stored = nfa.getAgentMetadata(id);
        assertEq(stored.persona, persona);
        assertEq(stored.experience, experience);
    }

    // ============================================================
    //                    FUZZ: STATE MACHINE
    // ============================================================

    /// @notice Random sequence of valid state transitions
    function testFuzz_stateMachineSequence(uint8 seed) public {
        uint256 id = nfa.mint(owner, defaultMeta, false);
        vm.startPrank(owner);

        INFA1Core.Status current = INFA1Core.Status.Active;
        uint256 steps = (seed % 10) + 1;

        for (uint256 i = 0; i < steps; i++) {
            if (current == INFA1Core.Status.Terminated) break;

            uint8 action = uint8(keccak256(abi.encode(seed, i))[0]) % 3;

            if (action == 0 && current == INFA1Core.Status.Active) {
                nfa.pause(id);
                current = INFA1Core.Status.Paused;
            } else if (action == 1 && current == INFA1Core.Status.Paused) {
                nfa.unpause(id);
                current = INFA1Core.Status.Active;
            } else if (action == 2 && current != INFA1Core.Status.Terminated) {
                nfa.terminate(id);
                current = INFA1Core.Status.Terminated;
            }
        }
        vm.stopPrank();

        assertEq(uint8(nfa.getState(id).status), uint8(current));
    }
}

/// @title MinimalNFA Invariant Test Handler
/// @notice Stateful handler for invariant testing
contract MinimalNFAHandler is Test {
    MinimalNFA public nfa;
    uint256[] public tokenIds;
    mapping(uint256 => uint256) public lastLearningVersion;

    address public constant OWNER = address(0xA11CE);

    INFA1Core.AgentMetadata internal defaultMeta;

    constructor(MinimalNFA _nfa) {
        nfa = _nfa;
        defaultMeta = INFA1Core.AgentMetadata({
            persona: '{"test":1}',
            experience: "invariant",
            voiceHash: "",
            animationURI: "",
            vaultURI: "vault://test",
            vaultHash: keccak256("inv")
        });
    }

    function mint() external {
        uint256 id = nfa.mint(OWNER, defaultMeta, true);
        tokenIds.push(id);
    }

    function pause(uint256 seed) external {
        if (tokenIds.length == 0) return;
        uint256 id = tokenIds[seed % tokenIds.length];
        INFA1Core.State memory s = nfa.getState(id);
        if (s.status != INFA1Core.Status.Active) return;
        vm.prank(OWNER);
        nfa.pause(id);
    }

    function unpause(uint256 seed) external {
        if (tokenIds.length == 0) return;
        uint256 id = tokenIds[seed % tokenIds.length];
        INFA1Core.State memory s = nfa.getState(id);
        if (s.status != INFA1Core.Status.Paused) return;
        vm.prank(OWNER);
        nfa.unpause(id);
    }

    function terminate(uint256 seed) external {
        if (tokenIds.length == 0) return;
        uint256 id = tokenIds[seed % tokenIds.length];
        INFA1Core.State memory s = nfa.getState(id);
        if (s.status == INFA1Core.Status.Terminated) return;
        vm.prank(OWNER);
        nfa.terminate(id);
    }

    function fund(uint256 seed, uint96 amount) external {
        if (tokenIds.length == 0) return;
        if (amount == 0) return;
        uint256 id = tokenIds[seed % tokenIds.length];
        vm.deal(address(this), uint256(amount));
        nfa.fundAgent{value: amount}(id);
    }

    function updateLearning(uint256 seed) external {
        if (tokenIds.length == 0) return;
        uint256 id = tokenIds[seed % tokenIds.length];
        INFA1Core.State memory s = nfa.getState(id);
        if (s.status == INFA1Core.Status.Terminated) return;
        if (!nfa.isLearningEnabled(id)) return;

        uint256 newVersion = lastLearningVersion[id] + 1;
        vm.prank(OWNER);
        nfa.updateLearning(
            id,
            string(abi.encodePacked("uri-", vm.toString(newVersion))),
            keccak256(abi.encode("hash", newVersion)),
            keccak256(abi.encode("root", newVersion)),
            newVersion
        );
        lastLearningVersion[id] = newVersion;
    }

    function getTokenCount() external view returns (uint256) {
        return tokenIds.length;
    }

    function getTokenId(uint256 index) external view returns (uint256) {
        return tokenIds[index];
    }
}

/// @title MinimalNFA Invariant Tests
contract MinimalNFAInvariantTest is Test {
    MinimalNFA public nfa;
    MinimalNFAHandler public handler;

    function setUp() public {
        nfa = new MinimalNFA();
        handler = new MinimalNFAHandler(nfa);

        // Seed some tokens
        handler.mint();
        handler.mint();
        handler.mint();

        targetContract(address(handler));
    }

    /// @notice Terminated agents MUST never return to Active or Paused
    function invariant_terminatedNeverReverts() public view {
        uint256 count = handler.getTokenCount();
        for (uint256 i = 0; i < count; i++) {
            uint256 id = handler.getTokenId(i);
            INFA1Core.State memory s = nfa.getState(id);
            if (s.status == INFA1Core.Status.Terminated) {
                assertFalse(nfa.isLearningEnabled(id), "Learning must be disabled after terminate");
            }
        }
    }

    /// @notice Learning version MUST be monotonically non-decreasing across all handlers
    function invariant_versionMonotonicity() public view {
        uint256 count = handler.getTokenCount();
        for (uint256 i = 0; i < count; i++) {
            uint256 id = handler.getTokenId(i);
            uint256 onChainVersion = nfa.getLearningVersion(id);
            uint256 trackedVersion = handler.lastLearningVersion(id);
            assertEq(onChainVersion, trackedVersion, "Version tracking mismatch");
        }
    }

    /// @notice State.owner MUST always match ERC-721 ownerOf
    function invariant_ownerSync() public view {
        uint256 count = handler.getTokenCount();
        for (uint256 i = 0; i < count; i++) {
            uint256 id = handler.getTokenId(i);
            INFA1Core.State memory s = nfa.getState(id);
            assertEq(s.owner, nfa.ownerOf(id), "State.owner out of sync with ownerOf");
        }
    }

    /// @notice Status MUST always be one of {Active, Paused, Terminated}
    function invariant_validStatus() public view {
        uint256 count = handler.getTokenCount();
        for (uint256 i = 0; i < count; i++) {
            uint256 id = handler.getTokenId(i);
            uint8 status = uint8(nfa.getState(id).status);
            assertTrue(status <= 2, "Invalid status value");
        }
    }
}
