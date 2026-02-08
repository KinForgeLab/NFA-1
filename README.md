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
- **Formal verification** — 15 symbolic proofs via Halmos + 130 Foundry tests

## Quick Start

```bash
git clone https://github.com/KinForgeLab/NFA-1.git
cd NFA-1
forge install
forge build
forge test  # 130 tests: unit + fuzz + invariant + gas + verifier
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
│   │   └── MinimalNFA.sol   # Reference implementation (Tier 1-3)
│   └── tools/
│       └── NFA1Verifier.sol # On-chain compliance checker
├── test/                    # Foundry tests (130 unit + fuzz + invariant + gas)
│   └── MinimalNFA.halmos.t.sol  # 15 Halmos symbolic proofs
├── spec/                    # NFA-1 specification (EN + 中文)
├── checklist/               # Compliance checklist (69 items)
├── compliance/              # KinForge compliance proof
├── tools/
│   └── nfa1-audit.js        # Off-chain audit script
├── script/
│   └── Deploy.s.sol         # Deployment script with self-verification
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
