
#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

# ============================================
#       ELITEHAXX FF INDIA v3.1
#       SINGLE ROOT SESSION LAUNCHER
# ============================================

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
    printf "${CYAN}[*]${RESET} %s\n" "$*"
}

ok() {
    printf "${GREEN}[+]${RESET} %s\n" "$*"
}

warn() {
    printf "${YELLOW}[!]${RESET} %s\n" "$*"
}

die() {
    printf "${RED}[X]${RESET} %s\n" "$*" >&2
    exit 1
}

banner() {
    printf "${CYAN}"
    cat <<'BANNER'
╔══════════════════════════════════════╗
║                                      ║
║          E L I T E H A X X          ║
║                                      ║
║              FF INDIA                ║
║                                      ║
║           ROOT LAUNCHER              ║
║               v3.1                   ║
║                                      ║
╚══════════════════════════════════════╝
BANNER
    printf "${RESET}\n"
}

WORKDIR=""

cleanup() {
    if [[ -n "$WORKDIR" && -d "$WORKDIR" ]]; then
        rm -rf -- "$WORKDIR"
    fi
}

trap cleanup EXIT

banner

# ============================================
# 1. CHECK DEPENDENCIES
# ============================================

info "Checking Termux dependencies..."

for cmd in \
    curl sha256sum su mktemp \
    od tr awk cmp mv chmod cat; do

    command -v "$cmd" >/dev/null 2>&1 ||
        die "Missing dependency: $cmd"
done

ok "Dependencies verified"

# ============================================
# 2. CREATE CACHE
# ============================================

info "Preparing persistent cache..."

mkdir -p "$CACHE" ||
    die "Cannot create cache"

chmod 700 "$CACHE"

WORKDIR="$(mktemp -d "${TMPDIR:-$PREFIX/tmp}/elitehaxx.XXXXXXXX")" ||
    die "Cannot create workspace"

chmod 700 "$WORKDIR"

ok "Cache and workspace ready"

# ============================================
# 3. CHECK ELF FORMAT
# ============================================

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

get_hash() {
    sha256sum "$1" | awk '{print $1}'
}

valid_cache() {
    local file="$1"
    local saved
    local actual

    [[ -s "$file" ]] || return 1
    [[ -s "${file}.sha256" ]] || return 1

    verify_elf "$file" || return 1

    saved="$(cat "${file}.sha256")" || return 1
    actual="$(get_hash "$file")" || return 1

    [[ "$saved" == "$actual" ]]
}

# ============================================
# 4. DOWNLOAD WITH CACHE
# ============================================

smart_download() {
    local url="$1"
    local dest="$2"
    local name="$3"
    local tmp="$WORKDIR/${name}.download"
    local hash

    info "Checking $name..."

    if valid_cache "$dest"; then
        ok "$name found in cache"
        ok "SHA256 matches"
        info "Download skipped"
        return 0
    fi

    warn "$name missing or failed cache check"
    info "Downloading fresh file..."

    curl \
        -fL \
        -sS \
        --retry 3 \
        --retry-delay 2 \
        --connect-timeout 15 \
        --max-time 180 \
        --proto '=https' \
        -o "$tmp" \
        "$url" ||
        die "Download failed: $name"

    verify_elf "$tmp" ||
        die "Invalid ELF: $name"

    hash="$(get_hash "$tmp")" ||
        die "Hash calculation failed"

    chmod 600 "$tmp"

    mv -f "$tmp" "$dest" ||
        die "Failed to save $name"

    printf '%s\n' "$hash" > "${dest}.sha256" ||
        die "Failed to save checksum"

    chmod 600 "$dest" "${dest}.sha256"

    valid_cache "$dest" ||
        die "Cache verification failed"

    ok "$name downloaded"
    ok "SHA256: $hash"
}

# ============================================
# 5. PREPARE FILES
# ============================================

smart_download \
    "$BIN_URL" \
    "$BIN_CACHE" \
    "casw"

smart_download \
    "$LIB_URL" \
    "$LIB_CACHE" \
    "libcisfc.so"

ok "Both cached files verified"

# ============================================
# 6. GENERATE ROOT SCRIPT
# ============================================

ROOT_SCRIPT="$WORKDIR/root_task.sh"

info "Preparing single root workflow..."

cat > "$ROOT_SCRIPT" <<'END_ROOT_TASK'
#!/system/bin/sh

set -eu

SRC_BIN="$1"
SRC_LIB="$2"

PKG="com.garena.game.ffi"
APP="/data/data/com.garena.game.ffi"

BIN="/data/local/tmp/casw"
LIB="/data/data/com.garena.game.ffi/libcisfc.so"

log() {
    printf '[ROOT] %s\n' "$1"
}

pass() {
    printf '[OK] %s\n' "$1"
}

fail() {
    printf '[ERROR] %s\n' "$1" >&2
    exit 1
}

# --------------------------------------------
# ROOT ID VERIFICATION
# --------------------------------------------

log "Checking root UID..."

if [ "$(id -u)" != "0" ]; then
    fail "Root authorization failed"
fi

pass "Root UID confirmed: 0"

