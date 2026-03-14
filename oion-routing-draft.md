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

6.
# GMP Module: CPU-Aligned Onion Routing (868MHz Data Link)

The Ghost Meshnet Protocol (GMP) implements a fixed-size, 3-hop Onion Routing architecture on the 868MHz (or 915MHz) ISM data band. 

Unlike traditional mesh networks where packet sizes fluctuate based on payload length—making them highly susceptible to traffic analysis and requiring dynamic memory allocation (`malloc`)—GMP enforces a mathematically rigid packet structure. 

To achieve maximum throughput while strictly adhering to a "Zero-Heap" architecture, every transmission on the data band is specifically aligned to the processor's memory architecture.

## 1. The 248-Byte "Dual-Relay Burst" Optimization

The RP2040 microcontroller utilizes a 32-bit ARM Cortex-M0+ architecture. Furthermore, standard Semtech LoRa transceivers (e.g., SX1262) have a hardware FIFO buffer limit of 255 bytes.

To maximize network throughput during the legal 1% duty-cycle transmission window, GMP nodes execute a **"Dual-Relay Burst."** Instead of sending one packet at a time, a routing node loads two complete, independent Onion packets into the LoRa hardware simultaneously.

**The Memory Alignment Flex:**
Rather than maxing out the radio buffer at 254 bytes, GMP optimizes the total burst to exactly **248 bytes** (Two 124-byte packets). 
* 248 is perfectly divisible by 4 (Ideal for 32-bit CPUs).
* 248 is perfectly divisible by 8 (Ideal for 64-bit CPUs).

When the RP2040 pulls this 248-byte chunk from the LoRa chip's SPI register, it does not have to execute costly, misaligned byte-shifts. It loops exactly 62 times, grabbing 32-bits per clock cycle, dropping the data cleanly into the static SRAM. This saves vital CPU cycles, reducing latency and preserving micro-amps of battery power on solar deployments.



## 2. The 124-Byte "Russian Doll" Architecture

Because the total burst is 248 bytes, each individual Onion packet must be exactly **124 bytes**, regardless of its position in the routing path. 

When a packet is forwarded, the relaying node strips off its layer and **must append random cryptographic padding** to the end of the payload before transmitting it to the next hop. This guarantees the packet never shrinks over the air, defeating size-based traffic analysis.

### The Byte Breakdown (Inside-Out)

#### Layer 3: The Core (Hop 3 - Final Destination)
This layer contains the actual text message and application metadata. It is encrypted with the destination node's Double Ratchet message key.
* **Sender Node ID:** 4 bytes (Globally unique 32-bit ID)
* **Auth Tag (MAC):** 16 bytes (Full-strength AES-GCM or ChaCha20-Poly1305)
* **Payload Type Flag:** 1 byte (e.g., `0x01` for Text, `0x02` for GPS)
* **Message ID / Nonce:** 2 bytes (Used for deduplication and Replay Attack defense)
* **Priority / TTL Flag:** 1 byte
* **Compressed Text Space:** 76 bytes (Holds max 128 characters using Static Huffman)
* *Total Core Size: 100 bytes*

#### Layer 2: The Middle Shell (Hop 2 - Relay 2)
This layer only contains instructions on where to send the Core next. It is encrypted with Relay 2's key.
* **Next Hop ID (Destination):** 4 bytes
* **Truncated Auth Tag (MAC):** 8 bytes (Optimized for LoRa Time-on-Air)
* **Encrypted Core:** 100 bytes
* *Total Middle Shell Size: 112 bytes*

#### Layer 1: The Outer Shell (Hop 1 - Relay 1)
This is the raw packet transmitted over the air by the sender.
* **Next Hop ID (Relay 2):** 4 bytes
* **Truncated Auth Tag (MAC):** 8 bytes
* **Encrypted Middle Shell:** 112 bytes
* *Total On-Air Packet Size: **124 bytes***



## 3. Cryptographic Defenses & Payload Trade-offs

### The 128-Character Cap
By shrinking the text payload space to 76 bytes to achieve the 124-byte CPU-aligned packet, the user input must be strictly capped. Assuming a Static Huffman compression ratio of ~4.5 bits per character (trained on tactical shorthand), 76 bytes (608 bits) holds approximately 135 characters. 

GMP enforces a rigid **128-character limit** on the smartphone companion app. 
* *Pro:* This leaves a 7-character mathematical buffer, guaranteeing that even highly complex strings will never overflow the 76-byte static SRAM allocation.
* *Pro:* 128 is a culturally symmetric, power-of-2 constraint that encourages tactical brevity.

### Defense: The Implicit Ratchet Nonce (Anti-Replay)
Standard AEAD cryptography requires a unique 12-byte Nonce to prevent Replay Attacks. Transmitting a 12-byte random number with every 124-byte packet is too expensive.

**The Solution:** GMP repurposes the 2-byte Application **Message ID** as the variable core of the Nonce. Because the Double Ratchet key rotates with every message, the 2-byte ID combined with the 4-byte Sender ID and 4-byte Receiver ID allows the receiving node to reconstruct a unique 12-byte Nonce *locally*. This stops Replay Attacks instantly without wasting a single byte of airtime.

## 4. Kaitai Struct (`.ksy`) Implementation 

Because GMP relies on static memory allocation, the packet architecture is defined mathematically using Kaitai Struct, ensuring safe, zero-heap parsing in C++.

Here is the exact layout of the 32-bit aligned Core Layer (`gmp_core_layer.ksy`):

```yaml
meta:
  id: gmp_core_layer
  endian: le
seq:
  - id: sender_node_id
    type: u4
    doc: 32-bit globally unique Node ID of the original sender
  - id: auth_tag_mac
    size: 16
    doc: Full 128-bit MAC to guarantee payload integrity
  - id: payload_type_flag
    type: u1
    doc: Hex flag defining data type (0x01 = Text, 0x02 = Coords)
  - id: message_id
    type: u2
    doc: 16-bit ID used for deduplication and local Nonce generation
  - id: priority_flag
    type: u1
    doc: Application-level priority or Time-to-Live (TTL)
  - id: compressed_text
    size: 76
    doc: Fixed 76-byte bucket holding the Static Huffman bit-stream (Max 128 chars).
instances:
  is_valid_size:
    value: _io.size == 100
    doc: Strict enforcement. Core must be exactly 100 bytes to ensure perfect 124-byte shell alignment.
```