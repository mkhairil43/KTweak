#!/bin/bash
# KTweak Magisk Module Build Script (Linux)
# Builds a flashable Magisk module zip with automatic versioning

set -euo pipefail

# Configuration
MODULE_NAME="KTweak"
MODULE_DIR="magisk"
BUILD_DIR="build"
VERSION_FILE="${MODULE_DIR}/module.prop"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running from correct directory
if [ ! -d "$MODULE_DIR" ]; then
    log_error "Error: Must run from repository root where 'magisk/' directory exists"
    exit 1
fi

# Check if module.prop exists
if [ ! -f "$VERSION_FILE" ]; then
    log_error "Error: ${VERSION_FILE} not found"
    exit 1
fi

# Extract version from module.prop
VERSION=$(grep "^version=" "$VERSION_FILE" | cut -d'=' -f2)
VERSION_CODE=$(grep "^versionCode=" "$VERSION_FILE" | cut -d'=' -f2)

if [ -z "$VERSION" ]; then
    log_error "Error: Could not extract version from ${VERSION_FILE}"
    exit 1
fi

# Remove leading 'v' if present for consistent filename
VERSION_CLEAN="${VERSION#v}"

log_info "Building ${MODULE_NAME} v${VERSION_CLEAN} (code: ${VERSION_CODE})"

# Create build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Create temporary build structure
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

log_info "Copying module files..."
cp -r "$MODULE_DIR"/* "$TEMP_DIR/"

# Validate required files exist
REQUIRED_FILES="module.prop post-fs-data.sh service.sh system/bin/ktweak.sh"
for file in $REQUIRED_FILES; do
    if [ ! -f "${TEMP_DIR}/${file}" ]; then
        log_error "Error: Required file ${file} not found"
        exit 1
    fi
done

# Run syntax checks on shell scripts
log_info "Running syntax validation..."
SHELL_SCRIPTS="post-fs-data.sh service.sh system/bin/ktweak.sh"
for script in $SHELL_SCRIPTS; do
    if ! sh -n "${TEMP_DIR}/${script}" 2>/dev/null; then
        log_error "Syntax error in ${script}"
        exit 1
    fi
    log_info "  ✓ ${script} syntax OK"
done

# Check if shellcheck is available
if command -v shellcheck &> /dev/null; then
    log_info "Running ShellCheck..."
    for script in $SHELL_SCRIPTS; do
        if shellcheck "${TEMP_DIR}/${script}" 2>/dev/null; then
            log_info "  ✓ ${script} ShellCheck OK"
        else
            log_warn "ShellCheck found issues in ${script} (continuing anyway)"
        fi
    done
else
    log_warn "ShellCheck not installed, skipping static analysis"
fi

# Create zip archive
OUTPUT_FILE="${BUILD_DIR}/${MODULE_NAME}-v${VERSION_CLEAN}.zip"
log_info "Creating zip archive: ${OUTPUT_FILE}"

# Ensure output directory exists (use absolute path)
OUTPUT_FILE_ABS="$(cd "$(dirname "$BUILD_DIR")" && pwd)/$(basename "$OUTPUT_FILE")"
mkdir -p "$BUILD_DIR"

cd "$TEMP_DIR"
if zip -rq9 "$OUTPUT_FILE_ABS" .; then
    OUTPUT_FILE="$OUTPUT_FILE_ABS"
    cd - > /dev/null
else
    cd - > /dev/null
    log_error "Failed to create zip archive"
    exit 1
fi

# Verify zip integrity
if unzip -t "$OUTPUT_FILE" > /dev/null 2>&1; then
    log_success "Build completed successfully!"
    log_info "Output file: ${OUTPUT_FILE}"
    
    # Show file size
    FILE_SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
    log_info "File size: ${FILE_SIZE}"
    
    # Copy to build directory for consistency
    mkdir -p "$BUILD_DIR"
    cp "$OUTPUT_FILE" "$BUILD_DIR/"
    
    # Show contents summary
    log_info "Module contents:"
    unzip -l "$OUTPUT_FILE" | tail -n +4 | head -n -2 | awk '{print "  " $4}'
    
    # Clean up root directory zip (keep only in build/)
    rm -f "$(basename "$OUTPUT_FILE")"
else
    log_error "Zip verification failed!"
    exit 1
fi

log_success "Ready to flash in Magisk Manager!"
