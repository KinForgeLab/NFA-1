// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/examples/MinimalNFA.sol";
import "../contracts/interfaces/INFA1Core.sol";
import "./mocks/MockLogic.sol";

/// @title MinimalNFA Unit Tests — NFA-1 Tier 1-3 Full Coverage
/// @notice Tests mapped to NFA1-CHECKLIST items (C-01..C-12, L-01..L-07, A-01..A-07)
contract MinimalNFATest is Test {
    MinimalNFA public nfa;
    MockLogic public logic;

    address public owner = address(0xA11CE);
    address public alice = address(0xBEEF);
    address public bob = address(0xCAFE);
    address public updater = address(0xD00D);

    INFA1Core.AgentMetadata internal defaultMeta;

    function setUp() public {
        nfa = new MinimalNFA();
        logic = new MockLogic();

        defaultMeta = INFA1Core.AgentMetadata({
            persona: '{"calm":0.8,"curious":0.6}',
            experience: "Test agent for NFA-1 compliance",
            voiceHash: "QmVoiceHash123",
            animationURI: "ipfs://QmAnimation",
            vaultURI: "https://vault.example.com/1",
            vaultHash: keccak256("vault-content-v1")
        });
    }

    // ============================================================
    //                    HELPERS
    // ============================================================

    function _mintDefault(address to) internal returns (uint256) {
        return nfa.mint(to, defaultMeta, true);
    }

    function _mintNoLearning(address to) internal returns (uint256) {
        return nfa.mint(to, defaultMeta, false);
    }

    // ============================================================
    //                    TIER 1: CORE (C-01 .. C-12)
    // ============================================================

    // --- C-01: ERC-721 Base ---

    function test_C01_isERC721() public {
        uint256 id = _mintDefault(owner);
        assertEq(nfa.ownerOf(id), owner);
        assertEq(nfa.balanceOf(owner), 1);
        assertEq(nfa.name(), "MinimalNFA");
        assertEq(nfa.symbol(), "NFA");
    }

    function test_C01_transfer() public {
        uint256 id = _mintDefault(owner);
        vm.prank(owner);
        nfa.transferFrom(owner, alice, id);
        assertEq(nfa.ownerOf(id), alice);
    }

    function test_C01_approve_and_transferFrom() public {
        uint256 id = _mintDefault(owner);
        vm.prank(owner);
        nfa.approve(alice, id);
        vm.prank(alice);
        nfa.transferFrom(owner, alice, id);
        assertEq(nfa.ownerOf(id), alice);
    }

    // --- C-02: Status Enum ---

    function test_C02_statusEnum_values() public {
        // Verify enum ordering: Active=0, Paused=1, Terminated=2
        assertEq(uint8(INFA1Core.Status.Active), 0);
        assertEq(uint8(INFA1Core.Status.Paused), 1);
        assertEq(uint8(INFA1Core.Status.Terminated), 2);
    }

    function test_C02_initialStatus_isActive() public {
        uint256 id = _mintDefault(owner);
        INFA1Core.State memory s = nfa.getState(id);
        assertEq(uint8(s.status), uint8(INFA1Core.Status.Active));
    }

    // --- C-03: State Struct ---

    function test_C03_stateStruct_fields() public {
        uint256 id = _mintDefault(owner);
        INFA1Core.State memory s = nfa.getState(id);
        assertEq(s.balance, 0);
        assertEq(uint8(s.status), uint8(INFA1Core.Status.Active));
        assertEq(s.owner, owner);
        assertEq(s.logicAddress, address(0));
        assertEq(s.lastActionTimestamp, 0);
    }

    function test_C03_stateOwner_syncsWithERC721() public {
        uint256 id = _mintDefault(owner);
        vm.prank(owner);
        nfa.transferFrom(owner, alice, id);
        INFA1Core.State memory s = nfa.getState(id);
        assertEq(s.owner, alice);
    }

    // --- C-04: AgentMetadata Struct ---

    function test_C04_agentMetadata_fields() public {
        uint256 id = _mintDefault(owner);
        INFA1Core.AgentMetadata memory m = nfa.getAgentMetadata(id);
        assertEq(m.persona, defaultMeta.persona);
        assertEq(m.experience, defaultMeta.experience);
        assertEq(m.voiceHash, defaultMeta.voiceHash);
        assertEq(m.animationURI, defaultMeta.animationURI);
        assertEq(m.vaultURI, defaultMeta.vaultURI);
        assertEq(m.vaultHash, defaultMeta.vaultHash);
    }

    // --- C-05: getState ---

    function test_C05_getState_returnsValidState() public {
        uint256 id = _mintDefault(owner);
        nfa.fundAgent{value: 1 ether}(id);
        INFA1Core.State memory s = nfa.getState(id);
        assertEq(s.balance, 1 ether);
        assertEq(s.owner, owner);
    }

    function test_C05_getState_revertsForNonexistent() public {
        vm.expectRevert(MinimalNFA.AgentDoesNotExist.selector);
        nfa.getState(999);
    }

    // --- C-06: getAgentMetadata ---

    function test_C06_getAgentMetadata_revertsForNonexistent() public {
        vm.expectRevert(MinimalNFA.AgentDoesNotExist.selector);
        nfa.getAgentMetadata(999);
    }

    // --- C-07: StatusChanged Events ---

    function test_C07_statusChanged_onMint() public {
        vm.expectEmit(true, false, false, true);
        emit INFA1Core.StatusChanged(1, INFA1Core.Status.Active);
        nfa.mint(owner, defaultMeta, true);
    }

    function test_C07_statusChanged_onPause() public {
        uint256 id = _mintDefault(owner);
        vm.expectEmit(true, false, false, true);
        emit INFA1Core.StatusChanged(id, INFA1Core.Status.Paused);
        vm.prank(owner);
        nfa.pause(id);
    }

    function test_C07_statusChanged_onUnpause() public {
        uint256 id = _mintDefault(owner);
        vm.prank(owner);
        nfa.pause(id);
        vm.expectEmit(true, false, false, true);
        emit INFA1Core.StatusChanged(id, INFA1Core.Status.Active);
        vm.prank(owner);
        nfa.unpause(id);
    }

    function test_C07_statusChanged_onTerminate() public {
        uint256 id = _mintDefault(owner);
        vm.expectEmit(true, false, false, true);
        emit INFA1Core.StatusChanged(id, INFA1Core.Status.Terminated);
        vm.prank(owner);
        nfa.terminate(id);
    }

    // --- C-08: Lifecycle Functions ---

    function test_C08_pause_fromActive() public {
        uint256 id = _mintDefault(owner);
        vm.prank(owner);
        nfa.pause(id);
        INFA1Core.State memory s = nfa.getState(id);
        assertEq(uint8(s.status), uint8(INFA1Core.Status.Paused));
    }

    function test_C08_unpause_fromPaused() public {
        uint256 id = _mintDefault(owner);
        vm.prank(owner);
        nfa.pause(id);
        vm.prank(owner);
        nfa.unpause(id);
        INFA1Core.State memory s = nfa.getState(id);
        assertEq(uint8(s.status), uint8(INFA1Core.Status.Active));
    }

    function test_C08_pause_revertsIfNotActive() public {
        uint256 id = _mintDefault(owner);
        vm.prank(owner);
        nfa.pause(id);
        vm.prank(owner);
        vm.expectRevert(MinimalNFA.NotActive.selector);
        nfa.pause(id); // Already paused
    }

    function test_C08_unpause_revertsIfNotPaused() public {
        uint256 id = _mintDefault(owner);
        vm.prank(owner);
        vm.expectRevert(MinimalNFA.NotPaused.selector);
        nfa.unpause(id); // Not paused
    }

    function test_C08_pause_requiresAuth() public {
        uint256 id = _mintDefault(owner);
        vm.prank(alice); // Not the owner
        vm.expectRevert(MinimalNFA.NotOwnerOrApproved.selector);
        nfa.pause(id);
    }

    function test_C08_unpause_requiresAuth() public {
        uint256 id = _mintDefault(owner);
        vm.prank(owner);
        nfa.pause(id);
        vm.prank(alice);
        vm.expectRevert(MinimalNFA.NotOwnerOrApproved.selector);
        nfa.unpause(id);
    }

    function test_C08_terminate_fromActive() public {
        uint256 id = _mintDefault(owner);
        vm.prank(owner);
        nfa.terminate(id);
        INFA1Core.State memory s = nfa.getState(id);
        assertEq(uint8(s.status), uint8(INFA1Core.Status.Terminated));
    }

    function test_C08_terminate_fromPaused() public {
        uint256 id = _mintDefault(owner);
        vm.prank(owner);
        nfa.pause(id);
        vm.prank(owner);
        nfa.terminate(id);
        INFA1Core.State memory s = nfa.getState(id);
        assertEq(uint8(s.status), uint8(INFA1Core.Status.Terminated));
    }

    function test_C08_terminate_requiresAuth() public {
        uint256 id = _mintDefault(owner);
        vm.prank(alice);
        vm.expectRevert(MinimalNFA.NotOwnerOrApproved.selector);
        nfa.terminate(id);
    }

    // --- C-09: Terminate Irreversibility ---

    function test_C09_terminate_isIrreversible() public {
        uint256 id = _mintDefault(owner);
        vm.startPrank(owner);
        nfa.terminate(id);

        // Cannot pause
        vm.expectRevert(MinimalNFA.NotActive.selector);
        nfa.pause(id);

        // Cannot unpause
        vm.expectRevert(MinimalNFA.NotPaused.selector);
        nfa.unpause(id);

        // Cannot terminate again
        vm.expectRevert(MinimalNFA.AlreadyTerminated.selector);
        nfa.terminate(id);

        vm.stopPrank();
    }

    function test_C09_terminated_cannotUpdateMetadata() public {
        uint256 id = _mintDefault(owner);
        vm.startPrank(owner);
        nfa.terminate(id);
        vm.expectRevert(MinimalNFA.AgentTerminated.selector);
        nfa.updateAgentMetadata(id, defaultMeta);
        vm.stopPrank();
    }

    function test_C09_terminated_cannotSetLogic() public {
        uint256 id = _mintDefault(owner);
        vm.startPrank(owner);
        nfa.terminate(id);
        vm.expectRevert(MinimalNFA.AgentTerminated.selector);
        nfa.setLogicAddress(id, address(logic));
        vm.stopPrank();
    }

    // --- C-10: Paused Agents MUST Be Transferable ---

    function test_C10_pausedAgents_areTransferable() public {
        uint256 id = _mintDefault(owner);
        vm.prank(owner);
        nfa.pause(id);

        // Transfer while paused
        vm.prank(owner);
        nfa.transferFrom(owner, alice, id);
        assertEq(nfa.ownerOf(id), alice);

        // State.owner synced
        INFA1Core.State memory s = nfa.getState(id);
        assertEq(s.owner, alice);
        assertEq(uint8(s.status), uint8(INFA1Core.Status.Paused));
    }

    function test_C10_terminatedAgents_areTransferable() public {
        uint256 id = _mintDefault(owner);
        vm.prank(owner);
        nfa.terminate(id);

        vm.prank(owner);
        nfa.transferFrom(owner, alice, id);
        assertEq(nfa.ownerOf(id), alice);
    }

    // --- C-11: ERC-165 / INFA1Core Interface ---

    function test_C11_supportsInterface_ERC165() public view {
        assertTrue(nfa.supportsInterface(0x01ffc9a7));
    }

    function test_C11_supportsInterface_ERC721() public view {
        assertTrue(nfa.supportsInterface(0x80ac58cd));
    }

    function test_C11_supportsInterface_INFA1Core() public view {
        bytes4 infa1CoreId = type(INFA1Core).interfaceId;
        assertTrue(nfa.supportsInterface(infa1CoreId));
    }

    function test_C11_supportsInterface_invalid() public view {
        assertFalse(nfa.supportsInterface(0xDEADBEEF));
    }

    // --- C-12: updateAgentMetadata ---

    function test_C12_updateAgentMetadata() public {
        uint256 id = _mintDefault(owner);
        INFA1Core.AgentMetadata memory newMeta = INFA1Core.AgentMetadata({
            persona: '{"bold":1.0}',
            experience: "Updated experience",
            voiceHash: "NewVoice",
            animationURI: "ipfs://NewAnim",
            vaultURI: "https://vault.example.com/v2",
            vaultHash: keccak256("vault-content-v2")
        });

        vm.expectEmit(true, false, false, true);
        emit INFA1Core.MetadataUpdated(id, "https://vault.example.com/v2");

        vm.prank(owner);
        nfa.updateAgentMetadata(id, newMeta);

        INFA1Core.AgentMetadata memory stored = nfa.getAgentMetadata(id);
        assertEq(stored.persona, '{"bold":1.0}');
        assertEq(stored.vaultURI, "https://vault.example.com/v2");
    }

    function test_C12_updateAgentMetadata_requiresAuth() public {
        uint256 id = _mintDefault(owner);
        vm.prank(alice);
        vm.expectRevert(MinimalNFA.NotOwnerOrApproved.selector);
        nfa.updateAgentMetadata(id, defaultMeta);
    }

    function test_C12_updateAgentMetadata_worksWhenPaused() public {
        uint256 id = _mintDefault(owner);
        vm.startPrank(owner);
        nfa.pause(id);
        // Paused but not terminated — should allow metadata update
        nfa.updateAgentMetadata(id, defaultMeta);
        vm.stopPrank();
    }

    function test_C12_approvedOperator_canUpdateMetadata() public {
        uint256 id = _mintDefault(owner);
        vm.prank(owner);
        nfa.approve(alice, id);
        vm.prank(alice);
        nfa.updateAgentMetadata(id, defaultMeta); // Should not revert
    }

    function test_C12_approvedForAll_canUpdateMetadata() public {
        uint256 id = _mintDefault(owner);
        vm.prank(owner);
        nfa.setApprovalForAll(alice, true);
        vm.prank(alice);
        nfa.updateAgentMetadata(id, defaultMeta); // Should not revert
    }

    // ============================================================
    //                    TIER 2: LEARNING (L-01 .. L-07)
    // ============================================================

    // --- L-01: LearningState Struct ---

    function test_L01_learningState_initialValues() public {
        uint256 id = _mintDefault(owner);
        INFA1Core.LearningState memory ls = nfa.getLearningState(id);
        assertEq(ls.learningRoot, bytes32(0));
        assertEq(ls.learningVersion, 0);
        assertEq(ls.lastLearningUpdate, 0);
        assertTrue(ls.learningEnabled);
    }

    function test_L01_learningDisabledOnMint() public {
        uint256 id = _mintNoLearning(owner);
        INFA1Core.LearningState memory ls = nfa.getLearningState(id);
        assertFalse(ls.learningEnabled);
    }

    // --- L-02: Version Query ---

    function test_L02_getLearningVersion() public {
        uint256 id = _mintDefault(owner);
        assertEq(nfa.getLearningVersion(id), 0);

        vm.prank(owner);
        nfa.updateLearning(id, "uri1", keccak256("v1"), keccak256("root1"), 1);
        assertEq(nfa.getLearningVersion(id), 1);
    }

    // --- L-03: Version Monotonicity ---

    function test_L03_versionMonotonicity() public {
        uint256 id = _mintDefault(owner);
        vm.startPrank(owner);
        nfa.updateLearning(id, "uri1", keccak256("v1"), keccak256("root1"), 1);
        nfa.updateLearning(id, "uri2", keccak256("v2"), keccak256("root2"), 5);

        // Cannot go backwards
        vm.expectRevert(MinimalNFA.VersionMustIncrease.selector);
        nfa.updateLearning(id, "uri3", keccak256("v3"), keccak256("root3"), 3);

        // Cannot stay same
        vm.expectRevert(MinimalNFA.VersionMustIncrease.selector);
        nfa.updateLearning(id, "uri4", keccak256("v4"), keccak256("root4"), 5);

        // Can continue forward
        nfa.updateLearning(id, "uri5", keccak256("v5"), keccak256("root5"), 6);
        vm.stopPrank();

        assertEq(nfa.getLearningVersion(id), 6);
    }

    // --- L-04: Learning Queries ---

    function test_L04_getLearningRoot() public {
        uint256 id = _mintDefault(owner);
        bytes32 root = keccak256("learning-root");
        vm.prank(owner);
        nfa.updateLearning(id, "uri", keccak256("vault"), root, 1);
        assertEq(nfa.getLearningRoot(id), root);
    }

    function test_L04_isLearningEnabled() public {
        uint256 idEnabled = _mintDefault(owner);
        uint256 idDisabled = _mintNoLearning(owner);
        assertTrue(nfa.isLearningEnabled(idEnabled));
        assertFalse(nfa.isLearningEnabled(idDisabled));
    }

    function test_L04_getLastLearningUpdate() public {
        uint256 id = _mintDefault(owner);
        assertEq(nfa.getLastLearningUpdate(id), 0);

        vm.warp(1000);
        vm.prank(owner);
        nfa.updateLearning(id, "uri", keccak256("v"), keccak256("r"), 1);
        assertEq(nfa.getLastLearningUpdate(id), 1000);
    }

    // --- L-05: LearningUpdated Event ---

    function test_L05_learningUpdated_event() public {
        uint256 id = _mintDefault(owner);
        bytes32 newRoot = keccak256("new-root");

        vm.expectEmit(true, true, true, true);
        emit INFA1Core.LearningUpdated(id, bytes32(0), newRoot, 1);

        vm.prank(owner);
        nfa.updateLearning(id, "uri", keccak256("v"), newRoot, 1);
    }

    function test_L05_learningUpdated_syncsVault() public {
        uint256 id = _mintDefault(owner);
        bytes32 newHash = keccak256("new-vault");

        vm.prank(owner);
        nfa.updateLearning(id, "https://new-vault-uri", newHash, keccak256("root"), 1);

        INFA1Core.AgentMetadata memory m = nfa.getAgentMetadata(id);
        assertEq(m.vaultURI, "https://new-vault-uri");
        assertEq(m.vaultHash, newHash);
    }

    // --- L-06: Learning Authorization ---

    function test_L06_owner_canUpdateLearning() public {
        uint256 id = _mintDefault(owner);
        vm.prank(owner);
        nfa.updateLearning(id, "uri", keccak256("v"), keccak256("r"), 1);
        assertEq(nfa.getLearningVersion(id), 1);
    }

    function test_L06_updater_canUpdateLearning() public {
        uint256 id = _mintDefault(owner);
        vm.prank(owner);
        nfa.setLearningUpdater(id, updater);

        vm.prank(updater);
        nfa.updateLearning(id, "uri", keccak256("v"), keccak256("r"), 1);
        assertEq(nfa.getLearningVersion(id), 1);
    }

    function test_L06_unauthorized_cannotUpdateLearning() public {
        uint256 id = _mintDefault(owner);
        vm.prank(alice);
        vm.expectRevert(MinimalNFA.NotLearningAuthorized.selector);
        nfa.updateLearning(id, "uri", keccak256("v"), keccak256("r"), 1);
    }

    function test_L06_learningDisabled_reverts() public {
        uint256 id = _mintNoLearning(owner);
        vm.prank(owner);
        vm.expectRevert(MinimalNFA.LearningNotEnabled.selector);
        nfa.updateLearning(id, "uri", keccak256("v"), keccak256("r"), 1);
    }

    function test_L06_setLearningUpdater_requiresAuth() public {
        uint256 id = _mintDefault(owner);
        vm.prank(alice);
        vm.expectRevert(MinimalNFA.NotOwnerOrApproved.selector);
        nfa.setLearningUpdater(id, updater);
    }

    function test_L06_revokeUpdater() public {
        uint256 id = _mintDefault(owner);
        vm.startPrank(owner);
        nfa.setLearningUpdater(id, updater);
        nfa.setLearningUpdater(id, address(0)); // Revoke
        vm.stopPrank();

        vm.prank(updater);
        vm.expectRevert(MinimalNFA.NotLearningAuthorized.selector);
        nfa.updateLearning(id, "uri", keccak256("v"), keccak256("r"), 1);
    }

    // --- L-07: Learning Disabled After Terminate ---

    function test_L07_terminate_disablesLearning() public {
        uint256 id = _mintDefault(owner);
        vm.startPrank(owner);
        nfa.updateLearning(id, "uri", keccak256("v"), keccak256("r"), 1);
        nfa.terminate(id);
        vm.stopPrank();

        assertFalse(nfa.isLearningEnabled(id));
    }

    function test_L07_terminated_cannotUpdateLearning() public {
        uint256 id = _mintDefault(owner);
        vm.startPrank(owner);
        nfa.terminate(id);
        vm.expectRevert(MinimalNFA.AgentTerminated.selector);
        nfa.updateLearning(id, "uri", keccak256("v"), keccak256("r"), 1);
        vm.stopPrank();
    }

    // ============================================================
    //                    TIER 3: ACTIONS (A-01 .. A-07)
    // ============================================================

    // --- A-01: executeAction ---

    function test_A01_executeAction_basic() public {
        uint256 id = _mintDefault(owner);
        vm.prank(owner);
        nfa.setLogicAddress(id, address(logic));

        bytes memory callData = abi.encodeWithSelector(MockLogic.doSomething.selector, uint256(42));

        vm.prank(owner);
        bytes memory result = nfa.executeAction(id, callData);

        uint256 decoded = abi.decode(result, (uint256));
        assertEq(decoded, 84); // 42 * 2
    }

    function test_A01_executeAction_updatesTimestamp() public {
        uint256 id = _mintDefault(owner);
        vm.prank(owner);
        nfa.setLogicAddress(id, address(logic));

        vm.warp(5000);
        vm.prank(owner);
        nfa.executeAction(id, abi.encodeWithSelector(MockLogic.doSomething.selector, uint256(1)));

        INFA1Core.State memory s = nfa.getState(id);
        assertEq(s.lastActionTimestamp, 5000);
    }

    // --- A-02: Action Authorization ---

    function test_A02_executeAction_requiresAuth() public {
        uint256 id = _mintDefault(owner);
        vm.prank(owner);
        nfa.setLogicAddress(id, address(logic));

        vm.prank(alice);
        vm.expectRevert(MinimalNFA.NotOwnerOrApproved.selector);
        nfa.executeAction(id, abi.encodeWithSelector(MockLogic.doSomething.selector, uint256(1)));
    }

    function test_A02_approved_canExecuteAction() public {
        uint256 id = _mintDefault(owner);
        vm.prank(owner);
        nfa.setLogicAddress(id, address(logic));
        vm.prank(owner);
        nfa.approve(alice, id);

        vm.prank(alice);
        nfa.executeAction(id, abi.encodeWithSelector(MockLogic.doSomething.selector, uint256(1)));
    }

    // --- A-03: setLogicAddress ---

    function test_A03_setLogicAddress() public {
        uint256 id = _mintDefault(owner);

        vm.expectEmit(true, true, true, false);
        emit INFA1Core.LogicUpgraded(id, address(0), address(logic));

        vm.prank(owner);
        nfa.setLogicAddress(id, address(logic));

        INFA1Core.State memory s = nfa.getState(id);
        assertEq(s.logicAddress, address(logic));
    }

    function test_A03_setLogicAddress_toZero() public {
        uint256 id = _mintDefault(owner);
        vm.startPrank(owner);
        nfa.setLogicAddress(id, address(logic));
        nfa.setLogicAddress(id, address(0)); // Disable logic
        vm.stopPrank();

        INFA1Core.State memory s = nfa.getState(id);
        assertEq(s.logicAddress, address(0));
    }

    function test_A03_setLogicAddress_requiresAuth() public {
        uint256 id = _mintDefault(owner);
        vm.prank(alice);
        vm.expectRevert(MinimalNFA.NotOwnerOrApproved.selector);
        nfa.setLogicAddress(id, address(logic));
    }

    function test_A03_setLogicAddress_worksWhenPaused() public {
        uint256 id = _mintDefault(owner);
        vm.startPrank(owner);
        nfa.pause(id);
        nfa.setLogicAddress(id, address(logic)); // Paused but not terminated
        vm.stopPrank();
    }

    // --- A-04: fundAgent ---

    function test_A04_fundAgent() public {
        uint256 id = _mintDefault(owner);

        vm.expectEmit(true, true, false, true);
        emit INFA1Core.AgentFunded(id, alice, 1 ether);

        vm.deal(alice, 10 ether);
        vm.prank(alice);
        nfa.fundAgent{value: 1 ether}(id);

        INFA1Core.State memory s = nfa.getState(id);
        assertEq(s.balance, 1 ether);
    }

    function test_A04_fundAgent_permissionless() public {
        uint256 id = _mintDefault(owner);
        // Anyone can fund
        vm.deal(bob, 1 ether);
        vm.prank(bob);
        nfa.fundAgent{value: 0.5 ether}(id);
        assertEq(nfa.getState(id).balance, 0.5 ether);
    }

    function test_A04_fundAgent_zeroReverts() public {
        uint256 id = _mintDefault(owner);
        vm.expectRevert(MinimalNFA.ZeroFunding.selector);
        nfa.fundAgent{value: 0}(id);
    }

    function test_A04_fundAgent_accumulates() public {
        uint256 id = _mintDefault(owner);
        vm.deal(alice, 10 ether);
        vm.startPrank(alice);
        nfa.fundAgent{value: 1 ether}(id);
        nfa.fundAgent{value: 2 ether}(id);
        vm.stopPrank();
        assertEq(nfa.getState(id).balance, 3 ether);
    }

    function test_A04_fundAgent_nonexistentReverts() public {
        vm.expectRevert(MinimalNFA.AgentDoesNotExist.selector);
        nfa.fundAgent{value: 1 ether}(999);
    }

    // --- A-05: Gas Capping ---

    function test_A05_gasLimit_constant() public view {
        assertEq(nfa.ACTION_GAS_LIMIT(), 500_000);
    }

    // --- A-06: Action Only When Active ---

    function test_A06_executeAction_revertsWhenPaused() public {
        uint256 id = _mintDefault(owner);
        vm.startPrank(owner);
        nfa.setLogicAddress(id, address(logic));
        nfa.pause(id);
        vm.expectRevert(MinimalNFA.AgentNotActive.selector);
        nfa.executeAction(id, abi.encodeWithSelector(MockLogic.doSomething.selector, uint256(1)));
        vm.stopPrank();
    }

    function test_A06_executeAction_revertsWhenTerminated() public {
        uint256 id = _mintDefault(owner);
        vm.startPrank(owner);
        nfa.setLogicAddress(id, address(logic));
        nfa.terminate(id);
        vm.expectRevert(MinimalNFA.AgentNotActive.selector);
        nfa.executeAction(id, abi.encodeWithSelector(MockLogic.doSomething.selector, uint256(1)));
        vm.stopPrank();
    }

    function test_A06_executeAction_revertsWithoutLogic() public {
        uint256 id = _mintDefault(owner);
        vm.prank(owner);
        vm.expectRevert(MinimalNFA.NoLogicContract.selector);
        nfa.executeAction(id, abi.encodeWithSelector(MockLogic.doSomething.selector, uint256(1)));
    }

    function test_A06_executeAction_revertsOnLogicRevert() public {
        uint256 id = _mintDefault(owner);
        vm.prank(owner);
        nfa.setLogicAddress(id, address(logic));
        vm.prank(owner);
        vm.expectRevert(MinimalNFA.ActionFailed.selector);
        nfa.executeAction(id, abi.encodeWithSelector(MockLogic.alwaysReverts.selector));
    }

    // --- A-07: ActionExecuted Event ---

    function test_A07_actionExecuted_event() public {
        uint256 id = _mintDefault(owner);
        vm.prank(owner);
        nfa.setLogicAddress(id, address(logic));

        bytes memory callData = abi.encodeWithSelector(MockLogic.doSomething.selector, uint256(7));

        vm.prank(owner);
        vm.recordLogs();
        nfa.executeAction(id, callData);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        // Find ActionExecuted event
        bool found;
        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == keccak256("ActionExecuted(uint256,bytes)")) {
                assertEq(entries[i].topics[1], bytes32(uint256(id)));
                found = true;
                break;
            }
        }
        assertTrue(found, "ActionExecuted event not emitted");
    }

    // ============================================================
    //                    REENTRANCY GUARD
    // ============================================================

    function test_reentrancy_executeAction() public {
        uint256 id = _mintDefault(owner);
        MockLogicReentrant reentrant = new MockLogicReentrant(address(nfa), id);

        vm.prank(owner);
        nfa.setLogicAddress(id, address(reentrant));

        // The reentrant logic calls back into executeAction
        // ReentrancyGuard should cause the inner call to fail,
        // which propagates as ActionFailed
        vm.prank(owner);
        vm.expectRevert(MinimalNFA.ActionFailed.selector);
        nfa.executeAction(id, "");
    }

    // ============================================================
    //                    MULTI-AGENT ISOLATION
    // ============================================================

    function test_multiAgent_stateIsolation() public {
        uint256 id1 = _mintDefault(owner);
        uint256 id2 = _mintDefault(alice);

        // Pause one, other remains active
        vm.prank(owner);
        nfa.pause(id1);

        assertEq(uint8(nfa.getState(id1).status), uint8(INFA1Core.Status.Paused));
        assertEq(uint8(nfa.getState(id2).status), uint8(INFA1Core.Status.Active));
    }

    function test_multiAgent_learningIsolation() public {
        uint256 id1 = _mintDefault(owner);
        uint256 id2 = _mintDefault(owner);

        vm.prank(owner);
        nfa.updateLearning(id1, "uri1", keccak256("v1"), keccak256("root1"), 10);

        assertEq(nfa.getLearningVersion(id1), 10);
        assertEq(nfa.getLearningVersion(id2), 0); // Unaffected
    }

    // ============================================================
    //                    SEQUENTIAL TOKEN IDs
    // ============================================================

    function test_tokenIds_sequential() public {
        uint256 id1 = _mintDefault(owner);
        uint256 id2 = _mintDefault(alice);
        uint256 id3 = _mintDefault(bob);
        assertEq(id1, 1);
        assertEq(id2, 2);
        assertEq(id3, 3);
    }
}
