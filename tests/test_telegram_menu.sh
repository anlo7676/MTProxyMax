#!/bin/bash
# Regression tests for Telegram inline menu generation and callback routing.
set -o pipefail

TEST_TMPDIR=$(mktemp -d)
INSTALL_DIR="$TEST_TMPDIR/install"
mkdir -p "$INSTALL_DIR"
trap 'rm -rf "$TEST_TMPDIR"' EXIT

MTPROXYMAX_SOURCE_ONLY=true source "$(dirname "$0")/../mtproxymax.sh"
set +e
INSTALL_DIR="$TEST_TMPDIR/install"
telegram_generate_service_script
BOT_SCRIPT="$INSTALL_DIR/mtproxymax-telegram.sh"

TESTS_RUN=0
TESTS_FAILED=0

assert_contains() {
    local name="$1" pattern="$2"
    TESTS_RUN=$((TESTS_RUN + 1))
    if grep -Fq -- "$pattern" "$BOT_SCRIPT"; then
        printf '  PASS  %s\n' "$name"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        printf '  FAIL  %s\n' "$name"
    fi
}

echo "Telegram inline menu tests"
bash -n "$BOT_SCRIPT"
if [ $? -eq 0 ]; then
    printf '  PASS  generated daemon syntax\n'
else
    printf '  FAIL  generated daemon syntax\n'
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_RUN=$((TESTS_RUN + 1))

assert_contains "public menu uses visible inline buttons" '"inline_keyboard"'
assert_contains "status callback is emitted" '"callback_data":"admin_status"'
assert_contains "callback queries are parsed" "r.get('callback_query',{})"
assert_contains "callback clicks are acknowledged" 'answerCallbackQuery'
assert_contains "callback routes to status handler" 'admin_status) text='
assert_contains "native command menu is registered" 'setMyCommands'
assert_contains "native menu button is enabled" 'setChatMenuButton'
assert_contains "polling removes conflicting webhook" 'deleteWebhook'
assert_contains "start payloads open the menu" '/start\ *'
assert_contains "menu command opens the menu" '/menu|/menu@*'
assert_contains "bot update is non-interactive" '--setenv=MTPROXYMAX_ASSUME_YES=true'

MAIN_SCRIPT="$(dirname "$0")/../mtproxymax.sh"
TESTS_RUN=$((TESTS_RUN + 1))
if grep -Fq 'systemctl stop mtproxymax-telegram.service' "$MAIN_SCRIPT" && \
   grep -Fq 'TELEGRAM_UPDATE_ID' "$MAIN_SCRIPT" && \
   grep -Fq 'relay_stats/tg_offset' "$MAIN_SCRIPT"; then
    printf '  PASS  setup prevents polling race and rebases offset\n'
else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf '  FAIL  setup prevents polling race and rebases offset\n'
fi

printf '\n%d tests, %d failures\n' "$TESTS_RUN" "$TESTS_FAILED"
[ "$TESTS_FAILED" -eq 0 ]
