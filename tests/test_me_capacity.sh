#!/bin/bash
# Verify ME capacity overrides survive configuration regeneration.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT
export INSTALL_DIR="$TEST_ROOT"
export CONFIG_DIR="$TEST_ROOT/mtproxy"
export SETTINGS_FILE="$TEST_ROOT/settings.conf"
export SECRETS_FILE="$TEST_ROOT/secrets.conf"
export STATS_DIR="$TEST_ROOT/relay_stats"
MTPROXYMAX_SOURCE_ONLY=true source "${SCRIPT_DIR}/../mtproxymax.sh"
set -eo pipefail
set +u

check_root() { :; }
confirm_settings_restart() { return 0; }
is_proxy_running() { return 1; }
log_success() { :; }
log_error() { :; }

param=me_adaptive_floor_max_active_writers_per_core
generate_telemt_config
if grep -q "^${param} =" "$CONFIG_DIR/config.toml"; then
    echo "FAIL: default configuration unexpectedly overrides ME capacity" >&2
    exit 1
fi
tune_set "$param" 96
grep -qx "${param}|96" "$_TUNE_FILE"
for attempt in 1 2; do
    generate_telemt_config
    actual=$(awk -v key="$param" '
        /^\[/ { section=$0 }
        $1 == key && $2 == "=" { print section ":" $3 }
    ' "$CONFIG_DIR/config.toml")
    [ "$actual" = '[general]:96' ]
done
for invalid in 0 -1 1000 65536 abc 1.5; do
    if tune_set "$param" "$invalid"; then
        echo "FAIL: accepted invalid capacity $invalid" >&2
        exit 1
    fi
    grep -qx "${param}|96" "$_TUNE_FILE"
done
echo "PASS: ME capacity persists in [general]; invalid overrides leave it intact"
