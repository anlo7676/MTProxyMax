#!/bin/bash
# Regression tests for HTB QoS configuration and caller variable isolation.
set -o pipefail

TEST_TMPDIR=$(mktemp -d) || exit 1
INSTALL_DIR="$TEST_TMPDIR/install"
mkdir -p "$INSTALL_DIR"
MTPROXYMAX_SOURCE_ONLY=true source "$(dirname "${BASH_SOURCE[0]}")/../mtproxymax.sh"
set +e
trap 'rm -rf "$TEST_TMPDIR"' EXIT

TESTS_RUN=0
TESTS_FAILED=0
APPLY_COUNT=0
LAST_MESSAGE=""
log_success() { LAST_MESSAGE="$*"; }
log_warn() { LAST_MESSAGE="$*"; }
log_error() { LAST_MESSAGE="$*"; }
# Keep persistence and reload behavior, without changing host networking.
speed_limit_apply() { APPLY_COUNT=$((APPLY_COUNT + 1)); load_speed_limits; }

assert_eq() {
    local name="$1" want="$2" got="$3"
    TESTS_RUN=$((TESTS_RUN + 1))
    if [ "$got" = "$want" ]; then
        printf '  PASS  %s\n' "$name"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        printf '  FAIL  %s (got=%q want=%q)\n' "$name" "$got" "$want"
    fi
}

seed_rules() {
    printf '%s\n' '443|port|51200|51200|true' 'global|global|102400|20480|false' > "$SPEED_LIMITS_FILE"
}

check_loader_scope() {
    local target=8443 type=port down=4096 up=2048 enabled=true
    load_speed_limits
    assert_eq "loading preserves caller variables" '8443|port|4096|2048|true' "$target|$type|$down|$up|$enabled"
    assert_eq "loading reads targets" '443 global' "${SPEED_LIMIT_TARGETS[*]}"
}

seed_rules
check_loader_scope
speed_limit_remove 443
assert_eq "remove port persists other rule unchanged" 'global|global|102400|20480|false' "$(cat "$SPEED_LIMITS_FILE")"
assert_eq "remove reports original target" '已移除 443 的 QoS 限速' "$LAST_MESSAGE"
assert_eq "remove refreshes rules" 1 "$APPLY_COUNT"
speed_limit_remove global
assert_eq "remove last rule empties configuration" '' "$(cat "$SPEED_LIMITS_FILE")"
assert_eq "remove last rule empties loaded targets" 0 "${#SPEED_LIMIT_TARGETS[@]}"

seed_rules
APPLY_COUNT=0
speed_limit_remove 8443
assert_eq "missing target is reported correctly" "限速规则中未找到目标 '8443'" "$LAST_MESSAGE"
assert_eq "missing target does not refresh rules" 0 "$APPLY_COUNT"
assert_eq "missing target preserves file" $'443|port|51200|51200|true\nglobal|global|102400|20480|false' "$(cat "$SPEED_LIMITS_FILE")"

speed_limit_set 443 4096 2048
assert_eq "update preserves target and requested rates" $'443|port|4096|2048|true\nglobal|global|102400|20480|false' "$(cat "$SPEED_LIMITS_FILE")"
speed_limit_set 8443 8192 4096
assert_eq "add persists valid port and rates" '8443|port|8192|4096|true' "$(tail -n 1 "$SPEED_LIMITS_FILE")"
speed_limit_set global 16384
assert_eq "global update defaults upload to download" 'global|global|16384|16384|true' "$(sed -n '2p' "$SPEED_LIMITS_FILE")"

clear_screen() { :; }
draw_header() { :; }
draw_box_line() { :; }
press_any_key() { :; }
read_choice() { local answer; read -r answer; printf '%s' "$answer"; }
seed_rules
show_speed_limit_menu <<< $'2\n443\n0' > "$TEST_TMPDIR/menu.out"
assert_eq "menu removes entered port" 'global|global|102400|20480|false' "$(cat "$SPEED_LIMITS_FILE")"

printf '\n%d tests, %d failures\n' "$TESTS_RUN" "$TESTS_FAILED"
[ "$TESTS_FAILED" -eq 0 ]
