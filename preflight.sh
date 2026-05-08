#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
#  ACROMAP v5.0 — Pre-Flight Validation Script (Memory-Bridge Edition)
#  Author: acro777x  |  github.com/acro777x/acromap
#  Run via Process Substitution from acromap.sh:
#  eval "$(./preflight.sh "$TARGET")"
# ══════════════════════════════════════════════════════════════════════════════
set -uo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
G='\033[0;32m'; R='\033[0;31m'; Y='\033[1;33m'; C='\033[0;36m'; B='\033[1m'; N='\033[0m'
# All visual output MUST go to stderr (>&2) to prevent polluting the eval space
ok()   { printf "  ${G}[✓]${N} %s\n" "$1" >&2; }
fail() { printf "  ${R}[✗]${N} %s\n" "$1" >&2; FAIL_COUNT=$(( FAIL_COUNT + 1 )); }
warn() { printf "  ${Y}[!]${N} %s\n" "$1" >&2; WARN_COUNT=$(( WARN_COUNT + 1 )); }
info() { printf "  ${C}[i]${N} %s\n" "$1" >&2; }
FAIL_COUNT=0; WARN_COUNT=0

TARGET="${1:-}"
if [[ -z "$TARGET" ]]; then
    echo -e "${R}Usage: $0 <target_url_or_ip>${N}" >&2
    exit 1
fi

echo "" >&2
echo -e "${B}═══════════════════════════════════════════════════════${N}" >&2
echo -e "${B}  ACROMAP v5.0 — PRE-FLIGHT VALIDATION${N}" >&2
echo -e "${B}═══════════════════════════════════════════════════════${N}" >&2
echo "" >&2

# ── 1. Dependency Check ──────────────────────────────────────────────────────
echo -e "${B}[1/4] Dependency & Path Check${N}" >&2
for bin in nmap curl jq python3 dig nc; do
    if command -v "$bin" &>/dev/null; then
        ok "$bin found: $(command -v "$bin")"
    else
        fail "$bin NOT FOUND — required for accurate scanning"
    fi
done
# Optional but important tools
for opt_bin in nuclei subfinder httpx dnsx sslyze testssl.sh whatweb rustscan masscan; do
    if command -v "$opt_bin" &>/dev/null; then
        ok "$opt_bin available"
    else
        warn "$opt_bin not found — some phases will be skipped"
    fi
done
# Go path check
if command -v go &>/dev/null; then
    ok "go found: $(go version 2>/dev/null | head -c 40)"
else
    warn "go not found — nuclei/httpx/subfinder may not be available"
fi
echo "" >&2

# ── 2. Network & DNS Health ──────────────────────────────────────────────────
echo -e "${B}[2/4] Outbound Network & DNS Health${N}" >&2
if curl -s --max-time 5 -o /dev/null -w "%{http_code}" "http://1.1.1.1" 2>/dev/null | grep -qE "^(2|3)"; then
    ok "Outbound internet: reachable (1.1.1.1)"
else
    fail "Outbound internet: UNREACHABLE — cloud tools will fail"
fi
dns_result=$(dig google.com +short A 2>/dev/null | head -1 || echo "")
if [[ -n "$dns_result" ]]; then
    ok "DNS resolver: working (google.com -> $dns_result)"
else
    fail "DNS resolver: FAILED — dig google.com returned nothing"
fi
echo "" >&2

# ── 3. Target Endpoint Baseline ──────────────────────────────────────────────
echo -e "${B}[3/4] Target Endpoint Sanity Check${N}" >&2
target_url="$TARGET"
echo "$target_url" | grep -qE "^https?://" || target_url="http://${target_url}"

