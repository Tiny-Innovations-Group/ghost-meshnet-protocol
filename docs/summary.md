# Ghost Meshnet Protocol (GMP) — Release Summary

> **Status:** Pre-implementation RFC. No firmware yet. We are publishing the
> protocol specification, SRAM memory maps, and Kaitai Structs under Apache 2.0
> and actively seeking peer review before a single line of C++ is written.

## Elevator pitch

GMP is a dual-band, zero-heap LoRa mesh protocol for the RP2040. It is designed
by working backwards from physical constraints — the 255-byte radio FIFO, the
1% ETSI/Ofcom duty cycle, the 264 KB SRAM budget, and the mathematical laws of
elliptic-curve cryptography — instead of forwards from application convenience.

Every packet size, every field offset, and every bit of every control byte is
locked to a specification file a compiler can verify. There is no dynamic
allocation in the hot path, no variable-length headers on the wire, and no
ambiguity about what a byte means.

## Why another mesh protocol?

Meshtastic and Reticulum are excellent for accessible, community-scale
communication. They are not designed for persistent, covert, or
high-reliability infrastructure. Two architectural problems appear as soon as
you try to push them into that role:

1. **Single-band congestion and interception.** Key exchange and encrypted
   payloads share one RF band. Traffic analysis becomes trivial, and handshake
   collisions degrade the network under load.
2. **Dynamic memory exhaustion.** `malloc`, `std::vector`, and `String` in an
   unpredictable RF environment fragment the heap over days or weeks. Remote
   solar-powered nodes silently die and need manual intervention.

GMP refuses both of those trade-offs at the architecture level.

## The three load-bearing ideas

### 1. Dual-band separation (433MHz + 868MHz)

- **Control Plane — 433MHz:** slow, long-range, dedicated to discovery, X3DH
  key exchange, and RTS/CTS air-traffic control. The decentralised directory
  server.
- **Data Plane — 868/915MHz:** silent until the Control Plane grants a
  transmission window. Then it fires fixed-size encrypted bursts.

Splitting the planes physically means SIGINT cannot correlate handshakes with
payloads by listening to one radio.

### 2. The 112-byte "Golden Ratio" data packet

Every 868MHz packet is exactly **112 bytes** on the wire. Not ≤112 — exactly
112, padded with zeroes when necessary.

| Component | Bytes | Notes |
| --- | ---: | --- |
| Outer routing shell (plaintext) | 12 | `next_hop_id` (4) + `truncated_mac` (8) |
| Encrypted core blob (AES-GCM ciphertext) | 100 | Sender ID, auth tag, bit-packed control byte, 77 bytes of compressed text |
| **Total** | **112** | |

Why 112?

- **Silicon alignment.** 112 = 14 × 8 (64-bit) = 28 × 4 (32-bit). Zero shifts,
  zero padding on SPI transfers.
- **Dual-Relay Burst.** The RP2040 loads two packets (224 bytes) into the
  SX1262 FIFO simultaneously, leaving a 31-byte safety margin inside the
  255-byte hardware buffer.
- **Traffic-analysis defence.** Every burst on an SDR looks identical.
- **Duty-cycle maths.** ToA for 224 bytes at SF7/125kHz/CR4/5 is ~350 ms. With
  a 36 s/hour legal budget, that is ~102 bursts × 2 messages = **~204 encrypted
  messages per hour per node** on the Data Plane alone.

The 433MHz Control Plane has a separate 36 s/hour budget; an RTS/CTS ping
is ~0.25 s, giving ~140 coordination pings per hour — enough to orchestrate
the full capacity of the Data Plane.

### 3. Specification-first, compiler-enforced

The wire format is defined in Kaitai Struct (`.ksy`) files, not prose:

- [`specs/gmp_433_beacon.ksy`](../specs/gmp_433_beacon.ksy) — 104-byte 433MHz
  Control Plane beacon. Unified 32-bit header (control type, power state,
  24-bit epoch-minutes timestamp) followed by the 100-byte crypto payload.
- [`specs/gmp_868_data_frame.ksy`](../specs/gmp_868_data_frame.ksy) — the
  112-byte outer routing shell for the 868MHz Data Plane.
- [`specs/gmp_868_onion_core.ksy`](../specs/gmp_868_onion_core.ksy) — the
  100-byte plaintext structure that emerges after AES-GCM decryption of the
  shell's `encrypted_core_blob`.

Every ambiguous field is an `enum` with explicit `0b` bit values. Kaitai
compiles these into strongly-typed C++ / Python / Rust parsers, so an illegal
`priority` or `ttl_mode` value refuses to compile — a protocol bug becomes a
build failure.

## Cryptographic model (in one paragraph)

X3DH handshake + Double Ratchet, exactly as in Signal, but with two
adaptations for the radio environment:

1. **Implicit Ratchet Nonce.** AES-GCM needs a 12-byte nonce per message.
   Putting that on the wire wastes 12 bytes of a 112-byte budget, so GMP
   reconstructs the nonce locally from the 2-byte `message_id` plus the
   current ratchet state. The 10 bytes saved go straight into payload.
2. **Hardware Root of Trust.** Identity keys are derived from silicon, not
   stored in readable memory — smartphone Secure Enclave on the client side,
   RP2040 SRAM PUF on the node side. To compromise an identity or decrypt
   captured traffic, an adversary has to physically capture the specific node
   via a direction-finding "fox hunt". Software cloning is impossible by
   construction.

## The "Quarantined Heap" SRAM map

GMP does not ban `malloc` — `RadioLib`, `libsodium`, and the BLE stack need
it. It quarantines it. 50 KB is reserved for third-party dynamic allocation;
all GMP-owned state (routing table, key ring, egress queue, radio buffers) is
statically allocated with fixed-size slots. When the BLE config radio is
disabled at deployment, heap activity drops to near-zero and fragmentation
becomes mathematically bounded.

## What we are asking for

This is the RFC phase. Firmware work starts only when the 1.0-draft is locked.
The specific things we want eyes on:

1. **Dual-radio SPI handoff.** The RP2040 has two LoRa transceivers competing
   for one SPI bus and one CPU. We propose PIO state machines to manage
   chip-select contention. We want to know where this breaks under sustained
   burst traffic.
2. **Ratchet resilience under packet loss.** A node that misses enough 433MHz
   broadcasts falls out of key sync. Our static 50-slot key ring uses an LRU
   replacement. Does this break Post-Compromise Security in realistic loss
   scenarios?
3. **Queue sizing.** The 20-slot static Egress Queue and 100-slot Routing
   Table are guesses informed by the duty cycle, not field data. Are they
   realistic for a heavily utilised relay?
4. **The 112-byte lock.** Shrinking from 128 to 112 buys alignment and
   throughput but kills future extensibility. Is this the right trade?

Issues and PRs against `.ksy` or Markdown files are open. We want the
protocol criticised hard before it is cast into firmware.

---

© 2026 Tiny Innovations Group Ltd. — Registered in England & Wales
(No. 16939792). Released under the Apache 2.0 License. Designed and engineered
in the United Kingdom.
