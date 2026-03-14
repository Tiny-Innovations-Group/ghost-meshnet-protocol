# GMP: Ghost Meshnet Protocol

> A mathematically rigid, zero-heap LoRa mesh protocol designed for tactical, delay-tolerant Onion Routing.

GMP is a dual-band, off-grid communication architecture built specifically for the hardware constraints of the RP2040 microcontroller and Semtech LoRa transceivers.

Modern software relies on infinite bandwidth and dynamic memory. GMP is designed by working backward from physical constraints: the 255-byte FIFO buffer of a radio chip, the zero-heap requirements of embedded C++, and the mathematical laws of Elliptic Curve Cryptography over a 1% legal duty cycle.

## 1. The Dual-Band Architecture

To solve the channel congestion that plagues standard single-band mesh networks, GMP strictly separates the Control Plane from the Data Plane.

* **The Control Plane (433MHz):** A slow, long-range channel dedicated entirely to node discovery, X3DH cryptographic key exchange, and air-traffic coordination (CSMA). It acts as the decentralized directory server.
* **The Data Plane (868MHz / 915MHz):** Strictly reserved for high-speed, mathematically rigid Onion-routed payloads. It remains completely silent until coordinated by the 433MHz channel, at which point it delivers collision-free bursts of ciphertext.

## 2. The 248-Byte "Dual-Relay Burst"

The absolute maximum payload a standard LoRa transceiver (e.g., SX1262) can handle in its hardware buffer is 255 bytes.

To maximize throughput and minimize Time-on-Air (ToA), GMP nodes execute a "Dual-Relay Burst." The architecture mathematically enforces a maximum packet size of exactly **124 bytes**.

This allows the RP2040 to load two complete, independent packets into the radio hardware simultaneously ($124 \times 2 = 248$ bytes).

* **Memory Alignment:** 248 bytes is perfectly divisible by 4 (for 32-bit CPUs like the RP2040), ensuring zero-shift, cycle-perfect memory transfers via SPI.
* **Throughput:** Halves the preamble overhead, effectively doubling the legal capacity of the network under Ofcom/ETSI 1% duty cycle regulations (achieving ~184 messages per hour, per node).

## 3. Fixed-Size Onion Routing (3-Hop)

To defeat traffic analysis, every transmission on the 868MHz data band is exactly 124 bytes, regardless of its position in the routing path. GMP utilizes a 3-hop "Russian Doll" architecture.

When a packet is forwarded, the relaying node strips its layer and must append random cryptographic padding to guarantee the packet never shrinks over the air.

### The 124-Byte Packet Breakdown

**Layer 3: The Core (Hop 3 - Final Destination)**

* Sender Node ID: 4 bytes
* Auth Tag (Full MAC): 16 bytes
* Payload Type Flag: 1 byte
* Message ID / Nonce: 2 bytes
* Priority / TTL Flag: 1 byte
* Compressed Text Space: 76 bytes (Holds max 128 chars via Static Huffman)
* *Total Core: 100 bytes*

**Layer 2 & Layer 1: The Routing Shells**

* Next Hop ID: 4 bytes
* Truncated Auth Tag (MAC): 8 bytes (Optimized for LoRa ToA)
* Encrypted Payload (Inner Layers): 112 bytes / 100 bytes
* *Total On-Air Packet: 124 bytes*

## 4. Cryptographic Defenses

GMP prioritizes absolute physical security over user convenience.

* **The Implicit Ratchet Nonce (Anti-Replay):** Standard AEAD requires a 12-byte Nonce. Transmitting this wastes precious airtime. GMP repurposes the 2-byte Application `Message_ID` as the variable core of the Nonce. Combined with the Double Ratchet (which guarantees the encryption key rotates every message), the receiving node reconstructs the 12-byte Nonce locally, stopping Replay Attacks without bloating the packet.
* **Hardware Root of Trust (The "Fox Hunt" Defense):** Identity Keys are not stored in readable software memory. They are derived directly from the physical silicon—either via a smartphone Secure Enclave or an RP2040 SRAM PUF (Physically Unclonable Function).
* **One Device, One Identity:** Because keys are fused to specific silicon, software cloning is impossible. To compromise an identity or decrypt intercepted traffic, an adversary must execute a radio direction-finding "Fox Hunt" to physically capture the specific node in the field.

## 5. Kaitai Struct Implementation

Because GMP relies entirely on static memory allocation to prevent heap fragmentation, the packet architecture is defined mathematically using Kaitai Struct (`.ksy`).

*(Include your `gmp_core_layer.ksy` and `gmp_data_frame.ksy` snippets here)*
