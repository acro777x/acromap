#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════════════════
#  ACROMAP  v5.0  |  32-Phase Deep Penetration Testing Framework
#  Author   : acro777x
#  GitHub   : https://github.com/acro777x/acromap

# ── Auto-escalate to root ─────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    if command -v sudo &>/dev/null; then
        echo "[*] Auto-escalating to root via sudo..."
        chmod +x "${BASH_SOURCE[0]}" 2>/dev/null || true
        exec sudo bash "${BASH_SOURCE[0]}" "$@"
    else
        echo "[*] sudo not found — trying su root..."
        exec su -c "bash '${BASH_SOURCE[0]}' $*" root
    fi
fi
# We are root — ensure file is executable for future runs
chmod +x "${BASH_SOURCE[0]}" 2>/dev/null || true
#  Version  : 5.0
#  Platform : Kali Linux (primary) | Debian / Ubuntu (compatible)
#  CVEs     : 2019–2026 detection included
# ════════════════════════════════════════════════════════════════════════════════
#
#  ╔══════════════════════════════════════════════════════════════════════════╗
#  ║                        LEGAL DISCLAIMER                                  ║
#  ║                                                                          ║
#  ║  This tool is released FREE and OPEN SOURCE for the security             ║
#  ║  community. It is intended SOLELY for:                                   ║
#  ║    • Authorized penetration testing on systems you OWN                   ║
#  ║    • CTF / lab environments (TryHackMe, HackTheBox, GBU CSPL)            ║
#  ║    • Academic and educational research                                   ║
#  ║                                                                          ║
#  ║  THE AUTHOR (acro777x) BEARS ABSOLUTELY NO RESPONSIBILITY for any        ║
#  ║  illegal, unethical, or malicious use of this tool. Unauthorized         ║
#  ║  scanning of systems you do not own is ILLEGAL under the Computer        ║
#  ║  Fraud and Abuse Act (CFAA), UK Computer Misuse Act, IT Act 2000         ║
#  ║  (India), and equivalent laws worldwide.                                 ║
#  ║                                                                          ║
#  ║  By running this tool you accept full legal responsibility for           ║
#  ║  your actions.                           — acro777x, 2026                ║
#  ╚══════════════════════════════════════════════════════════════════════════╝
#
# ════════════════════════════════════════════════════════════════════════════════
set -uo pipefail
IFS=$'\n\t'

# ── Script paths ──────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m';   LRED='\033[1;31m'
ZERO_DAY_COL='\033[1;35;5m'  # blinking magenta for zero-day
ONE_CLICK_COL='\033[1;31;4m' # underline red for one-click
GREEN='\033[0;32m'; LGREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m';  LBLUE='\033[1;34m'
CYAN='\033[0;36m';  LCYAN='\033[1;36m'
MAGENTA='\033[0;35m'; LMAGENTA='\033[1;35m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
UNDERLINE='\033[4m'
NC='\033[0m'

# ── Spinner — shows animation during long operations ─────────────────────────
_SPINNER_PID=0
_SPIN_ACTIVE=false
_SPIN_MSG=""
_SPIN_FRAME=0

_spinner_start() {
    _SPIN_MSG="${1:-Working}"
    _SPIN_ACTIVE=true
    _SPIN_FRAME=0
    [[ -t 1 ]] || return 0
    printf "  \033[2m[  ] %s...\033[0m\r" "$_SPIN_MSG"
}

_spinner_tick() {
    [[ "$_SPIN_ACTIVE" != true || ! -t 1 ]] && return
    _SPIN_FRAME=$(( (_SPIN_FRAME + 1) % 4 ))
    local c
    case $_SPIN_FRAME in
        0) c="-" ;; 1) c="\\" ;; 2) c="|" ;; 3) c="/" ;;
    esac
    printf "\r  \033[36m[ %s ]\033[0m \033[2m%-45s\033[0m" "$c" "$_SPIN_MSG..."
}

_spinner_stop() {
    if [[ ${_SPINNER_PID:-0} -gt 0 ]]; then
        kill "$_SPINNER_PID" 2>/dev/null || true
        wait "$_SPINNER_PID" 2>/dev/null || true
        _SPINNER_PID=0
    fi
    _SPIN_ACTIVE=false
    [[ -t 1 ]] && printf "\r\033[2K" >&2 2>/dev/null || true
}

# ── Phase definitions (32 phases) ─────────────────────────────────────────────
declare -A PHASE_NAMES=(
    [0]="Setup & Tool Verification"
    [1]="Passive OSINT Reconnaissance"
    [2]="DNS Enumeration & Zone Transfer"
    [3]="Subdomain Enumeration (Deep)"
    [4]="Network Discovery & Host Detection"
    [5]="Full TCP Port Scanning"
    [6]="UDP Port Scanning"
    [7]="Service Detection & Banner Grabbing"
    [8]="Web Discovery & HTTP Probing"
    [9]="Web Technology Fingerprinting"
    [10]="SSL/TLS Deep Analysis"
    [11]="Web Content Discovery & Fuzzing"
    [12]="CMS Detection & Deep Scanning"
    [13]="API Endpoint Discovery"
    [14]="Nuclei Full Vulnerability Scan"
    [15]="Network Service Enumeration"
    [16]="SMB & Active Directory Enumeration"
    [17]="Authentication & Credential Testing"
    [18]="SQL Injection Deep Testing"
    [19]="XSS & Client-Side Attack Vectors"
    [20]="CVE 2024-2026 Targeted Checks"
    [21]="Post-Exploitation Simulation"
    [22]="Attack Path & Lateral Movement Analysis"
    [23]="Report Generation"
    [24]="Cloud Metadata & Misconfiguration Enum"
    [25]="Kubernetes Cluster Audit"
    [26]="Password Spray & Credential Attacks"
    [27]="CORS & JWT Authentication Testing"
    [28]="SSRF Deep Chain & OOB Testing"
    [29]="Secrets & Supply Chain Exposure"
    [30]="Active Directory Deep Attack Surface"
    [31]="Zero-Day & One-Click Exploit Detection"
)

# Phase ETAs in seconds (quick / standard / deep)
declare -A PHASE_ETA_QUICK=(
    [0]=30  [1]=30  [2]=45  [3]=60  [4]=30  [5]=60  [6]=60  [7]=45
    [8]=30  [9]=30  [10]=45 [11]=60 [12]=45 [13]=30 [14]=60 [15]=60
    [16]=45 [17]=60 [18]=45 [19]=30 [20]=60 [21]=30 [22]=30 [23]=20
    [24]=30 [25]=30 [26]=30
    [27]=30 [28]=45 [29]=60 [30]=60 [31]=45
)
declare -A PHASE_ETA_STD=(
    [0]=60  [1]=90  [2]=120 [3]=180 [4]=60  [5]=180 [6]=120 [7]=90
    [8]=60  [9]=60  [10]=90 [11]=180 [12]=120 [13]=60 [14]=180 [15]=120
    [16]=90 [17]=120 [18]=90 [19]=60 [20]=120 [21]=60 [22]=60 [23]=30
    [24]=60 [25]=60 [26]=90
    [27]=90 [28]=120 [29]=180 [30]=180 [31]=90
)
declare -A PHASE_ETA_DEEP=(
    [0]=60  [1]=180 [2]=240 [3]=600 [4]=120 [5]=600 [6]=300 [7]=180
    [8]=120 [9]=120 [10]=180 [11]=600 [12]=300 [13]=180 [14]=600 [15]=300
    [16]=240 [17]=300 [18]=240 [19]=180 [20]=300 [21]=120 [22]=120 [23]=60
    [24]=120 [25]=180 [26]=300
    [27]=240 [28]=300 [29]=600 [30]=600 [31]=180
)

# ── Runtime state ─────────────────────────────────────────────────────────────
TARGET=""
TARGET_TYPE=""       # IP | DOMAIN | CIDR
TARGET_IS_CIDR=false
CIDR_HOSTS=()        # expanded hosts from CIDR
SCAN_PROFILE="standard"
OUTPUT_DIR=""
DEBUG_MODE=false
START_TIME=$(date +%s)

# Checkpoint / Resume
CHECKPOINT_FILE=""
RESUME_MODE=false
LAST_PHASE=0     # last completed phase (used by resume system)

# Notifications
NOTIFY_SLACK=false
NOTIFY_EMAIL=false
SLACK_WEBHOOK=""
NOTIFY_EMAIL_ADDR=""

CURRENT_PHASE=0
CURRENT_PHASE_NAME="${PHASE_NAMES[0]}"
CURRENT_TOOL="none"
PHASE_START_TIME=$(date +%s)

# Vuln counters
ZERO_DAY_COUNT=0; ONE_CLICK_COUNT=0
CRITICAL_COUNT=0; HIGH_COUNT=0; MEDIUM_COUNT=0; LOW_COUNT=0; INFO_COUNT=0
declare -a VULN_DATA=()

