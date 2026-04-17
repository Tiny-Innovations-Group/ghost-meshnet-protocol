meta:
  id: gmp_868_onion_core
  endian: le
  bit_endian: le
doc: |
  Ghost Meshnet Protocol (GMP) - 868MHz Decrypted Onion Core.
  © 2026 Tiny Innovations Group Ltd. All Rights Reserved.

  The plaintext 100-byte structure that emerges after AES-GCM decryption
  of `gmp_868_data_frame.encrypted_core_blob`.

  Layout (100 bytes):
    4  sender_node_id
   16  full_auth_tag
    2  message_id (implicit-nonce core)
    1  bit-packed control byte (payload_type | priority | requires_ack | ttl_mode)
   77  compressed_text (Static Huffman over the 6-bit tactical alphabet)

seq:
  - id: sender_node_id
    type: u4
  - id: full_auth_tag
    size: 16
    doc: 'Full 128-bit AES-GCM Authentication Tag.'
  - id: message_id
    type: u2
    doc: 'Variable core of the 12-byte implicit Double-Ratchet nonce.'

  # ---------------------------------------------------------------------------
  # Bit-Packed Control Byte (8 bits total)
  # ---------------------------------------------------------------------------
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
    doc: 'Static-Huffman-compressed tactical payload (6-bit alphabet source).'

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
    doc: 'Strict validation: the decrypted core must be exactly 100 bytes.'
