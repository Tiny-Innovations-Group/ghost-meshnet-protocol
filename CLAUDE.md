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

## Path to RFC — Phased Plan

### Phase 1: Document Consistency (Blockers — must be done before release)

These are hard blockers. Inconsistent specs will be called out in the
first wave of HN comments and will undermine credibility before anyone
engages with the ideas.

- [ ] **Sync `/docs/overview.md` to 112 B canon.**
  Currently quotes 124 B / 248 B dual-burst numbers and has a literal
  placeholder: `(Include your gmp_core_layer.ksy and gmp_data_frame.ksy
  snippets here)`. Remove the placeholder, update all byte counts, repoint
  to the real `.ksy` files in `/specs/`.

- [ ] **Sync `/docs/encryption-ratchet.md` to 112 B canon.**
  Currently quotes 124 B packet size and 248 B dual-burst throughout.
  Also contains an outdated bare `gmp_433_beacon.ksy` snippet (no enums,
  no bit-packing) — replace with a link to `/specs/gmp_433_beacon.ksy`.

- [ ] **Fix `/docs/oion-routing-draft.md`.**
  - Rename file: `oion-routing-draft.md` → `onion-routing-draft.md`.
  - Rewrite packet breakdown from 127 B to 112 B. The 127-byte figure
    is the oldest and most wrong version — it predates the bit-packing
    work entirely.

- [ ] **Resolve the compression ambiguity in `/docs/the-message.md`.**
  Section 2 describes a 6-bit tactical alphabet producing ~128 chars in
  77 bytes. Section 7 describes a Static Huffman layer on top producing
  ~140 chars. These are presented as the same 77-byte field but are
  mutually exclusive compression strategies. Pick one and delete the
  other, or explicitly document them as a two-stage pipeline
  (6-bit alphabet → then Huffman on the 6-bit output).

- [ ] **Create `SECURITY.md`.**
  Referenced from `SPECIFICATION.md` footer and the Apache 2.0 section.
  Minimum viable content: vulnerability disclosure policy, contact
  (j.thomas.houlker@gmail.com or a dedicated security address), scope
  (spec bugs, cryptographic weaknesses, timing attacks), and response SLA.

### Phase 2: Technical Completeness (Before release, high priority)

These gaps won't block release but will be immediately exposed by the
first technical reviewer.

- [ ] **Write `/docs/spi_arbitration.md`.**
  README §5 explicitly calls this out as the "primary engineering
  challenge" and sends reviewers to this file. It does not exist.
  Content needed: the dual-SPI chip-select contention problem, the
  proposed PIO state machine solution, the specific failure mode we're
  seeking review on (dropped packets during simultaneous interrupts),
  and the timing budget. This is the centrepiece RFC question — it
  deserves its own doc.

- [ ] **Write a packet generator script (`tools/generate_packet.py`).**
  A short Python script (using `struct` + `libsodium` bindings or just
  `cryptography`) that constructs a valid 112 B `gmp_868_data_frame` and
  a valid 104 B `gmp_433_beacon` and prints them as hex dumps.
  This lets reviewers immediately verify the `.ksy` parsers against a
  known-good fixture. Referenced in old spec history; reviewers will ask
  for it.

- [ ] **Sharpen the RFC questions in `README.md` §7.**
  The current three questions are too broad to generate useful answers.
  Replace with specific, answerable questions. Examples:
  - *"At SF7 with two simultaneous SPI interrupt handlers, can a single
    RP2040 core service both radios without dropping a packet? What is
    the minimum safe GPIO interrupt latency budget?"*
  - *"Does routing the 2-byte `message_id` as the implicit Double Ratchet
    nonce core (combined with 4-byte sender + 4-byte receiver to form 10
    of the 12 nonce bytes) break the anti-replay guarantee if a node
    reboots and resets `message_id` to 0 before the ratchet advances?"*
  - *"Is a 50-slot LRU key ring adequate for a relay node serving a busy
    tactical mesh, or will key eviction cause silent decryption failures
    under realistic load?"*

- [ ] **Add `CONTRIBUTING.md`.**
  Scope must be clear: spec and `.ksy` changes only, no firmware PRs
  until v1.0-draft is locked. Include the Kaitai Struct compiler command
  for validating `.ksy` changes locally.

### Phase 3: Release Preparation

- [ ] **Prepare the Hacker News post.**
  Use `docs/summary.md` as the base. HN "Ask HN" format works better
  than "Show HN" for an RFC — frame it as genuinely seeking technical
  review, not announcing a product. Title suggestion:
  *"Ask HN: Review our dual-band LoRa mesh protocol spec (zero-heap RP2040, Double Ratchet, Kaitai Structs)"*

- [ ] **Identify relevant subreddits.**
  Primary: `r/embedded`, `r/crypto`, `r/netsec`, `r/hamradio`.
  Secondary: `r/raspberry_pi`, `r/Meshtastic`.
  Each needs a slightly different framing (embedded angle vs crypto angle
  vs RF angle).

- [ ] **Set up GitHub Discussions or a pinned Issue.**
  A single "RFC v1.0 — Feedback Thread" issue gives reviewers one place
  to post without opening scattered PRs. Pin it.

- [ ] **Tag the release.**
  Before posting, tag the commit as `v0.1-rfc` so the HN post has a
  stable anchor.

### Phase 4: RFC Response & Spec Lock

- [ ] Monitor feedback, triage into: spec bugs, architectural questions,
  and implementation suggestions.
- [ ] Address any spec bugs in follow-up commits on `main`.
- [ ] Decide on any architectural changes based on reviewer input.
- [ ] Lock `v1.0-draft` once the SPI arbitration and ratchet resilience
  questions have satisfactory answers.
- [ ] Begin firmware planning (RP2040 C++ project scaffolding).

---

## Known outstanding gaps (not yet actioned)

These were identified during the April 2026 doc cleanup session but are
out of scope for Phase 1 work. Track here so they are not forgotten.

- No `SECURITY.md` (Phase 1 blocker — listed above).
- No `CONTRIBUTING.md` (Phase 2).
- No `/docs/spi_arbitration.md` (Phase 2 blocker — listed above).
- No example binary / hex dump for `.ksy` parser validation.
- `docs/the-message.md` §2 vs §7 compression ambiguity (Phase 1).
- `README.md` §2 (Hardware BOM) still lists "Radio B (868MHz)" but the
  SRAM map table header previously said "836MHz" — fixed, but review the
  BOM section for any other stale numbers.
- The RTS/CTS body format is only described in prose in
  `docs/encryption-ratchet.md`; there is no `.ksy` for it. A
  `gmp_433_rts.ksy` and `gmp_433_cts.ksy` may be needed before v1.0.

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

*Last updated: 2026-04-17. Phase 1 work pending.*
