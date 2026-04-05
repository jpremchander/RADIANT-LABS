#!/bin/bash
set -e
GREEN='\033[0;32m'; NC='\033[0m'
log() { echo -e "${GREEN}[DEMO]${NC} $1"; }
PCAP_DIR="/opt/radiant-pcaps"
INTERFACE="${DEMO_INTERFACE:-eth0}"
MODE="${DEMO_MODE:-}"

command -v tcpreplay &>/dev/null || sudo apt install -y tcpreplay
sudo mkdir -p "$PCAP_DIR"

log "Installing scapy and generating demo PCAP..."
sudo pip3 install scapy --quiet 2>/dev/null || true

sudo python3 << 'PYEOF'
from scapy.all import *
packets = []
packets.append(
  IP(src="192.168.10.50",dst="185.220.101.47")/
  TCP(sport=54321,dport=80,flags="PA")/
  Raw(load=b"POST /gate.php HTTP/1.1\r\nHost: 185.220.101.47\r\nUser-Agent: Mozilla/5.0\r\nContent-Length: 0\r\n\r\n")
)
packets.append(
  IP(src="192.168.10.50",dst="8.8.8.8")/
  UDP(sport=53421,dport=53)/
  DNS(rd=1,qd=DNSQR(qname="asdflkjhqwerty.malware-c2.example.com"))
)
packets.append(
  IP(src="192.168.10.51",dst="91.92.109.196")/
  TCP(sport=43210,dport=80,flags="PA")/
  Raw(load=b"GET / HTTP/1.1\r\nHost: 91.92.109.196\r\nUser-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64)\r\nConnection: keep-alive\r\n\r\n")
)
packets.append(
  IP(src="192.168.10.52",dst="194.165.16.90")/
  TCP(sport=55555,dport=443,flags="PA")/
  Raw(load=b"\x00"*400)
)
wrpcap("/opt/radiant-pcaps/demo-radiant.pcap", packets)
print(f"Written {len(packets)} packets to /opt/radiant-pcaps/demo-radiant.pcap")
PYEOF

log "PCAP ready. Choose replay mode:"
echo "  1) Quick (5x speed)   2) Slow (1x)   3) Loop"
if [ -n "$MODE" ]; then
  case "$MODE" in
    quick) C=1 ;;
    slow) C=2 ;;
    loop) C=3 ;;
    *)
      echo "Invalid DEMO_MODE: $MODE (use quick|slow|loop)"
      exit 1
      ;;
  esac
  echo "Running non-interactive mode: $MODE on interface $INTERFACE"
else
  read -p "Choice [1]: " C; C=${C:-1}
fi

case $C in
  1) sudo tcpreplay --intf1=$INTERFACE --multiplier=5 "$PCAP_DIR/demo-radiant.pcap" ;;
  2) sudo tcpreplay --intf1=$INTERFACE --multiplier=1 "$PCAP_DIR/demo-radiant.pcap" ;;
  3) sudo tcpreplay --intf1=$INTERFACE --loop=0 --multiplier=2 "$PCAP_DIR/demo-radiant.pcap" ;;
esac

log "Done. Check Kibana: http://kibana.lab -> Discover -> suricata-*"
