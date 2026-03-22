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
