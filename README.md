<div align="center">

<img src="banner.svg" alt="ACROMAP Banner" width="100%"/>

**ACROMAP v5.0 — 32-Phase Hardened Penetration Testing Framework**

[![Platform](https://img.shields.io/badge/Platform-Kali%20Linux-blue?style=flat-square&logo=linux)](https://www.kali.org/)
[![Shell](https://img.shields.io/badge/Shell-Bash-green?style=flat-square&logo=gnu-bash)](https://www.gnu.org/software/bash/)
[![Version](https://img.shields.io/badge/Version-5.0--Hardened-red?style=flat-square)](https://github.com/acro777x/acromap/releases)
[![License](https://img.shields.io/badge/License-MIT-yellow?style=flat-square)](LICENSE)
[![CVE Coverage](https://img.shields.io/badge/CVEs-2019–2026-orange?style=flat-square)](https://cve.mitre.org/)
[![Ethical Use](https://img.shields.io/badge/Use-Authorized%20Only-critical?style=flat-square)](#legal-disclaimer)

*Built for penetration testers who demand mathematical certainty and WAF-resilient results.*

</div>

---

## 📖 Table of Contents

- [Overview](#-overview)
- [What's New in v5.0 (Hardened Edition)](#-whats-new-in-v50-hardened-edition)
- [The 6-Layer Hardening Stack](#-the-6-layer-hardening-stack)
- [32-Phase Architecture](#-32-phase-architecture)
- [Requirements](#-requirements)
- [Installation](#-installation)
- [Usage](#-usage)
- [Output Structure](#-output-structure)
- [Legal Disclaimer](#-legal-disclaimer)
- [Author](#-author)

---

## 🔍 Overview

**ACROMAP v5.0** is a fully automated, root-level penetration testing framework. Unlike traditional scanners that rely on heuristic "grepping" of text output, the v5.0 **Hardened Edition** implements **Aristotelian Logic Proofs** to ensure that every finding is behaviorally confirmed and every failure is explicitly documented.

Designed for **Kali Linux**, ACROMAP auto-escalates privileges, parallelizes recon, and maintains scan checkpoints for resume support.

---

## 🆕 What's New in v5.0 (Hardened Edition)

### 🛡️ Aristotelian "Explicit State Degradation"
Legacy scanners fail silently when blinded by a WAF. ACROMAP v5.0 introduces **Sensor Layer Degradation**. Our new Python engines (`nmap_parser.py`, `web_parser.py`) detect when a WAF has injected garbage into scan results and explicitly signal the dispatcher. **The state becomes `UNKNOWN`, never "Secure by Error."**

### 📐 Arithmetic Hardening (The 10#0 Paradigm)
Eliminated all bash-arithmetic crashes. Every calculation (latency, port counts, finding tabulations) now uses base-10 forced evaluation. This ensures immunity to octal collisions (e.g., `08`, `09`), null-variable crashes, and malformed tool outputs.

### 🧬 Deterministic Behavioral Proofing
Moved beyond simple status-code checking. Vulnerabilities are now confirmed via:
- **Differential Boolean Analysis:** (SQLi) Comparing Baseline vs True vs False responses.
- **Safe Execution Loops:** (Webshells) Reflecting unique MD5-hashed tokens in execution.
- **Asynchronous OOB Polling:** (XSS/SSRF) A 9-second centralized polling window for DNS/LDAP callbacks.

---

## 🏗️ The 6-Layer Hardening Stack

1.  **Memory-Resident State Engine:** Zero-disk state transfer via a secure memory bridge between pre-flight and execution phases.
2.  **Structured Data Engines:** Deterministic XML/JSON parsing for Nmap, WhatWeb, and Wafw00f with explicit degradation guards.
3.  **Explicit State Degradation:** The framework never "fails silently." If a scanner is blinded by a WAF, it is explicitly logged as `UNKNOWN`.
4.  **Behavioral Proofing:** Vulnerabilities are confirmed via active loops (OOB callbacks, differential analysis) rather than simple status codes.
5.  **Arithmetic Hardening:** Every calculation uses the `10#0` paradigm, ensuring immunity to octal collisions and null-variable crashes.
6.  **OOB Verification Engine:** Centralized asynchronous polling for XSS, SSRF, and Log4Shell callbacks.

---

## 🗂️ 32-Phase Architecture

```
Phase 00 ── Setup & Tool Verification
Phase 01 ── Passive OSINT Reconnaissance
Phase 02 ── DNS Enumeration & Zone Transfer
Phase 03 ── Subdomain Enumeration (Deep)
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
Phase 23 ── Report Generation
Phase 24–31 ── Cloud, K8s, Secrets, and Zero-Day Detection
```

---

## 📋 Requirements

- **Operating System:** Kali Linux (Primary) / Debian / Ubuntu
- **Privileges:** Root (auto-escalates)
- **Dependencies:** `bash`, `python3`, `curl`, `jq`, `anew`, `nmap`, `nuclei`

---

## 🔧 Installation

```bash
git clone https://github.com/acro777x/acromap.git
cd acromap
chmod +x acromap.sh
```

---

## 🚀 Usage

### 1. Pre-Flight Calibration
Sets up the memory bridge and calculates the WAF interference threshold.
```bash
sudo ./preflight.sh <target>
```

### 2. Integrity Check
Verify the mathematical and logical integrity of your local installation:
```bash
bash qa_harness.sh
```

### 3. Execute Scan
```bash
sudo bash acromap.sh <target>
```

### Live Keypress Controls

| Key | Action |
|-----|--------|
| `T` | Print real-time status (phase, tool, ETA, findings) |
| `D` | Toggle debug output on/off |
| `Ctrl+C` | Graceful interrupt — saves checkpoint for resume |

---

## 📂 Output Structure

```
acromap_repo/
├── acromap.sh           # Main Hardened Engine
├── preflight.sh         # Memory Bridge & Calibration
├── nmap_parser.py       # XML Structured Sensor (Explicit Degradation)
├── web_parser.py        # JSON Structured Sensor (WAF-Garbage Stripping)
├── qa_harness.sh        # Aristotelian Integrity Suite
└── README.md            # Hardened Documentation
```

---

## ⚖️ Legal Disclaimer

Authorized use only. Unauthorized use is illegal. The author bears no responsibility for illegal or malicious use. By running this tool you accept full legal responsibility for your actions.

---

## 👤 Author

**acro777x**  
GitHub: [https://github.com/acro777x](https://github.com/acro777x)

---

<div align="center">

*ACROMAP v5.0 — Scan smarter. Prove it.*

</div>
