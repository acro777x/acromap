<div align="center">

<img src="banner.svg" alt="ACROMAP Banner" width="100%"/>

**ACROMAP v5.0 — 32-Phase Deep Penetration Testing Framework**

[![Platform](https://img.shields.io/badge/Platform-Kali%20Linux-blue?style=flat-square&logo=linux)](https://www.kali.org/)
[![Shell](https://img.shields.io/badge/Shell-Bash-green?style=flat-square&logo=gnu-bash)](https://www.gnu.org/software/bash/)
[![Version](https://img.shields.io/badge/Version-5.0-red?style=flat-square)](https://github.com/acro777x/acromap/releases)
[![License](https://img.shields.io/badge/License-MIT-yellow?style=flat-square)](LICENSE)
[![CVE Coverage](https://img.shields.io/badge/CVEs-2019–2026-orange?style=flat-square)](https://cve.mitre.org/)
[![Ethical Use](https://img.shields.io/badge/Use-Authorized%20Only-critical?style=flat-square)](#legal-disclaimer)

*Built for penetration testers, red teamers, CTF players, and security researchers.*

</div>

---

## 📖 Table of Contents

- [Overview](#-overview)
- [What's New in v5.0](#-whats-new-in-v50)
- [Features](#-features)
- [32-Phase Architecture](#-32-phase-architecture)
- [Requirements](#-requirements)
- [Installation](#-installation)
- [Usage](#-usage)
- [Scan Profiles](#-scan-profiles)
- [Output Structure](#-output-structure)
- [Vulnerability Severity Levels](#-vulnerability-severity-levels)
- [Notification Integrations](#-notification-integrations)
- [Resume & Checkpoint System](#-resume--checkpoint-system)
- [Legal Disclaimer](#-legal-disclaimer)
- [Author](#-author)

---

## 🔍 Overview

**ACROMAP v5.0** is a fully automated, root-level penetration testing framework written in Bash. It chains **32 sequential phases** — from passive OSINT reconnaissance through active exploitation simulation, cloud misconfiguration auditing, Active Directory deep dives, and zero-day pattern detection — into a single command.

Designed for **Kali Linux** (Debian/Ubuntu compatible), ACROMAP auto-escalates privileges, parallelizes early recon phases for speed, shows a live braille spinner during every tool run, maintains scan checkpoints for resume support, and pushes real-time Slack/email alerts on critical findings.

> **Supported targets:** Single IP · Domain Name · CIDR Range

---

## 🆕 What's New in v5.0

### ⚡ Parallel Recon Engine (Phases 1–3)
OSINT, DNS Enumeration, and Subdomain discovery now run **simultaneously** in background jobs, cutting early recon time by up to 3x. An IPC file (`vuln_ipc.txt`) safely syncs findings across subshells back into the parent process.

### 🌀 Live Braille Spinner
Every tool execution now shows a real-time animated braille spinner (`⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏`) with elapsed time — no more staring at a blank terminal wondering if the scan is still running.

### 🔒 Source Integrity Guard
A built-in `_acro_guard()` function verifies that the script's attribution and repository reference are intact before execution. If the file has been stripped of attribution, the tool refuses to run and points back to the original source.

### 🖥️ Improved Auto-Escalation
The privilege escalation chain now supports both `sudo` and `su` as fallbacks — covering environments where `sudo` is not installed. The script also self-`chmod +x`s after elevation for future runs.

### 🎨 Cyber-Noir Phase Display
Each phase boundary now renders a rich terminal UI showing the current phase number (out of 32), phase name, active target, and live **Critical / High** finding counts — updated at every phase transition.

### 🛡️ Interrupt & Terminal Safety
`_ACROMAP_INTERRUPTED` flag enables clean Ctrl+C handling mid-tool. All spinner and keypress code now guards against non-TTY environments with proper `stty sane` resets, preventing terminal corruption.

### 🔗 URL Validation Helper
Internal `_is_valid_url()` guard prevents malformed URLs from being passed to web-phase tools, reducing false tool failures on edge-case targets.

### 🏷️ Additional Runtime Flags
- `WILDCARD_DNS` — detected automatically; suppresses false-positive subdomain results
- `_TF_SCAN_DONE` — prevents duplicate TruffleHog filesystem scans across phases
- `PARALLEL_EXECUTION_ACTIVE` — global flag that switches tool wrappers to parallel-safe output mode

---

## ✨ Features

| Feature | Description |
|---|---|
| ⚡ **Parallel Recon** | Phases 1–3 run simultaneously — OSINT, DNS, Subdomains in parallel |
| 🌀 **Live Braille Spinner** | Animated progress indicator on every tool run with elapsed time |
| 🔄 **32-Phase Engine** | Fully automated recon-to-report pipeline |
| 🔒 **Source Integrity Guard** | Refuses to run if attribution has been stripped |
| 🎯 **3 Scan Profiles** | `quick` / `standard` / `deep` with per-phase timeout tuning |
| 📡 **CIDR Sweep Mode** | Ping sweep + nmap + masscan across entire network ranges |
| 🔔 **Live Notifications** | Instant push on CRITICAL/HIGH/ZERO-DAY findings via Slack or email |
| 💾 **Checkpoint & Resume** | Interrupted scans resume from the last completed phase |
| 📊 **Confidence Scoring** | Auto-calculated 0–10 score based on tool success, depth, and findings |
| 🕵️ **Zero-Day Detection** | Heuristic pattern matching for zero-day and one-click exploit surfaces |
| ☁️ **Cloud & K8s Auditing** | AWS/GCP/Azure metadata enum + Kubernetes cluster security audit |
| 🏢 **AD Deep Attack Surface** | Active Directory enumeration and lateral movement path analysis |
| 🧵 **GNU Parallel Support** | Multi-job throughput when `parallel` is available |
| 📡 **OOB Testing** | Interactsh integration for blind SSRF and OOB callback detection |
| 🔑 **Secrets Detection** | TruffleHog + gitleaks for supply chain and secrets exposure |

---

## 🗂️ 32-Phase Architecture

```
Phase 00 ── Setup & Tool Verification
Phase 01 ── Passive OSINT Reconnaissance          ┐
Phase 02 ── DNS Enumeration & Zone Transfer       ├─ Parallelized
Phase 03 ── Subdomain Enumeration (Deep)          ┘
Phase 04 ── Network Discovery & Host Detection
Phase 05 ── Full TCP Port Scanning
Phase 06 ── UDP Port Scanning
Phase 07 ── Service Detection & Banner Grabbing
Phase 08 ── Web Discovery & HTTP Probing
Phase 09 ── Web Technology Fingerprinting
Phase 10 ── SSL/TLS Deep Analysis
Phase 11 ── Web Content Discovery & Fuzzing
Phase 12 ── CMS Detection & Deep Scanning
Phase 13 ── API Endpoint Discovery
Phase 14 ── Nuclei Full Vulnerability Scan
Phase 15 ── Network Service Enumeration
Phase 16 ── SMB & Active Directory Enumeration
Phase 17 ── Authentication & Credential Testing
Phase 18 ── SQL Injection Deep Testing
Phase 19 ── XSS & Client-Side Attack Vectors
Phase 20 ── CVE 2024–2026 Targeted Checks
Phase 21 ── Post-Exploitation Simulation
Phase 22 ── Attack Path & Lateral Movement Analysis
Phase 23 ── Report Generation  (always last)
Phase 24 ── Cloud Metadata & Misconfiguration Enum
Phase 25 ── Kubernetes Cluster Audit
Phase 26 ── Password Spray & Credential Attacks
Phase 27 ── CORS & JWT Authentication Testing
Phase 28 ── SSRF Deep Chain & OOB Testing
Phase 29 ── Secrets & Supply Chain Exposure
Phase 30 ── Active Directory Deep Attack Surface
Phase 31 ── Zero-Day & One-Click Exploit Detection
```

---

## 📋 Requirements

### Operating System
- **Primary:** Kali Linux
- **Compatible:** Debian / Ubuntu

### Root Privileges
ACROMAP auto-escalates on launch. It tries `sudo` first, then falls back to `su root`. For best results run directly as root.

```bash
sudo bash acromap.sh
```

### Tools (auto-detected — missing tools are skipped gracefully)

**Recon & OSINT** — `whois`, `dig`, `theHarvester`, `amass`, `subfinder`, `assetfinder`, `dnsx`, `massdns`

**Network Scanning** — `nmap`, `masscan`, `netcat`

**Web** — `httpx`, `whatweb`, `wafw00f`, `ffuf`, `gobuster`, `feroxbuster`, `wpscan`, `nikto`, `nuclei`

**Exploitation** — `sqlmap`, `dalfox`, `hydra`, `medusa`, `crackmapexec`, `metasploit-framework`

**Cloud & Identity** — `aws`, `gcloud`, `az`, `kubectl`

**Secrets** — `trufflehog`, `gitleaks`

**Utilities** — `jq`, `anew`, `notify`, `interactsh-client`, `parallel`

**Optional DAST** — OWASP ZAP (auto-detected if daemon is running)

---

## 🔧 Installation

```bash
# Clone the repository
git clone https://github.com/acro777x/acromap.git
cd acromap

# Make executable
chmod +x acromap.sh

# Install core tools on Kali (recommended)
sudo apt update && sudo apt install -y \
  nmap masscan amass subfinder \
  httpx-toolkit nuclei ffuf gobuster \
  nikto sqlmap dalfox hydra \
  crackmapexec wpscan jq
```

> The script will `chmod +x` itself automatically after first root escalation.

---

## 🚀 Usage

```bash
# Standard run — recommended
sudo bash acromap.sh

# Resume an interrupted scan
sudo bash acromap.sh --resume
```

You will be prompted interactively for:

1. **Target** — IP address, domain name, or CIDR range (e.g. `192.168.1.0/24`)
2. **Scan Profile** — `quick` / `standard` / `deep`

### Live Keypress Controls

| Key | Action |
|-----|--------|
| `T` | Print real-time status (phase, tool, ETA, findings so far) |
| `D` | Toggle debug output on/off |
| `Ctrl+C` | Graceful interrupt — saves checkpoint for resume |

---

## ⚡ Scan Profiles

| Profile | Timeout Depth | Best For | Approx Duration |
|---------|--------------|----------|----------------|
| `quick` | Short | Initial triage, fast surface scan | ~15–30 min |
| `standard` | Balanced | Default, most engagements | ~1–3 hours |
| `deep` | Extended | Full assessment, bug bounty, red team | ~4–8+ hours |

---

## 📂 Output Structure

```
acromap_<target>_<timestamp>/
├── acromap.log                   # Full timestamped run log
├── checkpoint.txt                # Resume state (last completed phase)
├── vuln_ipc.txt                  # IPC file for parallel phase sync
├── report/
│   └── acromap_report.txt        # Final structured report
├── osint/                        # Phase 01 results
├── dns/                          # Phase 02 results
├── subdomains/
│   ├── all_subdomains.txt
│   ├── live_subdomains.txt
│   └── takeover_candidates.txt
├── ports/                        # TCP/UDP scan results
├── services/                     # Banner grabs
├── web/                          # Web discovery, CMS, API
├── vulns/                        # Nuclei findings
├── smb/                          # SMB & AD enumeration
├── cloud/                        # Cloud metadata
├── k8s/                          # Kubernetes audit
├── secrets/                      # TruffleHog / gitleaks output
├── ad/                           # Active Directory deep results
├── cidr_hosts/                   # CIDR sweep (if CIDR target)
└── msf_resource.rc               # Auto-generated Metasploit resource script
```

---

## 🚨 Vulnerability Severity Levels

| Severity | Colour | Description |
|----------|--------|-------------|
| 🟣 `ZERO_DAY` | Blinking Magenta | Unpatched / zero-day pattern detected |
| 🔴 `ONE_CLICK` | Underline Red | Single-action exploitable (e.g. subdomain takeover, RCE) |
| 🔴 `CRITICAL` | Red | Immediate exploitation risk |
| 🟠 `HIGH` | Orange | High-impact, readily exploitable |
| 🟡 `MEDIUM` | Yellow | Moderate risk, requires chaining |
| 🔵 `LOW` | Cyan | Low severity / defence-in-depth gap |
| ⚪ `INFO` | White | Informational |

A **Confidence Score (0.0–10.0)** is computed at the end based on tool success rate, scan profile depth, phases completed, and finding data quality.

---

## 🔔 Notification Integrations

```bash
# Slack webhook — set before running
export SLACK_WEBHOOK="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

# Email notification
export NOTIFY_EMAIL_ADDR="you@example.com"

# Push every CRITICAL/HIGH finding instantly (requires projectdiscovery/notify)
export NOTIFY_PER_FINDING=true
export NOTIFY_CHANNEL="slack"    # slack | discord | telegram
```

---

## 💾 Resume & Checkpoint System

```bash
# If a scan is interrupted, resume it from the last completed phase
sudo bash acromap.sh --resume
```

A `checkpoint.txt` file is written after every phase. On resume, all completed phases are skipped automatically. The parallel recon block (phases 1–3) is treated as a single checkpoint unit.

---

## ⚖️ Legal Disclaimer

This tool is released **free and open source** for the security community. It is intended **solely** for:

- Authorized penetration testing on systems you **own or have explicit written permission** to test
- CTF / lab environments (TryHackMe, HackTheBox, GBU CSPL)
- Academic and educational security research

**Unauthorized use is illegal** under the Computer Fraud and Abuse Act (CFAA), UK Computer Misuse Act, IT Act 2000 (India), and equivalent laws worldwide. The author bears **no responsibility** for illegal or malicious use. By running this tool you accept **full legal responsibility** for your actions.

---

## 👤 Author

**acro777x**
GitHub: [https://github.com/acro777x](https://github.com/acro777x)

---

<div align="center">

*ACROMAP v5.0 — Scan smarter. Report faster. Hack ethically.*

</div>

*Built for penetration testers, red teamers, CTF players, and security researchers.*

</div>

---

## 📖 Table of Contents

- [Overview](#-overview)
- [Features](#-features)
- [30-Phase Architecture](#-30-phase-architecture)
- [Requirements](#-requirements)
- [Installation](#-installation)
- [Usage](#-usage)
- [Scan Profiles](#-scan-profiles)
- [Output Structure](#-output-structure)
- [Vulnerability Severity Levels](#-vulnerability-severity-levels)
- [Notification Integrations](#-notification-integrations)
- [Resume & Checkpoint System](#-resume--checkpoint-system)
- [Legal Disclaimer](#-legal-disclaimer)
- [Author](#-author)

---

## 🔍 Overview

**ACROMAP v5.0** is a comprehensive, fully automated penetration testing framework written in Bash. It orchestrates 30+ industry-standard security tools across **32 sequential phases** — from passive OSINT all the way through active exploitation simulation, cloud misconfiguration audits, Active Directory attacks, and zero-day pattern detection.

Designed for use on **Kali Linux** (with Debian/Ubuntu support), ACROMAP produces structured reports, maintains real-time vulnerability counters, supports scan resumption via checkpoints, and delivers instant Slack/email notifications on critical findings.

> **Target types supported:** Single IP · Domain · CIDR Range

---

## ✨ Features

| Feature | Description |
|---|---|
| 🔄 **32-Phase Engine** | Fully sequential, automated recon-to-report pipeline |
| 🎯 **3 Scan Profiles** | `quick`, `standard`, `deep` — adapts tool timeout per phase |
| 📡 **CIDR Sweep Mode** | Expands CIDR ranges, ping sweeps, and runs nmap + masscan across all live hosts |
| 🔔 **Live Notifications** | Instant push on CRITICAL/HIGH findings via Slack webhook or email |
| 💾 **Checkpoint & Resume** | Interrupted scans can be resumed from the last completed phase |
| 📊 **Auto Report Generation** | Structured terminal + file report with confidence scoring (0–10) |
| 🕵️ **Zero-Day Detection** | Pattern-based heuristics for zero-day and one-click exploit surfaces |
| ☁️ **Cloud & K8s Auditing** | AWS, GCP, Azure metadata enumeration + Kubernetes cluster auditing |
| 🔑 **AD Attack Surface** | Active Directory deep enumeration and attack path analysis |
| 🧵 **Parallel Execution** | Uses GNU Parallel when available for multi-job throughput |
| 🔊 **Live Keypress Monitor** | Press `[T]` for live status · `[D]` to toggle debug mode mid-scan |
| 📡 **OOB Testing** | Interactsh integration for blind SSRF/OOB callback detection |
| 🗂️ **Structured Output** | All results saved per-phase into organized output directories |

---

## 🗂️ 30-Phase Architecture

```
Phase 00 — Setup & Tool Verification
Phase 01 — Passive OSINT Reconnaissance
Phase 02 — DNS Enumeration & Zone Transfer
Phase 03 — Subdomain Enumeration (Deep)
Phase 04 — Network Discovery & Host Detection
Phase 05 — Full TCP Port Scanning
Phase 06 — UDP Port Scanning
Phase 07 — Service Detection & Banner Grabbing
Phase 08 — Web Discovery & HTTP Probing
Phase 09 — Web Technology Fingerprinting
Phase 10 — SSL/TLS Deep Analysis
Phase 11 — Web Content Discovery & Fuzzing
Phase 12 — CMS Detection & Deep Scanning
Phase 13 — API Endpoint Discovery
Phase 14 — Nuclei Full Vulnerability Scan
Phase 15 — Network Service Enumeration
Phase 16 — SMB & Active Directory Enumeration
Phase 17 — Authentication & Credential Testing
Phase 18 — SQL Injection Deep Testing
Phase 19 — XSS & Client-Side Attack Vectors
Phase 20 — CVE 2024–2026 Targeted Checks
Phase 21 — Post-Exploitation Simulation
Phase 22 — Attack Path & Lateral Movement Analysis
Phase 23 — Report Generation
Phase 24 — Cloud Metadata & Misconfiguration Enum
Phase 25 — Kubernetes Cluster Audit
Phase 26 — Password Spray & Credential Attacks
Phase 27 — CORS & JWT Authentication Testing
Phase 28 — SSRF Deep Chain & OOB Testing
Phase 29 — Secrets & Supply Chain Exposure
Phase 30 — Active Directory Deep Attack Surface
Phase 31 — Zero-Day & One-Click Exploit Detection
```

---

## 📋 Requirements

### Operating System
- **Primary:** Kali Linux (fully tested)
- **Compatible:** Debian / Ubuntu

### Minimum Tools (auto-detected at Phase 0)
The framework gracefully skips any tool that is not installed. For full coverage, ensure the following are available:

**Recon & OSINT**
- `whois`, `dig`, `host`, `nslookup`
- `theHarvester`, `amass`, `subfinder`, `assetfinder`
- `dnsx`, `massdns`

**Network Scanning**
- `nmap`, `masscan`
- `netcat` (`nc`), `curl`, `wget`

**Web**
- `httpx`, `whatweb`, `wafw00f`
- `ffuf`, `gobuster`, `feroxbuster`
- `wpscan`, `droopescan`, `nikto`
- `nuclei` (with up-to-date templates)

**Exploitation & Post-Exploitation**
- `sqlmap`, `dalfox`
- `hydra`, `medusa`, `crackmapexec`
- `metasploit-framework` (optional, for resource script generation)
- `zaproxy` / OWASP ZAP (optional DAST integration)

**Cloud & Identity**
- `aws` CLI, `gcloud`, `az`
- `kubectl`
- `trufflehog`, `gitleaks`

**Utilities**
- `jq`, `anew`, `notify`
- `interactsh-client` (OOB testing)
- `parallel` (GNU Parallel)

---

## 🔧 Installation

```bash
# Clone the repository
git clone https://github.com/acro777x/acromap.git
cd acromap

# Make executable
chmod +x acromap.sh

# (Optional) Install commonly required tools on Kali
sudo apt update && sudo apt install -y \
  nmap masscan amass subfinder httpx-toolkit \
  nuclei ffuf gobuster nikto sqlmap dalfox \
  hydra crackmapexec wpscan jq
```

> **Tip:** Run `sudo bash acromap.sh` for full capability. Many scan phases (SYN scan, masscan, raw sockets) require root privileges. The script will auto-escalate via `sudo` if not already root.

---

## 🚀 Usage

```bash
# Standard interactive run (recommended)
sudo bash acromap.sh

# Resume an interrupted scan
sudo bash acromap.sh --resume

# You will be prompted for:
#   [1] Target  → IP address, domain, or CIDR range (e.g. 10.0.0.0/24)
#   [2] Profile → quick | standard | deep
```

### Interactive Controls During Scan

| Key | Action |
|-----|--------|
| `T` | Show real-time status (current phase, tool, ETA) |
| `D` | Toggle debug output on/off |

---

## ⚡ Scan Profiles

| Profile | Description | Typical Duration |
|---------|-------------|-----------------|
| `quick` | Fast pass — short timeouts, top ports only | ~15–30 min |
| `standard` | Balanced — default timeouts, full port range | ~1–3 hours |
| `deep` | Thorough — extended timeouts, aggressive fuzzing | ~4–8+ hours |

> Phase timeouts are individually tuned per profile. For example, subdomain enumeration gets 60s (quick), 180s (standard), or 600s (deep).

---

## 📂 Output Structure

```
acromap_<target>_<timestamp>/
├── acromap.log               # Full timestamped log
├── checkpoint.txt            # Resume state
├── report/
│   ├── acromap_report.txt    # Terminal-style report
│   └── acromap_report.html   # (if supported)
├── osint/                    # Phase 1 — OSINT results
├── dns/                      # Phase 2 — DNS enumeration
├── subdomains/               # Phase 3 — Subdomain lists + takeover candidates
├── ports/                    # Phases 5–6 — TCP/UDP scan results
├── services/                 # Phase 7 — Banner grabs
├── web/                      # Phases 8–13 — Web discovery, CMS, API
├── vulns/                    # Phase 14 — Nuclei findings
├── smb/                      # Phase 16 — SMB/AD results
├── cloud/                    # Phase 24 — Cloud metadata
├── k8s/                      # Phase 25 — Kubernetes audit
├── secrets/                  # Phase 29 — Leaked secrets
├── ad/                       # Phase 30 — Active Directory
├── cidr_hosts/               # CIDR sweep results (if CIDR target)
└── msf_resource.rc           # Metasploit resource script
```

---

## 🚨 Vulnerability Severity Levels

ACROMAP classifies findings across **7 severity tiers:**

| Severity | Description |
|----------|-------------|
| 🟣 `ZERO_DAY` | Unpatched / zero-day pattern detected |
| 🔴 `ONE_CLICK` | Exploitable with a single action (e.g. subdomain takeover, RCE) |
| 🔴 `CRITICAL` | Immediate exploitation risk |
| 🟠 `HIGH` | High-impact vulnerability |
| 🟡 `MEDIUM` | Moderate risk, requires chaining |
| 🔵 `LOW` | Low severity / defense-in-depth |
| ⚪ `INFO` | Informational finding |

A **Confidence Score (0.0–10.0)** is computed at the end of each scan based on: tool success rate, scan profile depth, phases completed, and finding data quality.

---

## 🔔 Notification Integrations

ACROMAP v5.0 supports real-time notifications:

**Slack Webhook**
```bash
# Set before running:
export SLACK_WEBHOOK="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
```

**Email**
```bash
export NOTIFY_EMAIL_ADDR="you@example.com"
```

**Per-Finding Push (CRITICAL/HIGH only)**
```bash
export NOTIFY_PER_FINDING=true
export NOTIFY_CHANNEL="slack"  # or discord / telegram
```

> Requires the [notify](https://github.com/projectdiscovery/notify) tool from ProjectDiscovery.

---

## 💾 Resume & Checkpoint System

If a scan is interrupted (e.g. network drop, manual stop), ACROMAP saves a checkpoint after each completed phase:

```bash
# Resume from last completed phase
sudo bash acromap.sh --resume
```

The checkpoint file (`checkpoint.txt`) stores the last completed phase number. Phases already completed will be skipped automatically.

---

## ⚖️ Legal Disclaimer

> **This tool is released FREE and OPEN SOURCE for the security community.**
>
> It is intended **SOLELY** for:
> - Authorized penetration testing on systems you **OWN or have explicit written permission** to test
> - CTF / lab environments (TryHackMe, HackTheBox, etc.)
> - Academic and educational research
>
> **Unauthorized scanning of systems you do not own is ILLEGAL** under the Computer Fraud and Abuse Act (CFAA), UK Computer Misuse Act, IT Act 2000 (India), and equivalent laws worldwide.
>
> The author (**acro777x**) bears **absolutely no responsibility** for any illegal, unethical, or malicious use of this tool. By running this tool you accept **full legal responsibility** for your actions.

---

## 👤 Author

**acro777x**  
GitHub: [https://github.com/acro777x](https://github.com/acro777x)

---

<div align="center">

*ACROMAP v5.0 — Scan smarter. Report faster. Hack ethically.*

</div>
