#!/usr/bin/env python3
# ══════════════════════════════════════════════════════════════════════════════
#  ACROMAP v5.0 — WhatWeb/Wafw00f Structured Data Engine
#  Explicit State Degradation: Never crash. Never lie. Always declare failure.
# ══════════════════════════════════════════════════════════════════════════════
import json
import sys
import os
import re

def extract_json(raw_text):
    """
    Aristotelian Isolation:
    Extracts the most likely JSON structure from a string that may contain
    WAF-injected garbage or HTML.
    """
    # Attempt 1: Standard strip and parse
    try:
        return json.loads(raw_text.strip())
    except:
        pass

    # Attempt 2: Greedy search for balanced brackets [...] or {...}
    # This handles WAF block pages that prepend/append HTML
    matches = []
    # Find all potential starts
    for start_char in ('[', '{'):
        for m in re.finditer(re.escape(start_char), raw_text):
            start_idx = m.start()
            # Try to find matching closing bracket
            end_char = ']' if start_char == '[' else '}'
            stack = 0
            for i in range(start_idx, len(raw_text)):
                if raw_text[i] == start_char:
                    stack += 1
                elif raw_text[i] == end_char:
                    stack -= 1
                    if stack == 0:
                        potential_json = raw_text[start_idx : i+1]
                        try:
                            matches.append(json.loads(potential_json))
                        except:
                            pass
                        break
    
    # Return the largest list or dict found
    if not matches:
        return None
    
    # Sort by complexity (length of string representations)
    matches.sort(key=lambda x: len(str(x)), reverse=True)
    return matches[0]

