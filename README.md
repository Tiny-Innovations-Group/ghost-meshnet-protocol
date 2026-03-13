# Ghost Meshnet Protocol (GMP)

**A Zero-Heap, Dual-Band LoRa Mesh Architecture using Static-Memory Double Ratchet Encryption.**

> **Note:** This repository currently contains **no C++ implementation code**. We are publishing the protocol specification, the SRAM memory maps, and the Kaitai Structs (`.ksy`) under an Apache 2.0 license. We are actively seeking peer review from embedded engineers and security researchers on the dual-radio SPI handoff state machine and the static memory key-ring rotation before firmware development begins.

---

## 1. Abstract

Modern open-source mesh networks (e.g., Meshtastic, Reticulum) provide excellent accessible communication but suffer from two critical architectural flaws when deployed as persistent, covert, or high-reliability infrastructure:

1. **Single-Band Congestion & Interception:** Both cryptographic handshakes and encrypted payloads share the same physical RF band, making traffic analysis and Signal Intelligence (SIGINT) interception trivial.
2. **Dynamic Memory Exhaustion:** Reliance on dynamic memory allocation (`malloc`, `std::vector`, `String`) inevitably leads to heap fragmentation in unpredictable RF environments, causing remote, solar-powered nodes to crash and require manual intervention.

The **Ghost Meshnet Protocol (GMP)** proposes a mathematically rigid, dual-band architecture designed to run on the Raspberry Pi Pico (RP2040) using strictly static memory allocation. It physically separates out-of-band key exchanges (433MHz) from encrypted data payloads (868/915MHz) while guaranteeing absolute cryptographic uptime.

---

## 2. Hardware Architecture & BOM

GMP is designed for low-SWaP (Size, Weight, and Power) deployments using accessible, off-the-shelf commercial components.

* **Microcontroller:** 1x Raspberry Pi Pico (RP2040) - Chosen for its deterministic dual-core architecture and PIO (Programmable I/O) capabilities to handle dual SPI buses.
* **Radio A (Control/Key Channel):** 1x Heltec LoRa Node (433MHz) - High penetration, long-range band dedicated exclusively to Double Ratchet key exchanges and network topology metadata.
* **Radio B (Data Channel):** 1x Heltec LoRa Node (868MHz or 915MHz ISM) - Higher bandwidth channel dedicated exclusively to AES-GCM encrypted data payloads.
* **Radio C (Local Admin):** Built-in 2.4GHz BLE - Used strictly for initial node setup and local message injection via smartphone. **Disabled during tactical deployment.**
* **Power:** Solar charge controller + rechargeable AA (NiMH) battery array.

---

## 3. The "Quarantined Heap" SRAM Memory Map

GMP does not ban the heap entirely; it quarantines it. We acknowledge that foundational libraries (`RadioLib`, `libsodium`) and the 2.4GHz Bluetooth stack require dynamic allocation. 

However, **all GMP protocol routing, queues, and cryptographic states are strictly statically allocated.** Once the BLE config is disabled and the node enters "Mesh Mode," heap activity drops to near zero, preventing long-term fragmentation.

| Section | Allocation Strategy | Size (KB) | Description |
| --- | --- | --- | --- |
| **.bss / .data** | Static System Globals | ~12.0 | RTOS/Scheduler overhead, hardware HAL states, and peripheral buffers. |
| **Radio A (433MHz)** | Fixed Array (10 slots) | 2.5 | Queue for incoming/outgoing Diffie-Hellman handshakes (max 255 bytes each). |
| **Radio B (836MHz)** | Fixed Array (20 slots) | 5.1 | Queue for AES-GCM data payloads. |
| **Crypto Key Ring** |  Fixed Ring Buffer (50 slots) | 25.0 | 50 pre-allocated Double Ratchet conversation states. The 51st overwrites the oldest (LRU). |
| **Routing Table** | Fixed Struct Array (100 slots)| 5.0 | 100 known node IDs, public keys, and next-hop MAC addresses. |
| **CPU Call Stack** | Core 0 & Core 1 Stacks | 16.0 | Pre-calculated stack depth to prevent overflow during crypto operations. |
| **Quarantined Heap** | Dynamic (`malloc`) | 50.0 | Strictly reserved for `RadioLib` init, `libsodium` contexts, and the BLE stack. |
| **RESERVED** | Unmapped | **~148.4** | Left completely empty for future protocol expansion. |


---

## 4. Protocol Specification (Kaitai Structs)

To prevent endianness issues, parsing vulnerabilities, and manual bit-shifting errors, the GMP physical layer is defined entirely using Kaitai Struct (`.ksy`).

This allows developers to auto-generate memory-safe parsing libraries in C++, Python, or Rust directly from the specification.

