#!/usr/bin/env python3

import json
from urllib.parse import urlparse

INPUT = "/tmp/misp-attributes.json"
OUTPUT = "/tmp/misp.rules"


def sanitize_content(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"').strip()


def make_url_rule(url: str, sid: int) -> str:
    parsed = urlparse(url)
    host = parsed.netloc.strip()
    path = parsed.path.strip() if parsed.path else "/"

    parts = []

    if host:
        parts.append(f'http.host; content:"{sanitize_content(host)}";')
    if path and path != "/":
        parts.append(f'http.uri; content:"{sanitize_content(path)}";')

    if not parts:
        parts.append(f'content:"{sanitize_content(url)}";')

    return (
        f'alert http any any -> any any '
        f'(msg:"RADIANT MISP URL IOC {sanitize_content(url)}"; '
        f'flow:established,to_server; '
        f'{" ".join(parts)} '
        f'sid:{sid}; rev:1;)'
    )


def make_domain_rule(domain: str, sid: int) -> str:
    d = sanitize_content(domain.lower())
    return (
        f'alert dns any any -> any any '
        f'(msg:"RADIANT MISP DOMAIN IOC {d}"; '
        f'dns.query; content:"{d}"; '
        f'sid:{sid}; rev:1;)'
    )


def make_ip_rule(ip: str, sid: int) -> str:
    ip = ip.strip()
    return (
        f'alert ip any any -> {ip} any '
        f'(msg:"RADIANT MISP IP IOC {ip}"; '
        f'sid:{sid}; rev:1;)'
    )


with open(INPUT, "r", encoding="utf-8") as f:
    data = json.load(f)

rules = []
sid = 9900001

items = data.get("response", {}).get("Attribute", [])

for item in items:
    attr_type = item.get("type", "").strip().lower()
    value = item.get("value", "").strip()

    if not value:
        continue

    try:
        if attr_type == "url":
            rules.append(make_url_rule(value, sid))
            sid += 1
        elif attr_type == "domain":
            rules.append(make_domain_rule(value, sid))
            sid += 1
        elif attr_type in ("ip-dst", "ip-src", "ip"):
            rules.append(make_ip_rule(value, sid))
            sid += 1
    except Exception as e:
        print(f"Skipping bad attribute {attr_type}={value}: {e}")

with open(OUTPUT, "w", encoding="utf-8") as f:
    for rule in rules:
        f.write(rule + "\n")

print(f"Wrote {len(rules)} rules to {OUTPUT}")