meta:
  id: gmp_868_packet
  endian: le
  bit_endian: le
doc: |
  Ghost Meshnet Protocol (GMP) - 868MHz Data Plane
  Enforces a strict 124-byte memory-aligned structure for Dual-Burst transmissions.

# -----------------------------------------------------------------------------
# 1. THE ROUTING SHELL (Plaintext - Parsed by the RP2040 Node)
# -----------------------------------------------------------------------------
seq:
  - id: next_hop_id
    type: u4
    doc: 'The physical LoRa node ID for the immediate next hop.'
  - id: truncated_mac
    size: 8
    doc: 'Truncated Auth Tag for outer shell validation.'
  - id: encrypted_core_blob
    size: 112
    doc: 'Raw AES-GCM ciphertext. Must be decrypted by the final destination before parsing.'

instances:
  is_hardware_aligned:
    value: _io.size == 124
    doc: 'Enforces the exact 124-byte limit for Dual-Burst functionality.'

# -----------------------------------------------------------------------------
# 2. THE DECRYPTED CORE (Plaintext - Parsed by the Smartphone App)
# -----------------------------------------------------------------------------
types:
  onion_core:
    doc: 'The underlying data structure applied ONLY after the blob is decrypted.'
    seq:
      - id: sender_node_id
        type: u4
      - id: full_auth_tag
        size: 16
      - id: message_id
        type: u2
      
      # The Bit-Packed Control Byte (1 byte total)
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

# -----------------------------------------------------------------------------
# 3. BIT-EXACT ENUMS
# -----------------------------------------------------------------------------
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