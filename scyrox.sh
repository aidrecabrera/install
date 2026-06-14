#!/usr/bin/env bash
#
# install udev rules for scyrox
# the web configurator needs this for WebHID/WebUSB
#
#

set -euo pipefail

readonly VENDOR_ID="3554"
readonly RULES_FILE="/etc/udev/rules.d/70-scyrox.rules"
TMP=""

# run as root and use sudo only if we are not root already
run() {
    if [[ "$EUID" -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

cleanup() {
    [[ -n "$TMP" ]] && rm -f "$TMP"
}

main() {
    if [[ "$(uname -s)" != "Linux" ]]; then
        echo "This only works on Linux." >&2
        return 1
    fi

    # make sure we can elevate
    if [[ "$EUID" -ne 0 ]] && ! sudo -n true 2>/dev/null; then
        echo "Need root or passwordless sudo." >&2
        return 1
    fi

    TMP=$(mktemp)
    trap cleanup EXIT

    cat > "$TMP" <<EOF
# SCYROX keyboards (vendor 0x${VENDOR_ID})
# Grant the current user access for WebHID/WebUSB.
SUBSYSTEM=="hidraw", ATTRS{idVendor}=="${VENDOR_ID}", TAG+="uaccess"
SUBSYSTEM=="usb", ATTRS{idVendor}=="${VENDOR_ID}", TAG+="uaccess"
EOF

    if [[ -f "$RULES_FILE" ]] && cmp -s "$TMP" "$RULES_FILE"; then
        echo "Rules already installed."
    else
        if [[ -f "$RULES_FILE" ]]; then
            run cp -a "$RULES_FILE" "${RULES_FILE}.bak.$(date +%s)"
        fi

        run install -m 0644 "$TMP" "$RULES_FILE"
        run udevadm control --reload-rules
        run udevadm trigger --subsystem-match=hidraw --subsystem-match=usb

        echo "Installed $RULES_FILE"
    fi

    # check if a scyrox device is already connected
    local NEEDS_REPLUG=false
    for f in /sys/bus/usb/devices/*/idVendor; do
        if [[ -r "$f" ]] && grep -qx "${VENDOR_ID}" "$f" 2>/dev/null; then
            NEEDS_REPLUG=true
            break
        fi
    done

    ls -l "$RULES_FILE"
    echo

    if [[ "$NEEDS_REPLUG" == true ]]; then
        echo "Unplug and replug your SCYROX dongle."
    else
        echo "Plug in your SCYROX device."
    fi

    echo "Then open https://www.scyrox.net/"
}

main "$@"
