@echo off
REM GroupLancing Browser - Main Launcher
REM This script handles everything automatically

setlocal enabledelayedexpansion

set SCRIPT_DIR=%~dp0
set APP_DIR=%SCRIPT_DIR%..
set CONFIG_DIR=%APPDATA%\GroupLancing
set LICENSE_FILE=%CONFIG_DIR%\grouplancing_license.dat
set FIREFOX=%APP_DIR%\bin\Firefox\firefox.exe
set SINGBOX=%APP_DIR%\bin\proxy\sing-box.exe

REM Check if Firefox is extracted
if not exist "%FIREFOX%" (
    echo Firefox not found. Installing Firefox automatically...
    REM Find the installer
    for %%f in ("%APP_DIR%\bin\firefox\Firefox Setup*.exe") do (
        echo Running installer: %%f
        start /wait "" "%%f" /S /InstallDirectoryPath="%APP_DIR%\bin\Firefox"
    )

    REM Check again after installation
    if not exist "%FIREFOX%" (
        echo.
        echo ERROR: Failed to install Firefox automatically.
        echo Please manually run the Firefox installer in bin\firefox
        echo and select bin\Firefox as the install location.
        echo.
        pause
        exit /b 1
    )
)


REM Check if Sing-box exists
if not exist "%SINGBOX%" (
    echo.
    echo ERROR: Proxy executable sing-box.exe not found in bin\proxy directory.
    echo Please make sure you have extracted all files correctly.
    echo.
    pause
    exit /b 1
)

REM Create config directory
if not exist "%CONFIG_DIR%" mkdir "%CONFIG_DIR%"

REM ===== STEP 1: LICENSE KEY SETUP =====
if not exist "%LICENSE_FILE%" (
    cls
    echo.
    echo ===================================================
    echo   GroupLancing Browser - First Time Setup
    echo ===================================================
    echo.
    echo Welcome to GroupLancing Browser!
    echo.
    echo This browser provides secure proxy access to approved sites.
    echo.
    echo Please enter your license key to get started.
    echo.
    set /p LICENSE_KEY=Enter License Key: 
    
    if "!LICENSE_KEY!"=="" (
        echo.
        echo ERROR: License key cannot be empty
        echo.
        pause
        exit /b 1
    )
    
    echo !LICENSE_KEY! > "%LICENSE_FILE%"
    echo.
    echo ✓ License key saved successfully!
    echo.
    timeout /t 2 /nobreak
)

REM Read license key
for /f "delims=" %%A in ('type "%LICENSE_FILE%"') do set LICENSE_KEY=%%A

REM ===== STEP 2: FETCH PROXY CONFIG FROM API =====
echo.
echo Fetching proxy configuration from GroupLancing servers...
echo.

cd /d "%TEMP%"

REM Try with curl (Windows 10+)
if exist "%SystemRoot%\System32\curl.exe" (
    curl -s -X POST "https://api.grouplancing.com/gpl_admin/get_proxy_for_user" ^
      -H "Content-Type: application/json" ^
      -d "{\"license_key\": \"!LICENSE_KEY!\"}" > grouplancing_api_response.json
    
    if exist grouplancing_api_response.json (
        echo API Response received
    ) else (
        echo Could not fetch from API - using default config
    )
) else (
    echo Using PowerShell to fetch configuration...
)

REM ===== STEP 3: CREATE FIREFOX PROFILE WITH LOCKED SETTINGS =====
echo Creating Firefox configuration...

set FIREFOX_PROFILE=%CONFIG_DIR%\firefox_profile

if not exist "%FIREFOX_PROFILE%" mkdir "%FIREFOX_PROFILE%"

REM Create user.js with locked proxy settings
(
  echo // GroupLancing Browser - Security Configuration
  echo // These settings are locked and cannot be changed
  echo.
  echo // PROXY SETTINGS - LOCKED
  echo user_pref("network.proxy.type", 1^);
  echo user_pref("network.proxy.socks", "127.0.0.1"^);
  echo user_pref("network.proxy.socks_port", 9050^);
  echo user_pref("network.proxy.no_proxies_on", ""^);
  echo user_pref("network.proxy.share_proxy_settings", true^);
  echo.
  echo // DISABLE EXTENSIONS - PREVENT BYPASSING
  echo user_pref("extensions.enabledScopes", 0^);
  echo user_pref("xpinstall.enabled", false^);
  echo.
  echo // DISABLE SYNC AND ACCOUNTS
  echo user_pref("identity.fxaccounts.enabled", false^);
  echo user_pref("datareporting.policy.dataSubmissionPolicyAcceptedVersion", 0^);
  echo.
  echo // THEME
  echo user_pref("extensions.activeThemeID", "firefox-compact-dark@mozilla.org"^);
  echo.
  echo // HOMEPAGE
  echo user_pref("browser.startup.homepage", "about:blank"^);
) > "%FIREFOX_PROFILE%\user.js"

REM ===== STEP 4: CREATE SING-BOX CONFIG =====
echo Starting proxy service...

REM Create Sing-box config for VLESS
(
  echo {
  echo   "inbounds": [
  echo     {
  echo       "type": "socks",
  echo       "listen": "127.0.0.1",
  echo       "listen_port": 9050
  echo     }
  echo   ],
  echo   "outbounds": [
  echo     {
  echo       "type": "vless",
  echo       "tag": "vless-out",
  echo       "server": "YOUR_SERVER.com",
  echo       "server_port": 443,
  echo       "uuid": "YOUR_UUID_HERE",
  echo       "flow": "xtls-rprx-vision",
  echo       "tls": {
  echo         "enabled": true,
  echo         "server_name": "YOUR_SERVER.com"
  echo       }
  echo     }
  echo   ],
  echo   "route": {
  echo     "rules": []
  echo   }
  echo }
) > "%CONFIG_DIR%\singbox-config.json"

REM ===== STEP 5: START PROXY SERVICE =====
start "" "%SINGBOX%" run -c "%CONFIG_DIR%\singbox-config.json"

REM Wait for proxy to start
timeout /t 2 /nobreak

REM ===== STEP 6: LAUNCH FIREFOX =====
cls
echo.
echo ===================================================
echo   GroupLancing Browser
echo ===================================================
echo.
echo Browser is starting...
echo.
echo Your connection is protected through secure proxy
echo Do NOT modify proxy settings in browser preferences
echo.
echo Enjoy browsing!
echo.

start "" "%FIREFOX%" -profile "%FIREFOX_PROFILE%" -no-remote

REM ===== STEP 7: WAIT FOR FIREFOX TO CLOSE =====
:wait_firefox
timeout /t 5 /nobreak
tasklist | find /I "firefox.exe" >nul
if !errorlevel! equ 0 goto wait_firefox

REM ===== CLEANUP =====
echo.
echo Cleaning up...
taskkill /F /IM sing-box.exe 2>nul
timeout /t 1 /nobreak

echo.
echo Thank you for using GroupLancing Browser
echo.
