#!/usr/bin/env python3
import json
import sys
from urllib.parse import urlparse

INPUT = "/tmp/misp-attributes.json"
OUTPUT = "/tmp/misp.rules"

def sanitize_content(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')

def make_url_rule(url: str, sid: int) -> str:
    parsed = urlparse(url)
    host = parsed.netloc
    path = parsed.path if parsed.path else "/"
    parts = []

    if host:
        parts.append(f'http.host; content:"{sanitize_content(host)}"; nocase;')
    if path and path != "/":
        parts.append(f'http.uri; content:"{sanitize_content(path)}"; nocase;')

    if not parts:
        parts.append(f'content:"{sanitize_content(url)}"; nocase;')

    return f'alert http any any -> any any (msg:"RADIANT MISP URL IOC {sanitize_content(url)}"; flow:established,to_server; {" ".join(parts)} sid:{sid}; rev:1;)'

def make_domain_rule(domain: str, sid: int) -> str:
    return f'alert dns any any -> any any (msg:"RADIANT MISP DOMAIN IOC {sanitize_content(domain)}"; dns.query; content:"{sanitize_content(domain)}"; nocase; sid:{sid}; rev:1;)'

def make_ip_rule(ip: str, sid: int) -> str:
    return f'alert ip any any -> {ip} any (msg:"RADIANT MISP IP IOC {ip}"; sid:{sid}; rev:1;)'

with open(INPUT, "r", encoding="utf-8") as f:
    data = json.load(f)

rules = []
sid = 9900001

items = data.get("response", {}).get("Attribute", [])
for item in items:
    attr_type = item.get("type", "")
    value = item.get("value", "").strip()

    if not value:
        continue

    try:
        if attr_type == "url":
            rules.append(make_url_rule(value, sid))
            sid += 1
        elif attr_type in ("domain", "hostname"):
            rules.append(make_domain_rule(value, sid))
            sid += 1
        elif attr_type in ("ip-dst", "ip-src"):
            rules.append(make_ip_rule(value, sid))
            sid += 1
    except Exception:
        continue

with open(OUTPUT, "w", encoding="utf-8") as f:
    f.write("\n".join(rules) + "\n")

print(f"Wrote {len(rules)} rules to {OUTPUT}")