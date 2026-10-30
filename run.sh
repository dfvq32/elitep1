
#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

# ELITEHAXX FF INDIA - VERSION 3.2
# Single root request, smart cache, verified workflow.

PKG="com.garena.game.ffi"

BIN_URL="https://github.com/dfvq32/elitep1/releases/download/v1.0.0/cwe"
LIB_URL="https://github.com/dfvq32/elitep1/releases/download/v1.0.0/libcisfc.so"

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
cat <<'END_BANNER'
╔══════════════════════════════════════╗
║                                      ║
║          E L I T E H A X X          ║
║                                      ║
║              FF INDIA                ║
║                                      ║
║        SINGLE ROOT LAUNCHER          ║
║               v3.2                   ║
║                                      ║
╚══════════════════════════════════════╝
END_BANNER
printf "${RESET}\n"

# ----------------------------------------
# Dependencies
# ----------------------------------------

info "Checking dependencies..."

for cmd in curl sha256sum su mktemp od tr cmp; do
    command -v "$cmd" >/dev/null 2>&1 ||
        die "Missing dependency: $cmd"
done

ok "Dependencies verified"

# ----------------------------------------
# Workspace
# ----------------------------------------

mkdir -p "$CACHE" ||
    die "Cache creation failed"

chmod 700 "$CACHE"

WORKDIR="$(mktemp -d "${TMPDIR:-$PREFIX/tmp}/elitehaxx.XXXXXXXX")" ||
    die "Workspace creation failed"

trap 'rm -rf -- "$WORKDIR"' EXIT

ROOT_SCRIPT="$WORKDIR/root_task.sh"
ROOT_MARKER="$WORKDIR/root_complete"

# ----------------------------------------
# ELF verification
# ----------------------------------------

verify_elf() {
    local magic

    [[ -s "$1" ]] || return 1

    magic="$(
        od -An -tx1 -N4 "$1" | tr -d ' \n'
    )" || return 1

    [[ "$magic" == "7f454c46" ]]
}

file_hash() {
    local result
    result="$(sha256sum "$1")" || return 1
    printf '%s\n' "${result%% *}"
}

valid_cache() {
    local file="$1"
    local expected actual

    [[ -s "$file" ]] || return 1
    [[ -s "$file.sha256" ]] || return 1

    verify_elf "$file" || return 1

    expected="$(cat "$file.sha256")" || return 1
    actual="$(file_hash "$file")" || return 1

    [[ "$expected" == "$actual" ]]
}

# ----------------------------------------
# Smart download
# ----------------------------------------

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

    warn "$name cache missing or invalid"
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
        die "Invalid ELF: $name"

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

    ok "$name downloaded and verified"
}

# ----------------------------------------
# Prepare cached files
# ----------------------------------------

smart_download "$BIN_URL" "$BIN_CACHE" "casw"
smart_download "$LIB_URL" "$LIB_CACHE" "libcisfc.so"

ok "Both files ready"

# ----------------------------------------
# Create root worker
# ----------------------------------------

info "Preparing root workflow..."

cat > "$ROOT_SCRIPT" <<'END_ELITE_ROOT'
#!/system/bin/sh
set -eu

SRC_BIN="$1"
SRC_LIB="$2"
MARKER="$3"

PKG="com.garena.game.ffi"
APP="/data/data/com.garena.game.ffi"
BIN="/data/local/tmp/casw"
LIB="/data/data/com.garena.game.ffi/libcisfc.so"

log() {
    printf '[ROOT] %s\n' "$1"
}

ok() {
    printf '[OK] %s\n' "$1"
}

fail() {
    printf '[ERROR] %s\n' "$1" >&2
    exit 1
}

log "ROOT WORKFLOW STARTED"

# Check root identity.
[ "$(id -u)" = "0" ] ||
    fail "Root permission denied"

ok "Root UID: 0"

# Check application.
log "Checking package..."

pm path "$PKG" 2>/dev/null |
    grep -q '^package:' ||
    fail "Package not installed"

[ -d "$APP" ] ||
    fail "Application data directory missing"

ok "Target package found"

# Check cached files.
[ -s "$SRC_BIN" ] ||
    fail "Cached binary missing"

[ -s "$SRC_LIB" ] ||
    fail "Cached library missing"

# Prepare destination.
mkdir -p /data/local/tmp ||
    fail "Cannot create binary directory"

