# Path to RFC

Live checklist. When an action is completed, change `[ ]` → `[x]` and
commit the change in the same commit that delivers the work.

---

## The Goal

Publish a credible, peer-reviewable **protocol specification** (not an
implementation) of the Ghost Meshnet Protocol for public review on Hacker
News, Reddit, and relevant technical communities. Collect structured
feedback, answer the hard questions, and lock a `v1.0-draft` only after
the RFC period.

**We are NOT releasing:**
- Firmware or skeleton C++ (contradicts the "spec before code" doctrine).
- A working prototype or demo hardware.
- Anything that implies implementation choices reviewers should be
  making for us (RTOS selection, libsodium version, PCB layout).

---

## The MVP (Minimum Viable RFC)

The smallest set of artefacts that constitutes a credible RFC bundle.
Anything missing from this list will be called out as a gap in the first
wave of reviewer comments.

| Artefact | Purpose | Status |
| --- | --- | --- |
| `specs/*.ksy` | Wire format (machine-readable) | ✅ Done |
| `SPECIFICATION.md` | Human-readable wire spec + ToA math | ✅ Done |
| `docs/flow-spec.md` | End-to-end state machine + scenarios | ❌ **#14 — centrepiece deliverable** |
| `tools/generate_packet.py` | Known-good fixture generator | ❌ #15 |
| `docs/spi_arbitration.md` | The specific RP2040 dual-SPI question | ❌ #16 |
| `SECURITY.md` | Vulnerability disclosure policy | ❌ #13 |

Everything else in the repo is **supporting material**. It must be
consistent with the MVP artefacts but is not load-bearing for the RFC ask.

---

## Status Legend

- `[x]` — Complete
- `[ ]` — Pending

---

## Phase 0: Foundation (Complete)

Work done prior to opening this checklist. Preserved here as a record.

1. [x] Extract the three Kaitai Structs into real `.ksy` files under `/specs/`.
2. [x] Consolidate `SPECIFICATION_new.md` + 433 beacon section into a single canonical `SPECIFICATION.md`.
3. [x] Delete superseded spec files (`SPECIFICATION_new.md`, `SPECIFICATION_OLD.md`, `SPECIFICATION_routing.md`).
4. [x] Delete byte-identical duplicate `README_GMP.md`.
5. [x] Fix `README.md`: broken `.ksy` links, `836MHz` → `868MHz` typo, duplicate Asynchronous Onion Routing block, double section-6 numbering.
6. [x] Add Time-on-Air table (SF7/9/12 × CR 4/5 & 4/6) to `SPECIFICATION.md` §3.
7. [x] Write `docs/summary.md` (HN/Reddit release summary).
8. [x] Add `CLAUDE.md` with project context, canonical decisions, and roadmap reference.

---

## Phase 1: Document Consistency (Blockers)

These are hard blockers for release. Inconsistent byte counts and
missing referenced files will be called out within the first 20 HN
comments and undermine credibility before anyone engages with the ideas.

9. [x] **Sync `docs/overview.md` to 112 B canon.** Replace all 124 B / 248 B references with 112 B / 224 B. Remove the literal placeholder `(Include your gmp_core_layer.ksy and gmp_data_frame.ksy snippets here)`. Repoint to the real `.ksy` files in `/specs/`.
10. [x] **Sync `docs/encryption-ratchet.md` to 112 B canon.** Replace the 124 B / 248 B quotes throughout. Replace the outdated inline `gmp_433_beacon.ksy` snippet (no enums, no bit-packing) with a link to `/specs/gmp_433_beacon.ksy`.
11. [x] **Fix `docs/oion-routing-draft.md`.** Rename file: `oion-routing-draft.md` → `onion-routing-draft.md`. Rewrite packet breakdown from 127 B to 112 B. Update the 79-byte compressed-text field to 77 bytes to match the canon.
12. [x] **Resolve the compression ambiguity in `docs/the-message.md`.** §2 and §7 currently describe two mutually exclusive compression strategies on the same 77-byte field. Pick one as canonical, delete the other, OR explicitly document them as a two-stage pipeline (6-bit alphabet → Huffman on the 6-bit output).
13. [ ] **Create `SECURITY.md`.** Referenced from `SPECIFICATION.md` footer. Minimum content: disclosure policy, contact address, scope (spec bugs / cryptographic weaknesses / timing attacks), response SLA.

