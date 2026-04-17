# GMP Module: Tactical Text Compression

Handling user text in a low-bandwidth, highly encrypted radio environment is not trivial. Modern applications assume infinite bandwidth and routinely use Unicode (UTF-8), where a single emoji can consume 4 bytes of data.

In the Ghost Meshnet Protocol (GMP), where a single 868MHz LoRa packet has a strict maximum of 112 bytes — and where Onion Routing and Double Ratchet cryptographic headers consume 23 of those — every bit of the remaining 77-byte text field matters.

To maximise the remaining payload space without fragmenting the packet across the network (which would require dynamic memory reassembly), GMP applies a **two-stage compression pipeline** to user text:

1. **Alphabet constraint** — the user is restricted to a 64-character tactical alphabet at input time.
2. **Static Huffman coding** — the constrained alphabet is then entropy-coded with a pre-computed Huffman tree trained on tactical brevity codes.

Each stage builds on the previous. Neither stage is optional; neither stage alone gives the compression ratio the 77-byte field requires for useful message lengths.

## 1. Stage 1 — The 64-Character Tactical Alphabet

Standard text (ASCII) uses 8 bits per character, allowing for 256 possible symbols — most of which are never used in tactical traffic. By aggressively stripping out lowercase letters, obscure punctuation, and emojis, GMP reduces the symbol set to exactly **64 characters**.

### The GMP Tactical Alphabet

When a user connects to a GMP node via the 2.4GHz BLE admin channel to send a message, the client app physically restricts keyboard input to these 64 characters:

| Character Type | Characters | Count |
| :--- | :--- | :--- |
| **Uppercase Letters** | `A` through `Z` | 26 |
| **Numbers** | `0` through `9` | 10 |
| **Punctuation** | `.` `,` `?` `!` `'` `"` `-` `/` `@` `#` `&` | 11 |
| **Math / Coordinates** | `+` `=` `<` `>` `*` | 5 |
| **Control / Spacing** | `[Space]` `[Newline]` | 2 |
| **Tactical Flags** | `[ACK]` `[URGENT]` `[LOC]` (location mapping) | 3 |
| **Reserved** | Reserved for future protocol expansion | 7 |
| **TOTAL** | | **64** |

*Note: all incoming lowercase text from the BLE client app is automatically capitalised before encoding.*

64 symbols require exactly **6 bits** to enumerate. If we transmitted the alphabet as a uniform 6-bit fixed-length code we would already save 25% over 8-bit ASCII — but we can do much better, because the distribution of characters in tactical English is very far from uniform.

## 2. Stage 2 — Static Huffman Coding

Huffman coding replaces uniform-length symbols with variable-length bit sequences based on frequency. The most common symbols get the shortest codes.

### Why *Static* Huffman

Dynamic Huffman or GZIP-style coders require dynamic memory to build their dictionary, which violates GMP's zero-heap architecture. They also waste bytes on transmitted dictionary overhead that defeats the purpose on payloads this small.

GMP uses a **pre-computed Static Huffman tree** hard-coded identically into every node and every client app:

* **Tactical training corpus.** The tree is not trained on standard English literature. It is trained on military brevity codes, geographic coordinates, and "00s SMS slang" (e.g., `SND`, `HLP`, `ASAP`, `LOC`, `SITREP`).
* **No dictionary transmitted.** Because every node shares the exact same tree, the dictionary itself never needs to be sent over the air. The wire format is pure Huffman bitstream.
* **Zero-heap decode.** The tree is a fixed lookup table in flash; decoding is a bitwise walk, no allocation.

### Typical compression ratio

For the 64-symbol tactical alphabet with the training corpus above, the average encoded length comes out at roughly **4 – 4.5 bits per character**. The most frequent symbols (`[Space]`, `E`, `T`, `A`, `O`) end up at 2–3 bits; rare punctuation ends up at 7–8 bits.

## 3. Compounding Example: The Space-Saving Math

Consider a typical tactical message:

> `SND HLP 2 SECTOR 7 ASAP. HOSTILE DRONES SPOTTED. OUT.` (53 characters)

