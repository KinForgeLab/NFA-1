// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/examples/MinimalNFA.sol";
import "../contracts/interfaces/INFA1Core.sol";

/// @title MinimalNFA Formal Verification — Halmos Symbolic Tests
/// @notice Uses `check_` prefix for Halmos symbolic execution.
///         Proves properties hold for ALL possible inputs, not just samples.
///         Run: halmos --contract MinimalNFAHalmosTest
contract MinimalNFAHalmosTest is Test {
    MinimalNFA public nfa;

    address public constant OWNER = address(0xA11CE);
    address public constant ALICE = address(0xBEEF);

    INFA1Core.AgentMetadata internal defaultMeta;

    function setUp() public {
        nfa = new MinimalNFA();
        defaultMeta = INFA1Core.AgentMetadata({
            persona: '{"calm":0.8}',
            experience: "Halmos test",
            voiceHash: "",
            animationURI: "",
            vaultURI: "vault://halmos",
            vaultHash: keccak256("halmos")
        });
    }

    // ============================================================
    //  PROPERTY 1: Terminate is irreversible
    //  Once status == Terminated, it MUST remain Terminated
    //  after any subsequent call to pause/unpause/terminate.
    // ============================================================

    function check_terminate_irreversible_pause(uint8 actionSeed) public {
        uint256 id = nfa.mint(OWNER, defaultMeta, true);
        vm.prank(OWNER);
        nfa.terminate(id);

        // Try pause — must revert
        vm.prank(OWNER);
        try nfa.pause(id) {
            assert(false); // Should never succeed
        } catch {}

        assertEq(uint8(nfa.getState(id).status), uint8(INFA1Core.Status.Terminated));
    }

    function check_terminate_irreversible_unpause() public {
        uint256 id = nfa.mint(OWNER, defaultMeta, true);
        vm.prank(OWNER);
        nfa.terminate(id);

        vm.prank(OWNER);
        try nfa.unpause(id) {
            assert(false);
        } catch {}

        assertEq(uint8(nfa.getState(id).status), uint8(INFA1Core.Status.Terminated));
    }

    function check_terminate_irreversible_terminate() public {
        uint256 id = nfa.mint(OWNER, defaultMeta, true);
        vm.prank(OWNER);
        nfa.terminate(id);

        vm.prank(OWNER);
        try nfa.terminate(id) {
            assert(false);
        } catch {}

        assertEq(uint8(nfa.getState(id).status), uint8(INFA1Core.Status.Terminated));
    }

    // ============================================================
    //  PROPERTY 2: Version monotonicity
    //  After updateLearning, version MUST be strictly greater
    //  than the previous version. Equal or lower MUST revert.
    // ============================================================

    function check_version_monotonicity(uint256 v1, uint256 v2) public {
        // Bound to avoid overflow
        vm.assume(v1 >= 1 && v1 <= type(uint128).max);
        vm.assume(v2 <= type(uint128).max);

        uint256 id = nfa.mint(OWNER, defaultMeta, true);

        vm.prank(OWNER);
        nfa.updateLearning(id, "u1", keccak256("h1"), keccak256("r1"), v1);

        uint256 versionBefore = nfa.getLearningVersion(id);
        assert(versionBefore == v1);

        if (v2 <= v1) {
            // MUST revert
            vm.prank(OWNER);
            try nfa.updateLearning(id, "u2", keccak256("h2"), keccak256("r2"), v2) {
                assert(false); // Should not succeed
            } catch {}
            // Version unchanged
            assert(nfa.getLearningVersion(id) == v1);
        } else {
            // MUST succeed
            vm.prank(OWNER);
            nfa.updateLearning(id, "u2", keccak256("h2"), keccak256("r2"), v2);
            assert(nfa.getLearningVersion(id) == v2);
            assert(v2 > v1);
        }
    }

    // ============================================================
    //  PROPERTY 3: Permission boundary — pause
    //  Only owner or approved can pause. All other callers MUST revert.
    // ============================================================

    function check_pause_permission(address caller) public {
        vm.assume(caller != OWNER);
        vm.assume(caller != address(0));

        uint256 id = nfa.mint(OWNER, defaultMeta, false);

        // Caller is not owner and not approved
        vm.prank(caller);
        try nfa.pause(id) {
            assert(false); // Must not succeed
        } catch {}

        // Status unchanged
        assertEq(uint8(nfa.getState(id).status), uint8(INFA1Core.Status.Active));
    }

    // ============================================================
    //  PROPERTY 4: Permission boundary — terminate
    // ============================================================

    function check_terminate_permission(address caller) public {
        vm.assume(caller != OWNER);
        vm.assume(caller != address(0));

        uint256 id = nfa.mint(OWNER, defaultMeta, false);

        vm.prank(caller);
        try nfa.terminate(id) {
            assert(false);
        } catch {}

        assertEq(uint8(nfa.getState(id).status), uint8(INFA1Core.Status.Active));
    }

    // ============================================================
    //  PROPERTY 5: Permission boundary — updateLearning
    //  Only owner or designated updater can update learning.
    // ============================================================

    function check_learning_permission(address caller) public {
        vm.assume(caller != OWNER);
        vm.assume(caller != address(0));

        uint256 id = nfa.mint(OWNER, defaultMeta, true);
        // No updater set, so only OWNER should work

        vm.prank(caller);
        try nfa.updateLearning(id, "u", keccak256("h"), keccak256("r"), 1) {
            assert(false);
        } catch {}

        assert(nfa.getLearningVersion(id) == 0);
    }

    // ============================================================
    //  PROPERTY 6: Learning disabled after terminate
    //  Terminate MUST set learningEnabled = false.
    // ============================================================

    function check_terminate_disables_learning() public {
        uint256 id = nfa.mint(OWNER, defaultMeta, true);
        assert(nfa.isLearningEnabled(id) == true);

        vm.prank(OWNER);
        nfa.terminate(id);

        assert(nfa.isLearningEnabled(id) == false);
    }

    // ============================================================
    //  PROPERTY 7: Terminated agent cannot update learning
    // ============================================================

    function check_terminated_no_learning(uint256 version) public {
        vm.assume(version >= 1);

        uint256 id = nfa.mint(OWNER, defaultMeta, true);
        vm.prank(OWNER);
        nfa.terminate(id);

        vm.prank(OWNER);
        try nfa.updateLearning(id, "u", keccak256("h"), keccak256("r"), version) {
            assert(false);
        } catch {}

        assert(nfa.getLearningVersion(id) == 0);
    }

    // ============================================================
    //  PROPERTY 8: Funding conservation
    //  fundAgent(msg.value) MUST add exactly msg.value to balance.
    // ============================================================

    function check_funding_conservation(uint96 amount) public {
        vm.assume(amount > 0);

        uint256 id = nfa.mint(OWNER, defaultMeta, false);
        uint256 balanceBefore = nfa.getState(id).balance;

        vm.deal(ALICE, uint256(amount));
        vm.prank(ALICE);
        nfa.fundAgent{value: amount}(id);

        uint256 balanceAfter = nfa.getState(id).balance;
        assert(balanceAfter == balanceBefore + amount);
    }

    // ============================================================
    //  PROPERTY 9: State.owner always equals ownerOf after transfer
    // ============================================================

    function check_owner_sync_after_transfer(address to) public {
        vm.assume(to != address(0));
        vm.assume(to.code.length == 0);

        uint256 id = nfa.mint(OWNER, defaultMeta, false);

        vm.prank(OWNER);
        nfa.transferFrom(OWNER, to, id);

        INFA1Core.State memory s = nfa.getState(id);
        assert(s.owner == nfa.ownerOf(id));
        assert(s.owner == to);
    }

    // ============================================================
    //  PROPERTY 10: Paused agent MUST be transferable
    // ============================================================

    function check_paused_transferable(address to) public {
        vm.assume(to != address(0));
        vm.assume(to.code.length == 0);

        uint256 id = nfa.mint(OWNER, defaultMeta, false);
        vm.prank(OWNER);
        nfa.pause(id);

        // Transfer must succeed
        vm.prank(OWNER);
        nfa.transferFrom(OWNER, to, id);

        assert(nfa.ownerOf(id) == to);
        assertEq(uint8(nfa.getState(id).status), uint8(INFA1Core.Status.Paused));
    }

    // ============================================================
    //  PROPERTY 11: Status always valid (0, 1, or 2)
    // ============================================================

    function check_status_always_valid() public {
        uint256 id = nfa.mint(OWNER, defaultMeta, false);
        uint8 status = uint8(nfa.getState(id).status);
        assert(status <= 2);
    }

    // ============================================================
    //  PROPERTY 12: Terminated cannot update metadata
    // ============================================================

    function check_terminated_no_metadata_update() public {
        uint256 id = nfa.mint(OWNER, defaultMeta, false);
        vm.prank(OWNER);
        nfa.terminate(id);

        vm.prank(OWNER);
        try nfa.updateAgentMetadata(id, defaultMeta) {
            assert(false);
        } catch {}
    }

    // ============================================================
    //  PROPERTY 13: Terminated cannot set logic address
    // ============================================================

    function check_terminated_no_logic_update() public {
        uint256 id = nfa.mint(OWNER, defaultMeta, false);
        vm.prank(OWNER);
        nfa.terminate(id);

        vm.prank(OWNER);
        try nfa.setLogicAddress(id, address(0x1234)) {
            assert(false);
        } catch {}
    }

    // ============================================================
    //  PROPERTY 14: ERC-165 interface consistency
    //  supportsInterface(INFA1Core.interfaceId) MUST return true.
    // ============================================================

    function check_erc165_infa1core() public view {
        bytes4 infa1Id = type(INFA1Core).interfaceId;
        assert(nfa.supportsInterface(infa1Id) == true);
        assert(nfa.supportsInterface(0x80ac58cd) == true);  // ERC-721
        assert(nfa.supportsInterface(0x01ffc9a7) == true);  // ERC-165
        assert(nfa.supportsInterface(0xDEADBEEF) == false); // Invalid
    }

    // ============================================================
    //  PROPERTY 15: State transitions are deterministic
    //  Active->Paused->Active round-trip preserves all state except status
    // ============================================================

    function check_pause_unpause_roundtrip() public {
        uint256 id = nfa.mint(OWNER, defaultMeta, true);

        vm.deal(ALICE, 1 ether);
        vm.prank(ALICE);
        nfa.fundAgent{value: 1 ether}(id);

        INFA1Core.State memory before = nfa.getState(id);

        vm.startPrank(OWNER);
        nfa.pause(id);
        nfa.unpause(id);
        vm.stopPrank();

        INFA1Core.State memory afterState = nfa.getState(id);

        assert(afterState.balance == before.balance);
        assert(afterState.owner == before.owner);
        assert(afterState.logicAddress == before.logicAddress);
        assert(afterState.lastActionTimestamp == before.lastActionTimestamp);
        assertEq(uint8(afterState.status), uint8(INFA1Core.Status.Active));
    }
}
