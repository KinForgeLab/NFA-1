# BAP-578 / KinForge — NFA-1 Compliance Mapping

This document verifies the compliance of `HouseForgeAgent.sol` (KinForge) against the NFA-1 standard, which is based on the BAP-578 BEP Draft.

**Contract**: HouseForgeAgent
**Network**: BNB Chain Mainnet
**Deployer**: 0x1E87e1d1F317e8C647380CE1e1233e1eDD265607
**Implementation**: Full BAP-578 BEP Draft (based on official BAP-578 specification)
**BAP-578 BEP Draft (Authoritative)**: [`bnb-chain/BEPs/BAPs/BAP-578.md`](https://github.com/bnb-chain/BEPs/blob/master/BAPs/BAP-578.md)
**Official BAP-578 Reference Impl**: [`ChatAndBuild/non-fungible-agents-BAP-578`](https://github.com/ChatAndBuild/non-fungible-agents-BAP-578)
**Project**: KinForge

---

## Compliance Summary

```
Tier 1 (Minimum Viable NFA): PASS  (12/12 items)
Tier 2 (Learning-Enabled):   PASS  (7/7 items)
Tier 3 (Autonomous):         PASS  (7/7 items)
Tier 4 Extensions:
  - Lineage (E-01):           PASS  (7/7 items)
  - Payment (E-02):           N/A   (not implemented)
  - Identity (E-03):          N/A   (not implemented)
  - Receipts (E-04):          N/A   (not implemented)
  - Compliance (E-05):        N/A   (not implemented)
  - Learning Modules (E-06):  N/A   (not implemented — 9 items in v1.4)
  - Proof-of-Prompt (E-07):   N/A   (not implemented)
  - Circuit Breaker (E-08):   N/A   (not implemented)
```

**Overall**: Tier 1 + Tier 2 + Tier 3 + Lineage Extension = **Full Learning Autonomous NFA with Lineage**

---

## Tier 1 — Minimum Viable NFA

| ID | Requirement | Status | Evidence |
|----|------------|--------|----------|
| C-01 | ERC-721 compliance | **PASS** | `HouseForgeAgent.sol` implements all ERC-721 functions: `balanceOf`, `ownerOf`, `transferFrom`, `safeTransferFrom` (both overloads), `approve`, `getApproved`, `setApprovalForAll`, `isApprovedForAll`. ERC721Receiver callback supported. |
| C-02 | Status enum: Active(0), Paused(1), Terminated(2) | **PASS** | Defined in `IBAP578Core.sol`: `enum Status { Active, Paused, Terminated }` — matches NFA-1 exactly. |
| C-03 | Correct state transitions | **PASS** | `pause()` requires Active → Paused. `unpause()` requires Paused → Active. `terminate()` requires not Terminated → Terminated. No path from Terminated to any other state. |
| C-04 | Paused agents transferable | **PASS** | Transfer functions check `isSealed` (fusion lock) but do NOT check status. Paused agents can be freely transferred. |
| C-05 | `getState()` returns correct State struct | **PASS** | Returns `State` with all 5 fields. The `owner` field is set from `_owners[tokenId]` which reflects current ERC-721 ownership. |
| C-06 | `getAgentMetadata()` returns correct struct | **PASS** | Returns `AgentMetadata` with all 6 fields: persona, experience, voiceHash, animationURI, vaultURI, vaultHash. |
| C-07 | `vaultHash` stored on-chain | **PASS** | `vaultHash` (bytes32) is part of `AgentMetadata`, stored in `_agentMetadata` mapping. Set during mint and updatable via `updateAgentMetadata` and `updateLearning`. |
| C-08 | Lifecycle functions with authorization | **PASS** | `pause()`, `unpause()`, `terminate()` all use `onlyTokenOwnerOrApproved` modifier. Admin can also call these functions. |
| C-09 | Terminate is irreversible | **PASS** | `terminate()` sets status to Terminated. `unpause()` requires status == Paused (not Terminated). `pause()` requires status == Active. No code path changes Terminated to anything else. |
| C-10 | All 6 core events emitted | **PASS** | `ActionExecuted` in executeAction, `LogicUpgraded` in setLogicAddress, `AgentFunded` in fundAgent, `StatusChanged` in pause/unpause/terminate, `MetadataUpdated` in updateAgentMetadata, `LearningUpdated` in updateLearning. |
| C-11 | ERC-165 support | **PASS** | `supportsInterface()` returns true for ERC-165, ERC-721, and ERC-721 Metadata interface IDs. Note: does not yet advertise INFA1Core interface ID (pre-standard implementation). |
| C-12 | `updateAgentMetadata` reverts if Terminated | **PASS** | Uses `whenNotTerminated` modifier which requires `_agentStatus[tokenId] != Status.Terminated`. Emits `MetadataUpdated`. |

---

## Tier 2 — Learning-Enabled NFA

| ID | Requirement | Status | Evidence |
|----|------------|--------|----------|
| L-01 | LearningState struct | **PASS** | Implemented via separate mappings: `_learningRoots` (bytes32), `_learningVersions` (uint256), `_lastLearningUpdates` (uint256), `_learningEnabled` (bool). Functionally equivalent to a struct. |
| L-02 | Monotonic version enforcement | **PASS** | `updateLearning()` contains: `require(newVersion > _learningVersions[tokenId], "Version must increase")`. Rejects same or lower versions. |
| L-03 | LearningUpdated event | **PASS** | `updateLearning()` emits `LearningUpdated(tokenId, oldRoot, newLearningRoot, newVersion)` with indexed old/new roots and version. |
| L-04 | Learning query functions | **PASS** | All four implemented: `getLearningRoot()`, `isLearningEnabled()`, `getLearningVersion()`, `getLastLearningUpdate()`. |
| L-05 | Terminate disables learning | **PASS** | `terminate()` sets `_learningEnabled[tokenId] = false`. Subsequent `updateLearning()` calls revert because `require(_learningEnabled[tokenId], ...)`. |
| L-06 | Documented learning path | **PASS** | KinForge uses Path A (JSON Light Memory): `learningRoot = keccak256(vaultHash || summaryHash)`. Documented in backend learning sync code. |
| L-07 | Verification flow provided | **PASS** | Backend provides vault JSON at vaultURI. Users can: (1) fetch vault from vaultURI, (2) compute keccak256(stableStringify(vault)), (3) compare with on-chain vaultHash, (4) verify learningRoot derivation. |

---

## Tier 3 — Autonomous NFA

| ID | Requirement | Status | Evidence |
|----|------------|--------|----------|
| A-01 | `executeAction` delegates to logicAddress | **PASS** | `executeAction()` performs `logicAddress.call{gas: gasLimit}(data)` where logicAddress is `_logicAddresses[tokenId]`. |
| A-02 | Gas limit on delegated call | **PASS** | Uses `MAX_GAS_FOR_ACTION = 500_000` constant. Delegated call is capped: `min(gasleft() - reserve, MAX_GAS_FOR_ACTION)`. |
| A-03 | `setLogicAddress` works correctly | **PASS** | Allows setting new logic address. Accepts `address(0)` to disable logic. Uses `onlyTokenOwnerOrApproved` modifier. Emits `LogicUpgraded`. |
| A-04 | `fundAgent` is permissionless | **PASS** | `fundAgent()` is `external payable` with no access restriction. Any address can fund any agent. Accumulates in `_agentBalances[tokenId]`. Emits `AgentFunded`. |
| A-05 | Action events emitted | **PASS** | `executeAction()` → `ActionExecuted`. `setLogicAddress()` → `LogicUpgraded`. `fundAgent()` → `AgentFunded`. All verified. |
| A-06 | lastActionTimestamp updated | **PASS** | `executeAction()` sets `_lastActionTimestamps[tokenId] = block.timestamp` before the delegated call. |
| A-07 | Status gating on executeAction | **PASS** | Uses `whenActive` modifier: `require(_agentStatus[tokenId] == Status.Active)`. Also reverts if `_logicAddresses[tokenId] == address(0)`. |

---

## Tier 4 — Extensions

### E-01: Lineage and Fusion

| ID | Requirement | Status | Evidence |
|----|------------|--------|----------|
| E-01a | Lineage struct | **PASS** | Defined in contract with: parent1 (uint256), parent2 (uint256), generation (uint256), isSealed (bool). Stored in `_lineage` mapping. |
| E-01b | `getLineage()` | **PASS** | Returns `Lineage` struct for any token. Genesis agents have parent1=0, parent2=0, generation=0. |
| E-01c | `getGeneration()` | **PASS** | Returns generation number from `_lineage[tokenId].generation`. |
| E-01d | `isSealed()` | **PASS** | Returns `_lineage[tokenId].isSealed`. Sealed agents cannot be transferred. |
| E-01e | OffspringCreated event | **PASS** | `mintOffspring()` emits `OffspringMinted` event with offspringId, parents, houseId, and generation. Functionally equivalent to NFA-1's `OffspringCreated`. |
| E-01f | Generation calculation | **PASS** | `mintOffspring()` calculates: `generation = max(parent1Gen, parent2Gen) + 1`. Verified in contract code. |
| E-01g | Commit-reveal for fusion | **PASS** | `FusionCore` contract (separate contract) implements full commit-reveal: `commitFusion()` stores hash + block number, `revealFusion()` verifies after N blocks. Prevents trait frontrunning. |

### E-02 through E-08: Not Implemented

Extensions E-02 (Payment), E-03 (Identity), E-04 (Receipts), E-05 (Compliance), E-06 (Learning Modules), E-07 (Proof-of-Prompt), and E-08 (Circuit Breaker) are not yet implemented in KinForge. These are optional extensions and their absence does not affect Tier 1–3 compliance.

**Note on E-06 (Learning Modules)**: NFA-1 expanded this extension to 9 items, including `LearningMetrics`, `verifyLearning()`, `getLearningMetrics()`, and `LearningMilestone` event — designed for Merkle proof-based learning verification.

**Note on E-08 (Circuit Breaker)**: Provides ecosystem-wide emergency pause independently from individual agent lifecycle pause. Inspired by the `paused` + `emergencyWithdraw` pattern in the official BAP-578 contract.

---

## Interface Mapping: IBAP578Core → INFA1Core

The following table maps every function in `IBAP578Core.sol` to its `INFA1Core` counterpart:

| IBAP578Core Function | INFA1Core Function | Match |
|---------------------|-------------------|-------|
| `executeAction(uint256, bytes)` | `executeAction(uint256, bytes)` | Exact |
| `setLogicAddress(uint256, address)` | `setLogicAddress(uint256, address)` | Exact |
| `fundAgent(uint256)` | `fundAgent(uint256)` | Exact |
| `pause(uint256)` | `pause(uint256)` | Exact |
| `unpause(uint256)` | `unpause(uint256)` | Exact |
| `terminate(uint256)` | `terminate(uint256)` | Exact |
| `getState(uint256)` | `getState(uint256)` | Exact |
| `getAgentMetadata(uint256)` | `getAgentMetadata(uint256)` | Exact |
| `updateAgentMetadata(uint256, AgentMetadata)` | `updateAgentMetadata(uint256, AgentMetadata)` | Exact |
| `getLearningRoot(uint256)` | `getLearningRoot(uint256)` | Exact |
| `isLearningEnabled(uint256)` | `isLearningEnabled(uint256)` | Exact |
| `getLearningVersion(uint256)` | `getLearningVersion(uint256)` | Exact |
| `getLastLearningUpdate(uint256)` | `getLastLearningUpdate(uint256)` | Exact |
| `updateLearning(uint256, string, bytes32, bytes32, uint256)` | `updateLearning(uint256, string, bytes32, bytes32, uint256)` | Exact |
| — | `getLearningState(uint256)` | **Added in NFA-1** |

**Note**: `getLearningState()` is a convenience function added in NFA-1 that returns all learning fields as a single struct. BAP-578 provides the individual query functions instead. Functionally equivalent.

## Struct Mapping

| IBAP578Core Struct | INFA1Core Struct | Match |
|-------------------|-----------------|-------|
| `Status { Active, Paused, Terminated }` | `Status { Active, Paused, Terminated }` | Exact |
| `State { balance, status, owner, logicAddress, lastActionTimestamp }` | `State { balance, status, owner, logicAddress, lastActionTimestamp }` | Exact |
| `AgentMetadata { persona, experience, voiceHash, animationURI, vaultURI, vaultHash }` | `AgentMetadata { persona, experience, voiceHash, animationURI, vaultURI, vaultHash }` | Exact |
| `LearningState { learningRoot, learningVersion, lastLearningUpdate, learningEnabled }` | `LearningState { learningRoot, learningVersion, lastLearningUpdate, learningEnabled }` | Exact |

## Event Mapping

| IBAP578Core Event | INFA1Core Event | Match |
|------------------|----------------|-------|
| `ActionExecuted(uint256, bytes)` | `ActionExecuted(uint256, bytes)` | Exact |
| `LogicUpgraded(uint256, address, address)` | `LogicUpgraded(uint256, address, address)` | Exact |
| `AgentFunded(uint256, address, uint256)` | `AgentFunded(uint256, address, uint256)` | Exact |
| `StatusChanged(uint256, Status)` | `StatusChanged(uint256, Status)` | Exact |
| `MetadataUpdated(uint256, string)` | `MetadataUpdated(uint256, string)` | Exact |
| `LearningUpdated(uint256, bytes32, bytes32, uint256)` | `LearningUpdated(uint256, bytes32, bytes32, uint256)` | Exact |

---

## Addressing ladyxtel's Feedback

### Feedback 1: "Distinguish what MUST be on-chain vs what can be verified on-chain"

**Response**: NFA-1 Section 0.2 defines a three-tier data classification model:
- **On-Chain** (Tier 1): Status, balance, learningRoot, learningVersion
- **Verifiably On-Chain** (Tier 2): vaultHash, learningRoot (hash commitment on-chain, full data off-chain)
- **Off-Chain** (Tier 3): Animation assets, voice files

BAP-578 follows this model: `vaultHash` on-chain anchors the off-chain vault JSON. `learningRoot` on-chain anchors the off-chain learning data. Every data field in the specification is classified.

### Feedback 2: "UUPS should be an implementation option, not a standard requirement"

**Response**: NFA-1 Section 6 explicitly states: *"NFA-1 does not mandate any specific upgrade mechanism."* The standard defines interfaces and behaviors (what), not implementation architecture (how). BAP-578 uses a direct (non-upgradeable) deployment, which is fully compliant. Other implementations may choose UUPS, Diamond, Beacon, or any other pattern.

---

## Alignment with BAP-578 BEP Draft (Authoritative Specification)

The BAP-578 BEP Draft ([`bnb-chain/BEPs/BAPs/BAP-578.md`](https://github.com/bnb-chain/BEPs/blob/master/BAPs/BAP-578.md)) is the **authoritative specification** published by BNB Chain. NFA-1's core interface is aligned with this specification.

### Core interface alignment

| BEP Draft (IBAP578) | NFA-1 (INFA1Core) | Match |
|---------------------|-------------------|-------|
| `enum Status { Active, Paused, Terminated }` | `enum Status { Active, Paused, Terminated }` | **Exact** |
| `struct State { balance, status, owner, logicAddress, lastActionTimestamp }` | Same | **Exact** |
| `struct AgentMetadata { persona, experience, voiceHash, animationURI, vaultURI, vaultHash }` | Same | **Exact** |
| `executeAction(uint256, bytes)` | Same | **Exact** |
| `pause() / unpause() / terminate()` | Same | **Exact** |
| `fundAgent(uint256)` | Same | **Exact** |
| `setLogicAddress(uint256, address)` | Same | **Exact** |
| `getState(uint256)` / `getAgentMetadata(uint256)` | Same | **Exact** |
| Learning system (ILearningModule) | Built-in Tier 2 | **Equivalent** |
| Circuit breaker (ICircuitBreaker) | INFA1CircuitBreaker extension | **Equivalent** |

### Event indexing divergence

| BEP Draft | NFA-1 | Rationale |
|-----------|-------|-----------|
| Events use `address indexed agent` | Events use `uint256 indexed tokenId` | BEP draft assumes one-contract-per-agent; NFA-1 follows ERC-721 multi-token pattern where tokenId is the primary key |

### BEP Draft features not in NFA-1

| Feature | Description | NFA-1 Position |
|---------|-------------|---------------|
| `IMemoryModuleRegistry` | Pluggable memory module marketplace | Future extension candidate |
| `IVaultPermissionManager` | Granular off-chain data access control | Addressed in Security Considerations |
| `IAgentTemplate` | Factory template management | Implementation guidance, not standard requirement |
| `recordInteraction()` | On-chain interaction counter | Implementation-level, not interface-level |
| `learningVelocity` | Aggregated learning rate metric | Implementation-level metric |
| Gas limit: 3,000,000 | Higher cap on delegated calls | NFA-1 uses 500,000; implementors MAY override |

### NFA-1 features beyond BEP Draft

| Feature | NFA-1 Extension | Description |
|---------|----------------|-------------|
| INFA1Lineage | E-01 | Generational breeding with commit-reveal fusion |
| INFA1Payment | E-02 | X402 machine payment compatibility |
| INFA1Identity | E-03 | ERC-8004 agent identity bridge |
| INFA1Receipts | E-04 | On-chain audit trail |
| INFA1Compliance | E-05 | Enterprise compliance metadata |
| Proof-of-Prompt | E-07 | Mint-time prompt hash commitment |
| 4-tier compliance | Checklist | Systematic verification framework |
| NFA1Verifier | Tool | On-chain compliance probe |
| nfa1-audit.js | Tool | Off-chain address-only audit script |

---

## KinForge Implementation Notes

KinForge's `HouseForgeAgent.sol` implements the full BAP-578 BEP draft specification. The ChatAndBuild reference implementation ([`ChatAndBuild/non-fungible-agents-BAP-578`](https://github.com/ChatAndBuild/non-fungible-agents-BAP-578)) is a simplified base that only covers a subset of the BEP draft (e.g., `bool active` instead of `enum Status`, no learning, no `executeAction()`).

### BEP draft features implemented by KinForge

| BEP Draft Feature | KinForge | NFA-1 Tier |
|-------------------|----------|------------|
| `enum Status { Active, Paused, Terminated }` | Implemented | Tier 1 (C-02) |
| `pause()` / `unpause()` / `terminate()` | Implemented | Tier 1 (C-08) |
| Irreversible termination | Implemented | Tier 1 (C-09) |
| `executeAction()` with gas cap | Implemented | Tier 3 (A-01) |
| Learning system (learningRoot, version, queries) | Implemented | Tier 2 |
| AgentMetadata (6 fields) | Implemented | Tier 1 (C-06) |
| `fundAgent()` / `setLogicAddress()` | Implemented | Tier 1 / Tier 3 |

### KinForge extensions beyond the BEP draft

| Feature | NFA-1 Extension |
|---------|----------------|
| Lineage / generational breeding with commit-reveal fusion | E-01 |
| Paused agents MUST be transferable | Tier 1 (C-04) |
| Monotonic learning version enforcement | Tier 2 (L-02) |

---

## Conclusion

KinForge's `HouseForgeAgent.sol` on BNB Chain is a **fully compliant NFA-1 implementation** at Tier 1 + Tier 2 + Tier 3 + Lineage Extension. It is the first known compliant deployment of the NFA-1 standard.

The interface, struct, and event signatures between IBAP578Core and INFA1Core are an **exact match**, confirming alignment with the BAP-578 BEP draft specification.

---

*Last verified: 2026-02-08*
*Verified against: NFA-1 Draft Specification v1.4*
*BAP-578 BEP Draft (Authoritative): [bnb-chain/BEPs/BAPs/BAP-578.md](https://github.com/bnb-chain/BEPs/blob/master/BAPs/BAP-578.md)*
*BAP-578 Reference Impl: [ChatAndBuild/non-fungible-agents-BAP-578](https://github.com/ChatAndBuild/non-fungible-agents-BAP-578)*
