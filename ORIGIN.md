# NFA-1 Standard — Origin and Methodology

# NFA-1 标准 — 起源与方法论

---

## 1. What is NFA-1? / NFA-1 是什么？

NFA-1 (Non-Fungible Agent Standard) is an open standard for representing AI agents as ownable, tradeable, and learnable assets on EVM blockchains. It extends ERC-721 with lifecycle management, on-chain learning commitments, and delegated action execution.

NFA-1（非同质化代理标准）是一个开放标准，用于在 EVM 区块链上将 AI 代理表示为可拥有、可交易、可学习的资产。它扩展了 ERC-721，增加了生命周期管理、链上学习承诺和委托动作执行。

---

## 2. Origin / 起源

NFA-1 is **based on the BAP-578 BEP Draft**, the official BNB Chain specification for Non-Fungible Agents. The standard takes the BEP draft's interface definitions and structures them into a modular, tiered framework with compliance tooling.

NFA-1 **基于 BAP-578 BEP 草案**，即 BNB Chain 官方的非同质化代理规范。标准将 BEP 草案的接口定义构建为模块化、分层的框架，并配备合规工具。

### Source 1: BAP-578 BEP Draft — BNB Chain Official Specification (Core Reference / 核心参考)

The **primary authoritative source** is the BAP-578 BEP draft, submitted to the official BNB Chain BEPs repository:

**最核心的权威来源**是 BAP-578 BEP 草案，提交在 BNB Chain 官方 BEPs 仓库中：

