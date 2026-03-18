# GMP Hardware Reference Guide: The £100 "Ghost" Node

This guide provides the Bill of Materials (BOM) for building a standard GMP-compliant node. The goal is to utilize generic, widely available consumer electronics to maintain Low Probability of Detection (LPD) and low cost.

## 1. Core Components (The "Scout" Node)

| Component | Specification | Estimated Cost (AliExpress) |
| :--- | :--- | :--- |
| **Microcontroller** | Raspberry Pi Pico (RP2040) | £4.00 |
| **Control Radio** | SX1278 (433MHz LoRa Module) | £12.00 |
| **Data Radio** | SX1262 (868MHz/915MHz LoRa Module) | £18.00 |
| **Antennas** | 2x Tuned Dipole or Whip Antennas | £15.00 |
| **Power Logic** | 5V Solar Charge Controller (USB-C) | £8.00 |
| **Battery** | 2x 18650 LiPo Cells (3000mAh+) | £14.00 |
| **Enclosure** | IP67 Waterproof Junction Box | £10.00 |
| **Cabling** | Breadboard Jumpers or Custom PCB | £5.00 |
| **Total** | | **~£86.00** |

## 2. Assembly Strategy

### The "Stealth" Build
For maximum safety in restricted environments, do not use custom-printed PCBs. Hand-wire the Pico to the radio modules using 28AWG silicone wire. This mimics the appearance of "hobbyist electronics" rather than a professional communication device.

### The "Anchor" Build (Buoy/Rooftop)
For permanent installations:
* **Upgrade:** Use a 5W-10W Rigid Solar Panel for 24/7 uptime.
* **Placement:** High-gain omni-directional antennas should be used, but keep them camouflaged to avoid visual detection (e.g., hidden inside PVC piping).

## 3. Flashing & Identity
1. Connect the Pico to a PC via USB.
2. Flash the `gmp_firmware_v1.0.uf2`.
3. Upon first boot, the Pico will generate a **Silicon Fingerprint (SRAM PUF)**.
4. Connect via Bluetooth to a smartphone running the Tiny Innovations GMP App to pair the Identity Key.

---
**Disclaimer:** This hardware is intended for emergency and humanitarian use. Always check local radio regulations regarding frequency use and duty cycles.