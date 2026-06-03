#!/system/bin/sh
# KTweak v2.1.0 - Safety & Robustness Enhanced
# POSIX-compliant kernel tuner for Android 10-17+
# Author: Draco (@tytydraco)

# --- Constants ---
VERSION="2.1.0"
LOG_DIR="/data/adb/ktweak"
LOG_FILE="${LOG_DIR}/ktweak.log"
BACKUP_DIR="${LOG_DIR}/backup"

DEFAULT_PROFILE="balanced"
PROFILE_BALANCED="24000000:6000000:500000:128:60"
PROFILE_BATTERY="48000000:12000000:1000000:64:40"
PROFILE_PERFORMANCE="12000000:3000000:200000:512:80"
PROFILE_GAMING="8000000:2000000:100000:256:70"

STORAGE_TYPE=""
SCHED_TYPE=""
DRY_RUN="false"
VERBOSE="false"
DEBUG="false"
ACTION="apply"
FAILURE_COUNT=0
SUCCESS_COUNT=0
VERIFY_MISMATCH_COUNT=0

log() {
    _level="$1"; shift
    _msg="$*"
    _timestamp=$(date '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || echo "UNKNOWN")
    _line="[${_timestamp}] [${_level}] ${_msg}"
    mkdir -p "$LOG_DIR" 2>/dev/null
    echo "$_line" >> "$LOG_FILE" 2>/dev/null
    [ "$_level" = "ERROR" ] || [ "$_level" = "WARN" ] && echo "$_line" >&2
    [ "$VERBOSE" = "true" ] && [ "$_level" != "ERROR" ] && [ "$_level" != "WARN" ] && echo "$_line"
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }
log_debug() { [ "$DEBUG" = "true" ] && log "DEBUG" "$@"; }

backup_value() {
    _file="$1"
    _key=$(echo "$_file" | tr '/' '_' | sed 's/^_//')
    _backup_file="${BACKUP_DIR}/${_key}"
    if [ -f "$_file" ]; then
        _current=$(tr -d '\n' < "$_file" 2>/dev/null)
        if [ -n "$_current" ]; then
            mkdir -p "$BACKUP_DIR" 2>/dev/null
            echo "$_current" > "$_backup_file" 2>/dev/null
            log_debug "Backed up $_file = $_current"
            return 0
        fi
    fi
    return 1
}

restore_all() {
    log_info "=== Restoring Original Values ==="
    [ ! -d "$BACKUP_DIR" ] && { log_error "Backup dir not found: $BACKUP_DIR"; return 1; }
    _restored=0
    for _bf in "$BACKUP_DIR"/*; do
        [ -f "$_bf" ] || continue
        _saved=$(cat "$_bf" 2>/dev/null)
        [ -n "$_saved" ] || continue
        _op=$(basename "$_bf" | sed 's/_/\//g')
        [ -f "/$_op" ] && printf '%s\n' "$_saved" > "/$_op" 2>/dev/null && _restored=$((_restored + 1))
    done
    log_info "Restored $_restored values"
}

write_sysfs() {
    _file="$1"; _value="$2"; _skip="${3:-}"
    [ ! -f "$_file" ] && { log_debug "Not found: $_file"; return 0; }
    
    if [ "$DRY_RUN" = "true" ]; then
        _cur=$(tr -d '\n' < "$_file" 2>/dev/null)
        [ "$_cur" != "$_value" ] && log_info "[DRY-RUN] $_file: $_cur -> $_value"
        return 0
    fi
    
    _key=$(echo "$_file" | tr '/' '_' | sed 's/^_//')
    _bf="${BACKUP_DIR}/${_key}"
    [ ! -f "$_bf" ] && backup_value "$_file"
    
    if printf '%s\n' "$_value" > "$_file" 2>/dev/null; then
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        if [ "$_skip" != "noreadback" ]; then
            _act=$(tr -d '\n' < "$_file" 2>/dev/null)
            if [ "$_act" != "$_value" ]; then
                VERIFY_MISMATCH_COUNT=$((VERIFY_MISMATCH_COUNT + 1))
                log_warn "Mismatch: $_file='$_act' (expected '$_value')"
                return 1
            fi
        fi
        log_debug "Set $_file=$_value"
        return 0
    else
        FAILURE_COUNT=$((FAILURE_COUNT + 1))
        log_debug "Failed: $_file=$_value"
        return 1
    fi
}

detect_android_version() {
    SDK_VER=$(getprop ro.build.version.sdk 2>/dev/null || echo "0")
    case "$SDK_VER" in
        29|30) ANDROID_VER="Android 10" ;;
        31) ANDROID_VER="Android 11" ;;
        32|33) ANDROID_VER="Android 12/12L" ;;
        34) ANDROID_VER="Android 13" ;;
        35) ANDROID_VER="Android 14" ;;
        36) ANDROID_VER="Android 15" ;;
        *) ANDROID_VER="Android 16+" ;;
    esac
    log_info "Detected: $ANDROID_VER (SDK $SDK_VER)"
}

detect_scheduler_type() {
    SCHED_TYPE="CFS"
    [ -f "/sys/kernel/sched_features" ] && {
        _f=$(cat /sys/kernel/sched_features 2>/dev/null)
        case "$_f" in *EEVDF*) SCHED_TYPE="EEVDF" ;; esac
    }
    log_info "Scheduler: $SCHED_TYPE"
}

detect_cpu_governor() {
    CPU_GOVERNOR="unknown"
    [ -f "/sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors" ] && {
        _ga=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors 2>/dev/null)
        case "$_ga" in
            *schedutil*) CPU_GOVERNOR="schedutil" ;;
            *interactive*) CPU_GOVERNOR="interactive" ;;
            *ondemand*) CPU_GOVERNOR="ondemand" ;;
        esac
    }
    log_info "Governor: $CPU_GOVERNOR"
}

detect_storage_type() {
    STORAGE_TYPE="Unknown"
    _retry=0
    while [ $_retry -lt 5 ]; do
        if [ -e "/dev/block/by-name/userdata" ]; then
            _bd=$(readlink -f /dev/block/by-name/userdata 2>/dev/null)
            if [ -n "$_bd" ]; then
                _dn=$(basename "$_bd")
                case "$_dn" in mmcblk*|sd*) STORAGE_TYPE="UFS/eMMC" ;; nvme*) STORAGE_TYPE="NVMe" ;; esac
                break
            fi
        fi
        [ -d "/sys/class/block/nvme0n1" ] && { STORAGE_TYPE="NVMe"; break; }
        [ -d "/sys/class/block/mmcblk0" ] && { STORAGE_TYPE="UFS/eMMC"; break; }
        _retry=$((_retry + 1)); sleep 1
    done
    log_info "Storage: $STORAGE_TYPE"
}

detect_zram_devices() {
    ZRAM_DEVICES=""
    for _zd in /sys/block/zram*; do
        [ -d "$_zd" ] && [ -f "${_zd}/disksize" ] && {
            _sz=$(tr -d '\n' < "${_zd}/disksize" 2>/dev/null)
            [ "$_sz" != "0" ] && [ -n "$_sz" ] && ZRAM_DEVICES="$ZRAM_DEVICES $(basename "$_zd")"
        }
    done
    ZRAM_DEVICES=$(echo "$ZRAM_DEVICES" | sed 's/^ //')
    [ -n "$ZRAM_DEVICES" ] && log_info "zRAM: $ZRAM_DEVICES"
}

load_profile() {
    _pn="${1:-$DEFAULT_PROFILE}"
    case "$_pn" in
        balanced) CURRENT_PROFILE="$PROFILE_BALANCED" ;;
        battery) CURRENT_PROFILE="$PROFILE_BATTERY" ;;
        performance) CURRENT_PROFILE="$PROFILE_PERFORMANCE" ;;
        gaming) CURRENT_PROFILE="$PROFILE_GAMING" ;;
        *) log_warn "Unknown profile: $_pn"; CURRENT_PROFILE="$PROFILE_BALANCED" ;;
    esac
    SCHED_LATENCY=$(echo "$CURRENT_PROFILE" | cut -d':' -f1)
    SCHED_MIN_GRAN=$(echo "$CURRENT_PROFILE" | cut -d':' -f2)
    SCHED_MIGRATION=$(echo "$CURRENT_PROFILE" | cut -d':' -f3)
    READAHEAD_KB=$(echo "$CURRENT_PROFILE" | cut -d':' -f4)
    SWAPPINESS=$(echo "$CURRENT_PROFILE" | cut -d':' -f5)
    log_info "Profile: $_pn (latency=$SCHED_LATENCY, readahead=$READAHEAD_KB)"
}

tune_scheduler() {
    log_info "=== Scheduler ==="
    write_sysfs "/proc/sys/kernel/sched_cfs_bandwidth_slice_us" "5000"
    write_sysfs "/proc/sys/kernel/sched_child_runs_first" "1"
    write_sysfs "/proc/sys/kernel/sched_migration_cost_ns" "$SCHED_MIGRATION"
    write_sysfs "/proc/sys/kernel/sched_min_granularity_ns" "$SCHED_MIN_GRAN"
    write_sysfs "/proc/sys/kernel/sched_latency_ns" "$SCHED_LATENCY"
    write_sysfs "/proc/sys/kernel/sched_initial_task_util" "20"
    write_sysfs "/proc/sys/kernel/sched_energy_margin" "120"
    write_sysfs "/proc/sys/kernel/sched_wakeup_granularity_ns" "4000000"
    [ "$SCHED_TYPE" = "EEVDF" ] && {
        write_sysfs "/proc/sys/kernel/sched_eevdf_latency_offset" "0"
        write_sysfs "/proc/sys/kernel/sched_eevdf_disabled" "0"
    }
    [ -f "/sys/kernel/sched_features" ] && {
        _feat=$(cat /sys/kernel/sched_features 2>/dev/null)
        case "$_feat" in *NEXT_BUDDY*) ;; *) printf '%s\n' "NEXT_BUDDY" > /sys/kernel/sched_features 2>/dev/null ;; esac
    }
}

tune_memory() {
    log_info "=== Memory ==="
    write_sysfs "/proc/sys/vm/dirty_ratio" "40"
    write_sysfs "/proc/sys/vm/dirty_background_ratio" "10"
    write_sysfs "/proc/sys/vm/dirty_expire_centisecs" "3000"
    write_sysfs "/proc/sys/vm/dirty_writeback_centisecs" "200"
    write_sysfs "/proc/sys/vm/swappiness" "$SWAPPINESS"
    write_sysfs "/proc/sys/vm/vfs_cache_pressure" "100"
    write_sysfs "/proc/sys/vm/overcommit_memory" "0"
    write_sysfs "/proc/sys/vm/page-cluster" "2"
    for _zr in $ZRAM_DEVICES; do
        write_sysfs "/sys/block/$_zr/max_comp_streams" "4"
        write_sysfs "/sys/block/$_zr/comp_algorithm" "lz4"
    done
}

tune_cpu_frequency() {
    log_info "=== CPU Frequency ==="
    [ "$CPU_GOVERNOR" = "unknown" ] && { log_warn "No governor"; return; }
    for _pol in /sys/devices/system/cpu/cpufreq/policy*; do
        [ -d "$_pol" ] || continue
        _gf="$_pol/scaling_governor"
        [ -f "$_gf" ] && {
            printf '%s\n' "$CPU_GOVERNOR" > "$_gf" 2>/dev/null
            _cg=$(tr -d '\n' < "$_gf" 2>/dev/null)
            [ "$_cg" = "$CPU_GOVERNOR" ] && SUCCESS_COUNT=$((SUCCESS_COUNT + 1)) || FAILURE_COUNT=$((FAILURE_COUNT + 1))
        }
        [ "$CPU_GOVERNOR" = "schedutil" ] && {
            write_sysfs "$_pol/schedutil/up_rate_limit_us" "500"
            write_sysfs "$_pol/schedutil/down_rate_limit_us" "2000"
        }
        [ "$CPU_GOVERNOR" = "interactive" ] && {
            write_sysfs "$_pol/interactive/go_hispeed_load" "85"
            write_sysfs "$_pol/interactive/timer_rate" "20000"
        }
    done
    write_sysfs "/sys/devices/system/cpu/cpufreq/boost" "1"
}

tune_io_scheduler() {
    log_info "=== I/O Scheduler ==="
    for _dev in /sys/block/*/queue; do
        _dn=$(echo "$_dev" | cut -d'/' -f4)
        case "$_dn" in loop*|ram*|fd*) continue ;; esac
        [ -f "$_dev/scheduler" ] && {
            _cs=$(tr -d '[]' < "$_dev/scheduler" 2>/dev/null)
            case "$STORAGE_TYPE" in
                NVMe|UFS*) case "$_cs" in mq-deadline|none|kyber) printf '%s\n' "mq-deadline" > "$_dev/scheduler" 2>/dev/null ;; *) printf '%s\n' "none" > "$_dev/scheduler" 2>/dev/null ;; esac ;;
                *) printf '%s\n' "mq-deadline" > "$_dev/scheduler" 2>/dev/null ;;
            esac
        }
        write_sysfs "$_dev/read_ahead_kb" "$READAHEAD_KB"
        write_sysfs "$_dev/nr_requests" "256"
    done
}

