# Security Policy

The Ghost Meshnet Protocol (GMP) is a pre-1.0 draft specification under
public review. This document explains what we treat as a security issue,
how to report one, and what response you can expect.

> **Status note.** GMP is currently a *protocol specification only* — no
> production firmware exists yet. Vulnerability reports at this stage
> concern flaws in the spec itself (cryptographic weaknesses, protocol
> design errors, traffic-analysis leaks) rather than implementation bugs.

---

## 1. Scope

In scope for disclosure:

* **Cryptographic weaknesses** in the documented X3DH handshake, Double
  Ratchet handoff, AES-GCM construction, implicit-nonce derivation, or
  Ed25519 hardware signature flow described in
  [`SPECIFICATION.md`](SPECIFICATION.md) and
  [`docs/encryption-ratchet.md`](docs/encryption-ratchet.md).
* **Protocol design flaws** in the 112-byte Onion Routing layout, the
  truncated outer MAC, the 433MHz RTS/CTS coordination, or the dual-band
  separation of control and data planes.
* **Traffic-analysis or timing leaks** that defeat the uniform 112-byte
  packet shape or the 224-byte Dual-Relay Burst obfuscation goals.
* **Wire-format ambiguities** in the canonical Kaitai Struct files
  ([`/specs/*.ksy`](specs/)) that would allow two conformant implementations
  to disagree on the meaning of a packet.
* **Anti-replay or key-rotation flaws** in the Double Ratchet message-key
  lifecycle.

Out of scope at this stage:

* Implementation bugs in third-party firmware, libraries, or apps. (No
  reference firmware is published yet.)
* Denial-of-service via lawful RF jamming. The 433/868MHz ISM bands are
  inherently jammable; GMP does not claim resistance to physical-layer
  denial.
* Issues that require an attacker who already has physical possession of
  the target hardware. The "Fox Hunt" defence explicitly accepts that an
  adversary who captures the silicon can break the identity binding.
* Social-engineering attacks against future companion-app users.

---

## 2. How to report

Please report suspected vulnerabilities **privately**, not via public
GitHub issues or pull requests, until a fix or mitigation has been
agreed.

* **Email:** `security@ghost-meshnet.org` *(placeholder until the
  v0.1-rfc tag is cut — will be replaced with a monitored address)*
* **PGP:** A signing key for the above address will be published in this
  file at the point of the v0.1-rfc release tag.

In your report, please include:

1. The artefact you are referring to: file path and (where relevant)
   section or line numbers in `SPECIFICATION.md`, the relevant
   `.ksy` file, or one of the `docs/` modules.
2. A concrete description of the flaw and its impact (confidentiality,
   integrity, availability, traffic analysis, identity binding).
3. Where possible, a reproducer: a worked example, a packet trace, or a
   reference to the underlying cryptographic result.

---

## 3. Response SLA

While GMP is in the public RFC period, we commit to:

| Stage | Target |
| --- | --- |
| Acknowledge receipt of report | within **3 working days** |
| Initial triage and severity assessment | within **10 working days** |
| Status update or remediation plan | within **30 working days** |
| Public disclosure (coordinated with reporter) | after fix is in `main`, or after **90 days**, whichever is sooner |

We will credit reporters in the commit message and release notes unless
they request otherwise.

---

## 4. Coordinated disclosure

We follow standard coordinated-disclosure practice. If you have already
notified another party (e.g. a downstream implementer once firmware
exists, or a related upstream library), please tell us in your initial
report so we can align timelines.

For protocol-level flaws that affect the on-air wire format, fixes will
ship as a numbered erratum against the current `vX.Y-draft` tag rather
than as a silent change to `main`. The errata log will live alongside
`SPECIFICATION.md` once the first such fix is required.

---

*This policy will be revisited at the `v1.0-draft` lock and again at
`v1.0`. Until then, treat all timelines as best-effort during the open
RFC review period.*
