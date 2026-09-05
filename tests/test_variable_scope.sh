#!/bin/bash
# Exercise nested calls with caller locals matching parser and loop variables.
set -o pipefail

TEST_TMPDIR=$(mktemp -d) || exit 1
INSTALL_DIR="$TEST_TMPDIR/install"
mkdir -p "$INSTALL_DIR/relay_stats"
MTPROXYMAX_SOURCE_ONLY=true source "${SCOPE_TEST_SOURCE:-$(dirname "${BASH_SOURCE[0]}")/../mtproxymax.sh}"
set +e
trap 'rm -rf "$TEST_TMPDIR"' EXIT

TESTS_RUN=0
TESTS_FAILED=0
assert_eq() {
    local description="$1" expected="$2" actual="$3"
    TESTS_RUN=$((TESTS_RUN + 1))
    if [ "$expected" = "$actual" ]; then
        printf '  PASS  %s\n' "$description"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        printf '  FAIL  %s (got=%q want=%q)\n' "$description" "$actual" "$expected"
    fi
}

# Execute in the current shell: a subshell would hide the scope regression.
assert_scope() {
    local __scope_names="$1" __scope_name __scope_command="$2"
    shift
    if ! declare -F "$__scope_command" > /dev/null; then
        assert_eq "$__scope_command exists" present missing
        return 1
    fi
    for __scope_name in $__scope_names; do
        local "$__scope_name=caller-value"
    done
    "$@" > "$TEST_TMPDIR/call.out" 2>&1
    for __scope_name in $__scope_names; do
        assert_eq "$__scope_command preserves $__scope_name" caller-value "${!__scope_name}"
    done
}

check_root() { :; }
is_proxy_running() { return 1; }
docker() { :; }
ip() { printf 'default via 192.0.2.1 dev eth0\n'; }
TC_CLASS_COUNT=0
tc() { [ "$1" != class ] || TC_CLASS_COUNT=$((TC_CLASS_COUNT + 1)); return 0; }
iptables() { :; }
flock() { :; }
log_info() { :; }
log_success() { :; }
log_warn() { :; }
audit_log() { :; }
METRICS=$'telemt_user_octets_from_client{user="alice"} 120\ntelemt_user_octets_to_client{user="alice"} 340'
curl() { printf '%s\n' "$METRICS"; }
_fetch_metrics() { printf '%s\n' "$METRICS"; }

printf '%s\n' 'alice|0123456789abcdef0123456789abcdef|1000|true|15|5|4096|0|note|' > "$SECRETS_FILE"
printf '%s\n' 'direct|direct||||10||true' > "$UPSTREAMS_FILE"
printf '%s\n' '8443|9091|true|secondary' > "$INSTANCES_FILE"
printf '%s\n' 'node.example|22|replica|true|0|unknown' > "$REPLICATION_FILE"
printf '%s\n' "PROXY_PORT='443'" "TELEGRAM_INTERVAL='9'" "REPLICATION_SYNC_INTERVAL='90'" > "$SETTINGS_FILE"
printf '%s\n' '443|port|51200|51200|true' > "$SPEED_LIMITS_FILE"
printf '%s\n' 'alice|1000|2000' > "$STATS_DIR/user_traffic"
printf '%s\n' 'alice|10|20' > "$STATS_DIR/user_traffic_snapshot"