- **BEP Draft**: [`bnb-chain/BEPs/BAPs/BAP-578.md`](https://github.com/bnb-chain/BEPs/blob/master/BAPs/BAP-578.md)
- **Status**: Draft
- **Type**: Application
- **Created**: 2025-05-27

The BEP draft defines the **complete BAP-578 specification**, including:

| Component | BEP Draft Content |
|-----------|------------------|
| **Core Interface (IBAP578)** | `enum Status { Active, Paused, Terminated }`, `State` struct, `AgentMetadata` struct, `executeAction()`, `pause()`/`unpause()`/`terminate()`, `fundAgent()`, `setLogicAddress()` |
| **Learning System** | `EnhancedAgentMetadata` with `learningEnabled`, `learningModule`, `learningTreeRoot`, `learningVersion`, `lastLearningUpdate` |
| **ILearningModule** | `updateLearning()`, `verifyLearning()`, `getLearningMetrics()`, `getLearningRoot()`, `isLearningEnabled()`, `recordInteraction()` |
| **ICircuitBreaker** | `pauseGlobally()`, `pauseContract()`, `pauseAgent()` + unpause counterparts + query functions |
| **IMemoryModuleRegistry** | External memory source registration and verification |
| **IVaultPermissionManager** | Off-chain data access control with permission levels and expiry |
| **IAgentTemplate** | Specialized agent type templates (DeFi, Game, DAO, Creator, Strategic) |
| **Dual-Path Architecture** | Path 1: JSON Light Memory (simple) / Path 2: Merkle Tree Learning (advanced) |
| **Security** | ReentrancyGuard, gas limits (`MAX_GAS_FOR_DELEGATECALL = 3,000,000`), circuit breakers |

**Critical finding**: The BEP draft's core interface (`IBAP578`) defines `enum Status { Active, Paused, Terminated }` and `struct State { balance, status, owner, logicAddress, lastActionTimestamp }` — which are an **exact match** with NFA-1's INFA1Core. This confirms that NFA-1 is aligned with the official Binance specification.

**关键发现**：BEP 草案的核心接口（`IBAP578`）定义了 `enum Status { Active, Paused, Terminated }` 和 `struct State { balance, status, owner, logicAddress, lastActionTimestamp }` —— 与 NFA-1 的 INFA1Core **完全一致**。这证实了 NFA-1 与币安官方规范的对齐。

### Source 2: BAP-578 Reference Implementation by ChatAndBuild (Base Code / 基础代码)

The reference implementation linked in the BEP draft:

- **Repository**: [`ChatAndBuild/non-fungible-agents-BAP-578`](https://github.com/ChatAndBuild/non-fungible-agents-BAP-578)
- **Contract**: BAP578.sol (ERC-721 + UUPS Upgradeable)
- **Implements**: AgentMetadata, AgentState, fundAgent, withdrawFromAgent, setAgentStatus, setLogicAddress, updateAgentMetadata, createAgent (3 free mints)

**Important**: The reference implementation is a **simplified base** that does not implement the full BEP specification. Specifically, it uses `bool active` instead of `Status` enum, has no learning system, no `executeAction()`, and no circuit breaker. It covers the "Path 1: JSON Light Memory" path only.

**重要说明**：参考实现是一个**简化的基础版本**，并未实现完整的 BEP 规范。具体来说，它使用 `bool active` 而非 `Status` 枚举，没有学习系统、没有 `executeAction()`、也没有熔断器。它只覆盖了"路径 1：JSON 轻量记忆"。

### Source 3: KinForge — First Compliant Deployment (验证性实现 / Validation Deployment)

KinForge is the **first known implementation** that achieves full NFA-1 compliance on BNB Chain:

- **Contract**: HouseForgeAgent.sol (deployed, 1300+ minted agents)
- **Network**: BNB Chain Mainnet
- **Compliance**: Tier 1 + Tier 2 + Tier 3 + Lineage Extension

KinForge 是**首个已知**在 BNB Chain 上达到完整 NFA-1 合规的实现。

KinForge's compliance is verified in [BAP578-COMPLIANCE.md](compliance/BAP578-COMPLIANCE.md).

### Source 4: Existing ERC Standards (Foundation / 基础)

NFA-1 builds on established Ethereum standards:

| Standard | Role in NFA-1 |
|----------|---------------|
| **ERC-721** | Ownership and transfer semantics — NFA-1 is a strict superset |
| **ERC-165** | Interface discovery — NFA-1 requires `supportsInterface` for INFA1Core |
| **ERC-8004** | Agent identity — NFA-1 bridges via optional INFA1Identity extension |
| **X402** | Machine payments — NFA-1 bridges via optional INFA1Payment extension |

### Source 5: Community Feedback (Refinement / 改进)

Feedback from **ladyxtel** (BNB Chain community reviewer) directly shaped two key design decisions:

1. **Three-tier data classification model** (On-Chain / Verifiably On-Chain / Off-Chain) — responding to the question: "What MUST be on-chain vs what can be verified on-chain?"
2. **Upgradeability neutrality** (Section 6) — responding to the feedback: "UUPS should be an implementation option, not a standard requirement."

### Source 6: nfa.xyz Ecosystem (Supplementary / 补充)

Information from [nfa.xyz](https://nfa.xyz) provided context for:

- **80-90% gas savings** → documented in Section 10.7 (Gas Efficiency Through Hybrid Architecture)
- **100+ chain roadmap via Hyperlane** → documented in Section 8.4 (Cross-Chain Considerations)
- **Merkle tree learning agents** → informed the verifyLearning() addition to INFA1LearningModules

---

## 3. NFA-1 vs BAP-578 BEP Draft / NFA-1 与 BAP-578 BEP 草案对比

### 3.1 Core Interface Alignment / 核心接口对齐

| Feature | BAP-578 BEP Draft | NFA-1 | Match |
|---------|-------------------|-------|-------|
| Status enum | `Active, Paused, Terminated` | `Active, Paused, Terminated` | **Exact** |
| State struct | `{ balance, status, owner, logicAddress, lastActionTimestamp }` | Same | **Exact** |
| AgentMetadata | `{ persona, experience, voiceHash, animationURI, vaultURI, vaultHash }` | Same | **Exact** |
| executeAction | `executeAction(uint256, bytes)` | Same | **Exact** |
| Lifecycle | `pause()` / `unpause()` / `terminate()` | Same | **Exact** |
| fundAgent | `fundAgent(uint256) payable` | Same | **Exact** |
| setLogicAddress | `setLogicAddress(uint256, address)` | Same | **Exact** |
| getState / getAgentMetadata | Present | Present | **Exact** |
| updateAgentMetadata | Present | Present | **Exact** |

### 3.2 Event Indexing Difference / 事件索引差异

| Event | BAP-578 BEP Draft | NFA-1 |
|-------|-------------------|-------|
| ActionExecuted | `address indexed agent` | `uint256 indexed tokenId` |
| LogicUpgraded | `address indexed agent` | `uint256 indexed tokenId` |
| AgentFunded | `address indexed agent` | `uint256 indexed tokenId` |
| StatusChanged | `address indexed agent` | `uint256 indexed tokenId` |
| MetadataUpdated | `uint256 indexed tokenId` | `uint256 indexed tokenId` |

**Rationale**: NFA-1 consistently uses `uint256 indexed tokenId` because the shared-contract model (one contract managing multiple agents) is more gas-efficient than one-contract-per-agent. The BEP draft itself is inconsistent — `MetadataUpdated` uses tokenId while others use address. NFA-1 standardizes on tokenId for all events.

### 3.3 Features in BEP Draft Not in NFA-1 / BEP 中有而 NFA-1 没有的

| BEP Feature | Status in NFA-1 | Reason |
|-------------|----------------|--------|
| `IMemoryModuleRegistry` | Not included | External memory registration is deployment infrastructure, not core agent behavior |
| `IVaultPermissionManager` | Mentioned in security guidance (Section 11.5) | Access control for off-chain data is implementation-specific |
| `IAgentTemplate` | Not included | Template patterns are deployment infrastructure, not standardized behavior |
| `recordInteraction()` | Not in NFA-1 | Interaction recording is an implementation detail of learning modules |
| `learningVelocity` in LearningMetrics | Not in NFA-1 | Simplified to 4 core metrics; velocity is derivable from other fields |
| Gas limit 3,000,000 | NFA-1 uses 500,000 | More conservative default; implementations MAY adjust |

### 3.4 Features in NFA-1 Not in BEP Draft / NFA-1 中有而 BEP 没有的

| NFA-1 Feature | Description |
|---------------|-------------|
| **INFA1Lineage** (E-01) | Generational breeding, fusion, offspring tracking |
| **INFA1Payment** (E-02) | X402 machine payment compatibility |
| **INFA1Identity** (E-03) | ERC-8004 identity bridge |
| **INFA1Receipts** (E-04) | On-chain audit trail |
| **INFA1Compliance** (E-05) | Enterprise compliance metadata |
| **Proof-of-Prompt** (E-07) | Mint-time prompt hash commitment |
| **4-tier compliance system** | Progressive adoption checklist |
| **NFA1Verifier.sol** | On-chain compliance probe tool |
| **nfa1-audit.js** | Off-chain address-only audit tool |
| **Three-tier data classification** | On-Chain / Verifiably On-Chain / Off-Chain |

---

## 4. Standardization Methodology / 标准化方法论

### Phase 1: BEP Specification — Official Standard / BEP 规范——官方标准

```
BAP-578 BEP Draft (bnb-chain/BEPs — Binance official)
    ↓
Defines: Status enum, State struct, AgentMetadata, learning system,
         circuit breaker, dual-path architecture, security model
    ↓
The authoritative specification for NFA agents on BNB Chain
```

币安官方 BEP 草案定义了 NFA 代理的完整规范。

### Phase 2: Standardize — Interface Design / 标准化——接口设计

```
BAP-578 BEP Draft (IBAP578 interface)
    ↓
Map to modular NFA-1 interface structure:
  - Core (INFA1Core): Status, State, AgentMetadata, lifecycle, action, learning
  - Extensions: Lineage, Payment, Identity, Receipts, Compliance, LearningModules, CircuitBreaker
    ↓
Add NFA-1 innovations:
  - 4-tier compliance system
  - Three-tier data classification (On-Chain / Verifiably On-Chain / Off-Chain)
  - Proof-of-Prompt
  - Compliance verification tools (NFA1Verifier, nfa1-audit.js)
    ↓
INFA1Core interface (15 functions, 4 structs, 6 events, 1 enum)
+ 8 optional extensions
```

**Principle**: The core interface follows the BEP draft specification. Extensions address real-world needs identified through production deployments.

**原则**：核心接口遵循 BEP 草案规范。扩展接口应对生产部署中发现的实际需求。

### Phase 4: Cross-Reference and Harden / 交叉参考与加固

```
NFA-1 v1.0 (initial draft)
    ↓
Compare against BAP-578 BEP draft + reference implementation
    ↓
Security audit (automated cross-reference + code review)
    ↓
Fix 8 issues found during audit
    ↓
NFA-1 v1.4 (current)
```

---

## 5. Design Principles / 设计原则

These principles guided every decision in NFA-1:

| Principle | Description |
|-----------|-------------|
| **BEP-aligned core** | Core interface matches the official BAP-578 BEP specification |
| **Spec-driven, not code-driven** | The core interface is based on the BAP-578 BEP draft specification |
| **Progressive adoption** | 4-tier system — start simple (Tier 1), add complexity as needed |
| **Minimal core, optional extensions** | Core is 15 functions; everything else is optional |
| **No architecture mandates** | Define WHAT (interfaces), not HOW (UUPS, Diamond, etc.) |
| **Hybrid efficiency** | On-chain hashes anchor off-chain data — 80-90% gas savings |
| **Composability** | Designed to work with ERC-8004, X402, A2A, MCP ecosystems |
| **Verifiable by default** | Built-in compliance checklist + on-chain/off-chain audit tools |

---

## 6. Version History / 版本历史

| Version | Date | Changes |
|---------|------|---------|
| **v1.0** | 2026-02-08 | Initial draft: INFA1Core + 6 extensions + MinimalNFA + spec + checklist |
| **v1.1** | 2026-02-08 | +INFA1CircuitBreaker (E-08), enhanced INFA1LearningModules, audit fixes, +NFA1Verifier.sol, +nfa1-audit.js |
| **v1.2** | 2026-02-08 | Corrected source attribution: official BAP-578 repo as foundation, KinForge as compliant implementation |
| **v1.3** | 2026-02-08 | BAP-578 BEP draft (`bnb-chain/BEPs`) established as core reference. Full BEP alignment analysis. |
| **v1.4** | 2026-02-08 | Narrative reframed: NFA-1 is based on BEP draft spec, not extracted from any implementation. KinForge repositioned as first compliant deployment, not source. |

---

## 7. File Inventory / 文件清单

| File | Purpose | Created | Last Modified |
|------|---------|---------|---------------|
| `spec/NFA-1.md` | English specification (13 sections) | v1.0 | v1.4 |
| `spec/NFA-1_zh.md` | Chinese specification (complete translation) | v1.0 | v1.4 |
| `contracts/interfaces/INFA1Core.sol` | Core interface (MUST implement) | v1.0 | v1.0 |
| `contracts/interfaces/INFA1Lineage.sol` | Lineage extension (E-01) | v1.0 | v1.0 |
| `contracts/interfaces/INFA1Payment.sol` | Payment extension (E-02) | v1.0 | v1.0 |
| `contracts/interfaces/INFA1Identity.sol` | Identity extension (E-03) | v1.0 | v1.1 |
| `contracts/interfaces/INFA1Receipts.sol` | Receipts extension (E-04) | v1.0 | v1.0 |
| `contracts/interfaces/INFA1Compliance.sol` | Compliance extension (E-05) | v1.0 | v1.0 |
| `contracts/interfaces/INFA1LearningModules.sol` | Learning Modules extension (E-06) | v1.0 | v1.1 |
| `contracts/interfaces/INFA1CircuitBreaker.sol` | Circuit Breaker extension (E-08) | v1.1 | v1.1 |
| `contracts/examples/MinimalNFA.sol` | Reference implementation (Tier 1-3) | v1.0 | v1.1 |
| `contracts/tools/NFA1Verifier.sol` | On-chain compliance probe | v1.1 | v1.4 |
| `tools/nfa1-audit.js` | Off-chain audit script | v1.1 | v1.1 |
| `checklist/NFA1-CHECKLIST.md` | 4-tier compliance checklist (69 items) | v1.0 | v1.4 |
| `compliance/BAP578-COMPLIANCE.md` | KinForge compliance proof | v1.0 | v1.4 |
| `README.md` | Project overview | v1.0 | v1.4 |
| `ORIGIN.md` | This document | v1.1 | v1.4 |

**Total**: 17 files (10 Solidity, 7 Markdown/JS)

---

*NFA-1 is released under CC0-1.0 — No rights reserved.*
