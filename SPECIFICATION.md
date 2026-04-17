# Ghost Meshnet Protocol (GMP) — Wire Specification

> **Status:** v1.0-draft. This is the canonical, binding protocol spec.
> The machine-readable source of truth is the Kaitai Struct files under
> [`/specs/`](specs/). The inline YAML blocks below mirror those files and
> are provided for human readability.

GMP is a dual-band LoRa protocol. Its two bands carry strictly different
traffic:

| Plane | Band | Packet | Size | Purpose |
| --- | --- | --- | ---: | --- |
| Control | 433 MHz | `gmp_433_beacon` | 104 B | Discovery, X3DH, RTS/CTS |
| Data | 868/915 MHz | `gmp_868_data_frame` wrapping `gmp_868_onion_core` | 112 B | Encrypted Onion payloads |

Every field offset and every bit of every control byte is locked. Illegal
enum values refuse to compile — a protocol bug becomes a build failure.

---

## 1. The 433MHz Control Plane: The 104-Byte Beacon

> **Design Constraint:** Absolute 32-bit and 64-bit CPU memory alignment
> to prevent wasted clock cycles during SPI hardware transfers.

The 433MHz channel acts as the decentralised directory server and
air-traffic controller. To optimise Time-on-Air (ToA) and guarantee
perfect memory alignment on the RP2040 microcontroller, the Discovery
Beacon is rigidly constrained to exactly **104 bytes**.

By compressing the network timestamp from *seconds* to a 24-bit
*minutes* counter (~32 years of rollover protection), we merge the
timestamp, power telemetry, and control flags into a single,
perfectly aligned 32-bit (4-byte) unified header.

* **Mathematical Alignment:** 104 bytes = 26 × 32-bit cycles = 13 ×
  64-bit cycles. Zero padding, zero wasted clock cycles.

### 104-Byte Profile Breakdown

| Field | Bytes | Notes |
| --- | ---: | --- |
| Unified Header | 4 | Control Type (4b) + Power State (4b) + 24-bit Epoch Minutes |
| Sender Node ID | 4 | |
| Public Identity Key | 32 | Curve25519 |
| Hardware Signature | 64 | Ed25519 from PUF / Secure Enclave |
| **Total** | **104** | |

### Kaitai Struct Specification

Canonical source: [`/specs/gmp_433_beacon.ksy`](specs/gmp_433_beacon.ksy)

```yaml
meta:
  id: gmp_433_beacon
  endian: le
  bit_endian: le
seq:
  # The 32-bit (4-byte) Unified Header
  - id: control_type
    type: b4
    enum: control_type_enum
  - id: power_state
    type: b4
    enum: power_state_enum
  - id: epoch_minutes
    type: b24
    doc: 'Minutes since Jan 1, 2024. Prevents long-term replay attacks.'

  # The Cryptographic Payload (100 bytes)
  - id: sender_node_id
    type: u4
  - id: public_identity_key
    size: 32
  - id: hardware_signature
    size: 64

enums:
  control_type_enum:
    0b0000: discovery_beacon
    0b0001: x3dh_handshake_init
    0b0010: x3dh_handshake_response
    0b0011: rts_request_to_send
    0b0100: cts_clear_to_send

  power_state_enum:
    0b0000: critical_do_not_route
    0b0001: battery_7_percent
    0b0010: battery_14_percent
    0b0011: battery_21_percent
    0b0100: battery_28_percent
    0b0101: battery_35_percent
    0b0110: battery_42_percent
    0b0111: battery_50_percent
    0b1000: battery_57_percent
    0b1001: battery_64_percent
    0b1010: battery_71_percent
    0b1011: battery_78_percent
    0b1100: battery_85_percent
    0b1101: battery_92_percent
    0b1110: battery_100_percent
    0b1111: external_solar_prioritize

instances:
  is_hardware_aligned:
    value: _io.size == 104
    doc: 'Strict validation: enforces 32-bit / 64-bit memory alignment.'
```

