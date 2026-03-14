# GMP Module: Out-of-Band Control & Key Exchange (433MHz)

In standard mesh networks (like Meshtastic), routing instructions, public key exchanges, and encrypted text messages all fight for space on a single radio frequency. This causes massive channel congestion and forces compromises on packet size and security.

The Ghost Meshnet Protocol (GMP) solves this by adopting a **Dual-Band Architecture**, separating the Control Plane from the Data Plane:
* **The Data Plane (868MHz/915MHz):** Strictly reserved for high-speed, 124-byte, mathematically rigid Onion-routed payloads. It never transmits public keys or plaintext metadata.
* **The Control Plane (433MHz):** A slow, long-range channel dedicated entirely to node discovery, cryptographic key exchange, and air-traffic coordination.

By offloading the "messy" variable-length cryptography to the 433MHz band, we keep the 868MHz data band pristine and optimized for the 1% legal duty cycle.

## 1. The X3DH Key Exchange (How Alice and Dave Get the Keys)

For Alice to send Dave an encrypted Onion packet on 868MHz, she needs to encrypt the innermost core with Dave's key. Because GMP operates completely off-grid with no central directory servers, Alice and Dave must mathematically agree on a Shared Secret symmetric key over the air, without ever transmitting the secret itself.

GMP utilizes the **Extended Triple Diffie-Hellman (X3DH)** protocol, powered by Elliptic Curve Cryptography (Curve25519).



### Phase 1: The Network Heartbeat (Discovery)
When Dave turns on his GMP node, his smartphone app generates a long-term **Public Identity Key** (32 bytes).
To announce his presence to the mesh, Dave's node uses the 433MHz radio to broadcast a slow, unencrypted "Beacon" packet every 10–15 minutes.
* Alice's node (and everyone else in range) hears this 433MHz beacon.
* Alice's node saves Dave's 32-byte Public Identity Key into its static SRAM directory.

### Phase 2: Alice Initiates the Handshake
Alice wants to send Dave a secure text message. She already has his Public Identity Key from his beacon.
Alice's smartphone app generates a temporary, one-time **Ephemeral Public Key** (32 bytes). 
Her node transmits a specific Handshake Packet addressed to Dave on the 433MHz band:
* `Alice's Node ID` (4 bytes)
* `Dave's Node ID` (4 bytes)
* `Alice's Public Identity Key` (32 bytes)
* `Alice's Public Ephemeral Key` (32 bytes)

### Phase 3: The Cryptographic Math (The Shared Secret)
Dave's node receives Alice's 433MHz handshake packet.
Now, both Alice's phone and Dave's phone perform Elliptic-Curve Diffie-Hellman (ECDH) math locally. 
ECDH allows two parties to combine their own *Private* Key with the other party's *Public* Key, resulting in the exact same mathematical output for both: **The Shared Secret.**

Even if an adversary recorded Alice's handshake and Dave's beacon, they only possess the *Public* keys. Without at least one Private key, calculating the Shared Secret is mathematically infeasible.

### Phase 4: The Double Ratchet Handoff
Once Alice and Dave both calculate the Shared Secret, the X3DH handshake is complete. **They never need to transmit these 32-byte public keys again.**

They feed that Shared Secret into the **Double Ratchet Algorithm**.
1. Alice uses the Ratchet to generate `Message_Key_1`.
2. She encrypts her text message using `Message_Key_1`.
3. She builds the perfectly padded 124-byte Onion packet and blasts it over the **868MHz Data Band**.
4. Dave receives the 868MHz packet, uses his Ratchet to generate `Message_Key_1`, and decrypts it.
5. Both nodes instantly delete `Message_Key_1` and ratchet forward to `Message_Key_2`.

## 2. Out-of-Band MAC (Collision Avoidance)

Beyond key exchanges, the 433MHz channel acts as the "Air Traffic Controller" to ensure the high-speed 868MHz bursts do not collide in mid-air.

Before Node A fires its 248-byte Dual-Relay Burst on 868MHz, it must ensure the local airspace is clear. Standard Carrier-Sense Multiple Access (CSMA) is unreliable on LoRa due to the "hidden node" problem and signals below the noise floor.