assert_scope 'line' load_settings
assert_eq 'settings still update shared configuration' 90 "$REPLICATION_SYNC_INTERVAL"
assert_scope 'label secret created enabled max_conns max_ips quota expires notes ad_tag name type addr user pass weight iface' load_secrets
assert_eq 'secrets still populate shared arrays' alice "${SECRETS_LABELS[*]}"
assert_eq 'nested upstream load still populates shared arrays' direct "${UPSTREAM_NAMES[*]}"
assert_scope 'port mport enabled label' load_instances
assert_eq 'instances still populate shared arrays' 8443 "${INSTANCE_PORTS[*]}"
assert_scope '_rl_h _rl_p _rl_l _rl_e _rl_ls _rl_st' load_replication
assert_eq 'replication still populates shared arrays' node.example "${REPL_HOSTS[*]}"
assert_scope 'parts part' validate_domain 'example.com,example.org'
assert_scope '_l _i _o _li _lo _lc' _load_all_cumulative_user_stats
assert_eq 'batch cumulative input includes live delta' 1110 "${_batch_cum_in[alice]}"
assert_scope 'label secret created enabled _l _i _o _mc _mi _q _ex _notes _adtag' flush_traffic_to_disk
assert_eq 'flush persists user traffic' 'alice|1110|2320' "$(cat "$STATS_DIR/user_traffic")"
load_speed_limits
assert_scope 'i' save_speed_limits
assert_scope 'i' speed_limit_apply
assert_eq 'HTB application visits configured classes' 3 "$TC_CLASS_COUNT"
assert_scope 'i' speed_limit_list

# Real hot reload traverses traffic loading, instances, and HTB rule application.
# The user's selected label must survive until secret_show_limits runs.
LAST_LIMIT_LABEL=""
secret_show_limits() { LAST_LIMIT_LABEL="$1"; }
secret_set_limits alice 30 6 8192 0 false > "$TEST_TMPDIR/limits.out" 2>&1
assert_eq 'limit update succeeds through hot reload' 0 "$?"
assert_eq 'hot reload retains selected secret label' alice "$LAST_LIMIT_LABEL"
assert_eq 'limit update persists requested connection limit' 30 "$(awk -F'|' '$1=="alice"{print $5}' "$SECRETS_FILE")"
assert_scope 'i label port' reload_proxy_config

# Check the actual generated daemon functions, without starting either daemon.
telegram_generate_service_script
replication_generate_sync_script
bash -n "$INSTALL_DIR/mtproxymax-telegram.sh"
assert_eq 'generated Telegram script parses' 0 "$?"
bash -n "$INSTALL_DIR/mtproxymax-sync.sh"
assert_eq 'generated sync script parses' 0 "$?"
awk '/^load_tg_settings\(\)/,/^}/; /^load_traffic\(\)/,/^}/' "$INSTALL_DIR/mtproxymax-telegram.sh" > "$TEST_TMPDIR/bot-functions.sh"
source "$TEST_TMPDIR/bot-functions.sh"
awk '/^load_sync_settings\(\)/,/^}/; /^load_sync_replication\(\)/,/^}/' "$INSTALL_DIR/mtproxymax-sync.sh" > "$TEST_TMPDIR/sync-functions.sh"
source "$TEST_TMPDIR/sync-functions.sh"
assert_scope 'line' load_tg_settings
assert_eq 'Telegram settings still update shared configuration' 9 "$TELEGRAM_INTERVAL"
assert_scope 'line' load_sync_settings
assert_scope 'host port label enabled last_sync status' load_sync_replication
assert_eq 'sync loader still populates shared arrays' node.example "${REPL_HOSTS[*]}"

TRAFFIC_FILE="$STATS_DIR/cumulative_traffic"
USER_TRAFFIC_FILE="$STATS_DIR/user_traffic"
declare -A _cum_user_in=() _cum_user_out=() _prev_user_in=() _prev_user_out=()
_cum_in=0 _cum_out=0 _prev_total_in=0 _prev_total_out=0
printf '500|700\n' > "$TRAFFIC_FILE"
printf '120|340\n' > "$STATS_DIR/global_traffic_snapshot"
assert_scope '_ul _ui _uo' load_traffic
assert_eq 'daemon loader updates shared global counters' '500|700|120|340' "$_cum_in|$_cum_out|$_prev_total_in|$_prev_total_out"
assert_eq 'daemon loader updates shared user counters' '1110|2320' "${_cum_user_in[alice]}|${_cum_user_out[alice]}"

printf '\n%d tests, %d failures\n' "$TESTS_RUN" "$TESTS_FAILED"
[ "$TESTS_FAILED" -eq 0 ]
