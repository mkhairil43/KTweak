# KTweak Magisk Module - Changelog

## v2.0.1 (2024) - Bug Fixes & Enhancements

### Fixed
- **Variable Scope**: Added proper global variable tracking for SUCCESS_COUNT and FAILURE_COUNT
- **Storage Detection Race Condition**: Added 2-second delay in `detect_storage_type()` to ensure block devices are ready
- **CPU Governor Verification**: Now verifies governor was actually set before applying tunings
- **zRAM Detection**: Improved check to verify zRAM is active (not just present) before tuning
- **Scheduler Features**: Safer handling of NEXT_BUDDY feature with proper error handling

### Changed
- **Security Enhancement**: Re-enabled TCP SYN cookies (was disabled in v2.0.0) for better security on public networks
- **Error Tracking**: Added comprehensive success/failure counting for all operations
- **Summary Output**: Added final summary showing successful and failed operations
- **Version**: Updated to v2.0.1

### Improved
- Better logging with specific failure reasons
- More robust sysfs write operations with verification
- Enhanced debugging output for troubleshooting

## v2.0.0 (2024) - Android 16/17 Support

### Added
- Full support for Android 10-17 (SDK 29-37+)
- EEVDF scheduler detection and optimization (Android 14+)
- BBRv2 congestion control support (Android 15+)
- UFS 4.0/NVMe storage optimizations
- Automatic detection system for:
  - Android version
  - Scheduler type (CFS/EEVDF)
  - CPU governor (schedutil/interactive/ondemand)
  - Storage type (UFS/eMMC/NVMe/SATA)

### Features
- POSIX-compliant scripts for maximum compatibility
- Graceful degradation for unsupported parameters
- Comprehensive logging to `/data/adb/ktweak/ktweak.log`
- Boot-safe execution with stability delays

## v1.0.0 - Initial Release

### Original KTweak Port
- Basic kernel parameter optimizations
- Systemd service conversion to Magisk service.sh
- Simple logging infrastructure