### 4.1 The Control Frame (433MHz)

The Control Frame handles the X25519 Diffie-Hellman key exchanges required to advance the Double Ratchet.

* See: [`/specs/gmp_control_frame.ksy`](https://www.google.com/search?q=%23) (Link to file in repo)

### 4.2 The Data Frame (868/915MHz)

The Data Frame carries the actual encrypted payload. It uses a minimal routing header and an AES-GCM ciphertext authenticated by the current message key from the 433MHz ratchet.

* See: [`/specs/gmp_data_frame.ksy`](https://www.google.com/search?q=%23) (Link to file in repo)

---

## 5. The Dual-Radio SPI Handoff (Core Challenge)

The primary engineering challenge of GMP is timing. We have two LoRa transceivers attempting to interrupt a single RP2040.

**The Handoff Sequence:**

1. **Radio A (433MHz)** receives a new Ratchet Public Key. Triggers GPIO Interrupt.
2. RP2040 (Core 0) reads the key into the static RX buffer via SPI.
3. RP2040 (Core 1) performs the Elliptic Curve (Curve25519) math to generate the new Message Key.
4. Fractions of a second later, **Radio B (868MHz)** receives the encrypted payload.
5. RP2040 uses the newly calculated Message Key to decrypt the payload in place.

> **Call for Review:** We are specifically looking for feedback on using the RP2040's PIO state machines to manage the SPI chip-select (CS) contention between the two radios to prevent dropped packets during high-traffic bursts. See `/docs/spi_arbitration.md`.

---

## 6. Asynchronous Onion Routing (DTN)

GMP implements a 3-hop Onion Routing protocol designed strictly for Delay Tolerant Networking (DTN). To comply with Ofcom/FCC ISM band duty cycles (e.g., 1%), GMP does not guarantee real-time delivery.

**The Store-and-Forward Architecture:**
1. **Static Egress Hoarding:** When a node peels a layer of an Onion packet, the resulting ciphertext is placed into the statically allocated `Egress_Queue`.
2. **Duty Cycle State Machine:** The RP2040 actively tracks its cumulative "Time on Air" (ToA). If the 1% limit is approached, the `Egress_Queue` pauses transmission. 
3. **Out-of-Band Coordination:** To minimize ToA on the 868MHz data band, nodes use the 433MHz control band to negotiate burst-transmission windows. A node will hoard routed packets and transmit them in a single, high-speed Spreading Factor 7 (SF7) burst (a "lightning shuffle") to clear its static memory legally.
4. **Queue Exhaustion:** If the `Egress_Queue` fills up (20/20 slots) due to duty cycle limits, the node broadcasts a "Choked" flag on 433MHz, instructing neighbors to route elsewhere.

Section X: Asynchronous Onion Routing (DTN)
GMP implements a 3-hop Onion Routing protocol designed strictly for Delay Tolerant Networking (DTN). To comply with Ofcom/FCC ISM band duty cycles (e.g., 1%), GMP does not guarantee real-time delivery.

The Store-and-Forward Architecture:

Static Egress Hoarding: When a node peels a layer of an Onion packet, the resulting ciphertext is placed into a pre-allocated static Egress_Queue (Maximum 20 packets).

Duty Cycle State Machine: The RP2040 actively tracks its cumulative "Time on Air" (ToA). If the 1% limit is approached, the Egress_Queue pauses transmission. Packets are held in SRAM until the rolling hour window permits transmission.

Out-of-Band Coordination: To minimize ToA on the 868MHz data band, nodes use the 433MHz control band to negotiate burst-transmission windows. A node will hoard multiple routed packets and transmit them in a single, high-speed Spreading Factor 7 (SF7) burst, acting as a "lightning shuffle" to clear its static memory queues legally.

Queue Exhaustion: If the static Egress_Queue fills up (20/20 slots) due to duty cycle limits or network congestion, the node will broadcast a "Choked" flag on the 433MHz band, instructing neighboring nodes to route Onions elsewhere.
---

## 6. Contributing & Governance

We believe that protocol architecture must precede implementation. We are currently in the **RFC (Request for Comments)** phase.

**How to contribute right now:**

1. Review the `.ksy` files. Are the byte allocations optimal for the LoRa physical layer?
2. Review the Cryptographic State Machine. Does our static ring-buffer approach break Post-Compromise Security if a node misses a 433MHz broadcast?
3. Review the SRAM map. Are the queue sizes realistic for a heavily utilized mesh relay?

Please open an Issue to discuss architectural changes. Pull Requests modifying the `.ksy` or Markdown specifications are welcome.

**Firmware development (C++) will commence only when the `1.0-draft` of the specification is locked.**

---

*Ghost Meshnet Protocol is released under the Apache 2.0 License.*