---

## Phase 2: Technical Completeness (MVP load-bearing)

These fill the genuine content gaps in the RFC. They are what reviewers
will actually engage with.

14. [ ] **Write `docs/flow-spec.md` — the E2E state machine (centrepiece).** Walk through complete scenarios step-by-step: Alice boots → broadcasts beacon → Dave saves pubkey → Alice initiates X3DH → both compute shared secret → Alice sends text → RTS on 433 → CTS back → Dual-Burst on 868 → Relay 1 peels layer → Relay 2 peels layer → Dave decrypts → ACK path. Cover failure modes: hop down, TTL expiry, queue full, ratchet desync, message lost. Include a Mermaid state diagram for the ratchet advance and one for the dual-SPI interrupt handoff.
15. [ ] **Write `tools/generate_packet.py`.** ~100 lines of Python using `cryptography` or `pynacl`. Constructs a valid 112 B `gmp_868_data_frame` and a valid 104 B `gmp_433_beacon`, prints both as annotated hex dumps. Converts the `.ksy` files from "documentation" into "testable specification."
16. [ ] **Write `docs/spi_arbitration.md`.** README §5 sends reviewers here; it currently 404s. Content: dual-SPI chip-select contention problem, proposed PIO state-machine solution, specific failure mode under review (dropped packets during simultaneous interrupts), minimum GPIO interrupt latency budget. This is the primary technical RFC question — deserves its own doc.
17. [ ] **Sharpen the three RFC questions in `README.md` §7.** Replace broad "review the X" bullets with specific answerable questions. Each should be narrow enough that a reviewer can answer yes/no or identify a concrete failure mode. Draft examples live in `CLAUDE.md` under Phase 2 guidance.
18. [ ] **Write `CONTRIBUTING.md`.** Scope: spec and `.ksy` changes only; no firmware PRs until `v1.0-draft` is locked. Include the Kaitai Struct Compiler command (`ksc --target cpp_stl specs/*.ksy`) for validating `.ksy` changes locally.

---

## Phase 3: Release Preparation

Cosmetic but important. Bad framing on HN kills good technical content.

19. [ ] **Prepare the Hacker News post.** Use `docs/summary.md` as the base. "Ask HN" format is stronger than "Show HN" for an RFC. Title suggestion: *"Ask HN: Review our dual-band LoRa mesh protocol spec (zero-heap RP2040, Double Ratchet, Kaitai Structs)"*. Keep it genuinely seeking review, not announcing a product.
20. [ ] **Identify target subreddits.** Primary: `r/embedded`, `r/crypto`, `r/netsec`, `r/amateurradio`. Secondary: `r/raspberry_pi`, `r/Meshtastic`, `r/LoRa`. Each needs a slightly different framing (embedded angle vs crypto angle vs RF angle). Draft the three framings separately.
21. [ ] **Set up GitHub Discussions or a pinned Issue.** A single "RFC v1.0 — Feedback Thread" issue gives reviewers one place to post without scattered PRs. Pin it. Add `rfc`, `spec`, and `needs-review` labels.
22. [ ] **Tag the release commit.** Before posting, tag as `v0.1-rfc` so the HN / Reddit posts have a stable anchor that won't drift as future commits land.

---

## Phase 4: Post-RFC — Spec Lock

The RFC period ends when the hard questions have satisfactory answers,
not on a fixed calendar date.

23. [ ] **Triage feedback.** Categorise into: spec bugs, architectural questions, implementation suggestions (deferred), off-topic.
24. [ ] **Address spec bugs.** Follow-up commits on `main`. Each bug gets a named closing commit linking the issue.
25. [ ] **Answer or revise on the architectural questions.** Primarily: SPI arbitration correctness, ratchet resilience under packet loss, key-ring sizing realism, the 112-byte lock trade-off.
26. [ ] **Lock `v1.0-draft`.** Tag it. Update `SPECIFICATION.md` status line from `v1.0-draft` to `v1.0`. Announce spec freeze.
27. [ ] **Begin firmware planning.** Scaffold the RP2040 C++ project in a separate repo or separate directory. This is a new phase of work outside the scope of this checklist.

---

*Last updated: 2026-04-17. Phase 1 work pending. Phase 0 complete.*
