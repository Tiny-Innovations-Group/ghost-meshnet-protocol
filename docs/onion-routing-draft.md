# GMP Module: Static Onion Routing (868MHz Data Link)

The Ghost Meshnet Protocol (GMP) implements a fixed-size, 3-hop Onion Routing architecture on the 868MHz (or 915MHz) ISM data band.

Unlike traditional mesh networks where packet sizes fluctuate based on payload length — making them highly susceptible to traffic analysis and requiring dynamic memory allocation (`malloc`) — GMP enforces a mathematically rigid packet structure. Every transmission on the 868MHz data band is exactly **112 bytes**, regardless of its position in the routing path.

This document explains the *why* behind the 112-byte "Russian Doll" architecture and the specific cryptographic trade-offs it makes. The machine-readable wire format lives in [`specs/gmp_868_data_frame.ksy`](../specs/gmp_868_data_frame.ksy) and [`specs/gmp_868_onion_core.ksy`](../specs/gmp_868_onion_core.ksy). The canonical byte layout and ToA math are in [`SPECIFICATION.md`](../SPECIFICATION.md) §2–§3.

## 1. The 224-Byte Dual-Relay Burst

A single 868MHz LoRa transceiver (SX1262-class) has a 255-byte hardware FIFO. By locking every GMP packet to exactly **112 bytes**, a routing node can load **two complete, independent packets** into the radio hardware simultaneously:

```
112 B packet A │ 112 B packet B  →  224 B Dual-Relay Burst
```

This leaves a **31-byte safety margin** inside the 255-byte FIFO — room for LoRa's preamble and sync-word overhead without risk of buffer overrun during high-stress RF interference.

**The tactical advantage:** during a legal 1% duty-cycle transmission window, the RP2040 does not spin the radio up, transmit, spin down, and spin up again for each packet. It executes a single continuous burst carrying two independent Onions — halving preamble overhead and clearing the static SRAM `Egress_Queue` twice as fast.

At the reference rate (SF7 / 125 kHz / CR 4/5), a 224-byte Dual-Burst has a ToA of ~354 ms. Against the 36 s/hour ETSI/Ofcom budget, that is ~101 bursts/hour × 2 messages = **~202 encrypted messages per hour per node**.

## 2. The 3-Hop "Russian Doll" Architecture

To maintain the fixed 112-byte on-air size and obscure the routing path from Signal Intelligence (SIGINT), each packet is constructed in nested cryptographic layers.

When a relaying node strips its outer layer, it **must append random cryptographic padding** to the next hop's packet to bring it back up to exactly 112 bytes. This guarantees the packet never shrinks over the air — an adversary watching on an SDR sees three identical 112-byte bursts traversing the mesh, not a packet getting progressively smaller with each hop.

### Path trace — Alice → Relay₁ → Relay₂ → Dave

| Hop | What's on the wire | Who can decrypt it |
| --- | --- | --- |
| Alice → R₁ | 12 B plaintext shell addressed to R₁, 100 B ciphertext | R₁ (outer shell), Dave (inner core) |
| R₁ → R₂  | 12 B plaintext shell addressed to R₂, 100 B ciphertext (re-padded) | R₂ (outer shell), Dave (inner core) |
| R₂ → Dave | 12 B plaintext shell addressed to Dave, 100 B ciphertext | Dave — decrypts both the shell and the core |

The inner 100-byte core is encrypted with **Dave's** Double Ratchet message key. Relays R₁ and R₂ cannot decrypt it. They can only read the 12-byte plaintext shell telling them the next hop and verify the truncated MAC.

### Byte breakdown

Plaintext routing shell (12 bytes — parsed at every hop):

| Field | Bytes |
| --- | ---: |
| Next Hop ID | 4 |
| Truncated Auth Tag (MAC) | 8 |

AES-GCM ciphertext core (100 bytes — decrypted only by the final destination):

| Field | Bytes | Notes |
| --- | ---: | --- |
| Sender Node ID | 4 | |
| Full Auth Tag (MAC) | 16 | 128-bit AES-GCM tag |
| Message ID | 2 | Implicit-nonce core |
| Control Byte | 1 | Bit-packed: `payload_type` (3b) + `priority` (2b) + `requires_ack` (1b) + `ttl_mode` (2b) |
| Compressed Text | 77 | Static Huffman over the 6-bit tactical alphabet |

**Total on-air packet: 112 bytes.**

## 3. Cryptographic Defences & Trade-offs

Designing a protocol for low-bandwidth radio requires calculated compromises. GMP balances perfect security against the physical limits of LoRa.

### Trade-off: Truncated MACs for Relays

To fit 4-byte Node IDs (ensuring network scalability) and the 77-byte compressed text payload into the 112-byte limit, GMP truncates the outer-shell Authentication Tag from 16 bytes to **8 bytes**.

| | |
| --- | --- |
| **Con** | An 8-byte MAC lowers the brute-force threshold for forging a routing header from 2¹²⁸ to 2⁶⁴. |
| **Pro** | In a 1%-duty-cycle LoRa environment, transmitting 2⁶⁴ attempts over the air is statistically impossible within the rotating Double Ratchet key's lifetime. Each key is retired after one message. |
| **Critical** | The inner Core Layer retains the **full 16-byte MAC**. Even if an adversary miraculously forged a routing header, they cannot alter the 77-byte payload delivered to the final destination without invalidating the full-strength inner tag. |

### Defence: The Implicit Ratchet Nonce (Anti-Replay)

Standard AEAD cryptography requires a unique 12-byte Nonce per message to prevent Replay Attacks. Transmitting a 12-byte random number with every 112-byte packet costs ~11% of the total payload budget.

**The solution:** GMP repurposes the 2-byte `message_id` field as the variable core of the Nonce. Because the Double Ratchet key rotates with every message, the receiving node combines the 2-byte ID with the 4-byte Sender ID and 4-byte Receiver ID from its routing state to reconstruct a unique 12-byte Nonce **locally** — no bytes transmitted, no replay vulnerability.

### Defence: Uniform Traffic Shape

Every payload is rigidly padded with zeroes to exactly 112 bytes before transmission. An adversary using a Software-Defined Radio (SDR) sees only identical bursts of white noise — no distinction between a short ACK and a full tactical message, no distinction between a packet at Hop 1 vs Hop 3.

## 4. Summary: The 112-Byte Discipline

By rigidly enforcing a 112-byte maximum packet size on the 868MHz data band, GMP achieves:

* **Zero-Heap Routing.** The RP2040 allocates fixed 112-byte slots in the static `Egress_Queue`. Heap fragmentation is mathematically impossible.
* **Traffic Obfuscation.** Every transmission looks identical to an adversary, masking sender, destination, and hop count.
* **Maximum Efficiency.** The 224-byte Dual-Relay Burst clears two packets per radio wake-up, maximising the 1% legal duty cycle at ~202 msgs/hr/node (SF7 reference rate).
* **Tactical Utility.** Despite 3 layers of Onion routing, the protocol still reliably delivers a fully authenticated compressed tactical payload within the airtime budget.