# --------------------------------------------
# PACKAGE CHECK
# --------------------------------------------

log "Checking application..."

if ! pm path "$PKG" 2>/dev/null |
    grep -q '^package:'; then
    fail "Target application not installed"
fi

[ -d "$APP" ] ||
    fail "Application data directory missing"

pass "Application found"

# --------------------------------------------
# VERIFY CACHED SOURCES
# --------------------------------------------

[ -s "$SRC_BIN" ] ||
    fail "Binary source missing"

[ -s "$SRC_LIB" ] ||
    fail "Library source missing"

pass "Source files accessible"

# --------------------------------------------
# PREPARE DESTINATION
# --------------------------------------------

log "Preparing destination..."

mkdir -p /data/local/tmp ||
    fail "Cannot prepare /data/local/tmp"

APP_UID="$(stat -c %u "$APP")" ||
    fail "Cannot read app UID"

APP_GID="$(stat -c %g "$APP")" ||
    fail "Cannot read app GID"

# --------------------------------------------
# COPY EXECUTABLE
# --------------------------------------------

log "Checking executable..."

if cmp -s "$SRC_BIN" "$BIN"; then
    pass "Existing executable matches"
else
    cp -f "$SRC_BIN" "$BIN" ||
        fail "Executable copy failed"

    pass "Executable copied"
fi

chown 0:0 "$BIN" ||
    fail "Executable ownership failed"

chmod 0755 "$BIN" ||
    fail "Executable chmod failed"

cmp -s "$SRC_BIN" "$BIN" ||
    fail "Executable verification failed"

pass "Executable verified"

# --------------------------------------------
# COPY LIBRARY
# --------------------------------------------

log "Checking shared library..."

if cmp -s "$SRC_LIB" "$LIB"; then
    pass "Existing library matches"
else
    cp -f "$SRC_LIB" "$LIB" ||
        fail "Library copy failed"

    pass "Library copied"
fi

chown "$APP_UID:$APP_GID" "$LIB" ||
    fail "Library ownership failed"

chmod 0644 "$LIB" ||
    fail "Library chmod failed"

cmp -s "$SRC_LIB" "$LIB" ||
    fail "Library verification failed"

pass "Library verified"

# --------------------------------------------
# SELINUX LABELS
# --------------------------------------------

log "Restoring file contexts..."

if command -v restorecon >/dev/null 2>&1; then
    restorecon "$BIN" ||
        fail "Binary restorecon failed"

    restorecon "$LIB" ||
        fail "Library restorecon failed"
fi

pass "File contexts checked"

# --------------------------------------------
# FINAL FILE CHECK
# --------------------------------------------

log "Running final file checks..."

[ -x "$BIN" ] ||
    fail "Executable permission invalid"

[ -s "$LIB" ] ||
    fail "Library missing"

pass "Deployment completed"

# --------------------------------------------
# EXACT LAUNCH COMMAND
# --------------------------------------------

log "Launching target..."

cd / ||
    fail "Unable to change to root directory"

if ./data/local/tmp/casw --package com.garena.game.ffi --launch --hide --delay 250000 --libs /data/data/com.garena.game.ffi/libcisfc.so
then
    pass "Launch command exited successfully"
else
    fail "Launch command returned failure"
fi

# --------------------------------------------
# CLEAN LIBRARY AFTER SUCCESS
# --------------------------------------------

log "Cleaning installed library..."

rm -f -- "$LIB" ||
    fail "Library removal failed"

[ ! -e "$LIB" ] ||
    fail "Library still present"

pass "Installed library removed"
pass "Cached library retained"

# --------------------------------------------
# ROOT WORKFLOW COMPLETE
# --------------------------------------------

echo "======================================"
echo " ELITEHAXX FF INDIA ROOT TASK COMPLETE"
echo "======================================"

exit 0
END_ROOT_TASK

# ============================================
# 7. VALIDATE GENERATED ROOT SCRIPT
# ============================================

chmod 700 "$ROOT_SCRIPT" ||
    die "Cannot set root script permissions"

# Check syntax before requesting root.
if command -v /system/bin/sh >/dev/null 2>&1; then
    /system/bin/sh -n "$ROOT_SCRIPT" ||
        die "Generated root script syntax error"
fi

ok "Root script prepared"

# ============================================
# 8. SINGLE SU INVOCATION
# ============================================

info "Requesting root authorization..."

# Keep the complete privileged workflow in one
# root process. No nested su calls.

if su -c "/system/bin/sh '$ROOT_SCRIPT' '$BIN_CACHE' '$LIB_CACHE'"
then
    ok "Root workflow returned success"
else
    die "Root workflow failed"
fi

# ============================================
# 9. FINAL STATUS
# ============================================

printf "\n${GREEN}"
cat <<'END_BANNER'
╔══════════════════════════════════════╗
║                                      ║
║          ELITEHAXX FF INDIA          ║
║                                      ║
║           TASK COMPLETED             ║
║                                      ║
║        SINGLE ROOT REQUEST           ║
║                                      ║
╚══════════════════════════════════════╝
END_BANNER
printf "${RESET}\n"

ok "Persistent cache preserved"
ok "Finished"
