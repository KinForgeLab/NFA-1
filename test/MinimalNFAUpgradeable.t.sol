// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../contracts/examples/MinimalNFAUpgradeable.sol";
import "../contracts/examples/MyAgentUpgradeable.sol";
import "../contracts/interfaces/INFA1Core.sol";
import "../contracts/tools/NFA1Verifier.sol";
import "./mocks/MockLogic.sol";

/// @title MinimalNFAUpgradeable Test Suite
/// @notice Tests proxy deployment, INFA1Core compliance through proxy,
///         upgrade scenarios, and NFA1Verifier compatibility.
contract MinimalNFAUpgradeableTest is Test {
    MinimalNFAUpgradeable public implementation;
    MinimalNFAUpgradeable public nfa; // proxy cast
    ERC1967Proxy public proxy;
    NFA1Verifier public verifier;
    MockLogic public logic;

    address public constant OWNER = address(0xA11CE);
    address public constant ALICE = address(0xBEEF);
    address public constant BOB = address(0xCAFE);

    INFA1Core.AgentMetadata internal defaultMeta;

    function setUp() public {
        // Deploy implementation
        implementation = new MinimalNFAUpgradeable();

        // Deploy proxy
        bytes memory initData = abi.encodeCall(
            MinimalNFAUpgradeable.initialize,
            (OWNER)
        );
        proxy = new ERC1967Proxy(address(implementation), initData);
        nfa = MinimalNFAUpgradeable(address(proxy));

        // Deploy verifier and logic
        verifier = new NFA1Verifier();
        logic = new MockLogic();

        defaultMeta = INFA1Core.AgentMetadata({
            persona: '{"calm":0.8}',
            experience: "Test agent",
            voiceHash: "",
            animationURI: "",
            vaultURI: "vault://test",
            vaultHash: keccak256("test")
        });
    }

    // ============================================================
    //                 PROXY DEPLOYMENT & INITIALIZATION
    // ============================================================

    function test_proxy_ownerIsSet() public view {
        assertEq(nfa.owner(), OWNER);
    }

    function test_proxy_nameAndSymbol() public view {
        assertEq(nfa.name(), "MinimalNFA");
        assertEq(nfa.symbol(), "NFA");
    }

    function test_proxy_cannotReinitialize() public {
        vm.expectRevert();
        nfa.initialize(ALICE);
    }

    function test_implementation_cannotInitialize() public {
        vm.expectRevert();
        implementation.initialize(ALICE);
    }

    // ============================================================
    //                 INFA1CORE VIA PROXY — MINTING
    // ============================================================

    function test_proxy_mint() public {
        uint256 id = nfa.mint(ALICE, defaultMeta, true);
        assertEq(id, 1);
        assertEq(nfa.ownerOf(1), ALICE);
    }

    function test_proxy_mintSequentialIds() public {
        uint256 id1 = nfa.mint(ALICE, defaultMeta, false);
        uint256 id2 = nfa.mint(BOB, defaultMeta, false);
        assertEq(id1, 1);
        assertEq(id2, 2);
    }

    // ============================================================
    //                 INFA1CORE VIA PROXY — LIFECYCLE
    // ============================================================

    function test_proxy_pause() public {
        uint256 id = nfa.mint(OWNER, defaultMeta, false);
        vm.prank(OWNER);
        nfa.pause(id);
        assertEq(uint8(nfa.getState(id).status), uint8(INFA1Core.Status.Paused));
    }

    function test_proxy_unpause() public {
        uint256 id = nfa.mint(OWNER, defaultMeta, false);
        vm.startPrank(OWNER);
        nfa.pause(id);
        nfa.unpause(id);
        vm.stopPrank();
        assertEq(uint8(nfa.getState(id).status), uint8(INFA1Core.Status.Active));
    }

    function test_proxy_terminate() public {
        uint256 id = nfa.mint(OWNER, defaultMeta, false);
        vm.prank(OWNER);
        nfa.terminate(id);
        assertEq(uint8(nfa.getState(id).status), uint8(INFA1Core.Status.Terminated));
    }

    function test_proxy_terminateIrreversible() public {
        uint256 id = nfa.mint(OWNER, defaultMeta, false);
        vm.startPrank(OWNER);
        nfa.terminate(id);
        vm.expectRevert();
        nfa.unpause(id);
        vm.stopPrank();
    }

    // ============================================================
    //                 INFA1CORE VIA PROXY — FUNDING
    // ============================================================

    function test_proxy_fundAgent() public {
        uint256 id = nfa.mint(ALICE, defaultMeta, false);
        vm.deal(BOB, 1 ether);
        vm.prank(BOB);
        nfa.fundAgent{value: 0.5 ether}(id);
        assertEq(nfa.getState(id).balance, 0.5 ether);
    }

    // ============================================================
    //                 INFA1CORE VIA PROXY — ACTIONS
    // ============================================================

    function test_proxy_executeAction() public {
        uint256 id = nfa.mint(OWNER, defaultMeta, false);
        vm.startPrank(OWNER);
        nfa.setLogicAddress(id, address(logic));
        bytes memory result = nfa.executeAction(id, abi.encodeCall(MockLogic.doSomething, (42)));
        vm.stopPrank();
        assertEq(abi.decode(result, (uint256)), 84); // doSomething returns value * 2
    }

    // ============================================================
    //                 INFA1CORE VIA PROXY — LEARNING
    // ============================================================

    function test_proxy_updateLearning() public {
        uint256 id = nfa.mint(OWNER, defaultMeta, true);
        vm.prank(OWNER);
        nfa.updateLearning(id, "vault://v2", keccak256("v2"), keccak256("root2"), 1);
        assertEq(nfa.getLearningVersion(id), 1);
        assertEq(nfa.getLearningRoot(id), keccak256("root2"));
        assertTrue(nfa.isLearningEnabled(id));
    }

    function test_proxy_versionMustIncrease() public {
        uint256 id = nfa.mint(OWNER, defaultMeta, true);
        vm.startPrank(OWNER);
        nfa.updateLearning(id, "v1", keccak256("v1"), keccak256("r1"), 5);
        vm.expectRevert();
        nfa.updateLearning(id, "v2", keccak256("v2"), keccak256("r2"), 3);
        vm.stopPrank();
    }

    function test_proxy_learningUpdater() public {
        uint256 id = nfa.mint(OWNER, defaultMeta, true);
        vm.prank(OWNER);
        nfa.setLearningUpdater(id, ALICE);

        vm.prank(ALICE);
        nfa.updateLearning(id, "v1", keccak256("v1"), keccak256("r1"), 1);
        assertEq(nfa.getLearningVersion(id), 1);
    }

    // ============================================================
    //                 INFA1CORE VIA PROXY — METADATA
    // ============================================================

    function test_proxy_updateMetadata() public {
        uint256 id = nfa.mint(OWNER, defaultMeta, false);
        INFA1Core.AgentMetadata memory newMeta = INFA1Core.AgentMetadata({
            persona: '{"bold":0.9}',
            experience: "Updated",
            voiceHash: "hash",
            animationURI: "anim",
            vaultURI: "vault://new",
            vaultHash: keccak256("new")
        });
        vm.prank(OWNER);
        nfa.updateAgentMetadata(id, newMeta);
        assertEq(nfa.getAgentMetadata(id).experience, "Updated");
    }

    // ============================================================
    //                 INFA1CORE VIA PROXY — TRANSFER
    // ============================================================

    function test_proxy_transferSyncsOwner() public {
        uint256 id = nfa.mint(OWNER, defaultMeta, false);
        vm.prank(OWNER);
        nfa.transferFrom(OWNER, ALICE, id);
        assertEq(nfa.ownerOf(id), ALICE);
        assertEq(nfa.getState(id).owner, ALICE);
    }

    function test_proxy_pausedAgentTransferable() public {
        uint256 id = nfa.mint(OWNER, defaultMeta, false);
        vm.startPrank(OWNER);
        nfa.pause(id);
        nfa.transferFrom(OWNER, ALICE, id);
        vm.stopPrank();
        assertEq(nfa.ownerOf(id), ALICE);
    }

    // ============================================================
    //                 ERC-165 VIA PROXY
    // ============================================================

    function test_proxy_supportsINFA1Core() public view {
        assertTrue(nfa.supportsInterface(type(INFA1Core).interfaceId));
    }

    function test_proxy_supportsERC721() public view {
        assertTrue(nfa.supportsInterface(0x80ac58cd));
    }

    function test_proxy_supportsERC165() public view {
        assertTrue(nfa.supportsInterface(0x01ffc9a7));
    }

    // ============================================================
    //                 NFA1VERIFIER ON PROXY
    // ============================================================

    function test_verifier_quickCheckProxy() public view {
        (bool isNFA, uint8 tier) = verifier.quickCheck(address(proxy));
        assertTrue(isNFA);
        assertEq(tier, 3);
    }

    function test_verifier_fullAuditProxy() public view {
        NFA1Verifier.AuditReport memory report = verifier.fullAudit(address(proxy));
        assertTrue(report.isContract);
        assertTrue(report.tier1.c01_erc721);
        assertTrue(report.tier1.c11_infa1core);
        assertTrue(report.tier2.l01_learningState);
        assertTrue(report.tier3.a04_fundAgent);
        assertEq(keccak256(bytes(report.verdict)), keccak256("TIER3"));
    }

    // ============================================================
    //                 UPGRADE SCENARIO
    // ============================================================

    function test_upgrade_statePreserved() public {
        // Mint an agent before upgrade
        uint256 id = nfa.mint(OWNER, defaultMeta, true);
        vm.deal(ALICE, 1 ether);
        vm.prank(ALICE);
        nfa.fundAgent{value: 0.5 ether}(id);
        vm.prank(OWNER);
        nfa.updateLearning(id, "v1", keccak256("v1"), keccak256("r1"), 1);

        // Record state before upgrade
        uint256 balanceBefore = nfa.getState(id).balance;
        uint256 versionBefore = nfa.getLearningVersion(id);
        address ownerBefore = nfa.ownerOf(id);

        // Deploy new implementation and upgrade
        MinimalNFAUpgradeable newImpl = new MinimalNFAUpgradeable();
        vm.prank(OWNER);
        nfa.upgradeToAndCall(address(newImpl), "");

        // Verify state preserved after upgrade
        assertEq(nfa.getState(id).balance, balanceBefore);
        assertEq(nfa.getLearningVersion(id), versionBefore);
        assertEq(nfa.ownerOf(id), ownerBefore);
        assertEq(nfa.owner(), OWNER);
    }

    function test_upgrade_onlyOwner() public {
        MinimalNFAUpgradeable newImpl = new MinimalNFAUpgradeable();
        vm.prank(ALICE);
        vm.expectRevert();
        nfa.upgradeToAndCall(address(newImpl), "");
    }

    function test_upgrade_newFunctionality() public {
        // Mint before upgrade
        uint256 id = nfa.mint(OWNER, defaultMeta, true);

        // Upgrade
        MinimalNFAUpgradeable newImpl = new MinimalNFAUpgradeable();
        vm.prank(OWNER);
        nfa.upgradeToAndCall(address(newImpl), "");

        // Existing functions still work after upgrade
        vm.prank(OWNER);
        nfa.pause(id);
        assertEq(uint8(nfa.getState(id).status), uint8(INFA1Core.Status.Paused));
    }

    // ============================================================
    //                 PERMISSION BOUNDARIES
    // ============================================================

    function test_proxy_onlyOwnerCanPause() public {
        uint256 id = nfa.mint(OWNER, defaultMeta, false);
        vm.prank(ALICE);
        vm.expectRevert();
        nfa.pause(id);
    }

    function test_proxy_onlyOwnerCanTerminate() public {
        uint256 id = nfa.mint(OWNER, defaultMeta, false);
        vm.prank(ALICE);
        vm.expectRevert();
        nfa.terminate(id);
    }

    function test_proxy_terminatedCannotUpdateMetadata() public {
        uint256 id = nfa.mint(OWNER, defaultMeta, false);
        vm.startPrank(OWNER);
        nfa.terminate(id);
        vm.expectRevert();
        nfa.updateAgentMetadata(id, defaultMeta);
        vm.stopPrank();
    }

    function test_proxy_terminatedCannotUpdateLearning() public {
        uint256 id = nfa.mint(OWNER, defaultMeta, true);
        vm.startPrank(OWNER);
        nfa.terminate(id);
        vm.expectRevert();
        nfa.updateLearning(id, "v", keccak256("v"), keccak256("r"), 1);
        vm.stopPrank();
    }

    function test_proxy_fundAgentPermissionless() public {
        uint256 id = nfa.mint(OWNER, defaultMeta, false);
        vm.deal(BOB, 1 ether);
        vm.prank(BOB);
        nfa.fundAgent{value: 0.1 ether}(id);
        assertEq(nfa.getState(id).balance, 0.1 ether);
    }
}

