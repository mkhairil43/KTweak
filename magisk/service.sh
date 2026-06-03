#!/system/bin/sh
# KTweak - Main Service Script
# Executes kernel tweaks at boot completion

MODPATH="${0%/*}"
KTWEAK_BIN="$MODPATH/system/bin/ktweak.sh"
LOGFILE="/data/adb/ktweak/ktweak.log"

# Wait for boot to complete
while [ "$(getprop sys.boot_completed 2>/dev/null)" != "1" ]; do
    sleep 1
done

# Additional wait for stability
sleep 5

# Execute ktweak with logging
"$KTWEAK_BIN" > "$LOGFILE" 2>&1

exit 0
