# NFA-1: Non-Fungible Agent Standard

**An open standard for AI agents as ownable, tradeable, learnable assets on EVM blockchains.**

[![License: CC0-1.0](https://img.shields.io/badge/License-CC0_1.0-lightgrey.svg)](https://creativecommons.org/publicdomain/zero/1.0/)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.20-blue.svg)](https://soliditylang.org/)
[![Based on BAP-578](https://img.shields.io/badge/Based_on-BAP--578-orange.svg)](https://github.com/bnb-chain/BEPs/blob/master/BAPs/BAP-578.md)

---

## Overview

NFA-1 extends ERC-721 with lifecycle management, on-chain learning commitments, and delegated action execution for AI agents. It is based on the [BAP-578 BEP Draft](https://github.com/bnb-chain/BEPs/blob/master/BAPs/BAP-578.md) — the official BNB Chain specification for Non-Fungible Agents.

### Key Features

- **15-function core interface** — `INFA1Core` covers lifecycle, actions, learning, funding, and metadata
- **4-tier compliance system** — Progressive adoption from minimal (Tier 1) to full extensions (Tier 4)
- **Hybrid storage model** — On-chain hashes anchor off-chain data (80-90% gas savings)
- **7 optional extensions** — Lineage, Payment, Identity, Receipts, Compliance, Learning Modules, Circuit Breaker
- **Built-in verification tools** — On-chain `NFA1Verifier.sol` + off-chain `nfa1-audit.js`
- **Formal verification** — 15 symbolic proofs via Halmos + 174 Foundry tests

## Use Cases

- **AI Companion NFTs** — Mint agents with unique personas that learn and evolve through user interaction; personality and memory persist on-chain across owners
- **Autonomous Trading Agents** — Deploy on-chain agents that execute strategies via `executeAction`, with built-in gas capping and circuit breaker for risk control
- **GameFi / Metaverse NPCs** — Create tradeable game characters whose skills, experience, and behavioral data are verifiably committed on-chain via Merkle roots
- **DAO Agents** — Govern treasury or execute proposals through delegated logic contracts; lifecycle controls (pause/terminate) provide emergency safeguards
- **Agent Marketplaces** — Standard ERC-721 compatibility enables trading on any NFT marketplace while preserving agent state, learning history, and lineage
- **Cross-platform Agent Identity** — Bridge agent identity to off-chain services via `INFA1Identity` (ERC-8004); one on-chain NFT anchors a portable AI identity
- **Enterprise AI Compliance** — `INFA1Compliance` and `INFA1Receipts` extensions provide auditable metadata and action trails for regulated environments

NFA-1 solves a fundamental problem: **AI agents today are stateless, non-portable, and platform-locked.** By anchoring agent state, learning, and identity as transferable on-chain assets, NFA-1 makes AI agents ownable, composable, and interoperable across any EVM chain.

## Quick Start

```bash
git clone https://github.com/KinForgeLab/NFA-1.git
cd NFA-1
forge install
forge build
forge test  # 174 tests: unit + fuzz + invariant + gas + verifier + upgradeable
```

See [QUICKSTART.md](QUICKSTART.md) for a full developer walkthrough.

## Architecture

```
Your NFA Contract
├── ERC-721 (ownership, transfers, approvals)
├── INFA1Core (required — 15 functions)
│   ├── State        — balance, status, owner, logicAddress, lastActionTimestamp
│   ├── AgentMetadata — persona, experience, voiceHash, animationURI, vaultURI, vaultHash
│   ├── LearningState — learningRoot, learningVersion, lastLearningUpdate, learningEnabled
│   ├── Lifecycle    — pause(), unpause(), terminate()
│   ├── Actions      — executeAction(), setLogicAddress()
│   ├── Funding      — fundAgent()
│   └── Learning     — updateLearning(), getLearningRoot(), ...
└── Optional Extensions
    ├── INFA1Lineage          — breeding, fusion, offspring tracking
    ├── INFA1Payment          — X402 machine payment compatibility
    ├── INFA1Identity         — ERC-8004 identity bridge
    ├── INFA1Receipts         — on-chain audit trail
    ├── INFA1Compliance       — enterprise compliance metadata
    ├── INFA1LearningModules  — advanced learning with Merkle proofs
    └── INFA1CircuitBreaker   — global + per-agent emergency pause
```

## Compliance Tiers

| Tier | Requirements | Checks |
|------|-------------|--------|
| **Tier 1** (Core) | ERC-721, Status enum, State/Metadata structs, lifecycle, ERC-165 | C-01 to C-12 |
| **Tier 2** (Learning) | LearningState, version monotonicity, learning queries | L-01 to L-07 |
| **Tier 3** (Actions) | executeAction, gas capping, setLogicAddress, fundAgent | A-01 to A-07 |
| **Tier 4** (Extensions) | Optional: Lineage, Payment, Identity, Receipts, Compliance, LearningModules, CircuitBreaker | E-01 to E-08 |

## Project Structure

```
nfa-standard/
├── contracts/
│   ├── interfaces/          # 8 Solidity interfaces
│   │   ├── INFA1Core.sol    # Required core interface
│   │   ├── INFA1Lineage.sol # Optional: breeding/fusion
│   │   ├── INFA1Payment.sol # Optional: withdrawals
│   │   └── ...              # 5 more optional extensions
│   ├── examples/
│   │   ├── MinimalNFA.sol              # Reference implementation (Tier 1-3)
│   │   ├── MinimalNFAUpgradeable.sol   # UUPS upgradeable version
│   │   ├── MyAgent.sol                 # Deployment template (fork this!)
│   │   └── MyAgentUpgradeable.sol      # Upgradeable template (production)
│   └── tools/
│       └── NFA1Verifier.sol # On-chain compliance checker
├── test/                    # Foundry tests (174 unit + fuzz + invariant + gas + upgradeable)
│   └── MinimalNFA.halmos.t.sol  # 15 Halmos symbolic proofs
├── spec/                    # NFA-1 specification (EN + 中文)
├── checklist/               # Compliance checklist (69 items)
├── compliance/              # KinForge compliance proof
├── tools/
│   └── nfa1-audit.js        # Off-chain audit script
├── script/
│   ├── Deploy.s.sol                # Simple deployment (non-upgradeable)
│   └── DeployUpgradeable.s.sol     # UUPS proxy deployment (upgradeable)
├── QUICKSTART.md            # Developer quick start guide
└── ORIGIN.md                # Origin and methodology
```

## Testing

```bash
# All tests
forge test

# Gas report
forge test --match-contract MinimalNFAGasTest --gas-report

# Specific tier
forge test --match-test "test_C"   # Tier 1 (Core)
forge test --match-test "test_L"   # Tier 2 (Learning)
forge test --match-test "test_A"   # Tier 3 (Actions)

# Formal verification (requires Halmos)
halmos --contract MinimalNFAHalmosTest
```

## Verification

After deploying, verify compliance on-chain:

```bash
# Quick check
cast call <VERIFIER_ADDRESS> "quickCheck(address)(bool,uint8)" <YOUR_NFA_ADDRESS> --rpc-url <RPC>

# Full audit
cast call <VERIFIER_ADDRESS> "fullAudit(address)" <YOUR_NFA_ADDRESS> --rpc-url <RPC>
```

Or off-chain:

```bash
node tools/nfa1-audit.js --rpc <RPC_URL> --address <YOUR_NFA_ADDRESS>
```

## Documentation

- **Spec (English)**: [spec/NFA-1.md](spec/NFA-1.md)
- **Spec (中文)**: [spec/NFA-1_zh.md](spec/NFA-1_zh.md)
- **Compliance Checklist**: [checklist/NFA1-CHECKLIST.md](checklist/NFA1-CHECKLIST.md)
- **Origin & Methodology**: [ORIGIN.md](ORIGIN.md)
- **Quick Start**: [QUICKSTART.md](QUICKSTART.md)
- **BAP-578 BEP Draft**: [bnb-chain/BEPs/BAPs/BAP-578.md](https://github.com/bnb-chain/BEPs/blob/master/BAPs/BAP-578.md)

## Related

- **BAP-578 BEP Draft** (official BNB Chain spec): https://github.com/bnb-chain/BEPs/blob/master/BAPs/BAP-578.md
- **KinForge** (first compliant deployment): https://github.com/KinForgeLab/kinforge
- **nfa.xyz** (ecosystem): https://nfa.xyz

## License

CC0-1.0 — No rights reserved.
