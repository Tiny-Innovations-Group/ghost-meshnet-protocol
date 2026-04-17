# GMP: Ghost Meshnet Protocol

> A mathematically rigid, zero-heap LoRa mesh protocol designed for tactical, delay-tolerant Onion Routing.

GMP is a dual-band, off-grid communication architecture built specifically for the hardware constraints of the RP2040 microcontroller and Semtech LoRa transceivers.

Modern software relies on infinite bandwidth and dynamic memory. GMP is designed by working backward from physical constraints: the 255-byte FIFO buffer of a radio chip, the zero-heap requirements of embedded C++, and the mathematical laws of Elliptic Curve Cryptography over a 1% legal duty cycle.

## 1. The Dual-Band Architecture

To solve the channel congestion that plagues standard single-band mesh networks, GMP strictly separates the Control Plane from the Data Plane.

* **The Control Plane (433MHz):** A slow, long-range channel dedicated entirely to node discovery, X3DH cryptographic key exchange, and air-traffic coordination (RTS/CTS). It acts as the decentralized directory server.
* **The Data Plane (868MHz / 915MHz):** Strictly reserved for high-speed, mathematically rigid Onion-routed payloads. It remains completely silent until coordinated by the 433MHz channel, at which point it delivers collision-free bursts of ciphertext.

## 2. The 224-Byte "Dual-Relay Burst"

The absolute maximum payload a standard LoRa transceiver (e.g., SX1262) can handle in its hardware buffer is 255 bytes.

To maximize throughput and minimize Time-on-Air (ToA), GMP nodes execute a "Dual-Relay Burst." The architecture mathematically enforces a maximum packet size of exactly **112 bytes** — the "Golden Ratio."

This allows the RP2040 to load two complete, independent packets into the radio hardware simultaneously ($112 \times 2 = 224$ bytes), leaving a **31-byte safety margin** inside the 255-byte hardware FIFO.

* **Memory Alignment:** 112 bytes = 14 × 64-bit cycles = 28 × 32-bit cycles. Zero misaligned memory pointers, zero wasted clock ticks on SPI transfers.
* **Throughput:** Halves the preamble overhead. At the reference rate (SF7 / 125 kHz / CR 4/5), a 224-byte Dual-Burst has a ToA of ~354 ms, giving **~202 encrypted messages per hour per node** within the Ofcom/ETSI 1% duty cycle (36 s/hour budget).

See [`SPECIFICATION.md`](../SPECIFICATION.md) §3 for the full Time-on-Air table across SF7 / SF9 / SF12 at CR 4/5 and 4/6.

## 3. Fixed-Size Onion Routing (3-Hop)

To defeat traffic analysis, every transmission on the 868MHz data band is exactly 112 bytes, regardless of its position in the routing path. GMP utilizes a 3-hop "Russian Doll" architecture.

When a packet is forwarded, the relaying node strips its layer and must append random cryptographic padding to guarantee the packet never shrinks over the air.

### The 112-Byte Packet Breakdown

**Outer Routing Shell — 12 bytes, plaintext, parsed at each relay**

* Next Hop ID: 4 bytes
* Truncated Auth Tag (MAC): 8 bytes

**Encrypted Core Blob — 100 bytes, AES-GCM ciphertext, parsed only by the final destination**

* Sender Node ID: 4 bytes
* Full Auth Tag (MAC): 16 bytes
* Message ID / Implicit Nonce Core: 2 bytes
* Control Byte (bit-packed): 1 byte — payload type (3b) + priority (2b) + requires_ack (1b) + ttl_mode (2b)
* Compressed Text: 77 bytes — Static Huffman over the 6-bit tactical alphabet

**Total on-air packet: 112 bytes**

## 4. Cryptographic Defenses

GMP prioritizes absolute physical security over user convenience.

* **The Implicit Ratchet Nonce (Anti-Replay):** Standard AEAD requires a 12-byte Nonce. Transmitting this wastes precious airtime. GMP repurposes the 2-byte Application `Message_ID` as the variable core of the Nonce. Combined with the Double Ratchet (which guarantees the encryption key rotates every message), the receiving node reconstructs the 12-byte Nonce locally, stopping Replay Attacks without bloating the packet.
* **Hardware Root of Trust (The "Fox Hunt" Defense):** Identity Keys are not stored in readable software memory. They are derived directly from the physical silicon — either via a smartphone Secure Enclave or an RP2040 SRAM PUF (Physically Unclonable Function).
* **One Device, One Identity:** Because keys are fused to specific silicon, software cloning is impossible. To compromise an identity or decrypt intercepted traffic, an adversary must execute a radio direction-finding "Fox Hunt" to physically capture the specific node in the field.

## 5. Kaitai Struct Implementation

Because GMP relies entirely on static memory allocation to prevent heap fragmentation, the packet architecture is defined mathematically using Kaitai Struct (`.ksy`). The `.ksy` files are the **canonical machine-readable wire format**; the prose in this document and in [`SPECIFICATION.md`](../SPECIFICATION.md) explains them.

* [`specs/gmp_433_beacon.ksy`](../specs/gmp_433_beacon.ksy) — 104-byte Control Plane beacon (discovery, X3DH, RTS/CTS).
* [`specs/gmp_868_data_frame.ksy`](../specs/gmp_868_data_frame.ksy) — 112-byte plaintext Outer Routing Shell for the Data Plane.
* [`specs/gmp_868_onion_core.ksy`](../specs/gmp_868_onion_core.ksy) — 100-byte decrypted Onion Core with the bit-packed control byte and all four enums (`payload_type`, `priority`, `ack`, `ttl`).

Kaitai compiles these into strongly-typed C++ / Python / Rust parsers, so an illegal enum value refuses to compile — a protocol bug becomes a build failure.
