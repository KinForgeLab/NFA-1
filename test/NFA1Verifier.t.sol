// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/tools/NFA1Verifier.sol";
import "../contracts/examples/MinimalNFA.sol";
import "../contracts/interfaces/INFA1Core.sol";

/// @title NFA1Verifier Tests — Verify the on-chain compliance probe
contract NFA1VerifierTest is Test {
    NFA1Verifier public verifier;
    MinimalNFA public nfa;

    INFA1Core.AgentMetadata internal defaultMeta;

    function setUp() public {
        verifier = new NFA1Verifier();
        nfa = new MinimalNFA();

        defaultMeta = INFA1Core.AgentMetadata({
            persona: '{"calm":0.8}',
            experience: "Verifier test agent",
            voiceHash: "voice",
            animationURI: "anim",
            vaultURI: "https://vault.example.com/1",
            vaultHash: keccak256("vault")
        });

        // Mint token 1 so probes have valid data
        nfa.mint(address(this), defaultMeta, true);
    }

    // ============================================================
    //                    INTERFACE ID MATCH
    // ============================================================

    /// @notice Verifier's computed INFA1CORE_ID must match Solidity's type().interfaceId
    function test_interfaceId_matchesSolidity() public view {
        bytes4 solidityId = type(INFA1Core).interfaceId;
        bytes4 verifierId = verifier.INFA1CORE_ID();
        assertEq(verifierId, solidityId, "INFA1CORE_ID mismatch between verifier and solidity");
    }

    // ============================================================
    //                    QUICK CHECK
    // ============================================================

    function test_quickCheck_validNFA() public view {
        (bool isNFA, uint8 tier) = verifier.quickCheck(address(nfa));
        assertTrue(isNFA);
        assertEq(tier, 3); // MinimalNFA implements Tier 1+2+3
    }

    function test_quickCheck_EOA() public view {
        (bool isNFA, uint8 tier) = verifier.quickCheck(address(0xDEAD));
        assertFalse(isNFA);
        assertEq(tier, 0);
    }

    function test_quickCheck_nonNFAContract() public view {
        // Verifier itself is a contract but not NFA-1
        (bool isNFA, uint8 tier) = verifier.quickCheck(address(verifier));
        assertFalse(isNFA);
        assertEq(tier, 0);
    }

    // ============================================================
    //                    FULL AUDIT — Tier 1
    // ============================================================

    function test_fullAudit_tier1() public view {
        NFA1Verifier.AuditReport memory report = verifier.fullAudit(address(nfa));

        assertTrue(report.isContract);
        assertEq(report.target, address(nfa));

        // Tier 1 checks
        assertTrue(report.tier1.c01_erc721, "C-01: ERC-721");
        assertTrue(report.tier1.c02_statusEnum, "C-02: Status enum");
        assertTrue(report.tier1.c05_getState, "C-05: getState");
        assertTrue(report.tier1.c06_getAgentMetadata, "C-06: getAgentMetadata");
        assertTrue(report.tier1.c08_lifecycleFunctions, "C-08: Lifecycle");
        assertTrue(report.tier1.c11_erc165, "C-11: ERC-165");
        assertTrue(report.tier1.c11_infa1core, "C-11: INFA1Core");
        assertTrue(report.tier1.c12_updateMetadata, "C-12: updateMetadata");

        assertEq(report.tier1.passCount, 8);
        assertEq(report.tier1.totalProbeable, 8);
    }

    // ============================================================
    //                    FULL AUDIT — Tier 2
    // ============================================================

    function test_fullAudit_tier2() public view {
        NFA1Verifier.AuditReport memory report = verifier.fullAudit(address(nfa));

        assertTrue(report.tier2.l01_learningState, "L-01: LearningState");
        assertTrue(report.tier2.l02_versionQuery, "L-02: Version query");
        assertTrue(report.tier2.l04_learningQueries, "L-04: All learning queries");

        assertEq(report.tier2.passCount, 3);
        assertEq(report.tier2.totalProbeable, 3);
    }

    // ============================================================
    //                    FULL AUDIT — Tier 3
    // ============================================================

    function test_fullAudit_tier3() public view {
        NFA1Verifier.AuditReport memory report = verifier.fullAudit(address(nfa));

        assertTrue(report.tier3.a01_executeAction, "A-01: executeAction");
        assertTrue(report.tier3.a03_setLogicAddress, "A-03: setLogicAddress");
        assertTrue(report.tier3.a04_fundAgent, "A-04: fundAgent");

        assertEq(report.tier3.passCount, 3);
        assertEq(report.tier3.totalProbeable, 3);
    }

    // ============================================================
    //                    FULL AUDIT — Verdict
    // ============================================================

    function test_fullAudit_verdict_tier3() public view {
        NFA1Verifier.AuditReport memory report = verifier.fullAudit(address(nfa));
        assertEq(report.verdict, "TIER3");
    }

    function test_fullAudit_verdict_notContract() public view {
        NFA1Verifier.AuditReport memory report = verifier.fullAudit(address(0xDEAD));
        assertFalse(report.isContract);
        assertEq(report.verdict, "NOT_CONTRACT");
    }

    function test_fullAudit_verdict_notNFA() public view {
        NFA1Verifier.AuditReport memory report = verifier.fullAudit(address(verifier));
        assertEq(report.verdict, "NOT_NFA1");
    }

    // ============================================================
    //                    EXTENSIONS — MinimalNFA has none
    // ============================================================

    function test_fullAudit_extensions_allFalse() public view {
        NFA1Verifier.AuditReport memory report = verifier.fullAudit(address(nfa));

        assertFalse(report.extensions.e01_lineage, "E-01 should be false");
        assertFalse(report.extensions.e02_payment, "E-02 should be false");
        assertFalse(report.extensions.e03_identity, "E-03 should be false");
        assertFalse(report.extensions.e04_receipts, "E-04 should be false");
        assertFalse(report.extensions.e05_compliance, "E-05 should be false");
        assertFalse(report.extensions.e06_learningModules, "E-06 should be false");
        assertFalse(report.extensions.e07_proofOfPrompt, "E-07 should be false");
        assertFalse(report.extensions.e08_circuitBreaker, "E-08 should be false");
    }

    // ============================================================
    //                    TIMESTAMP
    // ============================================================

    function test_fullAudit_timestamp() public {
        vm.warp(12345);
        NFA1Verifier.AuditReport memory report = verifier.fullAudit(address(nfa));
        assertEq(report.timestamp, 12345);
    }

    // ============================================================
    //                    _hasFunction EDGE CASES
    // ============================================================

    /// @notice Verifier correctly detects function that exists but reverts (auth check)
    function test_hasFunction_detectsRevertingFunction() public view {
        // pause(1) reverts with NotOwnerOrApproved (auth check) but _hasFunction
        // should still detect the selector exists via non-empty revert data
        NFA1Verifier.AuditReport memory report = verifier.fullAudit(address(nfa));
        assertTrue(report.tier1.c08_lifecycleFunctions);
    }

    // ============================================================
    //                    _isNoArgFunction
    // ============================================================

    /// @notice The internal helper correctly identifies no-arg signatures
    /// @dev We test this indirectly through extension detection
    function test_noArgDetection_circuitBreaker() public view {
        // isGloballyPaused() is a no-arg function — verifier should handle it
        // MinimalNFA doesn't have it, so detection should be false
        NFA1Verifier.AuditReport memory report = verifier.fullAudit(address(nfa));
        assertFalse(report.extensions.e08_circuitBreaker);
    }
}