APP_UID="$(stat -c %u "$APP")" ||
    fail "Cannot determine app UID"

APP_GID="$(stat -c %g "$APP")" ||
    fail "Cannot determine app GID"

# Reject unexpected symbolic links.
[ ! -L "$BIN" ] ||
    fail "Binary destination is a symlink"

[ ! -L "$LIB" ] ||
    fail "Library destination is a symlink"

# Install binary.
log "Installing executable..."

if ! cmp -s "$SRC_BIN" "$BIN"; then
    cp -f "$SRC_BIN" "$BIN" ||
        fail "Binary copy failed"
fi

chown 0:0 "$BIN" ||
    fail "Binary chown failed"

chmod 0755 "$BIN" ||
    fail "Binary chmod failed"

cmp -s "$SRC_BIN" "$BIN" ||
    fail "Binary content mismatch"

ok "Binary verified"

# Install library.
log "Installing library..."

if ! cmp -s "$SRC_LIB" "$LIB"; then
    cp -f "$SRC_LIB" "$LIB" ||
        fail "Library copy failed"
fi

chown "$APP_UID:$APP_GID" "$LIB" ||
    fail "Library chown failed"

chmod 0644 "$LIB" ||
    fail "Library chmod failed"

cmp -s "$SRC_LIB" "$LIB" ||
    fail "Library content mismatch"

ok "Library verified"

# Restore file contexts.
if command -v restorecon >/dev/null 2>&1; then
    restorecon "$BIN" ||
        fail "Binary restorecon failed"

    restorecon "$LIB" ||
        fail "Library restorecon failed"
fi

# Final deployment check.
[ -x "$BIN" ] ||
    fail "Executable not runnable"

[ -s "$LIB" ] ||
    fail "Library unavailable"

ok "All file checks passed"

# ----------------------------------------
# Execute exact requested command
# ----------------------------------------

log "LAUNCH STARTED"

cd / ||
    fail "Cannot change directory"

if ./data/local/tmp/casw --package com.garena.game.ffi --launch --hide --delay 250000 --libs /data/data/com.garena.game.ffi/libcisfc.so
then
    ok "Launch command returned exit code 0"
else
    STATUS=$?
    log "Launch failed with exit code $STATUS"
    exit "$STATUS"
fi

# ----------------------------------------
# Remove installed library
# ----------------------------------------

log "Cleaning installed library..."

rm -f -- "$LIB" ||
    fail "Library cleanup failed"

[ ! -e "$LIB" ] ||
    fail "Library still exists"

ok "Installed library removed"

# Create actual completion marker.
printf 'COMPLETE\n' > "$MARKER" ||
    fail "Cannot write completion marker"

log "ROOT WORKFLOW FINISHED"

exit 0
END_ELITE_ROOT

chmod 700 "$ROOT_SCRIPT" ||
    die "Cannot set root script permissions"

# ----------------------------------------
# Check root script syntax
# ----------------------------------------

info "Validating generated script..."

/system/bin/sh -n "$ROOT_SCRIPT" ||
    die "Root script syntax invalid"

ok "Syntax verified"

# ----------------------------------------
# Request root only once
# ----------------------------------------

info "Requesting root permission once..."

if su -c "/system/bin/sh '$ROOT_SCRIPT' '$BIN_CACHE' '$LIB_CACHE' '$ROOT_MARKER'" </dev/null
then
    ok "Root command returned"
else
    die "Root command failed"
fi

# ----------------------------------------
# Confirm actual workflow completion
# ----------------------------------------

info "Verifying completion marker..."

if [[ ! -f "$ROOT_MARKER" ]]; then
    die "Root command returned, but workflow did not complete"
fi

if [[ "$(cat "$ROOT_MARKER")" != "COMPLETE" ]]; then
    die "Invalid root completion marker"
fi

ok "Root workflow confirmed"

printf "\n${GREEN}"
cat <<'END_SUCCESS'
╔══════════════════════════════════════╗
║                                      ║
║          ELITEHAXX FF INDIA          ║
║                                      ║
║          WORKFLOW COMPLETE           ║
║                                      ║
║         SINGLE ROOT REQUEST          ║
║                                      ║
╚══════════════════════════════════════╝
END_SUCCESS
printf "${RESET}\n"

ok "Cached downloads retained"
ok "Finished"
END_SUCCESS_UNUSED
