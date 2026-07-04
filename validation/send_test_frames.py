#!/usr/bin/env python3
"""Send raw Ethernet test frames to the Arty A7 eth_test design.

The FPGA pops one byte per second from its internal FIFO and shows the
lower 4 bits on the green LEDs.  Run with sudo (needs CAP_NET_RAW).

Usage:
    sudo python3 send_test_frames.py
"""

from scapy.all import Ether, Raw, sendp

# enx207bd25880ef
IFACE   = "enx207bd25880ef"
DST_MAC = "ff:ff:ff:ff:ff:ff"   # broadcast — no MAC filtering needed
SRC_MAC = "de:ad:be:ef:00:01"   # arbitrary source
ETHERTYPE = 0x9999              # custom, so the OS ignores the payload

# Alternating 0x55 / 0xAA — lower nibbles are 0101 then 1010, so the LEDs
# should flip between 0b0101 and 0b1010 each second.
payload = bytes([0x55, 0xAA] * 32)  # 64 bytes

frame = Ether(dst=DST_MAC, src=SRC_MAC, type=ETHERTYPE) / Raw(payload)

print(f"Sending on {IFACE}  dst={DST_MAC}  ethertype=0x{ETHERTYPE:04x}")
print(f"Payload: {payload.hex()}")
print(f"Frame length: {len(frame)} bytes")
print()
print("Sending 1 frame — LEDs should alternate 0101 / 1010 each second for ~64 seconds")
sendp(frame, iface=IFACE, count=1, verbose=True)
print("Done.")