---

## 2. The 868MHz Data Plane: The 112-Byte Golden Ratio

> **Design Constraint:** Maximise the 255-byte LoRa hardware FIFO to
> achieve a safe "Dual-Relay Burst" (224 bytes) inside the legal 1%
> ETSI/Ofcom duty cycle, while keeping the packet perfectly aligned
> to both 32-bit and 64-bit CPU memory architectures.

GMP mathematically enforces a strict **112-byte** limit for every
over-the-air data packet. The packet is an Onion: a 12-byte plaintext
Routing Shell wraps a 100-byte encrypted Core Blob.

### 112-Byte Profile Breakdown

**Outer Routing Shell — 12 bytes, plaintext, parsed at each relay**

| Field | Bytes |
| --- | ---: |
| Next Hop ID | 4 |
| Truncated Auth Tag (MAC) | 8 |

**Encrypted Core Blob — 100 bytes, AES-GCM ciphertext, parsed only by the final destination**

| Field | Bytes | Notes |
| --- | ---: | --- |
| Sender Node ID | 4 | |
| Full Auth Tag | 16 | Full 128-bit AES-GCM tag |
| Message ID | 2 | Implicit-nonce core |
| Control Byte | 1 | Bit-packed: payload_type (3b) + priority (2b) + requires_ack (1b) + ttl_mode (2b) |
| Compressed Text | 77 | Static Huffman over the 6-bit tactical alphabet |

### Trade-offs & Architecture Decisions

* **Pro — Perfect Silicon Alignment:** 112 bytes = 14 × 64-bit cycles
  = 28 × 32-bit cycles. Zero misaligned memory pointers, zero wasted
  clock ticks.
* **Pro — Buffer Safety:** A Dual-Burst totals 224 bytes. This fits
  comfortably inside the 255-byte LoRa hardware buffer, leaving a
  31-byte safety margin against high-stress RF interference.
* **Con — Zero Metadata Bloat:** The protocol is effectively
  "locked." Because the text payload is fixed at 77 bytes, there is
  no room to add arbitrary features (avatars, read-receipt
  timestamps) in the future without cannibalising text space. We
  accept this trade-off for speed.

### Security Validation

Shrinking the packet from standard 128-byte alignments does **not**
degrade cryptographic strength.

* **AES-GCM as a stream cipher:** AES-GCM does not require plaintext
  padding to 16-byte blocks; a 100-byte encrypted core is
  mathematically native and secure.
* **Primitives retained:** The 16-byte full Authentication Tag and
  the implicitly derived 12-byte Double-Ratchet Nonce remain
  completely intact.
* **Traffic-analysis defence:** Every payload is rigidly padded with
  zeroes to hit exactly 112 bytes before transmission, so an
  adversary on an SDR sees only identical bursts of white noise.

### 2.1 The Outer Routing Shell

Canonical source: [`/specs/gmp_868_data_frame.ksy`](specs/gmp_868_data_frame.ksy)

```yaml
meta:
  id: gmp_868_data_frame
  endian: le
seq:
  - id: next_hop_id
    type: u4
    doc: 'The physical LoRa node ID for the immediate next hop.'
  - id: truncated_mac
    size: 8
    doc: 'Truncated AES-GCM Auth Tag for outer shell validation.'
  - id: encrypted_core_blob
    size: 100
    doc: 'Raw AES-GCM ciphertext. Decrypted by the final destination only.'

instances:
  is_hardware_aligned:
    value: _io.size == 112
    doc: 'Enforces the 112-byte Golden Ratio for Dual-Burst functionality.'
```

### 2.2 The Decrypted Onion Core

Canonical source: [`/specs/gmp_868_onion_core.ksy`](specs/gmp_868_onion_core.ksy)

