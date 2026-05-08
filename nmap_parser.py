#!/usr/bin/env python3
# ══════════════════════════════════════════════════════════════════════════════
#  ACROMAP v5.0 — Nmap XML Structured Data Engine
#  Explicit State Degradation: Never crash. Never lie. Always declare failure.
# ══════════════════════════════════════════════════════════════════════════════
import xml.etree.ElementTree as ET
import sys
import os

def parse_nmap(xml_file):
    # ── Guard: File existence ─────────────────────────────────────────────────
    if not xml_file or not os.path.exists(xml_file):
        _emit_degraded("FILE_NOT_FOUND", f"Nmap XML file does not exist: {xml_file}")
        return

    # ── Guard: File is not empty ──────────────────────────────────────────────
    if os.path.getsize(xml_file) == 0:
        _emit_degraded("EMPTY_FILE", f"Nmap XML file is 0 bytes: {xml_file}")
        return

    try:
        tree = ET.parse(xml_file)
        root = tree.getroot()
    except ET.ParseError as e:
        _emit_degraded("XML_CORRUPT", f"XML parsing failed: {e}")
        return
    except Exception as e:
        _emit_degraded("UNKNOWN_PARSE_ERROR", str(e))
        return

    # ── Structural Guard: Nmap XML root MUST be <nmaprun> ─────────────────
    # WAFs inject valid HTML (e.g. <html><body>...) which ET.parse() accepts.
    # If root tag is not 'nmaprun', the data is WAF garbage, not Nmap output.
    if root.tag != 'nmaprun':
        _emit_degraded("WAF_CORRUPTION",
                        f"XML root tag is '{root.tag}', expected 'nmaprun'. "
                        f"WAF likely injected HTML into Nmap output.")
        return

    open_ports = []
    web_ports = []
    services = set()
    os_matches = []

    for host in root.findall('host'):
        # Parse OS
        os_elem = host.find('os')
        if os_elem is not None:
            for match in os_elem.findall('osmatch'):
                os_matches.append(match.get('name', ''))

        # Parse Ports
        ports = host.find('ports')
        if ports is not None:
            for port in ports.findall('port'):
                state = port.find('state')
                if state is not None and state.get('state') == 'open':
                    portid = port.get('portid')
                    open_ports.append(portid)

                    service = port.find('service')
                    if service is not None:
                        name = service.get('name', '').lower()
                        if name in ['http', 'https', 'http-alt', 'https-alt', 'ssl/http', 'http-proxy']:
                            web_ports.append(portid)
                        services.add(name)

    # Determine Windows vs Linux primarily
    os_guess = "Unknown"
    if os_matches:
        first_match = os_matches[0].lower()
        if "windows" in first_match:
            os_guess = "Windows"
        elif "linux" in first_match:
            os_guess = "Linux"
        else:
            os_guess = os_matches[0]

    # ── Healthy State Export ──────────────────────────────────────────────────
    print(f"export NMAP_PARSER_FAILURE=false")
    print(f"export NMAP_PARSER_REASON=\"\"")
    print(f"export OPEN_PORTS=\"{','.join(open_ports)}\"")
    if web_ports:
        print(f"export WEB_PORTS=\"{','.join(web_ports)}\"")
    print(f"export NMAP_OS_GUESS=\"{os_guess}\"")
    print(f"export NMAP_SERVICES=\"{','.join(services)}\"")


def _emit_degraded(reason, detail):
    """Explicit State Degradation: emit the fact of failure, not a lie."""
    # All output to stderr for human visibility
    print(f"[NMAP_PARSER] DEGRADED: {reason} — {detail}", file=sys.stderr)
    # Structured exports: the dispatcher knows we are BLINDED, not SECURE
    print(f"export NMAP_PARSER_FAILURE=true")
    print(f"export NMAP_PARSER_REASON=\"{reason}\"")
    print(f"export OPEN_PORTS=\"\"")
    print(f"export NMAP_OS_GUESS=\"Unknown\"")
    print(f"export NMAP_SERVICES=\"\"")


if __name__ == '__main__':
    if len(sys.argv) < 2:
        _emit_degraded("NO_INPUT", "No XML file argument provided")
        sys.exit(0)  # Do NOT crash the bash source pipeline
    parse_nmap(sys.argv[1])
