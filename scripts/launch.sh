#!/bin/bash
set -euo pipefail

# Suppress Wine debug/fixme/err/warn channels
export WINEDEBUG=-all
export WINEARCH="${WINEARCH:-win64}"

# Suppress libEGL / Mesa / DRI driver noise (Linux graphics stack)
export EGL_LOG_LEVEL=fatal
export MESA_DEBUG=silent
export LIBGL_DEBUG=quiet
export GALLIUM_HUD=

# Suppress GStreamer pipeline warnings
export GST_DEBUG=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(dirname "$SCRIPT_DIR")"
SINGBOX="$APP_DIR/bin/proxy/sing-box.exe"
FIREFOX="$APP_DIR/bin/Firefox/firefox.exe"
CONFIG_DIR="$HOME/.grouplancing"
LICENSE_FILE="$CONFIG_DIR/grouplancing_license.dat"
SINGBOX_CONFIG="$CONFIG_DIR/singbox-config.json"
FIREFOX_PROFILE="$CONFIG_DIR/firefox_profile"

SINGBOX_PID=""

cleanup() {
    if [ -n "$SINGBOX_PID" ]; then
        kill "$SINGBOX_PID" 2>/dev/null || true
        wait "$SINGBOX_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

mkdir -p "$CONFIG_DIR" "$FIREFOX_PROFILE"

# ===== LICENSE SETUP =====
if [ ! -f "$LICENSE_FILE" ]; then
    clear
    echo ""
    echo "==================================================="
    echo "  GroupLancing Browser - First Time Setup"
    echo "==================================================="
    echo ""
    echo "Welcome to GroupLancing Browser!"
    echo ""
    echo "This browser provides secure proxy access to approved sites."
    echo ""
    echo "Please enter your license key to get started."
    echo ""
    read -rp "Enter License Key: " LICENSE_KEY
    if [ -z "$LICENSE_KEY" ]; then
        echo ""
        echo "ERROR: License key cannot be empty"
        exit 1
    fi
    echo "$LICENSE_KEY" > "$LICENSE_FILE"
    echo ""
    echo "License key saved successfully!"
    sleep 2
fi

LICENSE_KEY="$(tr -d '[:space:]' < "$LICENSE_FILE")"

# ===== FETCH PROXY CONFIG =====
echo "Fetching proxy configuration from GroupLancing servers..."
API_RESPONSE="$(curl -sf --max-time 10 \
    -X POST "https://api.grouplancing.com/gpl_admin/get_proxy_for_user" \
    -H "Content-Type: application/json" \
    -d "{\"license_key\": \"$LICENSE_KEY\"}" 2>/dev/null)" || API_RESPONSE=""

if [ -n "$API_RESPONSE" ]; then
    echo "$API_RESPONSE" > "$CONFIG_DIR/api_response.json"
    if echo "$API_RESPONSE" | python3 -c "import sys,json; c=json.load(sys.stdin); exit(0 if 'inbounds' in c else 1)" 2>/dev/null; then
        echo "$API_RESPONSE" > "$SINGBOX_CONFIG"
    fi
fi

if [ ! -f "$SINGBOX_CONFIG" ]; then
    cp "$APP_DIR/bin/proxy/singbox-config.json" "$SINGBOX_CONFIG"
fi

# ===== FIREFOX INSTALLATION =====
if [ ! -f "$FIREFOX" ]; then
    echo "Firefox not found. Installing Firefox automatically..."
    INSTALLER="$(find "$APP_DIR/bin/firefox" -name "Firefox Setup*.exe" 2>/dev/null | head -1)"
    if [ -z "$INSTALLER" ]; then
        echo "ERROR: Firefox installer not found in bin/firefox"
        exit 1
    fi
    WINE_INSTALL_DIR="$(winepath -w "$APP_DIR/bin/Firefox" 2>/dev/null)"
    wine "$INSTALLER" /S "/InstallDirectoryPath=$WINE_INSTALL_DIR" >/dev/null 2>&1
    if [ ! -f "$FIREFOX" ]; then
        echo "ERROR: Failed to install Firefox automatically."
        echo "Please run the installer in bin/firefox and install to bin/Firefox."
        exit 1
    fi
    echo "Firefox installed successfully."
fi

# ===== FIREFOX PROFILE =====
cat > "$FIREFOX_PROFILE/user.js" << 'USERJS'
user_pref("network.proxy.type", 1);
user_pref("network.proxy.socks", "127.0.0.1");
user_pref("network.proxy.socks_port", 9050);
user_pref("network.proxy.no_proxies_on", "");
user_pref("network.proxy.share_proxy_settings", true);
user_pref("extensions.enabledScopes", 0);
user_pref("xpinstall.enabled", false);
user_pref("identity.fxaccounts.enabled", false);
user_pref("datareporting.policy.dataSubmissionPolicyAcceptedVersion", 0);
user_pref("extensions.activeThemeID", "firefox-compact-dark@mozilla.org");
user_pref("browser.startup.homepage", "about:blank");
USERJS

# ===== START PROXY =====
echo "Starting proxy service..."
SINGBOX_WIN_CONFIG="$(winepath -w "$SINGBOX_CONFIG" 2>/dev/null)"
wine "$SINGBOX" run -c "$SINGBOX_WIN_CONFIG" >/dev/null 2>&1 &
SINGBOX_PID=$!

# Poll until port 9050 is listening (up to 5 s)
for i in $(seq 1 10); do
    if ss -tlnp 2>/dev/null | grep -q ':9050'; then
        break
    fi
    sleep 0.5
done

if ! ss -tlnp 2>/dev/null | grep -q ':9050'; then
    echo "WARNING: Proxy did not start on port 9050 — check singbox-config.json"
fi

# ===== LAUNCH FIREFOX =====
clear
echo ""
echo "==================================================="
echo "  GroupLancing Browser"
echo "==================================================="
echo ""
echo "Browser is starting..."
echo "Your connection is protected through secure proxy"
echo "Do NOT modify proxy settings in browser preferences"
echo ""

FIREFOX_WIN_PROFILE="$(winepath -w "$FIREFOX_PROFILE" 2>/dev/null)"
wine "$FIREFOX" -profile "$FIREFOX_WIN_PROFILE" -no-remote >/dev/null 2>&1

echo ""
echo "Cleaning up..."
# cleanup() runs automatically via EXIT trap
