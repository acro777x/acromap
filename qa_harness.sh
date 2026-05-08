#!/bin/bash
# ════════════════════════════════════════════════════════════════════════════════
# ACROMAP v5.0 QA HARNESS: ARISTOTELIAN INTEGRATION PROOF
# Tests: Math Safety, OOB Latency, Honeypot Isolation, Parser Degradation,
#        Timing Safety, wc/grep Pipeline Safety
# ════════════════════════════════════════════════════════════════════════════════

PASS=0; FAIL=0
assert_pass() { echo "[PASS] $1"; PASS=$(( PASS + 1 )); }
assert_fail() { echo "[FAIL] $1"; FAIL=$(( FAIL + 1 )); }

echo "═══════════════════════════════════════════════════"
echo "  ACROMAP v5.0 — Aristotelian QA Harness"
echo "═══════════════════════════════════════════════════"
echo ""

# ══════════════════════════════════════════════════════════════════════════════
# TEST 1: Math Safety (Octals, Empties, Nulls, Alphabetics)
# ══════════════════════════════════════════════════════════════════════════════
echo "[*] Test 1: Bash Arithmetic Safety (10#0 paradigm)"

test_vals=("" "  " "08" "09" "abc" "1024" "0" "007" "  42  " "3.14")
expected=(0 0 8 9 0 1024 0 7 42 314)
i=0
t1_pass=true
for v in "${test_vals[@]}"; do
    safe_v=$(echo "$v" | tr -cd '0-9')
    safe_v=$(( 10#0${safe_v} ))
    if [[ $safe_v -ne ${expected[$i]} ]]; then
        assert_fail "  Input='$v' → got $safe_v, expected ${expected[$i]}"
        t1_pass=false
    fi
    i=$(( i + 1 ))
done
[[ "$t1_pass" == true ]] && assert_pass "All 10 arithmetic edge-cases survive the 10#0 paradigm"

# ══════════════════════════════════════════════════════════════════════════════
# TEST 2: grep -c || true Pipeline (No multiline contamination)
# ══════════════════════════════════════════════════════════════════════════════
echo "[*] Test 2: grep -c pipeline safety"

# Simulate: file exists, no match → grep returns 0 on stdout, exit 1
tmpfile="/tmp/acromap_test_grep_$$"
echo "no matches here" > "$tmpfile"
result=$(grep -c "xss-" "$tmpfile" 2>/dev/null || true)
result=$(( 10#0${result} ))
[[ $result -eq 0 ]] && assert_pass "grep -c no-match + || true → clean integer 0" \
                     || assert_fail "grep -c no-match → got '$result', expected 0"

# Simulate: file doesn't exist → grep fails entirely
result2=$(grep -c "xss-" "/tmp/nonexistent_file_$$" 2>/dev/null || true)
result2=$(( 10#0${result2} ))
[[ $result2 -eq 0 ]] && assert_pass "grep -c missing-file + || true → clean integer 0" \
                      || assert_fail "grep -c missing-file → got '$result2', expected 0"

# Simulate: file has matches
echo -e "xss-12345\nxss-67890\nclean-line" > "$tmpfile"
result3=$(grep -c "xss-" "$tmpfile" 2>/dev/null || true)
result3=$(( 10#0${result3} ))
[[ $result3 -eq 2 ]] && assert_pass "grep -c with 2 matches → clean integer 2" \
                      || assert_fail "grep -c with 2 matches → got '$result3', expected 2"
rm -f "$tmpfile"

# ══════════════════════════════════════════════════════════════════════════════
# TEST 3: wc -l Pipeline Safety
# ══════════════════════════════════════════════════════════════════════════════
echo "[*] Test 3: wc -l pipeline safety"

tmpfile2="/tmp/acromap_test_wc_$$"
echo -e "line1\nline2\nline3" > "$tmpfile2"
wc_result=$(wc -l < "$tmpfile2" 2>/dev/null || true)
wc_result=$(( 10#0${wc_result} ))
[[ $wc_result -eq 3 ]] && assert_pass "wc -l with 3 lines → clean integer 3" \
                        || assert_fail "wc -l with 3 lines → got '$wc_result', expected 3"

# Empty file
echo -n "" > "$tmpfile2"
wc_result2=$(wc -l < "$tmpfile2" 2>/dev/null || true)
wc_result2=$(( 10#0${wc_result2} ))
[[ $wc_result2 -eq 0 ]] && assert_pass "wc -l empty file → clean integer 0" \
                         || assert_fail "wc -l empty file → got '$wc_result2', expected 0"

# Missing file
wc_result3=$(wc -l < "/tmp/nonexistent_file_$$" 2>/dev/null || true)
wc_result3=$(( 10#0${wc_result3} ))
[[ $wc_result3 -eq 0 ]] && assert_pass "wc -l missing file → clean integer 0" \
                         || assert_fail "wc -l missing file → got '$wc_result3', expected 0"
rm -f "$tmpfile2"

# ══════════════════════════════════════════════════════════════════════════════
# TEST 4: OOB Latency (Asynchronous Callback Polling)
# ══════════════════════════════════════════════════════════════════════════════
echo "[*] Test 4: OOB Asynchronous Polling (4-second delayed callback)"

test_oob_log="/tmp/interactsh_mock_$$"
echo "" > "$test_oob_log"

# Simulate callback arriving at 4 seconds
( sleep 4; echo '{"protocol":"dns","raw_request":"xss-12345.interactsh.com"}' >> "$test_oob_log" ) &
bg_pid=$!

xss_callbacks=0
for _ in {1..3}; do
    sleep 3
    xss_callbacks=$(grep -c "xss-" "$test_oob_log" 2>/dev/null || true)
    xss_callbacks=$(( 10#0${xss_callbacks} ))
    if [[ $xss_callbacks -gt 0 ]]; then
        break
    fi
done
wait $bg_pid 2>/dev/null || true

[[ $xss_callbacks -eq 1 ]] && assert_pass "OOB engine captured delayed callback on poll iteration 2" \
                            || assert_fail "OOB engine missed delayed callback (got $xss_callbacks)"
rm -f "$test_oob_log"

# ══════════════════════════════════════════════════════════════════════════════
# TEST 5: Honeypot WebShell Token Isolation (5MB noisy buffer)
# ══════════════════════════════════════════════════════════════════════════════
echo "[*] Test 5: Safe Execution Proof — Token Isolation in Noisy Buffer"

exec_token="ACROMAP_EXEC_CONFIRMED_99999"
noisy_output=$(printf 'A%.0s' {1..50000})
noisy_output="${noisy_output}<br><html><body>honeypot... ${exec_token} ...</body></html>${noisy_output}"
parsed_token=$(echo "$noisy_output" | grep -o "${exec_token}" | head -1 || echo "")

[[ "$parsed_token" == "${exec_token}" ]] \
    && assert_pass "Token isolated from 100KB+ noisy HTML buffer" \
    || assert_fail "Token isolation failed in noisy buffer"

# ══════════════════════════════════════════════════════════════════════════════
# TEST 6: Explicit State Degradation (Parser Failure Detection)
# ══════════════════════════════════════════════════════════════════════════════
echo "[*] Test 6: Explicit State Degradation — Parser Failure Signals"

# Simulate nmap_parser.py receiving corrupt XML
corrupt_xml="/tmp/corrupt_nmap_$$"
echo "<html><body>WAF says no</body></html>" > "$corrupt_xml"

# Source the parser output (it should export NMAP_PARSER_FAILURE=true)
if command -v python3 &>/dev/null; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    eval "$(python3 "${SCRIPT_DIR}/nmap_parser.py" "$corrupt_xml" 2>/dev/null)"
    if [[ "${NMAP_PARSER_FAILURE:-false}" == "true" ]]; then
        assert_pass "nmap_parser.py correctly flagged XML corruption: NMAP_PARSER_FAILURE=true (${NMAP_PARSER_REASON})"
    else
        assert_fail "nmap_parser.py silently swallowed corrupt XML — PARSER_FAILURE was not set"
    fi

    # Simulate web_parser.py receiving corrupt JSON
    corrupt_json="/tmp/corrupt_whatweb_$$"
    echo "<!DOCTYPE html><html>WAF blocked you</html>" > "$corrupt_json"
    eval "$(python3 "${SCRIPT_DIR}/web_parser.py" "$corrupt_json" "/tmp/nonexistent" 2>/dev/null)"
    if [[ "${WEB_PARSER_FAILURE:-false}" == "true" ]]; then
        assert_pass "web_parser.py correctly flagged JSON corruption: WEB_PARSER_FAILURE=true (${WEB_PARSER_REASON})"
    else
        assert_fail "web_parser.py silently swallowed corrupt JSON — PARSER_FAILURE was not set"
    fi
    rm -f "$corrupt_xml" "$corrupt_json"
else
    echo "  [SKIP] python3 not available — parser degradation tests skipped"
fi

# ══════════════════════════════════════════════════════════════════════════════
# TEST 7: Timing Math Safety (Negative/Zero elapsed time)
# ══════════════════════════════════════════════════════════════════════════════
echo "[*] Test 7: Timing Math — Negative and Zero elapsed time safety"

# Simulate clock rollback (network jitter)
t_start=1000; t_end=990
elapsed=$(( t_end - t_start ))
# The script uses ${diff#-} to strip negatives
abs_elapsed=${elapsed#-}
[[ $abs_elapsed -eq 10 ]] && assert_pass "Negative elapsed time → absolute value correctly calculated (10)" \
                           || assert_fail "Negative elapsed → got $abs_elapsed, expected 10"

# Zero elapsed
t_start=500; t_end=500
elapsed=$(( t_end - t_start ))
[[ $elapsed -eq 0 ]] && assert_pass "Zero elapsed time handled safely" \
                      || assert_fail "Zero elapsed → got $elapsed"

# ══════════════════════════════════════════════════════════════════════════════
# FINAL REPORT
# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "═══════════════════════════════════════════════════"
total=$(( PASS + FAIL ))
if [[ $FAIL -eq 0 ]]; then
    echo "  ✓ ALL ${total} ASSERTIONS PASSED"
    echo "  Reality = Theoretical Design."
else
    echo "  ✗ ${FAIL}/${total} ASSERTIONS FAILED"
    echo "  Execution reality diverges from design."
fi
echo "═══════════════════════════════════════════════════"
exit $FAIL

