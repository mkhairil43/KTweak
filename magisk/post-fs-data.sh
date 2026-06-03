#!/system/bin/sh
# KTweak - Post-FS-Data Script
# Sets up permissions and prepares environment

MODPATH="${0%/*}"
KTWEAK_BIN="$MODPATH/system/bin/ktweak.sh"

# Set executable permissions
chmod 0755 "$KTWEAK_BIN" 2>/dev/null

# Create log directory
mkdir -p /data/adb/ktweak 2>/dev/null

# Clean old logs
rm -f /data/adb/ktweak/ktweak.log.old 2>/dev/null
mv /data/adb/ktweak/ktweak.log /data/adb/ktweak/ktweak.log.old 2>/dev/null

exit 0