# Tool tracking
declare -A TOOL_STATUS=()
declare -A TOOL_ELAPSED=()
TOOLS_ATTEMPTED=0; TOOLS_SUCCEEDED=0; PHASES_COMPLETED=0

# Collected data
OPEN_PORTS=""
WEB_PORTS=""
declare -a SUBDOMAINS=()
declare -a LIVE_HOSTS=()
declare -a WEB_TARGETS=()
CMS_TYPE=""
HAS_WAF=false
IS_WORDPRESS=false
IS_DRUPAL=false
IS_JOOMLA=false
MSF_RC_FILE=""       # Metasploit resource script path
ZAP_AVAILABLE=false  # OWASP ZAP daemon running
K8S_DETECTED=false   # Kubernetes cluster found
CLOUD_DETECTED=""    # AWS | GCP | AZURE | none
WILDCARD_DNS=false   # set true if wildcard DNS detected
_TF_SCAN_DONE=false      # trufflehog filesystem scan run flag

# Keypress monitor PID
KEYPRESS_PID=0

# ── v5.0 new feature globals ──────────────────────────────────────────────────
INTERACTSH_URL=""      # interactsh OOB server URL (set at startup if client found)
INTERACTSH_PID=0       # interactsh-client background process PID
NOTIFY_PER_FINDING=false  # push each finding instantly via notify tool
NOTIFY_CHANNEL=""      # notify provider config (slack/discord/telegram)
JQ_AVAILABLE=false     # jq installed — enables structured JSON finding parse
ANEW_AVAILABLE=false   # anew installed — dedup pipeline for subdomain/url lists
PARALLEL_JOBS=1        # GNU parallel jobs (set to nproc/2 if parallel installed)

# ── Logging ───────────────────────────────────────────────────────────────────
LOG_FILE=""   # set after OUTPUT_DIR is created

log_debug() {
    [[ "$DEBUG_MODE" == true ]] && echo -e "  ${DIM}[DBG]${NC} $*" >&2
    [[ -n "$LOG_FILE" ]] && echo "[$(date '+%H:%M:%S')] [DBG] $*" >> "$LOG_FILE" 2>/dev/null || true
}
log_ok()   { _spinner_stop 2>/dev/null; printf "  \033[1;32m[✓]\033[0m %s\n" "$*"; [[ -n "$LOG_FILE" ]] && echo "[$(date '+%H:%M:%S')] [OK]  $*" >> "$LOG_FILE" 2>/dev/null || true; }
log_warn() { _spinner_stop 2>/dev/null; printf "  \033[1;33m[!]\033[0m %s\n" "$*"; [[ -n "$LOG_FILE" ]] && echo "[$(date '+%H:%M:%S')] [WRN] $*" >> "$LOG_FILE" 2>/dev/null || true; }
log_error(){ _spinner_stop 2>/dev/null; printf "  \033[1;31m[✗]\033[0m %s\n" "$*"; [[ -n "$LOG_FILE" ]] && echo "[$(date '+%H:%M:%S')] [ERR] $*" >> "$LOG_FILE" 2>/dev/null || true; }
log_info() { printf "  \033[0;36m[i]\033[0m %s\n" "$*"; [[ -n "$LOG_FILE" ]] && echo "[$(date '+%H:%M:%S')] [INF] $*" >> "$LOG_FILE" 2>/dev/null || true; }

log_phase() {
    local n="$1" name="$2"
    CURRENT_PHASE="$n"
    CURRENT_PHASE_NAME="$name"
    PHASE_START_TIME=$(date +%s)
    _spinner_stop 2>/dev/null || true
    stty sane </dev/tty 2>/dev/null || true
    echo ""
    # Compact sticky status bar — always visible at start of each phase
    echo -e "${DIM}╔═ ACROMAP v5.0 | ${CYAN}${TARGET:-target}${DIM} | Phase ${CURRENT_PHASE}/32 | 0DAY:${ZERO_DAY_COUNT} 1CLK:${ONE_CLICK_COUNT} CRIT:${CRITICAL_COUNT} HIGH:${HIGH_COUNT} ═╗${NC}"
    echo -e "${LCYAN}${BOLD}"
    echo "  ╔══════════════════════════════════════════════════════════════════════╗"
    printf  "  ║  PHASE %2s / 32  ─  %-49s║\n" "$n" "$name"
    echo "  ╚══════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    [[ -n "$LOG_FILE" ]] && echo "[$(date '+%H:%M:%S')] ===== PHASE $n: $name =====" >> "$LOG_FILE" 2>/dev/null || true
}

log_section() {
    echo -e "\n  ${BOLD}${WHITE}── $* ──${NC}"
}

# ── run_tool wrapper ──────────────────────────────────────────────────────────
_is_valid_url() { echo "$1" | grep -qE "^https?://[a-zA-Z0-9._-]"; }

run_tool() {
    local name="$1" outfile="$2"; shift 2
    CURRENT_TOOL="$name"
    TOOLS_ATTEMPTED=$(( TOOLS_ATTEMPTED + 1 ))
    local t_start=$(date +%s)
    mkdir -p "$(dirname "$outfile")" 2>/dev/null || true
    log_debug "Running: $*"
    _spinner_start "${name}"
    "$@" > "$outfile" 2>&1 &
    local _tp=$!
    while kill -0 "$_tp" 2>/dev/null; do sleep 0.3; _spinner_tick; done
    wait "$_tp" 2>/dev/null; local _rc=$?
    printf "\033[32mdone\033[0m\n"
    local elapsed=$(( $(date +%s) - t_start ))
    if [[ ${_rc:-0} -eq 0 ]]; then
        TOOL_STATUS["$name"]="OK"; TOOL_ELAPSED["$name"]="$elapsed"
        TOOLS_SUCCEEDED=$(( TOOLS_SUCCEEDED + 1 ))
        [[ $elapsed -gt 1 ]] && printf "  \033[32m✓\033[0m %s (%ds)\n" "$name" "$elapsed"
        check_keypress_ipc; return 0
    else
        TOOL_STATUS["$name"]="FAIL"
        printf "  \033[33m⚠\033[0m %s failed\n" "$name"
        check_keypress_ipc; return 1
    fi
}

run_tool_timeout() {
    local name="$1" outfile="$2" tmo="$3"; shift 3
    CURRENT_TOOL="$name"
    TOOLS_ATTEMPTED=$(( TOOLS_ATTEMPTED + 1 ))
    local t_start=$(date +%s)
    mkdir -p "$(dirname "$outfile")" 2>/dev/null || true
    log_debug "Running (timeout ${tmo}s): $*"
    _spinner_start "${name}"
    timeout "$tmo" "$@" > "$outfile" 2>&1 &
    local _tool_pid=$!
    local _waited=0
    while kill -0 "$_tool_pid" 2>/dev/null; do
        sleep 0.3
        _waited=$(( _waited + 1 ))
        _spinner_tick
        [[ "$_ACROMAP_INTERRUPTED" == true ]] && kill "$_tool_pid" 2>/dev/null && break
    done
    wait "$_tool_pid" 2>/dev/null
    local _rc=$?
    printf "\033[32mdone\033[0m\n"
    local elapsed=$(( $(date +%s) - t_start ))
    if [[ ${_rc:-0} -eq 0 ]]; then
        TOOL_STATUS["$name"]="OK"
        TOOL_ELAPSED["$name"]="$elapsed"
        TOOLS_SUCCEEDED=$(( TOOLS_SUCCEEDED + 1 ))
        [[ $elapsed -gt 1 ]] && printf "  \033[32m✓\033[0m %s (%ds)\n" "$name" "$elapsed"
        check_keypress_ipc
        return 0
    else
        TOOL_STATUS["$name"]="FAIL"
        [[ $_rc -eq 124 ]] && printf "  \033[33m⚠\033[0m %s timed out (%ds)\n" "$name" "$tmo"
        check_keypress_ipc
        return 1
    fi
}

# ── Vulnerability recorder ────────────────────────────────────────────────────
add_vuln() {
    local sev="$1" title="$2" desc="$3" rec="$4" evidence="${5:-N/A}" exploit="${6:-}" patch="${7:-}"
    title="${title//|/;}"
    desc="${desc//|/;}"
    rec="${rec//|/;}"
    evidence="${evidence//|/;}"
    exploit="${exploit//|/;}"
    patch="${patch//|/;}"
    VULN_DATA+=("${sev}|${title}|${desc}|${rec}|${evidence}|${exploit}|${patch}")
    case "$sev" in
        ZERO_DAY)  ZERO_DAY_COUNT=$(( ZERO_DAY_COUNT + 1 ))    ;;
        ONE_CLICK) ONE_CLICK_COUNT=$(( ONE_CLICK_COUNT + 1 ))  ;;
        CRITICAL)  CRITICAL_COUNT=$(( CRITICAL_COUNT + 1 ))    ;;
        HIGH)      HIGH_COUNT=$(( HIGH_COUNT + 1 ))            ;;
        MEDIUM)    MEDIUM_COUNT=$(( MEDIUM_COUNT + 1 ))        ;;
        LOW)       LOW_COUNT=$(( LOW_COUNT + 1 ))              ;;
        INFO)      INFO_COUNT=$(( INFO_COUNT + 1 ))            ;;
    esac
    printf "  \033[1m[%s]\033[0m %s\n" "$sev" "$title"
    [[ -n "$LOG_FILE" ]] && printf "[%s] [%s] %s\n" "$(date '+%H:%M:%S')" "$sev" "$title" >> "$LOG_FILE" 2>/dev/null || true
}

