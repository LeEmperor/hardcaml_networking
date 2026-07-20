#!/usr/bin/env python3
"""Host-side companion for the UDP-over-MAC validation harness on the Arty A7.

Two modes:

  --validate   Sniff the wire and verify the UDP datagrams the FPGA emits
               (FPGA -> host). This is the currently-validatable path: the
               Udp_mac_top TX stack (Udp_tx on Mac_top) is sim-verified and
               driven on the board by a btn[3] press. Each press emits one
               datagram; this parses + checks the IPv4/UDP header and payload.

  --send       Craft + send a UDP datagram toward the FPGA (host -> FPGA) to
               exercise the RX path. Targets the Udp_rx_mac_top RX stack
               (Ipv4_rx + Udp_rx stacked on Mac_top's RX path), which is
               sim-verified and driven on the board by
               udp_rx_mac_top_validation_harness. The frame's dst UDP port
               (0x1235) and ethertype (0x0800) match what that harness accepts.

               Confirmation is VISUAL on the board LEDs — this is fire-and-forget;
               there is no host-side readback of the recovered datagram yet (that
               needs an echo-back full-duplex harness). Use --pattern alt to send
               an alternating 0xAA/0x55 payload so the harness's 1-byte/sec drain
               makes led[3:0] visibly toggle 0xA <-> 0x5 as each recovered byte
               pops — the UDP mirror of the MAC-RX FIFO-drain check.

ETHERTYPE
---------
The MAC's tx_datapath now emits ethertype 0x0800 (real IPv4), so these are
genuine IPv4/UDP frames. --validate still raw-sniffs (scapy) and hand-parses the
IPv4/UDP header rather than leaning on the OS stack — that keeps the check
self-contained (independent of kernel routing/socket state) and lets it assert
on every field. A normal `recvfrom` on a UDP socket would now also work if you
prefer to simplify. (Historically the datapath emitted a custom 0x9999 so the
OS would ignore the payload; that has since been parameterized to 0x0800.)

Golden constants below MUST match udp_tx.ml / test/udp/udp_mac_top_tb.ml.

Usage (needs CAP_NET_RAW, i.e. sudo):
    sudo python3 udp_app.py --validate --iface enx207bd25880ef
    sudo python3 udp_app.py --send     --iface enx207bd25880ef
    sudo python3 udp_app.py --send --pattern alt --app-len 8 --iface enx207bd25880ef
"""

import argparse
import sys

from scapy.all import Ether, Raw, sendp, sniff

# ── golden constants (mirror udp_tx.ml / udp_mac_top_tb.ml) ──────────────────
FPGA_SRC_MAC = "02:00:00:00:00:01"   # Mac_top tx_datapath hardcoded SRC MAC
FPGA_DST_MAC = "ff:ff:ff:ff:ff:ff"   # hardcoded DST MAC (broadcast)
ETHERTYPE = 0x0800                   # IPv4 — MAC tx_datapath now emits real 0x0800

SRC_IP = "192.168.1.10"
DST_IP = "192.168.1.1"
SRC_PORT = 0x1234
DST_PORT = 0x1235

# The harness (udp_mac_top_validation_harness.ml) streams app_payload_len bytes
# of incrementing data 0x01, 0x02, …; default there is 18.
DEFAULT_APP_LEN = 18
DEFAULT_IFACE = "enx207bd25880ef"


def expected_app(n):
    """Incrementing 0x01..0x?? truncated to a byte — matches payload_byte in the TX harness."""
    return bytes(((i + 1) & 0xFF) for i in range(n))


def make_payload(pattern, n):
    """Application payload for --send.

    'inc' — incrementing 0x01,0x02,… (same as the TX harness emits).
    'alt' — alternating 0xAA,0x55,… so the RX harness's 1-byte/sec drain makes
            led[3:0] toggle 0xA <-> 0x5, the UDP mirror of the MAC-RX check.
    """
    if pattern == "alt":
        return bytes((0xAA if i % 2 == 0 else 0x55) for i in range(n))
    return expected_app(n)  # 'inc'


