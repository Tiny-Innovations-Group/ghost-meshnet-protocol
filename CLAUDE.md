# CLAUDE.md — Ghost Meshnet Protocol (GMP)

This file is the project context for Claude Code. Read it fully before
touching any file in this repo.

---

## What this project is

GMP is a **dual-band, zero-heap LoRa mesh protocol** designed to run on
the Raspberry Pi Pico (RP2040). It sits at the intersection of three
hard domains:

1. **RF / radio law** — ETSI/Ofcom 1% duty cycle, SX1262 hardware FIFO
   constraints, Time-on-Air math, 433 MHz + 868 MHz band separation.
2. **Embedded systems** — strictly static memory allocation, dual SPI
   arbitration, PIO state machines, zero-heap C++.
3. **Applied cryptography** — X3DH key exchange, Double Ratchet,
   AES-GCM, Ed25519 hardware roots of trust (SRAM PUF / Secure Enclave).

**The repo is currently in the RFC (Request for Comments) phase. There
is no C++ implementation yet.** The goal is to get the specification peer-
reviewed by embedded engineers and security researchers before any
firmware is written.

---

## Canonical architectural decisions (do not change without discussion)

| Decision | Value | Locked in |
| --- | --- | --- |
| 868 MHz data packet size | **112 bytes** (the "Golden Ratio") | `SPECIFICATION.md`, `specs/` |
| 433 MHz control beacon size | **104 bytes** | `SPECIFICATION.md`, `specs/` |
| Dual-Burst payload | **224 bytes** (2 × 112 B, one preamble) | `SPECIFICATION.md` §3 |
| FIFO safety margin | **31 bytes** (255 − 224) | `SPECIFICATION.md` §2 |
| Reference spreading factor | **SF7 / 125 kHz / CR 4/5** | `SPECIFICATION.md` §3 |
| Compressed text field | **77 bytes** (Static Huffman output) | `specs/gmp_868_onion_core.ksy` |
| Heap strategy | Quarantined — all GMP state is statically allocated | `README.md` §3 |
| Hops | **3-hop** fixed-depth Onion Routing | `README.md` §6 |

The 112-byte figure supersedes all earlier numbers (127 B, 124 B) that
appear in older git history. If you find a doc quoting 124 B or 127 B,
it needs updating — do not accept it as a valid alternative.

---

## Repository structure

```
SPECIFICATION.md          ← canonical wire spec (single source of truth)
path_to_RFC.md            ← live RFC roadmap checklist — keep in sync with commits
CLAUDE.md                 ← this file (project context for Claude sessions)
DISCLAIMER.md
HARDWARE_REFERENCE.md
THREAT_MODEL.md
LICENSE                   ← Apache 2.0

specs/
  gmp_433_beacon.ksy      ← 104 B Control Plane beacon
  gmp_868_data_frame.ksy  ← 112 B Outer Routing Shell (plaintext)
  gmp_868_onion_core.ksy  ← 100 B Decrypted Onion Core (post-AES-GCM)

docs/
  overview.md             ← high-level architecture summary
  encryption-ratchet.md   ← X3DH + Double Ratchet explanation
  oion-routing-draft.md   ← onion routing deep-dive (filename typo: oion)
  the-message.md          ← text compression (6-bit alphabet + Huffman)
  summary.md              ← HN/Reddit release summary

README.md                 ← project landing page
```

---

## Path to RFC

The live, phased roadmap is maintained in [`path_to_RFC.md`](path_to_RFC.md).

That file is the **single source of truth** for:
- The RFC goal and scope (what we are and are not releasing).
- The MVP artefact set that constitutes a credible RFC bundle.
- The numbered, checkbox-tracked action list across Phase 0 (Foundation,
  complete) through Phase 4 (Post-RFC Spec Lock).

**Working rule:** when an action is delivered, tick its checkbox
(`[ ]` → `[x]`) in `path_to_RFC.md` **in the same commit** that delivers
the work. Do not let the checklist drift from the repo state.

The **centrepiece RFC deliverable** is `docs/flow-spec.md` (item #14):
the end-to-end protocol state machine covering beacon → X3DH →
RTS/CTS → Dual-Burst → relay → ACK, including failure modes. This is
the highest-value, highest-risk artefact in the MVP. `.ksy` files
describe static byte layout; `flow-spec.md` describes protocol
behaviour. Without it, reviewers cannot assess correctness.

---

## Working conventions

- **The `.ksy` files under `/specs/` are the canonical wire format.**
  Prose documents are explanations of those files, not the other way
  around. If a doc and a `.ksy` conflict, fix the doc.
- **Do not create new markdown docs without a clear home** in the
  structure above. Prefer updating existing files.
- **Commit messages** in this repo are terse and lowercase (see git log).
  Match the style.
- **The PR branch naming convention** is `claude/<worktree-name>` for
  Claude-authored work. Human-authored branches follow the same pattern.

---

*Last updated: 2026-04-17. Phase 0 complete; Phase 1 pending. See [`path_to_RFC.md`](path_to_RFC.md) for current checklist state.*