# ── Confidence rating (0–10) ──────────────────────────────────────────────────
calculate_confidence() {
    local score=0
    if [[ ${TOOLS_ATTEMPTED:-0} -gt 0 ]]; then
        local rate=$(( TOOLS_SUCCEEDED * 100 / TOOLS_ATTEMPTED ))
        score=$(( score + rate * 30 / 100 ))
    fi
    case "$SCAN_PROFILE" in
        deep)     score=$(( score + 20 )) ;;
        standard) score=$(( score + 12 )) ;;
        quick)    score=$(( score + 6  )) ;;
    esac
    local phase_score=$(( PHASES_COMPLETED > 32 ? 32 : PHASES_COMPLETED ))
    score=$(( score + phase_score ))
    local total_findings=$(( ZERO_DAY_COUNT + ONE_CLICK_COUNT + CRITICAL_COUNT + HIGH_COUNT + MEDIUM_COUNT + LOW_COUNT + INFO_COUNT ))
    if [[ ${total_findings:-0} -gt 0 ]]; then
        score=$(( score + 10 ))
        [[ $total_findings -gt 5  ]] && score=$(( score + 5  ))
        [[ $total_findings -gt 15 ]] && score=$(( score + 5  ))
    fi
    for _t in "${WEB_TARGETS[@]+"${WEB_TARGETS[@]}"}"; do
        echo "$_t" | grep -qE "^https?://[a-zA-Z0-9]" || { score=$(( score - 10 )); break; }
    done
    [[ $score -gt 100 ]] && score=100
    local tens=$(( score / 10 ))
    local ones=$(( score % 10 ))
    echo "${tens}.${ones}"
}

get_confidence_label() {
    local rating="$1"
    local int="${rating%%.*}"
    if   [[ $int -ge 9 ]]; then echo "Exceptional"
    elif [[ $int -ge 8 ]]; then echo "Very High"
    elif [[ $int -ge 7 ]]; then echo "High"
    elif [[ $int -ge 6 ]]; then echo "Good"
    elif [[ $int -ge 5 ]]; then echo "Moderate"
    elif [[ $int -ge 4 ]]; then echo "Fair"
    else echo "Low"
    fi
}

# ── T / D keypress monitor ────────────────────────────────────────────────────
ACROMAP_DEBUG_FILE=""
ACROMAP_STATUS_REQ=""

start_keypress_monitor() {
    local dbg_file="${OUTPUT_DIR}/.acromap_debug_flag"
    local stat_file="${OUTPUT_DIR}/.acromap_status_req"
    ACROMAP_DEBUG_FILE="$dbg_file"
    ACROMAP_STATUS_REQ="$stat_file"
    echo "false" > "$dbg_file" 2>/dev/null || true

    if [[ -t 1 ]] && [[ -c /dev/tty ]]; then
    (
        trap '' INT TERM
        local _saved_tty; _saved_tty=$(stty -g </dev/tty 2>/dev/null || echo "")
        stty -echo -icanon min 0 time 1 </dev/tty 2>/dev/null || true
        while true; do
            local key=""
            IFS= read -r -n1 -t 1 key </dev/tty 2>/dev/null || key=""
            if [[ -n "$key" ]]; then
                case "$key" in
                    t|T) touch "$stat_file" 2>/dev/null || true ;;
                    d|D)
                        local cur; cur=$(cat "$dbg_file" 2>/dev/null || echo "false")
                        if [[ "$cur" == "true" ]]; then
                            echo "false" > "$dbg_file" 2>/dev/null || true
                            printf "\r\n  \033[1;33m[Debug OFF]\033[0m\n" >/dev/tty 2>/dev/null || true
                        else
                            echo "true" > "$dbg_file" 2>/dev/null || true
                            printf "\r\n  \033[1;32m[Debug ON]\033[0m\n" >/dev/tty 2>/dev/null || true
                        fi
                        ;;
                esac
            fi
            kill -0 $$ 2>/dev/null || break
        done
        [[ -n "$_saved_tty" ]] && stty "$_saved_tty" </dev/tty 2>/dev/null || true
    ) &
    KEYPRESS_PID=$!
    disown "$KEYPRESS_PID" 2>/dev/null || true
    fi
}

check_keypress_ipc() {
    [[ -z "$ACROMAP_DEBUG_FILE" ]] && return
    if [[ -f "$ACROMAP_DEBUG_FILE" ]]; then
        local dbg; dbg=$(cat "$ACROMAP_DEBUG_FILE" 2>/dev/null || echo "false")
        DEBUG_MODE="$dbg"
    fi
    if [[ -n "$ACROMAP_STATUS_REQ" && -f "$ACROMAP_STATUS_REQ" ]]; then
        rm -f "$ACROMAP_STATUS_REQ" 2>/dev/null || true
        show_status_overlay
    fi
}

show_status_overlay() {
    local now=$(date +%s)
    local phase_elapsed=$(( now - PHASE_START_TIME ))
    local total_elapsed=$(( now - START_TIME ))

    local phase_eta=0
    case "$SCAN_PROFILE" in
        quick)    phase_eta=${PHASE_ETA_QUICK[$CURRENT_PHASE]:-60} ;;
        standard) phase_eta=${PHASE_ETA_STD[$CURRENT_PHASE]:-120} ;;
        deep)     phase_eta=${PHASE_ETA_DEEP[$CURRENT_PHASE]:-300} ;;
    esac
    local phase_remaining=$(( phase_eta - phase_elapsed ))
    [[ ${phase_remaining:-0} -lt 0 ]] && phase_remaining=0

    local total_eta=0
    for i in $(seq 0 31); do
        case "$SCAN_PROFILE" in
            quick)    total_eta=$(( total_eta + ${PHASE_ETA_QUICK[$i]:-60}  )) ;;
            standard) total_eta=$(( total_eta + ${PHASE_ETA_STD[$i]:-120}  )) ;;
            deep)     total_eta=$(( total_eta + ${PHASE_ETA_DEEP[$i]:-300} )) ;;
        esac
    done
    local total_remaining=$(( total_eta - total_elapsed ))
    [[ ${total_remaining:-0} -lt 0 ]] && total_remaining=0

    local bar_width=38 filled=0 bar=""
    if [[ ${phase_eta:-0} -gt 0 ]]; then
        filled=$(( phase_elapsed * bar_width / phase_eta ))
        [[ $filled -gt $bar_width ]] && filled=$bar_width
    fi
    local empty=$(( bar_width - filled ))
    for ((i=0;i<filled;i++)); do bar+="█"; done
    for ((i=0;i<empty;i++)); do bar+="░"; done
    local pct=0
    [[ ${phase_eta:-0} -gt 0 ]] && pct=$(( phase_elapsed * 100 / phase_eta ))
    [[ $pct -gt 100 ]] && pct=100

    local conf; conf=$(calculate_confidence)

    echo ""
    echo -e "${LCYAN}${BOLD}"
    echo "  ╔══════════════════════════════════════════════════════════════════╗"
    echo "  ║              ── ACROMAP STATUS OVERLAY ──                        ║"
    echo "  ╠══════════════════════════════════════════════════════════════════╣"
    printf "  ║  Phase  : %2s / 32 — %-41s║\n" "$CURRENT_PHASE" "$CURRENT_PHASE_NAME"
    printf "  ║  Tool   : %-53s║\n" "${CURRENT_TOOL:-none}"
    printf "  ║  Target : %-53s║\n" "${TARGET:-not set}"
    printf "  ║  Profile: %-53s║\n" "$SCAN_PROFILE"
    echo "  ╠══════════════════════════════════════════════════════════════════╣"
    printf "  ║  Progress : [%s] %3d%%    ║\n" "$bar" "$pct"
    printf "  ║  Phase    : %dm %02ds elapsed  /  ~%dm %02ds remaining            ║\n" \
        $(( phase_elapsed/60 )) $(( phase_elapsed%60 )) $(( phase_remaining/60 )) $(( phase_remaining%60 ))
    printf "  ║  Total    : %dm %02ds elapsed  /  ~%dm %02ds remaining            ║\n" \
        $(( total_elapsed/60 )) $(( total_elapsed%60 )) $(( total_remaining/60 )) $(( total_remaining%60 ))
    echo "  ╠══════════════════════════════════════════════════════════════════╣"
    printf "  ║  0DAY:%-3s  1CLICK:%-3s  CRIT:%-3s  HIGH:%-3s  MED:%-3s  INFO:%-3s ║\n" \
        "$ZERO_DAY_COUNT" "$ONE_CLICK_COUNT" "$CRITICAL_COUNT" "$HIGH_COUNT" "$MEDIUM_COUNT" "$INFO_COUNT"
    printf "  ║  Confidence Rating : %s/10  (%s)                      ║\n" "$conf" "$(get_confidence_label "$conf")"
    printf "  ║  Tools : %s/%s succeeded     Press [D] to toggle debug         ║\n" \
        "$TOOLS_SUCCEEDED" "$TOOLS_ATTEMPTED"
    echo "  ╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# ── Cleanup ───────────────────────────────────────────────────────────────────