def ones_complement_sum(data):
    """16-bit ones-complement sum over a byte string (odd length is zero-padded)."""
    if len(data) % 2:
        data = data + b"\x00"
    s = 0
    for i in range(0, len(data), 2):
        s += (data[i] << 8) | data[i + 1]
    while s >> 16:
        s = (s & 0xFFFF) + (s >> 16)
    return s


def ip_checksum(header20):
    return (~ones_complement_sum(header20)) & 0xFFFF


def ip_str(b):
    return ".".join(str(x) for x in b)


def hexdump(b):
    return " ".join(f"{x:02x}" for x in b)


# ── build a golden datagram (IPv4 header ++ UDP header ++ app) ────────────────
def build_datagram(app):
    n = len(app)
    total_length = 28 + n
    udp_length = 8 + n
    src_ip = bytes(int(x) for x in SRC_IP.split("."))
    dst_ip = bytes(int(x) for x in DST_IP.split("."))
    ip_hdr = bytes(
        [0x45, 0x00, (total_length >> 8) & 0xFF, total_length & 0xFF,
         0x00, 0x00, 0x40, 0x00, 0x40, 0x11, 0x00, 0x00]
    ) + src_ip + dst_ip
    ck = ip_checksum(ip_hdr)
    ip_hdr = ip_hdr[:10] + bytes([(ck >> 8) & 0xFF, ck & 0xFF]) + ip_hdr[12:]
    udp_hdr = bytes(
        [(SRC_PORT >> 8) & 0xFF, SRC_PORT & 0xFF,
         (DST_PORT >> 8) & 0xFF, DST_PORT & 0xFF,
         (udp_length >> 8) & 0xFF, udp_length & 0xFF,
         0x00, 0x00]  # UDP checksum 0 = disabled (matches udp_tx.ml)
    )
    return ip_hdr + udp_hdr + bytes(app)


# ── validation (FPGA -> host) ─────────────────────────────────────────────────
def check_datagram(payload, app_len, verbose=True):
    """Parse the Ethernet payload as IPv4/UDP and check it. Returns True on PASS."""
    ok = True

    def fail(msg):
        nonlocal ok
        ok = False
        print(f"  FAIL: {msg}")

    if len(payload) < 28:
        fail(f"payload too short for IPv4+UDP: {len(payload)} bytes")
        return False

    # IPv4 header
    ver_ihl = payload[0]
    if ver_ihl != 0x45:
        fail(f"version/IHL = 0x{ver_ihl:02x}, expected 0x45")
    total_length = (payload[2] << 8) | payload[3]
    proto = payload[9]
    if proto != 0x11:
        fail(f"IP protocol = 0x{proto:02x}, expected 0x11 (UDP)")
    if ip_checksum(payload[0:20]) != 0x0000:
        # a valid header checksums to 0 when its own field is included
        fail("IPv4 header checksum invalid")
    got_src_ip, got_dst_ip = ip_str(payload[12:16]), ip_str(payload[16:20])
    if got_src_ip != SRC_IP:
        fail(f"src IP = {got_src_ip}, expected {SRC_IP}")
    if got_dst_ip != DST_IP:
        fail(f"dst IP = {got_dst_ip}, expected {DST_IP}")

    # UDP header (IHL is 5 => header starts at byte 20)
    udp = payload[20:]
    sport = (udp[0] << 8) | udp[1]
    dport = (udp[2] << 8) | udp[3]
    ulen = (udp[4] << 8) | udp[5]
    if sport != SRC_PORT:
        fail(f"UDP src port = 0x{sport:04x}, expected 0x{SRC_PORT:04x}")
    if dport != DST_PORT:
        fail(f"UDP dst port = 0x{dport:04x}, expected 0x{DST_PORT:04x}")
    if ulen != 8 + app_len:
        fail(f"UDP length = {ulen}, expected {8 + app_len}")
    if total_length != 28 + app_len:
        fail(f"IP total_length = {total_length}, expected {28 + app_len}")

    # Application payload — sized by the IP total_length field, so trailing MAC
    # zero-padding (present when the datagram is shorter than the 46-byte min
    # Ethernet payload) is naturally excluded.
    app = payload[28:total_length]
    exp = expected_app(app_len)
    if verbose:
        print(f"  src {got_src_ip}:0x{sport:04x} -> dst {got_dst_ip}:0x{dport:04x}"
              f"  udp_len={ulen}  app={len(app)}B")
        print(f"  payload: {hexdump(app)}")
    if bytes(app) != exp:
        fail(f"payload mismatch\n    expected: {hexdump(exp)}\n    got:      {hexdump(bytes(app))}")

    print(f"  => {'PASS' if ok else 'FAIL'}")
    return ok


