@echo off
REM KTweak Magisk Module Build Script (Windows)
REM Builds a flashable Magisk module zip with automatic versioning

setlocal EnableDelayedExpansion

REM Configuration
set MODULE_NAME=KTweak
set MODULE_DIR=magisk
set BUILD_DIR=build
set VERSION_FILE=%MODULE_DIR%\module.prop

REM Colors (ANSI escape codes for Windows 10+)
for /F "tokens=1,2 delims=#" %%a in ('"prompt #$H#$E# & echo on & for %%b in (1) do rem"') do (
  set "DEL=%%a"
  set "ESC=%%b"
)

set "BLUE=%ESC%[34m"
set "GREEN=%ESC%[32m"
set "YELLOW=%ESC%[33m"
set "RED=%ESC%[31m"
set "NC=%ESC%[0m"

:log_info
echo %BLUE%[INFO]%NC% %~1
goto :eof

:log_success
echo %GREEN%[SUCCESS]%NC% %~1
goto :eof

:log_warn
echo %YELLOW%[WARN]%NC% %~1
goto :eof

:log_error
echo %RED%[ERROR]%NC% %~1
goto :eof

REM Check if running from correct directory
if not exist "%MODULE_DIR%" (
    call :log_error "Error: Must run from repository root where '%MODULE_DIR%' directory exists"
    exit /b 1
)

REM Check if module.prop exists
if not exist "%VERSION_FILE%" (
    call :log_error "Error: %VERSION_FILE% not found"
    exit /b 1
)

REM Extract version from module.prop
for /f "tokens=2 delims==" %%i in ('findstr "^version=" "%VERSION_FILE%"') do set VERSION=%%i
for /f "tokens=2 delims==" %%i in ('findstr "^versionCode=" "%VERSION_FILE%"') do set VERSION_CODE=%%i

if "%VERSION%"=="" (
    call :log_error "Error: Could not extract version from %VERSION_FILE%"
    goto :cleanup
)

REM Remove leading 'v' if present for consistent filename
set VERSION_CLEAN=%VERSION:v=%

call :log_info "Building %MODULE_NAME% v%VERSION_CLEAN% (code: %VERSION_CODE%)"

REM Create build directory
if exist "%BUILD_DIR%" rmdir /s /q "%BUILD_DIR%"
mkdir "%BUILD_DIR%"

REM Create temporary build structure
set "TEMP_DIR=%TEMP%\ktweak_build_%RANDOM%"
mkdir "%TEMP_DIR%"

REM Copy module files
call :log_info "Copying module files..."
xcopy /E /I /Q /Y "%MODULE_DIR%\*" "%TEMP_DIR%" > nul

REM Validate required files exist
set "REQUIRED_FILES=module.prop post-fs-data.sh service.sh system\bin\ktweak.sh"
for %%f in (%REQUIRED_FILES%) do (
    if not exist "%TEMP_DIR%\%%f" (
        call :log_error "Error: Required file %%f not found"
        goto :cleanup
    )
)

REM Run syntax checks on shell scripts (requires WSL or Git Bash)
call :log_info "Running syntax validation..."
set "SHELL_SCRIPTS=post-fs-data.sh service.sh system\bin\ktweak.sh"
for %%f in (%SHELL_SCRIPTS%) do (
    where sh >nul 2>nul
    if %ERRORLEVEL%==0 (
        sh -n "%TEMP_DIR%\%%f" 2>nul
        if errorlevel 1 (
            call :log_error "Syntax error in %%f"
            goto :cleanup
        )
        call :log_info "  OK: %%f"
    ) else (
        call :log_warn "sh.exe not found, skipping syntax check for %%f"
    )
)

REM Check if zip is available
where zip >nul 2>nul
if errorlevel 1 (
    call :log_error "zip.exe not found. Please install Info-ZIP or use WSL."
    goto :cleanup
)

REM Create zip archive
set "OUTPUT_FILE=%BUILD_DIR%\%MODULE_NAME%-v%VERSION_CLEAN%.zip"
call :log_info "Creating zip archive: %OUTPUT_FILE%"

REM Ensure build directory exists
if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"

cd /d "%TEMP_DIR%"
zip -rq9 "%OUTPUT_FILE%" .
if errorlevel 1 (
    cd /d "%~dp0"
    call :log_error "Failed to create zip archive"
    goto :cleanup
)
cd /d "%~dp0"

REM Verify zip integrity
where unzip >nul 2>nul
if not errorlevel 1 (
    unzip -t "%OUTPUT_FILE%" >nul 2>&1
    if errorlevel 1 (
        call :log_error "Zip verification failed!"
        goto :cleanup
    )
)

call :log_success "Build completed successfully!"
call :log_info "Output file: %CD%\%OUTPUT_FILE%"

REM Show file size
for %%A in ("%OUTPUT_FILE%") do set "FILE_SIZE=%%~zA"
call :log_info "File size: %FILE_SIZE% bytes"

REM Show contents summary
call :log_info "Module contents:"
if exist unzip.exe (
    unzip -l "%OUTPUT_FILE%" | findstr /V "^$" | findstr /V "^Archive:" | findstr /V "^----"
) else (
    dir "%TEMP_DIR%" /s /b
)

:cleanup
rmdir /s /q "%TEMP_DIR%" 2>nul

if not errorlevel 1 (
    call :log_success "Ready to flash in Magisk Manager!"
) else (
    call :log_error "Build failed!"
    exit /b 1
)

endlocal