def parse_web_state(whatweb_file, wafw00f_file):
    techs = set()
    cms_type = "None"
    has_waf = "false"
    waf_name = "None"
    whatweb_failed = False
    wafw00f_failed = False

    # ── 1. Parse WhatWeb JSON ────────────────────────────────────────────────
    if whatweb_file and os.path.exists(whatweb_file):
        if os.path.getsize(whatweb_file) == 0:
            whatweb_failed = True
            print("[WEB_PARSER] DEGRADED: EMPTY_WHATWEB — WhatWeb JSON is 0 bytes", file=sys.stderr)
        else:
            try:
                with open(whatweb_file, 'r', encoding='utf-8', errors='ignore') as f:
                    raw = f.read()
                    data = extract_json(raw)
                    
                    if data is None:
                        raise json.JSONDecodeError("No valid JSON structure found in file", raw, 0)

                    # whatweb --log-json outputs an array of objects
                    if isinstance(data, dict):
                        data = [data]
                    for item in data:
                        plugins = item.get('plugins', {})
                        for plugin_name, plugin_data in plugins.items():
                            name_lower = plugin_name.lower()
                            techs.add(name_lower)

                            # High-level CMS identification
                            if name_lower == "wordpress":
                                cms_type = "WordPress"
                            elif name_lower == "drupal":
                                cms_type = "Drupal"
                            elif name_lower == "joomla":
                                cms_type = "Joomla"

                            # Generic technology mapping
                            if name_lower in ["apache", "nginx", "iis", "tomcat"]:
                                techs.add("web_server:" + name_lower)
                                if name_lower == "apache" and "version" in plugin_data:
                                    versions = plugin_data.get("version", [])
                                    if versions: print(f"export APACHE_VERSION=\"{versions[0]}\"")
                            if "php" in name_lower:
                                techs.add("php")
                                if "version" in plugin_data:
                                    versions = plugin_data.get("version", [])
                                    if versions: print(f"export PHP_VERSION=\"{versions[0]}\"")
            except json.JSONDecodeError as e:
                whatweb_failed = True
                print(f"[WEB_PARSER] DEGRADED: JSON_CORRUPT — WhatWeb JSON decode failed: {e}", file=sys.stderr)
            except Exception as e:
                whatweb_failed = True
                print(f"[WEB_PARSER] DEGRADED: UNKNOWN_ERROR — {e}", file=sys.stderr)
    elif whatweb_file:
        whatweb_failed = True
        print(f"[WEB_PARSER] DEGRADED: FILE_NOT_FOUND — {whatweb_file}", file=sys.stderr)

    # ── 2. Parse wafw00f JSON ────────────────────────────────────────────────
    if wafw00f_file and os.path.exists(wafw00f_file):
        if os.path.getsize(wafw00f_file) == 0:
            wafw00f_failed = True
            print("[WEB_PARSER] DEGRADED: EMPTY_WAFW00F — Wafw00f JSON is 0 bytes", file=sys.stderr)
        else:
            try:
                with open(wafw00f_file, 'r', encoding='utf-8', errors='ignore') as f:
                    raw = f.read()
                    data = extract_json(raw)
                    
                    if data is None:
                        raise json.JSONDecodeError("No JSON structure in wafw00f output", raw, 0)

                    if isinstance(data, list) and len(data) > 0:
                        for item in data:
                            if item.get("detected"):
                                has_waf = "true"
                                waf_name = item.get("firewall", "Unknown WAF")
                                break
            except json.JSONDecodeError as e:
                wafw00f_failed = True
                print(f"[WEB_PARSER] DEGRADED: WAFW00F_CORRUPT — {e}", file=sys.stderr)
            except Exception as e:
                wafw00f_failed = True
                print(f"[WEB_PARSER] DEGRADED: WAFW00F_ERROR — {e}", file=sys.stderr)
    elif wafw00f_file:
        wafw00f_failed = True
        print(f"[WEB_PARSER] DEGRADED: WAFW00F_NOT_FOUND — {wafw00f_file}", file=sys.stderr)

    # ── 3. Build Nuclei tag mapping ──────────────────────────────────────────
    nuclei_tag_map = {
        "wordpress": ["wordpress", "wp-plugin"],
        "drupal": ["drupal"],
        "joomla": ["joomla"],
        "apache": ["apache"],
        "nginx": ["nginx"],
        "iis": ["iis", "asp"],
        "tomcat": ["tomcat", "java"],
        "php": ["php"],
        "nodejs": ["nodejs", "javascript"],
        "express": ["nodejs", "javascript"],
        "laravel": ["laravel", "php"],
        "symfony": ["php"],
        "django": ["python", "django"],
        "flask": ["python", "flask"],
        "react": ["javascript"],
        "angular": ["javascript"],
        "vue": ["javascript"],
    }
    nuclei_tags = set()
    for tech in techs:
        clean = tech.split(":")[-1]
        if clean in nuclei_tag_map:
            nuclei_tags.update(nuclei_tag_map[clean])

    # Determine web server
    web_server = "Unknown"
    for srv in ["nginx", "apache", "iis", "tomcat"]:
        if srv in techs or f"web_server:{srv}" in techs:
            web_server = srv.capitalize()
            break

    # ── 4. Explicit State Degradation Export ──────────────────────────────────
    parser_failed = whatweb_failed
    failure_reason = ""
    if whatweb_failed and wafw00f_failed:
        failure_reason = "WAF_CORRUPTION_BOTH"
    elif whatweb_failed:
        failure_reason = "WAF_CORRUPTION_WHATWEB"
    elif wafw00f_failed:
        failure_reason = "WAF_CORRUPTION_WAFW00F"

    print(f"export WEB_PARSER_FAILURE={'true' if parser_failed else 'false'}")
    print(f"export WEB_PARSER_REASON=\"{failure_reason}\"")
    print(f"export CMS_TYPE=\"{cms_type}\"")
    print(f"export HAS_WAF=\"{has_waf}\"")
    print(f"export WAF_NAME=\"{waf_name}\"")
    print(f"export WEB_SERVER=\"{web_server}\"")
    print(f"export DETECTED_TECHS_ARRAY=\"{' '.join(techs)}\"")
    print(f"export NUCLEI_TAGS=\"{','.join(sorted(nuclei_tags))}\"")


if __name__ == '__main__':
    whatweb_f = sys.argv[1] if len(sys.argv) > 1 else ""
    wafw00f_f = sys.argv[2] if len(sys.argv) > 2 else ""
    parse_web_state(whatweb_f, wafw00f_f)
