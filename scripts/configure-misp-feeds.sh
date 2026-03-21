#!/bin/bash
# scripts/configure-misp-feeds.sh
# Run after MISP is fully up and accessible
# Configures threat intelligence feeds via MISP API

set -e

MISP_URL="http://misp.lab"
MISP_KEY=$(grep "MISP auth key" ../credentials.txt | awk '{print $NF}')

if [ -z "$MISP_KEY" ]; then
  echo "ERROR: Could not read MISP auth key from credentials.txt"
  echo "Get your key from MISP UI: Administration > My Profile > Auth key"
  read -p "Paste your MISP auth key: " MISP_KEY
fi

CURL="curl -s -H \"Authorization: $MISP_KEY\" -H \"Accept: application/json\" -H \"Content-Type: application/json\""

echo "=== Configuring MISP feeds ==="

# Enable MISP community feeds
feeds=(
  # id 1 - CIRCL OSINT Feed
  "1"
  # id 2 - Botvrij.eu Data
  "2"
)

for id in "${feeds[@]}"; do
  echo "Enabling feed $id..."
  curl -s -X POST "$MISP_URL/feeds/enable/$id" \
    -H "Authorization: $MISP_KEY" \
    -H "Accept: application/json" | python3 -c "import sys,json; d=json.load(sys.stdin); print('OK' if d.get('message') else d)"
done

# Add Abuse.ch URLhaus feed
echo "Adding Abuse.ch URLhaus feed..."
curl -s -X POST "$MISP_URL/feeds/add" \
  -H "Authorization: $MISP_KEY" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -d '{
    "Feed": {
      "name": "Abuse.ch URLhaus",
      "provider": "Abuse.ch",
      "url": "https://urlhaus.abuse.ch/downloads/misp/",
      "enabled": true,
      "caching_enabled": true,
      "pull": true,
      "source_format": "misp",
      "fixed_event": false,
      "delta_merge": false,
      "event_id": "",
      "publish": false,
      "tag_id": false,
      "distribution": "0"
    }
  }' | python3 -c "import sys,json; d=json.load(sys.stdin); print('Added:', d.get('Feed',{}).get('name','error'))"

# Add Feodo Tracker feed (botnet C2)
echo "Adding Feodo Tracker feed..."
curl -s -X POST "$MISP_URL/feeds/add" \
  -H "Authorization: $MISP_KEY" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -d '{
    "Feed": {
      "name": "Feodo Tracker Botnet C2",
      "provider": "Abuse.ch",
      "url": "https://feodotracker.abuse.ch/downloads/ipblocklist.json",
      "enabled": true,
      "caching_enabled": true,
      "pull": true,
      "source_format": "json",
      "fixed_event": false,
      "delta_merge": false,
      "distribution": "0"
    }
  }' | python3 -c "import sys,json; d=json.load(sys.stdin); print('Added:', d.get('Feed',{}).get('name','error'))"

# Add ThreatFox feed (IOC sharing)
echo "Adding ThreatFox IOC feed..."
curl -s -X POST "$MISP_URL/feeds/add" \
  -H "Authorization: $MISP_KEY" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -d '{
    "Feed": {
      "name": "ThreatFox IOC",
      "provider": "Abuse.ch",
      "url": "https://threatfox.abuse.ch/export/misp/",
      "enabled": true,
      "caching_enabled": true,
      "pull": true,
      "source_format": "misp",
      "fixed_event": false,
      "distribution": "0"
    }
  }' | python3 -c "import sys,json; d=json.load(sys.stdin); print('Added:', d.get('Feed',{}).get('name','error'))"

# Enable ATT&CK galaxy and taxonomy
echo "Enabling ATT&CK galaxy..."
curl -s -X POST "$MISP_URL/galaxies/update" \
  -H "Authorization: $MISP_KEY" \
  -H "Accept: application/json" | python3 -c "import sys,json; d=json.load(sys.stdin); print('Galaxies updated')"

echo ""
echo "=== Feed configuration complete ==="
echo "Trigger initial fetch from MISP UI: Sync Actions > Fetch all feeds"
