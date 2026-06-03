# KTweak Build Scripts

This repository includes automated build scripts for creating flashable Magisk module ZIP files on both Linux and Windows environments.

## Prerequisites

### Linux
- `bash` (required)
- `zip` and `unzip` utilities
- `shellcheck` (optional, for static analysis)

Install dependencies on Debian/Ubuntu:
```bash
sudo apt-get install zip unzip shellcheck
```

### Windows
- Windows 10 or later (for ANSI color support)
- Info-ZIP (`zip.exe` and `unzip.exe`) in PATH, OR
- Git Bash with zip/unzip installed
- WSL (Windows Subsystem for Linux) recommended for full compatibility

Install zip on Windows:
1. Download from [Info-ZIP](http://www.info-zip.org/)
2. Or use Chocolatey: `choco install zip`
3. Or use Scoop: `scoop install zip`

## Usage

### Linux
```bash
# Make executable (first time only)
chmod +x build.sh

# Build the module
./build.sh
```

### Windows
```cmd
REM Build the module
build.bat
```

Or in PowerShell:
```powershell
.\build.bat
```

## Build Process

Both scripts perform the following steps:

1. **Version Extraction**: Reads version from `magisk/module.prop`
2. **File Validation**: Checks all required files exist
3. **Syntax Validation**: Runs `sh -n` on all shell scripts
4. **Static Analysis**: Runs ShellCheck if available (Linux only)
5. **ZIP Creation**: Creates a compressed archive
6. **Integrity Check**: Verifies the ZIP file is valid
7. **Output**: Places final ZIP in `build/` directory

## Output

The build script generates:
- `build/KTweak-v{VERSION}.zip` - Flashable Magisk module
- Console output with build status and module contents

Example output:
```
[INFO] Building KTweak v2.1.0 (code: 210)
[INFO] Copying module files...
[INFO] Running syntax validation...
[INFO]   ✓ post-fs-data.sh syntax OK
[INFO]   ✓ service.sh syntax OK
[INFO]   ✓ system/bin/ktweak.sh syntax OK
[INFO] Running ShellCheck...
[INFO]   ✓ post-fs-data.sh ShellCheck OK
[INFO]   ✓ service.sh ShellCheck OK
[INFO]   ✓ system/bin/ktweak.sh ShellCheck OK
[INFO] Creating zip archive: build/KTweak-v2.1.0.zip
[SUCCESS] Build completed successfully!
[INFO] Output file: /workspace/build/KTweak-v2.1.0.zip
[INFO] File size: 12K
[SUCCESS] Ready to flash in Magisk Manager!
```

## Versioning

Version is automatically extracted from `magisk/module.prop`:
```properties
version=v2.1.0
versionCode=210
```

The build script removes the leading 'v' for consistent filename formatting:
- Input: `version=v2.1.0`
- Output: `KTweak-v2.1.0.zip`

## Troubleshooting

### "zip: command not found"
Install zip utility for your platform (see Prerequisites).

### "Could not create output file"
Ensure the `build/` directory doesn't have permission issues. The script will create it automatically.

### Syntax check failures
Run `sh -n magisk/system/bin/ktweak.sh` manually to see detailed errors.

### ShellCheck warnings
ShellCheck warnings are non-fatal. Fix any errors (not warnings) before building.

## Manual Build Alternative

If build scripts fail, you can manually create the ZIP:
```bash
cd magisk
zip -rq9 ../KTweak-manual.zip .
cd ..
```

Then flash `KTweak-manual.zip` in Magisk Manager.