```yaml
meta:
  id: gmp_868_onion_core
  endian: le
  bit_endian: le
seq:
  - id: sender_node_id
    type: u4
  - id: full_auth_tag
    size: 16
  - id: message_id
    type: u2

  # The Bit-Packed Control Byte (1 byte total)
  - id: payload_type
    type: b3
    enum: payload_type_enum
  - id: priority
    type: b2
    enum: priority_enum
  - id: requires_ack
    type: b1
    enum: ack_enum
  - id: ttl_mode
    type: b2
    enum: ttl_enum

  - id: compressed_text
    size: 77

enums:
  payload_type_enum:
    0b000: text_message
    0b001: gps_coordinate
    0b010: sos_emergency
    0b011: cryptographic_key_update
    0b100: network_ping_ack

  priority_enum:
    0b00: priority_low_background
    0b01: priority_normal
    0b10: priority_high_tactical
    0b11: priority_critical_bypass_silence

  ack_enum:
    0b0: fire_and_forget
    0b1: receiver_must_ack

  ttl_enum:
    0b00: ttl_1_hour
    0b01: ttl_24_hours
    0b10: ttl_7_days
    0b11: ttl_infinite

instances:
  is_core_aligned:
    value: _io.size == 100
```

---

## 3. Time-on-Air & Network Capacity

Loose ToA estimates for the Data Plane across the spreading factors and
coding rates GMP is expected to support. Assumptions: **BW = 125 kHz**,
explicit header, CRC on, 8-symbol preamble, Low-Data-Rate Optimisation
enabled only at SF12. The 1% ETSI/Ofcom duty cycle gives each band a
budget of **36 seconds per hour**.

| SF | CR | ToA — 112 B single | ToA — 224 B Dual-Burst | Bursts / hr @ 1% | Msgs / hr (Dual × 2) |
| :---: | :---: | ---: | ---: | ---: | ---: |
| **7**  | 4/5 | ~190 ms  | ~354 ms  | ~101 | **~202** |
| **7**  | 4/6 | ~223 ms  | ~420 ms  | ~85  | ~170 |
| **9**  | 4/5 | ~615 ms  | ~1.11 s  | ~32  | ~64  |
| **9**  | 4/6 | ~722 ms  | ~1.31 s  | ~27  | ~54  |
| **12** | 4/5 | ~4.10 s  | ~7.38 s  | ~4   | ~8   |
| **12** | 4/6 | ~4.79 s  | ~8.72 s  | ~4   | ~8   |

### Interpretation

* **SF7 CR 4/5 is the reference rate.** It is the only rate at which
  the "~204 encrypted messages per hour per node" headline figure holds.
* **CR 4/6 costs ~19% throughput** for one extra parity bit. Useful
  under heavy interference; not free.
* **SF9 is the natural resilience mode.** ~64 msgs/hr/node is still
  enough for tactical traffic, and the Control Plane can explicitly
  demote the Data Plane to SF9 via an RTS flag.
* **SF12 is pager-grade.** A single Dual-Burst consumes ~20% of the
  hourly budget. Reserved for last-mile emergency SOS / beaconing,
  not general traffic.
* **Control Plane implications:** the ~0.25 s RTS/CTS figure assumes
  SF7 on 433 MHz. If the Control Plane is forced to SF9 or SF12 the
  network cannot orchestrate a full 202-msg/hr Data Plane.

> **Caveat:** These numbers assume 125 kHz bandwidth and a standard
> 8-symbol preamble. 250 kHz roughly halves ToA at equivalent
> sensitivity loss. The Semtech LoRa calculator is the reference for
> exact figures — treat this table as within a few percent of the true
> value, not a substitute for the vendor calculation.

---

> **Ghost Meshnet Protocol (GMP) Specification**
> © 2026 Tiny Innovations Group Ltd. All Rights Reserved.
> Registered in England & Wales (No. 16939792). Registered Office: The Work Lab, Claydons Lane, Rayleigh, Essex, SS6 7UP.
> Designed and engineered in the United Kingdom.
>
> *Released under the **Apache 2.0 License**. For commercial integration, hardware partnerships, or security disclosures, please refer to the `SECURITY.md` policy.*