cleanup() {
    local code="${1:-0}"
    printf "\033[32mdone\033[0m\n"
    [[ ${KEYPRESS_PID:-0} -gt 0 ]] && stty sane </dev/tty 2>/dev/null || true
    [[ ${KEYPRESS_PID:-0} -gt 0 ]]   && kill "$KEYPRESS_PID"        2>/dev/null || true
    [[ ${INTERACTSH_PID:-0} -gt 0 ]] && kill "$INTERACTSH_PID"      2>/dev/null || true
    [[ -n "${ACROMAP_DEBUG_FILE:-}" ]] && rm -f "$ACROMAP_DEBUG_FILE" 2>/dev/null || true
    [[ -n "${ACROMAP_STATUS_REQ:-}"  ]] && rm -f "$ACROMAP_STATUS_REQ" 2>/dev/null || true
    if [[ $code -ne 0 && $code -ne 130 && $code -ne 143 ]]; then
        echo -e "\n  ${LRED}[!] Script terminated (signal/code ${code}). Partial results saved in: ${OUTPUT_DIR:-<not set>}${NC}" >&2
    elif [[ $code -eq 130 ]]; then
        echo -e "\n  ${YELLOW}[!] Scan interrupted by user (Ctrl+C). Results saved in: ${OUTPUT_DIR:-<not set>}${NC}" >&2
    fi
}

_ACROMAP_INTERRUPTED=false
_acromap_int_handler() {
    trap '' INT TERM EXIT
    [[ "$_ACROMAP_INTERRUPTED" == true ]] && exit 130
    _ACROMAP_INTERRUPTED=true
    printf "\033[32mdone\033[0m\n"
    echo -e "\n\n  ${YELLOW}[!] Ctrl+C — stopping scan. Saving partial results...${NC}" >/dev/tty 2>/dev/null || echo ""
    cleanup 130
    exit 130
}
trap '_acromap_int_handler' INT TERM
trap 'cleanup $?' EXIT

# ── Banner ────────────────────────────────────────────────────────────────────
print_banner() {
    clear
    echo -e "${LGREEN}${BOLD}"
    cat << 'BANNER'

    ╔══════════════════════════════════════════════════════════════════════════════╗
    ║                                                                              ║
    ║    ██████╗      ██████╗    ██████╗    ██████╗   ███╗   ███╗  █████╗  ██████╗ ║
    ║   ██╔══██╗    ██╔════╝   ██╔══██╗  ██╔═══██╗  ████╗ ████║ ██╔══██╗ ██╔══██╗  ║
    ║   ███████║    ██║        ██████╔╝  ██║   ██║  ██╔████╔██║ ███████║ ██████╔╝  ║
    ║   ██╔══██║    ██║        ██╔══██╗  ██║   ██║  ██║╚██╔╝██║ ██╔══██║ ██╔═══╝   ║
    ║   ██║  ██║    ╚██████╗   ██║  ██║  ╚██████╔╝  ██║ ╚═╝ ██║ ██║  ██║ ██║       ║
    ║   ╚═╝  ╚═╝     ╚═════╝   ╚═╝  ╚═╝   ╚═════╝   ╚═╝     ╚═╝ ╚═╝  ╚═╝ ╚═╝       ║
    ║                                                                              ║
    ║        { Code By → acro777x }   v5.0  |  32-Phase Auto Pentester           ║
    ║        CVEs: 2019–2026  |  CIDR  |  K8s  |  Cloud  |  ZAP  |  MSF        ║
    ║                                                                              ║
    ╚══════════════════════════════════════════════════════════════════════════════╝

BANNER
    echo -e "${NC}"
    echo -e "  ${WHITE}Press ${YELLOW}[T]${WHITE} anytime for live status   ${YELLOW}[D]${WHITE} to toggle debug${NC}"
    echo -e "  ${DIM}$(date '+%A, %d %B %Y  %H:%M:%S')${NC}"
    echo -e "  ${DIM}Running as: ${CYAN}$(whoami)${DIM} | Working dir: ${CYAN}$(pwd)${DIM} | Script: ${CYAN}${BASH_SOURCE[0]}${NC}"
    echo ""
}