tune_network() {
    log_info "=== Network ==="
    [ -f "/proc/sys/net/ipv4/tcp_available_congestion_control" ] && {
        _acc=$(cat /proc/sys/net/ipv4/tcp_available_congestion_control 2>/dev/null)
        case "$_acc" in
            *bbr_v2*) printf '%s\n' "bbr_v2" > /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null ;;
            *bbr*) printf '%s\n' "bbr" > /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null ;;
            *) printf '%s\n' "cubic" > /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null ;;
        esac
    }
    write_sysfs "/proc/sys/net/ipv4/tcp_fastopen" "3"
    write_sysfs "/proc/sys/net/ipv4/tcp_syncookies" "1"
    write_sysfs "/proc/sys/net/ipv4/tcp_timestamps" "1"
    write_sysfs "/proc/sys/net/ipv4/tcp_window_scaling" "1"
    write_sysfs "/proc/sys/net/ipv4/tcp_keepalive_time" "300"
    write_sysfs "/proc/sys/net/core/rmem_max" "16777216"
    write_sysfs "/proc/sys/net/core/wmem_max" "16777216"
}

tune_power() {
    log_info "=== Power ==="
    write_sysfs "/sys/devices/system/cpu/cpu0/pm_qos_resume_latency_us" "0"
    write_sysfs "/proc/sys/kernel/nmi_watchdog" "0"
}

