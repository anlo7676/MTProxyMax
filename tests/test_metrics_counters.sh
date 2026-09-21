#!/bin/bash
# Exercise both historical and Prometheus-compliant telemt byte counters.
set -o pipefail
TEST_TMPDIR=$(mktemp -d) || exit 1
INSTALL_DIR="$TEST_TMPDIR/install"
mkdir -p "$INSTALL_DIR/relay_stats"
MTPROXYMAX_SOURCE_ONLY=true source "$(dirname "${BASH_SOURCE[0]}")/../mtproxymax.sh"
set +e
trap 'rm -rf "$TEST_TMPDIR"' EXIT
TESTS_RUN=0
TESTS_FAILED=0
assert_eq() {
    TESTS_RUN=$((TESTS_RUN + 1))
    if [ "$2" = "$3" ]; then
        printf '  PASS  %s\n' "$1"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        printf '  FAIL  %s (want=%q got=%q)\n' "$1" "$2" "$3"
    fi
}
is_proxy_running() { return 0; }
_fetch_metrics() { printf '%s\n' "$METRICS"; }
curl() { printf '%s\n' "$METRICS"; }
check_root() { :; }
log_info() { :; }
log_success() { :; }
audit_log() { :; }
load_settings() { :; }
SECRETS_LABELS=(alice bob)
SECRETS_ENABLED=(true true)
printf 'alice|0123456789abcdef0123456789abcdef|0|true|0|0|0|0||\nbob|abcdef0123456789abcdef0123456789|0|true|0|0|0|0||\n' > "$SECRETS_FILE"
telegram_generate_service_script
DAEMON="$INSTALL_DIR/mtproxymax-telegram.sh"
for fn in get_stats update_traffic; do
    sed -n "/^${fn}()/,/^}/p" "$DAEMON" >> "$TEST_TMPDIR/daemon-functions.sh"
done
source "$TEST_TMPDIR/daemon-functions.sh"
save_traffic() { :; }
declare -A _cum_user_in=() _cum_user_out=() _prev_user_in=() _prev_user_out=()

for suffix in '' _total; do
    METRICS="telemt_user_octets_from_client${suffix}{user=\"alice\"} 120
telemt_user_octets_to_client${suffix}{user=\"alice\"} 340
telemt_user_octets_from_client${suffix}{user=\"bob\"} 50
telemt_user_octets_to_client${suffix}{user=\"bob\"} 70
telemt_user_connections_current{user=\"alice\"} 3
telemt_user_connections_current{user=\"bob\"} 2"
    : > "$STATS_DIR/user_traffic"
    : > "$STATS_DIR/user_traffic_snapshot"
    printf '0|0\n' > "$STATS_DIR/cumulative_traffic"
    printf '0|0\n' > "$STATS_DIR/global_traffic_snapshot"
    assert_eq "global counters ($suffix)" '170 410 5' "$(get_proxy_stats)"
    assert_eq "single user counters ($suffix)" '120 340 3' "$(get_user_stats alice)"
    _load_all_cumulative_user_stats
    assert_eq "batch user counters ($suffix)" '120|340' "${_batch_cum_in[alice]}|${_batch_cum_out[alice]}"
    flush_traffic_to_disk
    assert_eq "persisted global traffic ($suffix)" '170|410' "$(cat "$STATS_DIR/cumulative_traffic")"
    assert_eq "persisted user traffic ($suffix)" 'alice|120|340' "$(grep '^alice|' "$STATS_DIR/user_traffic")"
    assert_eq "daemon live counters ($suffix)" '170 410 5' "$(get_stats)"
    _cum_in=0 _cum_out=0 _prev_total_in=0 _prev_total_out=0
    _cum_user_in=() _cum_user_out=() _prev_user_in=() _prev_user_out=()
    update_traffic
    assert_eq "daemon global accumulation ($suffix)" '170|410' "$_cum_in|$_cum_out"
    assert_eq "daemon user accumulation ($suffix)" '120|340' "${_cum_user_in[alice]}|${_cum_user_out[alice]}"
    update_traffic
    assert_eq "unchanged sample is not double-counted ($suffix)" '170|410' "$_cum_in|$_cum_out"
    secret_reset_traffic alice no_reload
    assert_eq "reset captures live baseline ($suffix)" 'alice|120|340' "$(grep '^alice|' "$STATS_DIR/user_traffic_snapshot")"
done
printf '\n%d tests, %d failures\n' "$TESTS_RUN" "$TESTS_FAILED"
[ "$TESTS_FAILED" -eq 0 ]
