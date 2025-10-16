#!/bin/bash
# CIS Compliance checks for Linux images

# Array of tests
declare -A tests

# Function to run a test and record result
run_test() {
    local test_name=$1
    local test_command=$2
    local result
    
    echo "Running test: $test_name"
    if eval "$test_command"; then
        result="PASS"
    else
        result="FAIL"
    fi
    tests["$test_name"]=$result
}

# 1. Check if AIDE is installed and initialized
run_test "AIDE Installation" "which aide && test -f /var/lib/aide/aide.db"

# 2. Check SSH Configuration
run_test "SSH Root Login" "grep '^PermitRootLogin no' /etc/ssh/sshd_config"
run_test "SSH Password Auth" "grep '^PasswordAuthentication no' /etc/ssh/sshd_config"

# 3. Check System Updates
run_test "Auto Updates" "test -f /etc/apt/apt.conf.d/50unattended-upgrades"

# 4. Check Azure Monitor Agent
run_test "Azure Monitor Agent" "test -f /opt/microsoft/azuremonitoragent/bin/agent"

# 5. Check Firewall
run_test "UFW Status" "ufw status | grep -q 'Status: active'"

# 6. Check System Hardening
run_test "Core Dumps" "grep -q 'hard core 0' /etc/security/limits.conf"
run_test "Password Policy" "test -f /etc/pam.d/common-password"

# Generate XML report
echo '<?xml version="1.0" encoding="UTF-8"?>' > test-results.xml
echo '<testsuites>' >> test-results.xml
echo '  <testsuite name="Linux CIS Compliance" tests="'${#tests[@]}'">' >> test-results.xml

for test_name in "${!tests[@]}"; do
    result=${tests[$test_name]}
    echo '    <testcase classname="CISBenchmark" name="'"$test_name"'">' >> test-results.xml
    if [ "$result" = "FAIL" ]; then
        echo '      <failure message="Test failed"/>' >> test-results.xml
    fi
    echo '    </testcase>' >> test-results.xml
done

echo '  </testsuite>' >> test-results.xml
echo '</testsuites>' >> test-results.xml
