# 🔥 ACROMAP v5.0 — Major Update

> 32-Phase automated deep penetration testing framework for Kali Linux.
> This release ships significant engine rewrites, a new parallel recon system, live spinner UI, and integrity protection.

---

## ⚡ What's New

### Parallel Recon Engine (Phases 1–3)
OSINT, DNS Enumeration, and Subdomain discovery now execute **simultaneously** in background jobs. An IPC file safely syncs all findings back into the parent scan state. Early recon is now up to **3x faster**.

### 🌀 Live Braille Spinner
Every tool run now shows a real-time animated spinner (`⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏`) with elapsed time. No more blank terminal during long scans.

### 🔒 Source Integrity Guard
`_acro_guard()` verifies attribution before execution. Stripped or tampered copies refuse to run and redirect to the original repository.

### 🖥️ Improved Auto-Escalation
Privilege chain now tries `sudo` first, then falls back to `su root` for environments without `sudo`. Script auto-`chmod +x`s itself after elevation.

### 🎨 Cyber-Noir Phase Display
Phase boundaries now show a rich terminal UI with current phase (XX/32), phase name, active target, and live **Critical / High** finding counters.

### 🛡️ Interrupt & Terminal Safety
Clean `Ctrl+C` handling via `_ACROMAP_INTERRUPTED` flag. `stty sane` resets prevent terminal corruption. Spinner and keypress code properly guards non-TTY environments.

### 🔗 URL Validation
Internal `_is_valid_url()` prevents malformed URLs reaching web-phase tools.

### 🏷️ New Runtime Flags
- `WILDCARD_DNS` — auto-detected; suppresses false-positive subdomains
- `_TF_SCAN_DONE` — prevents duplicate TruffleHog filesystem scans
- `PARALLEL_EXECUTION_ACTIVE` — switches tool wrappers to parallel-safe output mode

---

## 🐛 Bug Fixes

- Fixed `wc -l` arithmetic errors causing phase-skip logic to fail on empty files
- Fixed `EUID` unbound variable crash on certain Debian configurations
- Fixed terminal state corruption after interrupted spinner during parallel phases
- Fixed masscan CIDR output path collision with `run_tool_timeout` stdout capture
- Fixed `add_vuln` not writing to IPC file during parallel subshell execution

---

## 📋 Requirements

- Kali Linux (primary) / Debian / Ubuntu
- Run as root: `sudo bash acromap.sh`
- See [README](README.md) for full tool list

---

## ⚖️ Legal

For authorized penetration testing only. See [LICENSE](LICENSE).

---

**Full changelog and documentation:** [README.md](README.md)