tune_misc() {
    log_info "=== Misc ==="
    write_sysfs "/sys/kernel/mm/ksm/run" "0"
    [ -f "/sys/kernel/mm/transparent_hugepage/enabled" ] && printf '%s\n' "madvise" > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null
}

show_summary() {
    log_info "=========================================="
    log_info "KTweak v${VERSION} Complete"
    log_info "Success: $SUCCESS_COUNT | Failures: $FAILURE_COUNT | Mismatches: $VERIFY_MISMATCH_COUNT"
    [ "$DRY_RUN" = "true" ] && log_info "(Dry-run - no changes applied)"
    log_info "=========================================="
}

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "  --profile NAME   (balanced|battery|performance|gaming)"
    echo "  --dry-run        Show changes without applying"
    echo "  --restore        Restore original values"
    echo "  --verbose        Show output"
    echo "  --debug          Debug mode"
    echo "  --help           Show help"
}

main() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --profile) shift; DEFAULT_PROFILE="$1" ;;
            --dry-run) DRY_RUN="true"; VERBOSE="true" ;;
            --restore) ACTION="restore" ;;
            --verbose) VERBOSE="true" ;;
            --debug) DEBUG="true"; VERBOSE="true" ;;
            --help|-h) usage; exit 0 ;;
            *) log_error "Unknown: $1"; usage; exit 1 ;;
        esac
        shift
    done
    
    log_info "KTweak v${VERSION} Starting"
    [ "$ACTION" = "restore" ] && { restore_all; exit $?; }
    
    detect_android_version
    detect_scheduler_type
    detect_cpu_governor
    detect_storage_type
    detect_zram_devices
    load_profile "$DEFAULT_PROFILE"
    
    tune_scheduler
    tune_memory
    tune_cpu_frequency
    tune_io_scheduler
    tune_network
    tune_power
    tune_misc
    
    show_summary
    [ "$FAILURE_COUNT" -gt 0 ] && return 1
    return 0
}

main "$@"