**The "Clear to Burst" Coordination:**
1. **The RTS (Request to Send):** Node A broadcasts a tiny, 8-byte packet on 433MHz: `[Target_ID] + [Intent_to_Burst_in_500ms]`.
2. **The Wake-Up:** The intended receiver (Node B) hears this on 433MHz. It immediately wakes up its 868MHz radio chip, preparing the FIFO buffer to receive the massive influx of data.
3. **The Silence:** Other nodes in the area hear the 433MHz RTS. They mathematically back off and pause their own 868MHz transmission queues to prevent a collision.
4. **The Burst:** 500ms later, Node A fires the 248-byte Onion packet on 868MHz into a perfectly quiet RF environment, directly to an awake receiver.

## 3. Kaitai Struct (`.ksy`) Implementation Example

Because the 433MHz channel handles variable control data (unlike the rigidly fixed 868MHz band), we define specific packet types in Kaitai.

Here is the definition for the Phase 1 Discovery Beacon (`gmp_433_beacon.ksy`):

```yaml
meta:
  id: gmp_433_beacon
  endian: le
seq:
  - id: packet_type
    type: u1
    doc: Hex flag defining this as a Beacon (e.g., 0xFF)
  - id: sender_node_id
    type: u4
    doc: 32-bit globally unique Node ID
  - id: public_identity_key
    size: 32
    doc: Curve25519 Public Key for X3DH initialization
  - id: battery_status
    type: u1
    doc: Node health diagnostic (0-100)
  - id: epoch_timestamp
    type: u4
    doc: Network time synchronization

```

## 4. Hardware Root of Trust: The "Fox Hunt" Defense

A critical vulnerability in standard mesh networks is "software cloning." If an adversary hacks a node or compromises the companion app, they can copy the Private Keys to another device, allowing them to impersonate the user or decrypt intercepted traffic remotely.

GMP eliminates software cloning by enforcing a **Hardware Root of Trust** via Physically Unclonable Functions (PUF) or Smartphone Secure Enclaves.

### The Mechanism
The long-term Identity Key of a GMP node is not stored in standard readable memory. 
* **Mobile Clients:** The Identity Key is generated inside the smartphone's Secure Enclave (iOS) or TrustZone/Titan M (Android). The private key cannot be extracted by the OS.
* **Autonomous Nodes:** The RP2040 generates its Identity Key using an SRAM PUF (Physically Unclonable Function)—leveraging the microscopic, unique silicon variations of the chip's memory at boot-up to seed the cryptography.

### The 433MHz Ed25519 Signature
Because GMP utilizes a Dual-Band architecture, the 433MHz Control Channel has the payload capacity to support robust hardware verification without clogging the 868MHz data plane.

Every 433MHz Discovery Beacon includes a 64-byte Ed25519 signature generated directly by the hardware enclave.
When Node B receives Node A's beacon, it verifies the signature. 

### The Tactical Result: Forced Physical Proximity
By mathematically fusing the network identity to the physical silicon, GMP forces adversaries to change their attack vector. A remote software hack is no longer sufficient to break the cryptography. 

To impersonate a node or decrypt a captured Onion payload, an adversary must physically possess the exact hardware chip used to initialize the Ratchet. They cannot do this from across the world; they must execute a radio direction-finding "Fox Hunt" to physically locate and steal the node in the field.


## 5. The "One Device, One Identity" Doctrine

Standard communication platforms prioritize user convenience, allowing a single account identity to be synced across multiple devices (phones, tablets, laptops). This requires exporting private keys or relying on central servers, creating massive attack surfaces.

The Ghost Meshnet Protocol (GMP) strictly enforces a **"One Device, One Identity"** doctrine. 

By deriving the long-term Identity Key exclusively from the Physically Unclonable Function (PUF) or the Secure Enclave of the specific hardware initiating the connection, the identity becomes immutably bound to that exact piece of silicon.

### The "Two Alices" Scenario
If a user ("Alice") operates two different smartphones and connects both to a GMP node, the network will perceive them as two entirely distinct cryptographic entities (Alice_A and Alice_B).

* **No Cross-Device Syncing:** A message encrypted for Alice's primary phone cannot be decrypted by her secondary phone, even if connected to the same RP2040 node. The private key never leaves the specific hardware enclave it was generated in. 
* **Cryptographic Quarantine:** This intentional friction prevents software cloning. If an adversary compromises Alice's primary phone, they cannot export her identity to a server farm to decrypt intercepted historical traffic.
* **Tactical Signaling:** If a user loses their primary device and switches to a backup, they must establish new Double Ratchet sessions (via the 433MHz X3DH exchange) with their contacts. This sudden change in cryptographic identity acts as a passive alert to the network that the original hardware may be compromised.

In GMP, ease of access is deliberately sacrificed to guarantee the physical containment of cryptographic material.