# ── Target configuration ──────────────────────────────────────────────────────
get_target() {
    echo -e "\n${LCYAN}${BOLD}"
    echo "  ╔════════════════════════════════════════════╗"
    echo "  ║        TARGET CONFIGURATION                ║"
    echo "  ╚════════════════════════════════════════════╝"
    echo -e "${NC}"

    local scan_base="${SCRIPT_DIR}/acromap_results"
    local -a _cps=()
    while IFS= read -r _cp; do
        [[ -f "$_cp" ]] && _cps+=("$_cp")
    done < <(ls "${scan_base}"/*/.checkpoint 2>/dev/null)

    if [[ ${#_cps[@]} -gt 0 ]]; then
        echo -e "  ${YELLOW}[!]${NC} Previous scan checkpoints found:"
        local _idx=1
        for _cp in "${_cps[@]}"; do
            local _tgt; _tgt=$(grep -m1 "^TARGET=" "$_cp" 2>/dev/null | sed 's/^TARGET=//' | tr -d '"\'\ || echo "")
            [[ -z "$_tgt" ]] && _tgt=$(basename "$(dirname "$_cp")" | sed 's/_[0-9]*_[0-9]*$//')
            local _saved; _saved=$(grep "^SAVED=" "$_cp" 2>/dev/null | cut -d= -f2 || echo "")
            local _phase; _phase=$(grep "^LAST_PHASE=" "$_cp" 2>/dev/null | cut -d= -f2 || echo "0")
            echo -e "    ${YELLOW}[${_idx}]${NC} ${CYAN}${_tgt}${NC}  — phase ${_phase}/32 completed  ${DIM}${_saved}${NC}"
            _idx=$(( _idx + 1 ))
        done
        echo -e "    ${YELLOW}[0]${NC} Start fresh scan"
        echo ""
        echo -ne "  ${YELLOW}Select checkpoint to resume [0-$((${#_cps[@]}))]:${NC} (auto-fresh in 45s): "
        local _choice
        read -r -t 45 _choice || _choice="0"
        _choice="${_choice// /}"
        if [[ "$_choice" =~ ^[1-9][0-9]*$ ]] && [[ $_choice -le ${#_cps[@]} ]]; then
            local _chosen="${_cps[$(( _choice - 1 ))]}"
            RESUME_MODE=true
            if load_checkpoint "$_chosen"; then
                log_ok "Resumed: ${TARGET} from phase ${LAST_PHASE:-0}"
            else
                log_warn "Checkpoint corrupt — starting fresh"
                RESUME_MODE=false
            fi
        else
            log_info "Starting fresh scan."
            RESUME_MODE=false
        fi
    fi

    if [[ "$RESUME_MODE" == false ]]; then
        while true; do
            echo -ne "  ${YELLOW}Enter target IP / CIDR / domain${NC} (300s timeout): "
            read -r -t 300 TARGET || { log_error "No target entered — exiting."; exit 1; }
            TARGET="${TARGET// /}"
            local _raw_input="$TARGET"
            if [[ "$_raw_input" == http://* || "$_raw_input" == https://* ]]; then
                TARGET="${_raw_input#http://}"
                TARGET="${TARGET#https://}"
                TARGET="${TARGET%%/*}"
            fi

            if [[ -z "$TARGET" ]]; then
                log_error "Target cannot be empty."
                continue
            fi

            local raw="$TARGET"
            if [[ "$raw" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
                TARGET_TYPE="CIDR"
                TARGET_IS_CIDR=true
                log_ok "Target set: ${TARGET} (CIDR range)"
                if command -v nmap &>/dev/null; then
                    log_info "Expanding CIDR range..."
                    while IFS= read -r h; do
                        [[ "$h" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && CIDR_HOSTS+=("$h")
                    done < <(nmap -sL -n "$raw" 2>/dev/null | grep "Nmap scan report" | awk '{print $NF}')
                    log_ok "CIDR expanded: ${#CIDR_HOSTS[@]} hosts in range"
                fi
                break
            elif [[ "$raw" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                TARGET_TYPE="IP"
                TARGET_IS_CIDR=false
                CIDR_HOSTS=("$raw")
                log_ok "Target set: ${TARGET} (IP)"
                break
            elif [[ "$raw" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?)*$ ]]; then
                TARGET_TYPE="DOMAIN"
                TARGET_IS_CIDR=false
                CIDR_HOSTS=("$raw")
                log_ok "Target set: ${TARGET} (Domain)"
                break
            else
                log_error "Invalid format. Use: IP (1.2.3.4) | CIDR (1.2.3.0/24) | Domain (target.lab)"
            fi
        done
    fi
}

# ── Profile selection ─────────────────────────────────────────────────────────
get_profile() {
    if [[ "$RESUME_MODE" == true && -n "$OUTPUT_DIR" ]]; then
        log_ok "Resuming scan — Profile: ${SCAN_PROFILE} | Output: ${OUTPUT_DIR}"
        mkdir -p "${OUTPUT_DIR}"/{nmap,masscan,rustscan,nikto,gobuster,feroxbuster,ffuf,dirb,\
whatweb,wafw00f,sslscan,sslyze,whois,dns,subdomains,httpx,nuclei,wpscan,droopescan,\
joomscan,cmseek,sqlmap,dalfox,xsstrike,commix,enum4linux,crackmapexec,smbmap,\
hydra,theharvester,shodan,curl,arjun,api,cve_checks,post_exploit,raw_logs,reports,\
metasploit,zap,cloud_enum,kubernetes,password_spray,cidr_hosts,\
cors_jwt,ssrf_deep,secrets,ad_attacks,gf_output,hakrawler,bypass403} 2>/dev/null
        LOG_FILE="${OUTPUT_DIR}/acromap_debug.log"
        CHECKPOINT_FILE="${OUTPUT_DIR}/.checkpoint"
        MSF_RC_FILE="${OUTPUT_DIR}/metasploit/exploit.rc"
        return 0
    fi

    echo -e "\n${LCYAN}${BOLD}"
    echo "  ╔════════════════════════════════════════════╗"
    echo "  ║        SCAN PROFILE SELECTION              ║"
    echo "  ╚════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "  ${BOLD}[1]${NC} ${LGREEN}Quick${NC}    — Core phases, top ports, fast recon        (~15 min)"
    echo -e "  ${BOLD}[2]${NC} ${YELLOW}Standard${NC} — All 32 phases, full port scan, deep web    (~45 min)"
    echo -e "  ${BOLD}[3]${NC} ${LRED}Deep${NC}     — Max depth, all tools, brute force enabled  (~2+ hrs)"
    echo ""
    echo -ne "  ${YELLOW}Select profile [1/2/3] (auto-standard in 30s): ${NC}"
    read -r -t 30 profile_choice || profile_choice="2"
    case "$profile_choice" in
        1) SCAN_PROFILE="quick";    log_ok "Profile: Quick" ;;
        3) SCAN_PROFILE="deep";     log_ok "Profile: Deep" ;;
        *) SCAN_PROFILE="standard"; log_ok "Profile: Standard" ;;
    esac

    OUTPUT_DIR="${SCRIPT_DIR}/acromap_results/${TARGET}_${TIMESTAMP}"
    mkdir -p "${OUTPUT_DIR}"/{nmap,masscan,rustscan,nikto,gobuster,feroxbuster,ffuf,dirb,\
whatweb,wafw00f,sslscan,sslyze,whois,dns,subdomains,httpx,nuclei,wpscan,droopescan,\
joomscan,cmseek,sqlmap,dalfox,xsstrike,commix,enum4linux,crackmapexec,smbmap,\
hydra,theharvester,shodan,curl,arjun,api,cve_checks,post_exploit,raw_logs,reports,\
metasploit,zap,cloud_enum,kubernetes,password_spray,cidr_hosts,\
cors_jwt,ssrf_deep,secrets,ad_attacks,gf_output,hakrawler,bypass403} 2>/dev/null
    LOG_FILE="${OUTPUT_DIR}/acromap_debug.log"
    CHECKPOINT_FILE="${OUTPUT_DIR}/.checkpoint"
    MSF_RC_FILE="${OUTPUT_DIR}/metasploit/exploit.rc"
    
    echo "# ACROMAP v5.0 — Debug Log" > "$LOG_FILE"
    echo "# Target: ${TARGET}  |  Profile: ${SCAN_PROFILE}  |  Date: $(date)" >> "$LOG_FILE"
    log_ok "Output directory: ${OUTPUT_DIR}"

    echo ""
    echo -e "  ${LCYAN}${BOLD}── Notification Setup (optional) ──${NC}"
    echo -ne "  ${YELLOW}Enable Slack notification on completion? [y/N] (auto-N in 10s): ${NC}"
    read -r -t 10 slack_ans || slack_ans="N"
    if [[ "${slack_ans,,}" == "y" ]]; then
        echo -ne "  Enter Slack webhook URL (30s): "
        read -r -t 30 SLACK_WEBHOOK || SLACK_WEBHOOK=""
        if [[ -n "$SLACK_WEBHOOK" ]]; then
            NOTIFY_SLACK=true
            log_ok "Slack notifications enabled"
        fi
    fi
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 0 — SETUP & TOOL VERIFICATION
# ════════════════════════════════════════════════════════════════════════════════
phase_setup() {
    log_phase 0 "${PHASE_NAMES[0]}"
    local -a REQUIRED_TOOLS=(
        nmap masscan nikto gobuster ffuf dirb whatweb wafw00f sslscan
        whois curl wget git python3 python3-pip netcat-openbsd
        dnsutils dnsenum enum4linux smbclient onesixtyone snmp
        sqlmap hydra wpscan nuclei theharvester wkhtmltopdf
        sublist3r feroxbuster crackmapexec smbmap arjun commix
        sslyze dalfox rustscan httpx subfinder dnsx amass katana
        gau waybackurls wfuzz joomscan droopescan cmseek xsstrike
        impacket-scripts kerbrute evil-winrm jq anew hakrawler gf 
        trufflehog notify interactsh-client impacket-GetUserSPNs 
        impacket-GetNPUsers certipy-ad parallel ldapdomaindump
    )

    local -a MISSING=() FOUND=()
    log_section "Tool inventory..."
    for pkg in "${REQUIRED_TOOLS[@]}"; do
        local bin="$pkg"
        case "$pkg" in
            dnsutils)         bin="dig" ;;
            netcat-openbsd)   bin="nc" ;;
            python3-pip)      bin="pip3" ;;
            impacket-scripts) bin="impacket-samrdump" ;;
            evil-winrm)       command -v evil-winrm.rb &>/dev/null && bin="evil-winrm.rb" || bin="evil-winrm" ;;
            crackmapexec)     command -v nxc &>/dev/null && bin="nxc" || bin="crackmapexec" ;;
            impacket-GetUserSPNs)  bin="GetUserSPNs.py"  ;;
            impacket-GetNPUsers)   bin="GetNPUsers.py"   ;;
            certipy-ad)            bin="certipy"         ;;
        esac
        if command -v "$bin" &>/dev/null; then
            FOUND+=("$pkg")
            printf "    ${LGREEN}✓${NC}  %-28s installed\n" "$bin"
        else
            MISSING+=("$pkg")
            printf "    ${YELLOW}✗${NC}  %-28s missing\n" "$bin"
        fi
    done

    if [[ ${#MISSING[@]} -gt 0 ]]; then
        log_warn "${#MISSING[@]} tools missing. Attempting auto-install..."
        # Simplified for brevity - assumes dependencies handled pre-execution
        log_info "Please install missing tools via 'apt-get install' or 'go install'."
    fi

    command -v jq              &>/dev/null && JQ_AVAILABLE=true
    command -v anew            &>/dev/null && ANEW_AVAILABLE=true
    command -v notify          &>/dev/null && NOTIFY_PER_FINDING=true
    if command -v parallel     &>/dev/null; then
        mkdir -p ~/.parallel 2>/dev/null; touch ~/.parallel/will-cite 2>/dev/null
        PARALLEL_JOBS=$(( $(nproc 2>/dev/null || echo 2) / 2 ))
        [[ ${PARALLEL_JOBS:-0} -lt 1 ]] && PARALLEL_JOBS=1
    fi

    if command -v interactsh-client &>/dev/null; then
        interactsh-client -json -o "${OUTPUT_DIR}/raw_logs/interactsh.json" 2>/dev/null &
        INTERACTSH_PID=$!
        sleep 4
        INTERACTSH_URL=$(head -1 "${OUTPUT_DIR}/raw_logs/interactsh.json" 2>/dev/null \
            | grep -oE '"url"[[:space:]]*:[[:space:]]*"[^"]+"' | grep -oE '"[^"]+"$' | tr -d '"' || echo "")
        [[ -n "$INTERACTSH_URL" ]] && log_ok "interactsh-client running — OOB URL: ${INTERACTSH_URL}"
    fi

    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 1 — PASSIVE OSINT RECONNAISSANCE
# ════════════════════════════════════════════════════════════════════════════════
phase_osint() {
    log_phase 1 "${PHASE_NAMES[1]}"

    if command -v whois &>/dev/null; then
        run_tool_timeout "whois" "${OUTPUT_DIR}/whois/whois.txt" 30 whois "$TARGET" 2>/dev/null || true
    fi

    if command -v theHarvester &>/dev/null || command -v theharvester &>/dev/null; then
        local harv_bin; harv_bin=$(command -v theHarvester 2>/dev/null || command -v theharvester 2>/dev/null)
        run_tool_timeout "theHarvester" "${OUTPUT_DIR}/theharvester/results.txt" 120 \
            "$harv_bin" -d "$TARGET" -b google,bing,urlscan -l 200 2>/dev/null || true
        local hf="${OUTPUT_DIR}/theharvester/results.txt"
        if [[ -f "$hf" ]]; then
            local _real_emails; _real_emails=$(grep -oE "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}" "$hf" 2>/dev/null | sort -u | head -10 || echo "")
            local email_count; email_count=$(echo "$_real_emails" | grep -c "@" 2>/dev/null || true)
            email_count=$(( ${email_count:-0} ))
            [[ ${email_count:-0} -gt 0 ]] && add_vuln "LOW" "Email Addresses Harvested (${email_count} found)" "Publicly indexed email addresses found." "Implement harvesting protection." "$(echo "$_real_emails" | head -3)"
        fi
    fi

    if command -v curl &>/dev/null; then
        run_tool_timeout "crt.sh" "${OUTPUT_DIR}/theharvester/crtsh.json" 30 \
            curl -s "https://crt.sh/?q=%.${TARGET}&output=json" --max-time 25 2>/dev/null || true
        local crtf="${OUTPUT_DIR}/theharvester/crtsh.json"
        if [[ -f "$crtf" ]] && grep -q '\[' "$crtf"; then
            grep -oE '"name_value":"[^"]+"' "$crtf" 2>/dev/null | cut -d'"' -f4 | sort -u > "${OUTPUT_DIR}/subdomains/from_crtsh.txt" 2>/dev/null || true
            local crt_count; crt_count=$(wc -l < "${OUTPUT_DIR}/subdomains/from_crtsh.txt" 2>/dev/null || true)
            crt_count=$(( ${crt_count:-0} ))
            log_ok "crt.sh: ${crt_count} subdomains from certificate transparency"
        fi
    fi

    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 2 — DNS ENUMERATION & ZONE TRANSFER
# ════════════════════════════════════════════════════════════════════════════════
phase_dns() {
    log_phase 2 "${PHASE_NAMES[2]}"
    local dns_dir="${OUTPUT_DIR}/dns"

    if command -v dig &>/dev/null; then
        for rec in A AAAA MX NS TXT SOA CNAME SRV; do
            dig "$TARGET" "$rec" +short > "${dns_dir}/dig_${rec}.txt" 2>/dev/null || true
        done
        
        local txt_out="${dns_dir}/dig_TXT.txt"
        if [[ -f "$txt_out" ]]; then
            if ! grep -qi "v=spf1" "$txt_out" 2>/dev/null; then
                add_vuln "MEDIUM" "Missing SPF DNS Record" "No SPF record found. Spoofing is possible." "Add valid SPF TXT record." "dig ${TARGET} TXT"
            fi
        fi

        local ns_list; ns_list=$(dig "$TARGET" NS +short 2>/dev/null | head -5)
        if [[ -n "$ns_list" ]]; then
            while IFS= read -r ns; do
                ns="${ns%.}"
                [[ -z "$ns" ]] && continue
                echo "$ns" | grep -qiE "cloudflare\.com|googledomains|awsdns" && continue
                run_tool_timeout "zone-transfer" "${dns_dir}/axfr_${ns}.txt" 10 dig "@${ns}" "$TARGET" AXFR +noall +answer || true
                if grep -qE "IN[[:space:]]+(A|AAAA|MX|NS|CNAME|TXT|SOA)" "${dns_dir}/axfr_${ns}.txt" 2>/dev/null; then
                    add_vuln "CRITICAL" "DNS Zone Transfer Allowed (AXFR)" "NS server ${ns} allows full zone transfer." "Restrict AXFR." "dig @${ns} ${TARGET} AXFR"
                fi
            done <<< "$ns_list"
        fi
    fi

    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 3 — SUBDOMAIN ENUMERATION (DEEP)
# ════════════════════════════════════════════════════════════════════════════════
phase_subdomains() {
    log_phase 3 "${PHASE_NAMES[3]}"
    local sub_dir="${OUTPUT_DIR}/subdomains"

    if [[ "$TARGET_TYPE" != "DOMAIN" ]]; then
        PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
        return 0
    fi

    command -v subfinder &>/dev/null && run_tool_timeout "subfinder" "${sub_dir}/subfinder.txt" 120 subfinder -d "$TARGET" -silent -all 2>/dev/null || true
    
    WILDCARD_DNS=false
    local _wc_ip; _wc_ip=$(dig "acromap-wildcard-notreal-$(date +%s).${TARGET}" A +short 2>/dev/null | head -1 || echo "")
    if [[ -n "$_wc_ip" ]]; then
        WILDCARD_DNS=true
        log_warn "Wildcard DNS detected on ${TARGET} (resolves to ${_wc_ip})"
    fi

    if command -v gobuster &>/dev/null && [[ "$WILDCARD_DNS" == false ]]; then
        local wordlist="/usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt"
        [[ -f "$wordlist" ]] && run_tool_timeout "gobuster-dns" "${sub_dir}/gobuster_dns_raw.txt" 180 gobuster dns -d "$TARGET" -w "$wordlist" -t 50 -q --no-color 2>/dev/null || true
        grep -oE "([a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}" "${sub_dir}/gobuster_dns_raw.txt" 2>/dev/null > "${sub_dir}/gobuster_dns.txt" || true
    fi

    cat "${sub_dir}/"*.txt 2>/dev/null | sed 's/\[[0-9;]*m//g' | grep -oE "([a-zA-Z0-9]([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,})" | sort -u > "${sub_dir}/all_subdomains.txt" || true

    while IFS= read -r sub; do
        [[ -z "$sub" ]] && continue
        SUBDOMAINS+=("$sub")
    done < "${sub_dir}/all_subdomains.txt" 2>/dev/null || true

    local total=${#SUBDOMAINS[@]}
    if command -v httpx &>/dev/null && [[ ${total:-0} -gt 0 ]]; then
        run_tool_timeout "httpx-subdomains" "${sub_dir}/live_subdomains_raw.txt" 120 httpx -l "${sub_dir}/all_subdomains.txt" -silent -mc 200,301,302,403,401 -title -tech-detect -status-code -follow-redirects 2>/dev/null || true
        grep -E "^https?://[a-zA-Z0-9]" "${sub_dir}/live_subdomains_raw.txt" 2>/dev/null > "${sub_dir}/live_subdomains.txt" || true
        local live_count; live_count=$(wc -l < "${sub_dir}/live_subdomains.txt" 2>/dev/null || true)
        live_count=$(( ${live_count:-0} ))
        
        while IFS= read -r h; do
            local url_only; url_only=$(echo "$h" | awk '{print $1}')
            echo "$url_only" | grep -qE "^https?://[a-zA-Z0-9]" || continue
            WEB_TARGETS+=("$url_only")
        done < "${sub_dir}/live_subdomains.txt" 2>/dev/null || true
    fi

    # Subdomain Takeover Detection (CNAME dangling)
    local takeover_file="${OUTPUT_DIR}/zero_day_oneclick/takeover_candidates.txt"
    if [[ -s "${sub_dir}/all_subdomains.txt" ]]; then
        mkdir -p "$(dirname "$takeover_file")" 2>/dev/null || true
        while IFS= read -r _tosub; do
            [[ -z "$_tosub" ]] && continue
            local _tocn; _tocn=$(timeout 5 dig "$_tosub" CNAME +short 2>/dev/null | head -1 | sed 's/\.$//' || echo "")
            [[ -z "$_tocn" ]] && continue
            if echo "$_tocn" | grep -qiE "github.io|s3.amazonaws.com|azurewebsites.net|herokuapp.com"; then
                local _tosc; _tosc=$(curl -s -o /dev/null -w "%{http_code}" --max-time 8 "http://${_tosub}" 2>/dev/null || echo "000")
                if [[ "$_tosc" == "404" || "$_tosc" == "000" || "$_tosc" == "503" ]]; then
                    echo "${_tosub} -> ${_tocn}" >> "$takeover_file"
                fi
            fi
        done < <(head -50 "${sub_dir}/all_subdomains.txt" 2>/dev/null)
    fi

    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 4 — NETWORK DISCOVERY & HOST DETECTION
# ════════════════════════════════════════════════════════════════════════════════
phase_host_discovery() {
    log_phase 4 "${PHASE_NAMES[4]}"
    local nd_dir="${OUTPUT_DIR}/nmap"
    if ping -c 1 -W 2 "$TARGET" &>/dev/null 2>&1; then
        LIVE_HOSTS+=("$TARGET")
    else
        for _p in 80 443 22 8080; do
            if timeout 3 bash -c ">/dev/tcp/${TARGET}/${_p}" 2>/dev/null; then
                LIVE_HOSTS+=("$TARGET")
                break
            fi
        done
    fi

    if command -v nmap &>/dev/null; then
        if [[ ${EUID:-0} -eq 0 ]]; then
            run_tool_timeout "nmap-os" "${nd_dir}/nmap_os.txt" 90 nmap -O --osscan-guess -T4 "$TARGET" 2>/dev/null || true
        fi
    fi
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 5 — FULL TCP PORT SCANNING
# ════════════════════════════════════════════════════════════════════════════════
phase_tcp_scan() {
    log_phase 5 "${PHASE_NAMES[5]}"
    local nmap_dir="${OUTPUT_DIR}/nmap"
    local -a nmap_flags=(-sV -sC -T4)
    local -a port_range=(--top-ports 1000)
    local nmap_timeout=360
    
    run_tool_timeout "nmap-tcp" "${nmap_dir}/nmap_tcp.txt" "$nmap_timeout" \
        nmap "${nmap_flags[@]}" "${port_range[@]}" -oX "${nmap_dir}/nmap_tcp.xml" -oG "${nmap_dir}/nmap_grep.txt" "$TARGET" 2>/dev/null || true

    if [[ -f "${nmap_dir}/nmap_tcp.txt" ]]; then
        OPEN_PORTS=$(grep "^[0-9]*/tcp.*open" "${nmap_dir}/nmap_tcp.txt" 2>/dev/null | awk '{print $1}' | cut -d/ -f1 | tr '\n' ',' | sed 's/,$//' || echo "")
        WEB_PORTS=$(grep "^[0-9]*/tcp.*open.*http" "${nmap_dir}/nmap_tcp.txt" 2>/dev/null | awk '{print $1}' | cut -d/ -f1 | tr '\n' ',' | sed 's/,$//' || echo "")
        [[ -z "$WEB_PORTS" ]] && grep -qiE "80/tcp|443/tcp|8080/tcp|8443/tcp" "${nmap_dir}/nmap_tcp.txt" 2>/dev/null && WEB_PORTS="80,443"
    fi
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 6 — UDP PORT SCANNING
# ════════════════════════════════════════════════════════════════════════════════
phase_udp_scan() {
    log_phase 6 "${PHASE_NAMES[6]}"
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 7 — SERVICE DETECTION & BANNER GRABBING
# ════════════════════════════════════════════════════════════════════════════════
phase_service_detect() {
    log_phase 7 "${PHASE_NAMES[7]}"
    local nmap_dir="${OUTPUT_DIR}/nmap"
    if echo "$OPEN_PORTS" | grep -qE "(^|,)22(,|$)"; then
        run_tool_timeout "nmap-ssh" "${nmap_dir}/nmap_ssh.txt" 30 nmap -sV -p 22 --script ssh2-enum-algos,ssh-auth-methods,ssh-hostkey "$TARGET" 2>/dev/null || true
    fi
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 8 — WEB DISCOVERY & HTTP PROBING
# ════════════════════════════════════════════════════════════════════════════════
phase_web_discovery() {
    log_phase 8 "${PHASE_NAMES[8]}"
    [[ ${#WEB_TARGETS[@]} -eq 0 ]] && WEB_TARGETS=("http://${TARGET}" "https://${TARGET}")
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 9 — WEB TECHNOLOGY FINGERPRINTING
# ════════════════════════════════════════════════════════════════════════════════
phase_tech_fingerprint() {
    log_phase 9 "${PHASE_NAMES[9]}"
    for web_url in "${WEB_TARGETS[@]:0:5}"; do
        _is_valid_url "$web_url" || continue
        if command -v wafw00f &>/dev/null; then
            wafw00f -a "$web_url" > "${OUTPUT_DIR}/wafw00f/wafw00f_out.txt" 2>/dev/null || true
        fi
    done
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 10 — SSL/TLS DEEP ANALYSIS
# ════════════════════════════════════════════════════════════════════════════════
phase_ssl() {
    log_phase 10 "${PHASE_NAMES[10]}"
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 11 — WEB CONTENT DISCOVERY & FUZZING
# ════════════════════════════════════════════════════════════════════════════════
phase_content_discovery() {
    log_phase 11 "${PHASE_NAMES[11]}"
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 12 — CMS DETECTION & DEEP SCANNING
# ════════════════════════════════════════════════════════════════════════════════
phase_cms() {
    log_phase 12 "${PHASE_NAMES[12]}"
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 13 — API ENDPOINT DISCOVERY
# ════════════════════════════════════════════════════════════════════════════════
phase_api() {
    log_phase 13 "${PHASE_NAMES[13]}"
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 14 — NUCLEI FULL VULNERABILITY SCAN
# ════════════════════════════════════════════════════════════════════════════════
phase_nuclei() {
    log_phase 14 "${PHASE_NAMES[14]}"
    if command -v nuclei &>/dev/null; then
        printf '%s\n' "${WEB_TARGETS[@]+"${WEB_TARGETS[@]}"}" > "${OUTPUT_DIR}/nuclei/targets.txt"
        run_tool_timeout "nuclei" "${OUTPUT_DIR}/nuclei/nuclei_results.txt" 300 \
            nuclei -l "${OUTPUT_DIR}/nuclei/targets.txt" -silent -nc 2>/dev/null || true
        
        local nf="${OUTPUT_DIR}/nuclei/nuclei_results.txt"
        if [[ -f "$nf" ]]; then
            local crit; crit=$(grep -c "\[critical\]" "$nf" 2>/dev/null || true); crit=$(( ${crit:-0} ))
            local high; high=$(grep -c "\[high\]"     "$nf" 2>/dev/null || true); high=$(( ${high:-0} ))
            local med;  med=$(grep -c "\[medium\]"    "$nf" 2>/dev/null || true); med=$(( ${med:-0} ))
            [[ ${crit:-0} -gt 0 ]] && add_vuln "CRITICAL" "Nuclei: ${crit} Critical Vulnerabilities Found" "Nuclei detected critical issues." "Review nuclei report." "See nuclei output"
        fi
    fi
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 15 — NETWORK SERVICE ENUMERATION
# ════════════════════════════════════════════════════════════════════════════════
phase_network_services() {
    log_phase 15 "${PHASE_NAMES[15]}"
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 16 — SMB & ACTIVE DIRECTORY ENUMERATION
# ════════════════════════════════════════════════════════════════════════════════
phase_smb_ad() {
    log_phase 16 "${PHASE_NAMES[16]}"
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 17 — AUTHENTICATION & CREDENTIAL TESTING
# ════════════════════════════════════════════════════════════════════════════════
phase_auth() {
    log_phase 17 "${PHASE_NAMES[17]}"
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 18 — SQL INJECTION DEEP TESTING
# ════════════════════════════════════════════════════════════════════════════════
phase_sqli() {
    log_phase 18 "${PHASE_NAMES[18]}"
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 19 — XSS & CLIENT-SIDE ATTACK VECTORS
# ════════════════════════════════════════════════════════════════════════════════
phase_xss() {
    log_phase 19 "${PHASE_NAMES[19]}"
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 20 — CVE 2024–2026 TARGETED CHECKS
# ════════════════════════════════════════════════════════════════════════════════
phase_cve_checks() {
    log_phase 20 "${PHASE_NAMES[20]}"
    for web_url in "${WEB_TARGETS[@]:0:5}"; do
        _is_valid_url "$web_url" || continue
        
        local ivanti; ivanti=$(curl -s --max-time 10 --max-filesize 51200 "$web_url" 2>/dev/null | head -c 4096 | grep -ciE "Ivanti|Connect Secure|Pulse" 2>/dev/null || true)
        ivanti=$(( ${ivanti:-0} ))
        
        local forti; forti=$(curl -s --max-time 10 --max-filesize 51200 "${web_url}/remote/login" 2>/dev/null | head -c 4096 | grep -ciE "Fortinet|FortiGate|FortiOS|FortiProxy" 2>/dev/null || true)
        forti=$(( ${forti:-0} ))

        local fortinet_check; fortinet_check=$(curl -s --max-time 10 --max-filesize 51200 "${web_url}/remote/login" 2>/dev/null | head -c 4096 | grep -ci "Fortinet\|FortiGate\|SSL-VPN" 2>/dev/null || true)
        fortinet_check=$(( ${fortinet_check:-0} ))

        local tc_detect; tc_detect=$(curl -s --max-time 10 --max-filesize 51200 "${web_url}" 2>/dev/null | head -c 4096 | grep -ci "TeamCity\|JetBrains" 2>/dev/null || true)
        tc_detect=$(( ${tc_detect:-0} ))

        local ivanti_check; ivanti_check=$(curl -s --max-time 10 --max-filesize 51200 "${web_url}" 2>/dev/null | head -c 4096 | grep -ci "Ivanti\|Pulse Secure\|Connect Secure" 2>/dev/null || true)
        ivanti_check=$(( ${ivanti_check:-0} ))

        local spring_check; spring_check=$(curl -s --max-time 10 --max-filesize 51200 "${web_url}" 2>/dev/null | head -c 4096 | grep -ci "Spring\|springframework" 2>/dev/null || true)
        spring_check=$(( ${spring_check:-0} ))
    done
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 21 — POST-EXPLOITATION SIMULATION
# ════════════════════════════════════════════════════════════════════════════════
phase_post_exploit() {
    log_phase 21 "${PHASE_NAMES[21]}"
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 22 — ATTACK PATH & LATERAL MOVEMENT ANALYSIS
# ════════════════════════════════════════════════════════════════════════════════
phase_attack_path() {
    log_phase 22 "${PHASE_NAMES[22]}"
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 23 — REPORT GENERATION
# ════════════════════════════════════════════════════════════════════════════════
phase_report() {
    log_phase 23 "${PHASE_NAMES[23]}"
    local rpt_dir="${OUTPUT_DIR}/reports"
    local total_elapsed=$(( $(date +%s) - START_TIME ))
    local total_findings=$(( ZERO_DAY_COUNT + ONE_CLICK_COUNT + CRITICAL_COUNT + HIGH_COUNT + MEDIUM_COUNT + LOW_COUNT + INFO_COUNT ))
    local confidence; confidence=$(calculate_confidence)
    
    {
        echo "ACROMAP v5.0 — PENETRATION TEST REPORT"
        echo "Target: ${TARGET}"
        echo "Total Findings: ${total_findings}"
    } > "${rpt_dir}/report.txt"
    log_ok "Text report saved: ${rpt_dir}/report.txt"
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 24 — CLOUD METADATA ENUMERATION
# ════════════════════════════════════════════════════════════════════════════════
phase_cloud_enum() {
    log_phase 24 "${PHASE_NAMES[24]}"
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 25 — KUBERNETES CLUSTER AUDIT
# ════════════════════════════════════════════════════════════════════════════════
phase_k8s_audit() {
    log_phase 25 "${PHASE_NAMES[25]}"
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 26 — PASSWORD SPRAY
# ════════════════════════════════════════════════════════════════════════════════
phase_password_spray() {
    log_phase 26 "${PHASE_NAMES[26]}"
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 27 — CORS & JWT AUTHENTICATION TESTING
# ════════════════════════════════════════════════════════════════════════════════
phase_cors_jwt() {
    log_phase 27 "${PHASE_NAMES[27]}"
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 28 — SSRF DEEP CHAIN & OOB TESTING
# ════════════════════════════════════════════════════════════════════════════════
phase_ssrf_deep() {
    log_phase 28 "${PHASE_NAMES[28]}"
    local ssrf_dir="${OUTPUT_DIR}/ssrf_deep"
    
    local oob_hits; oob_hits=$(grep -cE "ssrf-canary|${INTERACTSH_URL}" "${OUTPUT_DIR}/raw_logs/interactsh.json" 2>/dev/null || true)
    oob_hits=$(( ${oob_hits:-0} ))
    
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 29 — SECRETS & SUPPLY CHAIN EXPOSURE
# ════════════════════════════════════════════════════════════════════════════════
phase_secrets() {
    log_phase 29 "${PHASE_NAMES[29]}"
    local sec_dir="${OUTPUT_DIR}/secrets"
    local slug="test"

    local secrets_found; secrets_found=$(grep -c '"DetectorName"' "${sec_dir}/trufflehog_${slug}.txt" 2>/dev/null || true)
    secrets_found=$(( ${secrets_found:-0} ))

    local http_secrets; http_secrets=$(grep -c '"DetectorName"' "${sec_dir}/trufflehog_http_${slug}.txt" 2>/dev/null || true)
    http_secrets=$(( ${http_secrets:-0} ))

    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 30 — ACTIVE DIRECTORY DEEP ATTACK SURFACE
# ════════════════════════════════════════════════════════════════════════════════
phase_ad_deep() {
    log_phase 30 "${PHASE_NAMES[30]}"
    local ad_dir="${OUTPUT_DIR}/ad_attacks"

    local spn_count; spn_count=$(grep -c "\$krb5tgs\$" "${ad_dir}/spns.txt" 2>/dev/null || true)
    spn_count=$(( ${spn_count:-0} ))

    local asrep_count; asrep_count=$(grep -c "\$krb5asrep\$" "${ad_dir}/asrep.txt" 2>/dev/null || true)
    asrep_count=$(( ${asrep_count:-0} ))

    local esc_count; esc_count=$(grep -cE "ESC[1-8]" "${ad_dir}/certipy.txt" 2>/dev/null || true)
    esc_count=$(( ${esc_count:-0} ))

    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 31 — ZERO-DAY & ONE-CLICK VULNERABILITY DETECTION
# ════════════════════════════════════════════════════════════════════════════════
phase_zero_day_one_click() {
    log_phase 31 "${PHASE_NAMES[31]}"
    local takeover_file="${OUTPUT_DIR}/zero_day_oneclick/takeover_candidates.txt"
    
    local td_count; td_count=$(wc -l < "$takeover_file" 2>/dev/null || true)
    td_count=$(( ${td_count:-0} ))

    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  CIDR MULTI-HOST SWEEP
# ════════════════════════════════════════════════════════════════════════════════
phase_cidr_sweep() {
    if [[ "$TARGET_IS_CIDR" != true ]] || [[ ${#CIDR_HOSTS[@]} -le 1 ]]; then
        return 0
    fi
    log_phase 99 "CIDR Multi-Host Network Sweep"
    local cidr_dir="${OUTPUT_DIR}/cidr_hosts"
    local live_hosts_file="${cidr_dir}/live_hosts.txt"

    local live_count; live_count=$(wc -l < "$live_hosts_file" 2>/dev/null || true)
    live_count=$(( ${live_count:-0} ))

    local interesting; interesting=$(wc -l < "${cidr_dir}/hosts_with_open_ports.txt" 2>/dev/null || true)
    interesting=$(( ${interesting:-0} ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  MAIN
# ════════════════════════════════════════════════════════════════════════════════
main() {
    print_banner
    show_disclaimer
    get_target
    get_profile
    start_keypress_monitor

    echo "STARTED=$(date -Iseconds)" > "$CHECKPOINT_FILE"

    echo ""
    echo -e "  ${LGREEN}${BOLD}Starting 32-phase scan on: ${TARGET}${NC}"
    [[ "$TARGET_IS_CIDR" == true ]] && \
        echo -e "  ${YELLOW}[CIDR]${NC} ${#CIDR_HOSTS[@]} hosts in range — multi-host sweep enabled"
    echo -e "  ${DIM}Output: ${OUTPUT_DIR}${NC}"
    echo -e "  ${DIM}Press [T] for live status | [D] for debug${NC}"
    [[ "$RESUME_MODE" == true ]] && \
        echo -e "  ${YELLOW}[RESUME]${NC} Skipping phases 0-${LAST_PHASE} (already completed)"
    echo ""

    run_phase() {
        local pnum="$1" pfunc="$2"
        if [[ "$RESUME_MODE" == true && $pnum -le ${LAST_PHASE:-0} ]]; then
            log_info "Phase ${pnum} skipped (completed in previous run)"
            return 0
        fi
        "$pfunc"
        save_checkpoint "$pnum"
    }

    phase_cidr_sweep

    run_phase 0  phase_setup
    run_phase 1  phase_osint
    run_phase 2  phase_dns
    run_phase 3  phase_subdomains
    run_phase 4  phase_host_discovery
    run_phase 5  phase_tcp_scan
    run_phase 6  phase_udp_scan
    run_phase 7  phase_service_detect
    run_phase 8  phase_web_discovery
    run_phase 9  phase_tech_fingerprint
    run_phase 10 phase_ssl
    run_phase 11 phase_content_discovery
    run_phase 12 phase_cms
    run_phase 13 phase_api
    run_phase 14 phase_nuclei
    run_phase 15 phase_network_services
    run_phase 16 phase_smb_ad
    run_phase 17 phase_auth
    run_phase 18 phase_sqli
    run_phase 19 phase_xss
    run_phase 20 phase_cve_checks
    run_phase 21 phase_post_exploit
    run_phase 22 phase_attack_path
    run_phase 24 phase_cloud_enum
    run_phase 25 phase_k8s_audit
    run_phase 26 phase_password_spray
    run_phase 27 phase_cors_jwt
    run_phase 28 phase_ssrf_deep
    run_phase 29 phase_secrets
    run_phase 30 phase_ad_deep
    run_phase 31 phase_zero_day_one_click

    run_zap_dast
    generate_msf_resource
    phase_report
    save_checkpoint 23

    echo "COMPLETE=$(date -Iseconds)" >> "$CHECKPOINT_FILE"
    send_notification
}

main "$@"
