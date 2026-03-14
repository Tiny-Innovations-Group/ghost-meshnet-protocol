# GMP Module: Tactical Text Compression (The 6-Bit Alphabet)

Handling user text in a low-bandwidth, highly encrypted radio environment is not trivial. Modern applications assume infinite bandwidth and routinely use Unicode (UTF-8), where a single emoji can consume 4 bytes of data. 

In the Ghost Meshnet Protocol (GMP), where a single 868MHz LoRa packet has a strict maximum of 255 bytes—and where Onion Routing and Double Ratchet cryptographic headers consume nearly half of that—every bit matters.

To maximize the remaining payload space without fragmenting the packet across the network (which would require dynamic memory reassembly), GMP strictly enforces a **Custom 6-Bit Tactical Alphabet**.

## 1. The Math: ASCII vs. 6-Bit Packing

Standard text (ASCII) uses 8 bits (1 byte) per character, allowing for 256 possible symbols.
By aggressively stripping out lowercase letters, obscure punctuation, and emojis, we reduce the total allowed characters to exactly 64. 

64 characters can be represented using only **6 bits** instead of 8. 

### The Savings Example
Consider a 160-character tactical message: `SND HLP 2 SECTOR 7 ASAP. HOSTILE DRONES SPOTTED. OUT.`

* **Standard ASCII (8-bit):** 160 characters * 8 bits = 1280 bits = **160 bytes**.
* **GMP 6-Bit Packing:** 160 characters * 6 bits = 960 bits = **120 bytes**.

**Result:** By changing the alphabet at the protocol level, we save 40 bytes of crucial LoRa real estate per message. This 25% reduction is often the difference between a message fitting into a single Onion-routed packet or failing entirely.

## 2. The GMP 64-Character Tactical Alphabet

When a user connects to a GMP node via the 2.4GHz BLE admin channel to send a message, the client app will physically restrict keyboard input to the following 64 characters:

| Character Type | Characters | Count |
| :--- | :--- | :--- |
| **Uppercase Letters** | `A` through `Z` | 26 |
| **Numbers** | `0` through `9` | 10 |
| **Punctuation** | `.` `,` `?` `!` `'` `"` `-` `/` `@` `#` `&` | 11 |
| **Math/Coordinates** | `+` `=` `<` `>` `*` | 5 |
| **Control/Spacing** | `[Space]` `[Newline]` | 2 |
| **Tactical Flags** | `[ACK]` `[URGENT]` `[LOC]` (Location mapping) | 3 |
| **Reserved** | Reserved for future protocol expansion | 7 |
| **TOTAL** | | **64** |

*Note: All incoming lowercase text from the BLE client app is automatically capitalized by the RP2040 before 6-bit encoding.*

## 3. Implementation in Kaitai Struct (`.ksy`)

Because GMP is a specification-first architecture, the 6-bit packing is handled flawlessly by the Kaitai compiler, entirely avoiding messy, manual bit-shifting in C++ that could lead to memory corruption.

In the `gmp_data_frame.ksy` definition, the payload is defined simply as a 6-bit integer array:

```yaml
  - id: payload_length_chars
    type: u1
    doc: Number of 6-bit characters in the payload
  - id: compressed_payload
    type: b6
    repeat: expr
    repeat-expr: payload_length_chars
    doc: The tactical text, packed tightly across byte boundaries

The auto-generated C++ code will map these 6-bit chunks directly into statically allocated arrays on the RP2040.
4. Pros, Cons, and Tactical Realities
The Benefits (Pros)
 * The "Tweet-Sized" Payload: Allows for 150-200 character messages (the size of an early Twitter post or SMS) to comfortably fit inside a heavily encrypted, multi-hop LoRa packet.
 * Zero-Heap Compatibility: Because the compression is mathematically fixed (every character is exactly 6 bits), the C++ parser never needs to dynamically allocate memory to calculate string lengths.
 * Culture of Brevity: Forcing a constrained keyboard naturally encourages "00s txt language" (CU L8R, SITREP?). This shorthand inherently compresses the message further at the human level before it even hits the radio.
The Trade-offs (Cons)
 * No Language Localization: The 64-character limit means there is no support for Cyrillic, Arabic, Mandarin, or accented European characters. The protocol is strictly locked to the basic Latin alphabet.
 * Loss of Case Nuance: "HELP" and "help" are identical. You cannot use capitalization for emphasis.
 * App-Side Complexity: The 2.4GHz BLE companion app must actively filter user input. If a user tries to paste a standard UTF-8 string containing an emoji into the app, the app must strip the unsupported characters before sending it to the Pi Pico.
5. Summary: Why We Ignore Modern Text Standards
Handling text is rarely viewed as a "hardware constraint" in modern software development. However, in the Ghost Meshnet Protocol, text is treated as a physical payload weight.
By aggressively abandoning standard ASCII and enforcing a 6-bit tactical alphabet, we ensure that the cryptographic headers (Double Ratchet MACs) and Onion Routing instructions have the physical radio space they need to function legally and securely across the mesh.