# Connection test with timing
conn_start=$(python3 -c "import time; print(int(time.time()*1000))" 2>/dev/null || date +%s%3N 2>/dev/null || echo 0)
http_code=$(curl -s -L -o /dev/null -w "%{http_code}" --max-time 15 -I "$target_url" 2>/dev/null || echo "000")
conn_end=$(python3 -c "import time; print(int(time.time()*1000))" 2>/dev/null || date +%s%3N 2>/dev/null || echo 0)
conn_start=$(echo "$conn_start" | tr -cd '0-9'); conn_start=$(( 10#0${conn_start} ))
conn_end=$(echo "$conn_end" | tr -cd '0-9'); conn_end=$(( 10#0${conn_end} ))
resp_ms=$(( conn_end - conn_start ))
[[ $resp_ms -lt 0 ]] && resp_ms=0

if [[ "$http_code" == "000" ]]; then
    fail "Target UNREACHABLE: $target_url (connection refused/timeout)"
elif [[ "$http_code" =~ ^(2|3) ]]; then
    ok "Target reachable: $target_url -> HTTP $http_code (${resp_ms}ms)"
else
    warn "Target returned HTTP $http_code — scan may produce limited results"
fi

# Timeout and parallel jobs calibration
DYNAMIC_TIMEOUT_MULT=1
SUGGESTED_PARALLEL_JOBS=0 # Let acromap decide based on nproc if 0

if [[ ${resp_ms:-0} -gt 5000 ]]; then
    warn "Response time: ${resp_ms}ms — SLOW target. Increase scanner timeouts."
    DYNAMIC_TIMEOUT_MULT=4
    SUGGESTED_PARALLEL_JOBS=1
elif [[ ${resp_ms:-0} -gt 2000 ]]; then
    warn "Response time: ${resp_ms}ms — moderate latency. Adjusting timeouts."
    DYNAMIC_TIMEOUT_MULT=2
    SUGGESTED_PARALLEL_JOBS=2
else
    ok "Response time: ${resp_ms}ms — fast target"
fi

# WAF/CDN detection
headers=$(curl -s -L -I --max-time 10 "$target_url" 2>/dev/null || echo "")
waf_detected=""
echo "$headers" | grep -qi "cloudflare"    && waf_detected="Cloudflare"
echo "$headers" | grep -qi "akamai"        && waf_detected="Akamai"
echo "$headers" | grep -qi "imperva\|incapsula" && waf_detected="Imperva/Incapsula"
echo "$headers" | grep -qi "sucuri"        && waf_detected="Sucuri"
echo "$headers" | grep -qi "f5\|bigip"     && waf_detected="F5 BIG-IP"
echo "$headers" | grep -qi "barracuda"     && waf_detected="Barracuda"
echo "$headers" | grep -qi "fortiweb\|fortigate" && waf_detected="Fortinet"
echo "$headers" | grep -qi "mod_security"  && waf_detected="ModSecurity"
if [[ -n "$waf_detected" ]]; then
    warn "WAF/CDN detected: ${waf_detected} — applying safe rates"
    SUGGESTED_PARALLEL_JOBS=1
    # Scale timeout multiplier slightly to account for WAF throttling
    DYNAMIC_TIMEOUT_MULT=$(( DYNAMIC_TIMEOUT_MULT + 1 ))
else
    ok "No WAF/CDN signatures detected in response headers"
fi

# Soft-404 Validation Engine
SOFT404_ACTIVE=false
SOFT404_SIZE=0
SOFT404_WORDS=0

uuid1=$(cat /proc/sys/kernel/random/uuid 2>/dev/null | cut -c1-16 || echo "acromap-s404-${RANDOM}${RANDOM}")
uuid2=$(cat /proc/sys/kernel/random/uuid 2>/dev/null | cut -c1-16 || echo "acromap-s404-${RANDOM}x${RANDOM}")
resp1=$(curl -s -L -w "\n%{http_code}:%{size_download}" --max-time 8 "${target_url}/acromap-nonexistent-${uuid1}.php" 2>/dev/null || echo "")
resp2=$(curl -s -L -w "\n%{http_code}:%{size_download}" --max-time 8 "${target_url}/acromap-nonexistent-${uuid2}.html" 2>/dev/null || echo "")
code1=$(echo "$resp1" | tail -1 | cut -d: -f1)
size1=$(echo "$resp1" | tail -1 | cut -d: -f2)
code2=$(echo "$resp2" | tail -1 | cut -d: -f1)
size2=$(echo "$resp2" | tail -1 | cut -d: -f2)
body1=$(echo "$resp1" | sed '$d')
words1=0; { words1=$(echo "$body1" | wc -w 2>/dev/null || true); words1=$(echo "$words1" | tr -cd '0-9'); words1=$(( 10#0${words1} )); } 2>/dev/null || true

if [[ "${code1:-0}" == "200" && "${code2:-0}" == "200" ]]; then
    size1=$(echo "$size1" | tr -cd '0-9'); size1=$(( 10#0${size1} ))
    size2=$(echo "$size2" | tr -cd '0-9'); size2=$(( 10#0${size2} ))
    size_diff=$(( size1 > size2 ? size1 - size2 : size2 - size1 ))
    size_avg=$(( (size1 + size2) / 2 ))
    if [[ ${size_avg:-0} -gt 0 ]]; then
        pct=$(( size_diff * 100 / size_avg ))
        if [[ ${pct:-100} -lt 20 ]]; then
            SOFT404_ACTIVE=true
            SOFT404_SIZE=$size_avg
            SOFT404_WORDS=$words1
            warn "Soft-404 detected on ${target_url}: baseline ${size_avg} bytes, ${words1} words"
        fi
    fi
else
    ok "404 handling: proper (random paths do not return 200)"
fi
echo "" >&2

# ── 4. Summary & State Export ────────────────────────────────────────────────
echo -e "${B}[4/4] Summary${N}" >&2
echo -e "  ─────────────────────────────────────" >&2
if [[ $FAIL_COUNT -eq 0 && $WARN_COUNT -eq 0 ]]; then
    echo -e "  ${G}${B}ALL CHECKS PASSED${N} — environment is ready for ACROMAP" >&2
elif [[ $FAIL_COUNT -eq 0 ]]; then
    echo -e "  ${Y}${B}${WARN_COUNT} WARNING(S)${N} — scan will work but some phases may be limited" >&2
else
    echo -e "  ${R}${B}${FAIL_COUNT} FAILURE(S)${N}, ${Y}${WARN_COUNT} WARNING(S)${N} — fix failures before running ACROMAP" >&2
    # Do not exit yet, we must export state anyway if possible, but the user must be warned.
fi
echo -e "  ─────────────────────────────────────" >&2
echo "" >&2

# ==============================================================================
#  MEMORY BRIDGE: STDOUT EXPORTS
#  Only output secure bash assignments here. No other text.
# ==============================================================================
echo "export PREFLIGHT_FAIL_COUNT=${FAIL_COUNT}"
echo "export PREFLIGHT_WARN_COUNT=${WARN_COUNT}"
echo "export LATENCY_MS=${resp_ms:-0}"
echo "export DYNAMIC_TIMEOUT_MULT=${DYNAMIC_TIMEOUT_MULT:-1}"
echo "export SUGGESTED_PARALLEL_JOBS=${SUGGESTED_PARALLEL_JOBS:-0}"
if [[ -n "$waf_detected" ]]; then
    echo "export WAF_DETECTED=\"${waf_detected}\""
else
    echo "export WAF_DETECTED=\"\""
fi
echo "export SOFT404_ACTIVE=${SOFT404_ACTIVE}"
echo "export SOFT404_SIZE=${SOFT404_SIZE}"
echo "export SOFT404_WORDS=${SOFT404_WORDS}"
echo "export PREFLIGHT_COMPLETED=true"