def validate(iface, app_len, count):
    print(f"Sniffing {iface} for FPGA frames (src {FPGA_SRC_MAC}, ethertype 0x{ETHERTYPE:04x})")
    print(f"Press btn[3] on the board to emit a datagram. Waiting for {count}...\n")
    seen = {"n": 0, "pass": 0}

    def is_fpga(pkt):
        return (
            Ether in pkt
            and pkt[Ether].src.lower() == FPGA_SRC_MAC
            and pkt[Ether].type == ETHERTYPE
        )

    def handle(pkt):
        seen["n"] += 1
        print(f"-- frame {seen['n']} ({len(bytes(pkt))} bytes on wire) --")
        payload = bytes(pkt[Ether].payload)   # everything after the 14-byte Eth header
        if check_datagram(payload, app_len):
            seen["pass"] += 1
        print()

    sniff(iface=iface, lfilter=is_fpga, prn=handle, count=count, store=False)
    print(f"==== {seen['pass']}/{seen['n']} datagrams passed ====")
    return seen["pass"] == seen["n"] and seen["n"] > 0


# ── send (host -> FPGA, RX path) ──────────────────────────────────────────────
def send(iface, app_len, count, pattern):
    app = make_payload(pattern, app_len)
    frame = Ether(dst=FPGA_DST_MAC, src="de:ad:be:ef:00:02", type=ETHERTYPE) / Raw(
        build_datagram(app)
    )
    print(f"Sending on {iface}: ethertype 0x{ETHERTYPE:04x}, "
          f"{SRC_IP}:0x{SRC_PORT:04x} -> {DST_IP}:0x{DST_PORT:04x}, "
          f"app={app_len}B (pattern={pattern})")
    print(f"  app payload: {hexdump(app)}")
    sendp(frame, iface=iface, count=count, verbose=True)

    # Confirmation is on the board (udp_rx_mac_top_validation_harness); no host
    # readback yet. Print the LED checklist so it's clear what a PASS looks like.
    print("\nConfirm on the RX board harness (udp_rx_mac_top_validation_harness):")
    print("  led0_g  saw_valid_datagram  -> lights and stays lit")
    print("  led2_g  checksum_ok (IPv4)  -> lit")
    print("  led2_r / led3_r  crc_error  -> DARK (good frame)")
    print("  led[3:0] steps through the recovered payload low-nibbles, ~1/sec:")
    if pattern == "alt":
        print("           toggles 0xA <-> 0x5   (0xAA/0x55 alternating)")
    else:
        print("           0x1, 0x2, 0x3, …      (incrementing)")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    mode = ap.add_mutually_exclusive_group(required=True)
    mode.add_argument("--validate", action="store_true", help="sniff + check FPGA-emitted UDP datagrams (TX path)")
    mode.add_argument("--send", action="store_true", help="send a UDP datagram to the FPGA (RX path)")
    ap.add_argument("--iface", default=DEFAULT_IFACE, help=f"network interface (default {DEFAULT_IFACE})")
    ap.add_argument("--app-len", type=int, default=DEFAULT_APP_LEN, help=f"application payload length (default {DEFAULT_APP_LEN})")
    ap.add_argument("--count", type=int, default=1, help="frames to capture/send (default 1)")
    ap.add_argument("--pattern", choices=("inc", "alt"), default="inc",
                    help="--send payload pattern: 'inc' incrementing (default), "
                         "'alt' alternating 0xAA/0x55 (led[3:0] toggles 0xA<->0x5)")
    args = ap.parse_args()

    if args.validate:
        ok = validate(args.iface, args.app_len, args.count)
        sys.exit(0 if ok else 1)
    else:
        send(args.iface, args.app_len, args.count, args.pattern)


if __name__ == "__main__":
    main()