/// @title MyAgentUpgradeable Test Suite
/// @notice Tests the upgradeable deployment template via proxy
contract MyAgentUpgradeableTest is Test {
    MyAgentUpgradeable public implementation;
    MyAgentUpgradeable public nfa;
    ERC1967Proxy public proxy;
    NFA1Verifier public verifier;

    address public constant OWNER = address(0xA11CE);
    address public constant ALICE = address(0xBEEF);

    INFA1Core.AgentMetadata internal defaultMeta;

    function setUp() public {
        implementation = new MyAgentUpgradeable();
        bytes memory initData = abi.encodeCall(
            MyAgentUpgradeable.initializeMyAgent,
            (OWNER)
        );
        proxy = new ERC1967Proxy(address(implementation), initData);
        nfa = MyAgentUpgradeable(address(proxy));
        verifier = new NFA1Verifier();

        defaultMeta = INFA1Core.AgentMetadata({
            persona: '{"calm":0.5}',
            experience: "Template test",
            voiceHash: "",
            animationURI: "",
            vaultURI: "vault://tmpl",
            vaultHash: keccak256("tmpl")
        });
    }

    function test_myAgent_nameOverride() public view {
        assertEq(nfa.name(), "My NFA Collection");
        assertEq(nfa.symbol(), "MNFA");
    }

    function test_myAgent_ownerSet() public view {
        assertEq(nfa.owner(), OWNER);
    }

    function test_myAgent_mintNotOpenByDefault() public {
        vm.deal(ALICE, 1 ether);
        vm.prank(ALICE);
        vm.expectRevert();
        nfa.publicMint{value: 0.01 ether}(defaultMeta, true);
    }

    function test_myAgent_setMintOpen() public {
        vm.prank(OWNER);
        nfa.setMintOpen(true);
        assertTrue(nfa.mintOpen());
    }

    function test_myAgent_publicMint() public {
        vm.prank(OWNER);
        nfa.setMintOpen(true);

        vm.deal(ALICE, 1 ether);
        vm.prank(ALICE);
        uint256 id = nfa.publicMint{value: 0.01 ether}(defaultMeta, true);
        assertEq(id, 1);
        assertEq(nfa.ownerOf(1), ALICE);
        assertEq(nfa.totalMinted(), 1);
        assertEq(nfa.mintCount(ALICE), 1);
    }

    function test_myAgent_publicMintInsufficientPayment() public {
        vm.prank(OWNER);
        nfa.setMintOpen(true);

        vm.deal(ALICE, 1 ether);
        vm.prank(ALICE);
        vm.expectRevert();
        nfa.publicMint{value: 0.001 ether}(defaultMeta, true);
    }

    function test_myAgent_ownerMintFree() public {
        vm.prank(OWNER);
        uint256 id = nfa.ownerMint(ALICE, defaultMeta, true);
        assertEq(id, 1);
        assertEq(nfa.ownerOf(1), ALICE);
        assertEq(nfa.totalMinted(), 1);
    }

    function test_myAgent_ownerMintNotByNonOwner() public {
        vm.prank(ALICE);
        vm.expectRevert();
        nfa.ownerMint(ALICE, defaultMeta, true);
    }

    function test_myAgent_withdraw() public {
        vm.prank(OWNER);
        nfa.setMintOpen(true);

        vm.deal(ALICE, 1 ether);
        vm.prank(ALICE);
        nfa.publicMint{value: 0.01 ether}(defaultMeta, true);

        uint256 ownerBalBefore = OWNER.balance;
        vm.prank(OWNER);
        nfa.withdraw();
        assertEq(OWNER.balance, ownerBalBefore + 0.01 ether);
    }

    function test_myAgent_verifierQuickCheck() public view {
        (bool isNFA, uint8 tier) = verifier.quickCheck(address(proxy));
        assertTrue(isNFA);
        assertEq(tier, 3);
    }

    function test_myAgent_cannotReinitialize() public {
        vm.expectRevert();
        nfa.initializeMyAgent(ALICE);
    }

    function test_myAgent_perWalletLimit() public {
        vm.prank(OWNER);
        nfa.setMintOpen(true);

        vm.deal(ALICE, 10 ether);
        vm.startPrank(ALICE);
        for (uint256 i = 0; i < 5; i++) {
            nfa.publicMint{value: 0.01 ether}(defaultMeta, false);
        }
        // 6th mint should fail (MAX_PER_WALLET = 5)
        vm.expectRevert();
        nfa.publicMint{value: 0.01 ether}(defaultMeta, false);
        vm.stopPrank();
    }

    function test_myAgent_upgradePreservesState() public {
        vm.prank(OWNER);
        nfa.setMintOpen(true);

        vm.deal(ALICE, 1 ether);
        vm.prank(ALICE);
        nfa.publicMint{value: 0.01 ether}(defaultMeta, true);

        // Upgrade
        MyAgentUpgradeable newImpl = new MyAgentUpgradeable();
        vm.prank(OWNER);
        nfa.upgradeToAndCall(address(newImpl), "");

        // State preserved
        assertEq(nfa.totalMinted(), 1);
        assertEq(nfa.ownerOf(1), ALICE);
        assertTrue(nfa.mintOpen());
    }
}
