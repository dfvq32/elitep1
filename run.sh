
#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail
umask 077

# ===========================================
#          ELITEHAXX FF INDIA
#           ROOT LAUNCHER v4.0
# ===========================================

PREFIX="/data/data/com.termux/files/usr"
HOME="/data/data/com.termux/files/home"

export PREFIX HOME
export PATH="$PREFIX/bin:/system/bin:/system/xbin:${PATH:-}"
export TMPDIR="$PREFIX/tmp"

PKG="com.garena.game.ffi"

BIN_URL="https://github.com/dfvq32/elitep1/releases/download/v1.0.0/cwe"
LIB_URL="https://github.com/dfvq32/elitep1/releases/download/v1.0.0/libcisfc.so"

BIN_DEST="/data/local/tmp/casw"
LIB_DEST="/data/data/com.garena.game.ffi/libcisfc.so"

CACHE="$HOME/.elitehaxx/cache/v1.0.0"
BIN_CACHE="$CACHE/casw"
LIB_CACHE="$CACHE/libcisfc.so"

RED='\033[1;31m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
RESET='\033[0m'

info() {
    printf "${CYAN}[*]${RESET} %s\n" "$1"
}

ok() {
    printf "${GREEN}[✓]${RESET} %s\n" "$1"
}

warn() {
    printf "${YELLOW}[!]${RESET} %s\n" "$1"
}

die() {
    printf "${RED}[✗]${RESET} %s\n" "$1" >&2
    exit 1
}

printf "${CYAN}"
printf '%s\n' \
'╔══════════════════════════════════════╗' \
'║                                      ║' \
'║         E L I T E H A X X          ║' \
'║                                      ║' \
'║              FF INDIA                ║' \
'║                                      ║' \
'║          ROOT LAUNCHER v4.0          ║' \
'║                                      ║' \
'╚══════════════════════════════════════╝'
printf "${RESET}\n"

# ===========================================
# 1. ROOT VERIFICATION
# NO SU COMMANDS INSIDE THE SCRIPT
# ===========================================

info "Checking root session..."

if [[ "$(id -u)" != "0" ]]; then
    die "Run using external root permission"
fi

ok "Root access already active"

# ===========================================
# 2. DEPENDENCY VERIFICATION
# ===========================================

info "Checking dependencies..."

for cmd in \
    curl sha256sum mktemp od \
    tr cmp stat cp chown chmod \
    mv rm grep cat; do

    command -v "$cmd" >/dev/null 2>&1 ||
        die "Missing dependency: $cmd"
done

ok "Dependencies verified"

# ===========================================
# 3. PACKAGE VERIFICATION
# ===========================================

info "Checking target package..."

if ! /system/bin/pm path "$PKG" 2>/dev/null |
    grep -q '^package:'; then

    die "Package not installed: $PKG"
fi

APP="/data/data/$PKG"

[[ -d "$APP" ]] ||
    die "Application data directory missing"

ok "Package verified: $PKG"

# ===========================================
# 4. INITIALIZE CACHE
# ===========================================

info "Preparing persistent cache..."

mkdir -p "$CACHE" ||
    die "Cannot create cache directory"

chmod 700 "$CACHE"

WORKDIR="$(mktemp -d "$TMPDIR/elitehaxx.XXXXXXXX")" ||
    die "Cannot create temporary workspace"

cleanup() {
    if [[ -n "${WORKDIR:-}" ]]; then
        rm -rf -- "$WORKDIR"
    fi
}

trap cleanup EXIT

ok "Cache ready"

# ===========================================
# 5. ELF FORMAT VERIFICATION
# ===========================================

verify_elf() {
    local file="$1"
    local magic

    [[ -s "$file" ]] || return 1

    magic="$(
        od -An -tx1 -N4 "$file" |
        tr -d ' \n'
    )" || return 1

    [[ "$magic" == "7f454c46" ]]
}

# ===========================================
# 6. SHA256 VERIFICATION
# ===========================================

file_hash() {
    local result

    result="$(sha256sum "$1")" ||
        return 1

    printf '%s\n' "${result%% *}"
}

valid_cache() {
    local file="$1"
    local expected actual

    [[ -s "$file" ]] || return 1
    [[ -s "$file.sha256" ]] || return 1

    verify_elf "$file" || return 1

    expected="$(cat "$file.sha256")" ||
        return 1

    actual="$(file_hash "$file")" ||
        return 1

    [[ "$expected" == "$actual" ]]
}

# ===========================================
# 7. SMART CACHE DOWNLOAD
# ===========================================