| Encoding | Bits / char | Total |
| --- | ---: | ---: |
| 8-bit ASCII (baseline) | 8.0 | 424 bits (53 B) |
| 6-bit fixed alphabet (Stage 1 only) | 6.0 | 318 bits (~40 B) |
| **Full GMP pipeline (Stage 1 → Stage 2 Huffman)** | **~4.5** | **~238 bits (~30 B)** |

The full pipeline takes a 53-byte ASCII string down to roughly 30 bytes before encryption. The 77-byte `compressed_text` field in the Onion Core therefore holds approximately **130–140 characters** of typical tactical English — somewhere between an early Twitter post and an SMS.

By saving ~23 bytes per message versus 6-bit fixed encoding, a statically allocated 5.1 KB `Egress_Queue` on the Pi Pico can hold nearly twice as many Onion-routed packets at peak relay load.

## 4. Pipeline Execution: The 2.4GHz Client Offload

The RP2040 microcontroller does **not** perform compression. Offloading it would waste CPU cycles and battery on a job the user's smartphone can do in microseconds.

The compression pipeline is executed on the smartphone via the 2.4GHz BLE admin channel:

1. **Input constraint (Stage 1).** The companion app keyboard physically restricts input to the allowed 64-character alphabet. Incoming lowercase is capitalised; unsupported UTF-8 (including emojis) is stripped.
2. **Huffman encoding (Stage 2).** The app applies the Static Huffman tree, converting the constrained string into a dense bitstream.
3. **Client-side encryption.** The app encrypts the Huffman bitstream using libsodium with the current Double Ratchet message key.
4. **Node injection.** The phone sends the finalised encrypted binary blob to the RP2040 over BLE.
5. **Dumb routing.** The RP2040 does not decompress or decrypt. It places the dense byte-array directly into its static `Egress_Queue` to wait for the next 868MHz transmission window.

## 5. Wire Format

The compressed bitstream lives in the 77-byte `compressed_text` field of the Onion Core — see [`specs/gmp_868_onion_core.ksy`](../specs/gmp_868_onion_core.ksy):

```yaml
- id: compressed_text
  size: 77
  doc: 'Static-Huffman-compressed tactical payload (6-bit alphabet source).'
```

The field is treated as an opaque 77-byte bitstream by the protocol layer. Decoding (Huffman walk → 64-char alphabet → displayable string) happens entirely on the receiving client device, not on the relaying RP2040 nodes.

## 6. Trade-offs

**Pros**

* **"Tweet-sized" payload.** ~130–140 character messages comfortably fit inside a heavily encrypted, multi-hop 112-byte LoRa packet.
* **Zero-heap compatibility.** Static dictionary, fixed 77-byte output bucket, deterministic bounded decode — no dynamic allocation anywhere in the pipeline.
* **Culture of brevity.** Forcing a constrained keyboard naturally encourages "00s txt language" (CU L8R, SITREP?), which compresses further at the human level before it even hits the radio.
* **Dictionary is not traffic.** Because every node shares the tree, none of the 77 bytes is spent shipping dictionary overhead.

**Cons**

* **No language localisation.** The 64-character limit means no support for Cyrillic, Arabic, Mandarin, or accented European characters. The protocol is locked to the basic Latin alphabet.
* **Loss of case nuance.** `HELP` and `help` are identical; capitalisation cannot carry emphasis.
* **App-side complexity.** The companion app must actively filter user input. Pasted UTF-8 strings containing emojis must be stripped before encoding.
* **Tree retraining is a breaking change.** Because the Huffman tree is hard-coded into every node, retraining it on a new corpus requires a coordinated firmware update across the entire mesh. The tree is effectively frozen at v1.0.

## 7. Summary: Why GMP Abandons Modern Text Standards

Handling text is rarely viewed as a "hardware constraint" in modern software development. In GMP, text is treated as a physical payload weight.

By aggressively abandoning standard ASCII, restricting to a 64-character tactical alphabet, and layering Static Huffman compression on top, the 77-byte `compressed_text` field delivers ~130–140 characters of useful tactical content per packet — enough physical room for the Double Ratchet MACs and Onion Routing instructions to function legally and securely across the mesh.
