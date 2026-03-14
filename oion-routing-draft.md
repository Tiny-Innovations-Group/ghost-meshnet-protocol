# GMP Module: Static Onion Routing (868MHz Data Link)

The Ghost Meshnet Protocol (GMP) implements a fixed-size, 3-hop Onion Routing architecture on the 868MHz (or 915MHz) ISM data band. 

Unlike traditional mesh networks where packet sizes fluctuate based on payload length—making them highly susceptible to traffic analysis and requiring dynamic memory allocation (`malloc`)—GMP enforces a mathematically rigid packet structure. Every transmission on the data band is exactly **127 bytes**, regardless of its position in the routing path.

This module details the byte-level architecture that allows GMP to achieve Delay Tolerant Network (DTN) routing, military-grade cryptographic security, and maximum physical radio throughput while strictly adhering to a "Zero-Heap" microcontroller architecture.

## 1. The 127-Byte Dual-Burst Optimization

The absolute maximum payload a standard Semtech LoRa transceiver (e.g., SX1262) can handle in its hardware FIFO buffer is 255 bytes. 

By aggressively optimizing the GMP Onion packet to exactly **127 bytes**, a routing node can load **two complete, independent packets** into the radio hardware simultaneously (127 + 127 = 254 bytes).

**The Tactical Advantage:**
During a legal 1% duty-cycle transmission window, the RP2040 does not need to spin the radio up, transmit, spin down, and spin up again. It executes a **"Dual-Relay Burst,"** transmitting two routed messages in a single continuous physical frame. This halves the preamble overhead, doubles the network throughput, and clears the node's static SRAM `Egress_Queue` twice as fast.



## 2. The 3-Hop "Russian Doll" Architecture

To maintain the fixed 127-byte size and obscure the routing path from Signal Intelligence (SIGINT), the packet is constructed in three nested cryptographic layers.

When a packet is forwarded, the relaying node strips off its layer and **must append random cryptographic padding** to the end of the payload before transmitting it to the next hop. This guarantees the packet never shrinks over the air.

### The Byte Breakdown (Inside-Out)

#### Layer 3: The Core (Hop 3 - Final Destination)
This layer contains the actual text message and application metadata. It is encrypted with the destination node's Double Ratchet message key.
* **Sender Node ID:** 4 bytes (Globally unique 32-bit ID)
* **Auth Tag (MAC):** 16 bytes (Full-strength AES-GCM or ChaCha20-Poly1305)
* **Payload Type Flag:** 1 byte (e.g., `0x01` for Text, `0x02` for GPS)
* **Message ID / Nonce:** 2 bytes (Used for deduplication and Replay Attack defense)
* **Priority / TTL Flag:** 1 byte
* **Compressed Text:** 79 bytes (Holds exactly 140 characters using Static Huffman)
* *Total Core Size: 103 bytes*

#### Layer 2: The Middle Shell (Hop 2 - Relay 2)
This layer only contains instructions on where to send the Core next. It is encrypted with Relay 2's key.
* **Next Hop ID (Destination):** 4 bytes
* **Truncated Auth Tag (MAC):** 8 bytes (Optimized for LoRa ToA)
* **Encrypted Core:** 103 bytes
* *Total Middle Shell Size: 115 bytes*

#### Layer 1: The Outer Shell (Hop 1 - Relay 1)
This is the raw packet transmitted over the air by the sender.
* **Next Hop ID (Relay 2):** 4 bytes
* **Truncated Auth Tag (MAC):** 8 bytes
* **Encrypted Middle Shell:** 115 bytes
* *Total On-Air Packet Size: **127 bytes***

## 3. Cryptographic Defenses & Trade-offs

Designing a protocol for low-bandwidth radio requires calculated compromises. GMP balances perfect security against the physical limits of the LoRa protocol.

### Defense: The Implicit Ratchet Nonce (Anti-Replay)
Standard AEAD cryptography requires a unique 12-byte Nonce to prevent Replay Attacks (where an adversary records and rebroadcasts an old packet). Transmitting a 12-byte random number with every 127-byte packet is too expensive.

**The Solution:** GMP repurposes the 2-byte Application **Message ID** as the variable core of the Nonce. 
Because the Double Ratchet key rotates with every message, the 2-byte ID combined with the 4-byte Sender ID and 4-byte Receiver ID allows the receiving node to reconstruct a unique 12-byte Nonce *locally*. This stops Replay Attacks instantly without wasting airtime.

### Trade-off: Truncated MACs for Relays
To fit the 4-byte Node IDs (ensuring network scalability) and the 140-character text payload into the 127-byte limit, GMP truncates the Authentication Tags (MACs) for the intermediate routing layers from 16 bytes to 8 bytes.

**Pros & Cons:**
* *Con:* An 8-byte MAC lowers the cryptographic threshold for forging a routing header.
* *Pro:* In a slow, duty-cycle-constrained LoRa environment, brute-forcing a 64-bit (8-byte) MAC over the air is statistically impossible before the rotating Double Ratchet key expires.
* *Crucially:* The inner Core Layer retains the full 16-byte MAC. Even if an adversary miraculously forged a routing header, they cannot alter the 140-character payload delivered to the final destination.

## 4. Kaitai Struct (`.ksy`) Implementation Example

Because GMP relies on static memory allocation, the packet architecture is defined mathematically using Kaitai Struct, ensuring safe, zero-heap parsing in C++.

Here is a simplified excerpt of the `gmp_data_frame.ksy` defining the Outer Shell (Hop 1):

```yaml
meta:
  id: gmp_data_frame
  endian: le
seq:
  - id: next_hop_id
    type: u4
    doc: 32-bit globally unique Node ID of Relay 2
  - id: relay_auth_tag
    size: 8
    doc: Truncated 64-bit MAC for the routing shell
  - id: encrypted_payload
    size: 115
    doc: The encrypted Middle Shell (must be exactly 115 bytes)
instances:
  is_valid_size:
    value: _io.size == 127
    doc: Strict enforcement. If the packet is not exactly 127 bytes, the node drops it to prevent heap overflow.
```

5. Summary: The 127-Byte Mastery
By rigidly enforcing a 127-byte maximum packet size on the 868MHz data band, GMP achieves:
 * Zero-Heap Routing: The RP2040 microcontroller allocates fixed 127-byte slots. Memory fragmentation is impossible.
 * Traffic Obfuscation: Every transmission looks identical to an adversary, masking the true sender, destination, and hop count.
 * Maximum Efficiency: The Dual-Relay Burst allows nodes to clear queues rapidly, maximizing the 1% legal duty cycle.
 * Tactical Utility: Despite 3 layers of Onion encryption, the protocol still reliably delivers a fully authenticated, 140-character (Tweet-sized) payload.

