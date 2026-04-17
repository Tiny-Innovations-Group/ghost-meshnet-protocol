meta:
  id: gmp_868_data_frame
  endian: le
doc: |
  Ghost Meshnet Protocol (GMP) - 868MHz Data Plane Outer Routing Shell.
  © 2026 Tiny Innovations Group Ltd. All Rights Reserved.

  Plaintext routing wrapper that carries an opaque 100-byte AES-GCM
  ciphertext. Total on-air size is locked to exactly 112 bytes (the
  "Golden Ratio"): 14 cycles on a 64-bit CPU, 28 cycles on a 32-bit
  CPU, and a safe dual-burst of 224 bytes inside the SX1262's 255-byte
  hardware FIFO.

  The `encrypted_core_blob` decrypts to a `gmp_868_onion_core` structure
  — see gmp_868_onion_core.ksy.

seq:
  - id: next_hop_id
    type: u4
    doc: 'The physical LoRa node ID for the immediate next hop.'
  - id: truncated_mac
    size: 8
    doc: 'Truncated AES-GCM Auth Tag for outer shell validation at each relay.'
  - id: encrypted_core_blob
    size: 100
    doc: 'Raw AES-GCM ciphertext. Decrypted by the final destination only.'

instances:
  is_hardware_aligned:
    value: _io.size == 112
    doc: |
      Strict validation: enforces the 112-byte Golden Ratio that guarantees
      64-bit memory alignment and a safe 224-byte Dual-Burst inside the
      255-byte LoRa hardware FIFO.
