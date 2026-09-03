#!/bin/bash
# MTProxyMax Quick Installer — SamNet Technologies
# 用法：curl -sL https://raw.githubusercontent.com/anlo7676/MTProxyMax/main/install.sh | sudo bash
set -e
SCRIPT_URL="https://raw.githubusercontent.com/anlo7676/MTProxyMax/main/mtproxymax.sh"
if [ "$(id -u)" -ne 0 ]; then echo "请以 root 身份运行：curl -sL $SCRIPT_URL | sudo bash" >&2; exit 1; fi
curl -fsSL "$SCRIPT_URL" -o /tmp/mtproxymax.sh && bash /tmp/mtproxymax.sh install && rm -f /tmp/mtproxymax.sh