smart_download() {
    local url="$1"
    local dest="$2"
    local name="$3"

    local temp="$WORKDIR/$name.download"
    local hash

    info "Checking $name..."

    if valid_cache "$dest"; then

        ok "$name already cached"
        ok "SHA256 matched"
        info "Download skipped"

        return 0
    fi

    warn "$name missing or checksum mismatch"
    info "Downloading $name..."

    curl \
        --fail \
        --location \
        --silent \
        --show-error \
        --retry 3 \
        --retry-delay 2 \
        --connect-timeout 15 \
        --max-time 180 \
        --proto '=https' \
        -o "$temp" \
        "$url" ||
        die "Download failed: $name"

    verify_elf "$temp" ||
        die "Invalid ELF file: $name"

    hash="$(file_hash "$temp")" ||
        die "Hash calculation failed"

    chmod 600 "$temp"

    mv -f "$temp" "$dest" ||
        die "Cannot save $name"

    printf '%s\n' "$hash" > "$dest.sha256" ||
        die "Cannot save checksum"

    chmod 600 "$dest" "$dest.sha256"

    valid_cache "$dest" ||
        die "Cache verification failed"

    ok "$name downloaded successfully"
}

# ===========================================
# 8. DOWNLOAD OR REUSE FILES
# ===========================================

smart_download \
    "$BIN_URL" \
    "$BIN_CACHE" \
    "casw"

smart_download \
    "$LIB_URL" \
    "$LIB_CACHE" \
    "libcisfc.so"

ok "Both files ready"

# ===========================================
# 9. DEPLOY EXECUTABLE
# ===========================================

info "Checking binary destination..."

mkdir -p /data/local/tmp ||
    die "Cannot prepare binary directory"

[[ ! -L "$BIN_DEST" ]] ||
    die "Executable destination is a symlink"

if cmp -s "$BIN_CACHE" "$BIN_DEST"; then

    ok "Executable already matches cache"

else

    info "Installing executable..."

    cp -f "$BIN_CACHE" "$BIN_DEST" ||
        die "Executable copy failed"
fi

chown 0:0 "$BIN_DEST" ||
    die "Executable ownership failed"

chmod 0755 "$BIN_DEST" ||
    die "Executable permissions failed"

cmp -s "$BIN_CACHE" "$BIN_DEST" ||
    die "Executable verification failed"

ok "Executable installed and verified"

# ===========================================
# 10. DEPLOY SHARED LIBRARY
# ===========================================

info "Checking library destination..."

APP_UID="$(stat -c %u "$APP")" ||
    die "Cannot get app UID"

APP_GID="$(stat -c %g "$APP")" ||
    die "Cannot get app GID"

[[ ! -L "$LIB_DEST" ]] ||
    die "Library destination is a symlink"

if cmp -s "$LIB_CACHE" "$LIB_DEST"; then

    ok "Library already matches cache"

else

    info "Installing shared library..."

    cp -f "$LIB_CACHE" "$LIB_DEST" ||
        die "Library copy failed"
fi

chown "$APP_UID:$APP_GID" "$LIB_DEST" ||
    die "Library ownership failed"

chmod 0644 "$LIB_DEST" ||
    die "Library permissions failed"

cmp -s "$LIB_CACHE" "$LIB_DEST" ||
    die "Library verification failed"

ok "Library installed and verified"

# ===========================================
# 11. RESTORE SELINUX CONTEXTS
# ===========================================

info "Checking file contexts..."

if command -v restorecon >/dev/null 2>&1; then

    restorecon "$BIN_DEST" ||
        die "Executable context restoration failed"

    restorecon "$LIB_DEST" ||
        die "Library context restoration failed"
fi

ok "File context checks completed"

# ===========================================
# 12. FINAL VERIFICATION
# ===========================================

info "Performing final checks..."

[[ -x "$BIN_DEST" ]] ||
    die "Executable is not runnable"

[[ -s "$LIB_DEST" ]] ||
    die "Library missing"

cmp -s "$BIN_CACHE" "$BIN_DEST" ||
    die "Binary integrity mismatch"

cmp -s "$LIB_CACHE" "$LIB_DEST" ||
    die "Library integrity mismatch"

ok "All verification checks passed"

# ===========================================
# 13. EXECUTE EXACT COMMAND
# ===========================================

info "Starting ELITEHAXX FF INDIA..."

cd / ||
    die "Unable to change directory"

if ./data/local/tmp/casw --package com.garena.game.ffi --launch --hide --delay 250000 --libs /data/data/com.garena.game.ffi/libcisfc.so
then

    ok "Launch command returned success"

else

    STATUS=$?

    die "Launch command failed: exit code $STATUS"
fi

# ===========================================
# 14. CLEAN INSTALLED LIBRARY
# ===========================================

info "Cleaning installed library..."

rm -f -- "$LIB_DEST" ||
    die "Library removal failed"

[[ ! -e "$LIB_DEST" ]] ||
    die "Installed library still exists"

ok "Installed library removed"
ok "Cached library preserved"

# ===========================================
# 15. COMPLETION
# ===========================================

printf "\n${GREEN}"

printf '%s\n' \
'╔══════════════════════════════════════╗' \
'║                                      ║' \
'║          ELITEHAXX FF INDIA          ║' \
'║                                      ║' \
'║          WORKFLOW COMPLETE           ║' \
'║                                      ║' \
'║         EXTERNAL ROOT MODE           ║' \
'║                                      ║' \
'╚══════════════════════════════════════╝'

printf "${RESET}\n"

ok "Finished successfully"
