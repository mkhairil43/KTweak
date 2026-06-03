# KTweak v2.1.0 - Safety-Enhanced Kernel Tuner

A POSIX-compliant Magisk module that optimizes kernel parameters for better UI/UX smoothness on Android 10-17+.

## Key Features (v2.1.0)

### Safety & Robustness
- **Automatic Backup**: All original kernel values are backed up before modification
- **Restore Function**: `--restore` flag to revert all changes instantly
- **Read-Back Verification**: Confirms kernel accepted each value, warns on mismatches
- **Dry-Run Mode**: Preview changes without applying (`--dry-run`)

### Profile System
Four pre-configured profiles for different use cases:
- **balanced** (default): Optimal for daily driving
- **battery**: Conservative settings for extended battery life
- **performance**: Low latency for demanding tasks
- **gaming**: Aggressive tuning for gaming sessions

### Platform Support
- Android 10-17+ (SDK 29-37+)
- CFS and EEVDF scheduler detection
- UFS, NVMe, eMMC storage optimization
- Multi-zRAM device support
- schedutil/interactive/ondemand governor support

## Installation

1. Download the latest release ZIP
2. Flash via Magisk Manager or KernelSU
3. Reboot (applies automatically on boot)

## Usage

### Manual Execution
```sh
# Apply balanced profile (default)
su -c ktweak

# Apply gaming profile
su -c "ktweak --profile gaming"

# Preview changes (dry-run)
su -c "ktweak --dry-run --verbose"

# Restore original values
su -c "ktweak --restore"

# Debug mode with verbose output
su -c "ktweak --debug"
```

### CLI Options
```
--profile NAME   Apply profile (balanced|battery|performance|gaming)
--dry-run        Show changes without applying
--restore        Restore all original values from backup
--verbose        Show detailed output
--debug          Enable debug logging
--help           Show help message
```

## File Structure

```
/data/adb/ktweak/
├── ktweak.log          # Execution log
├── backup/             # Original parameter backups
│   ├── _proc_sys_kernel_sched_latency_ns
│   └── ...
└── ktweak.conf         # (Future) user configuration
```

## Profiles Explained

| Profile | Latency (ns) | Readahead (KB) | Swappiness | Use Case |
|---------|-------------|----------------|------------|----------|
| battery | 48,000,000 | 64 | 40 | Battery saving, background tasks |
| balanced | 24,000,000 | 128 | 60 | Daily driving (default) |
| performance | 12,000,000 | 512 | 80 | Heavy multitasking |
| gaming | 8,000,000 | 256 | 70 | Gaming, low-latency apps |

## What Gets Tuned

### Scheduler
- CFS/EEVDF bandwidth and latency parameters
- Migration cost and wakeup granularity
- NEXT_BUDDY feature enablement

### Memory
- Dirty page writeback ratios
- Swappiness and cache pressure
- zRAM compression (lz4, multi-stream)

### CPU Frequency
- Governor rate limits (schedutil/interactive)
- Boost enablement

### I/O Scheduler
- mq-deadline for UFS/NVMe
- Read-ahead optimization per storage type
- Request queue depth tuning

### Network
- BBRv2/BBR congestion control
- TCP Fast Open, timestamps, window scaling
- Socket buffer optimization

## Troubleshooting

### Check Logs
```sh
cat /data/adb/ktweak/ktweak.log
```

### Verify Changes
```sh
# Run dry-run to see current vs proposed values
ktweak --dry-run --verbose
```

### Restore Defaults
```sh
# Instantly restore all original values
ktweak --restore
```

## Changelog

### v2.1.0 (Safety Enhancement)
- ✅ Added automatic backup/restore system
- ✅ Implemented read-back verification
- ✅ Added dry-run mode for safe testing
- ✅ Fixed storage detection (uses /data mountpoint resolution)
- ✅ Added multi-zRAM device support
- ✅ Improved error reporting with mismatch counts
- ✅ Structured logging with timestamps
- ✅ Four usage profiles (battery/balanced/performance/gaming)

### v2.0.1
- Fixed TCP security (syncookies enabled)
- Improved EEVDF scheduler detection
- Enhanced error handling

## License

BSD 2-Clause License

## Credits

Original concept by Draco (@tytydraco).  
Community contributions welcome.
