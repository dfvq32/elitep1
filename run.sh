
#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

# ================================================
#             ELITEHAXX FF INDIA
#          ADVANCED ROOT LAUNCHER v1.0
# ================================================

PKG="com.garena.game.ffi"

BIN_URL="https://github.com/dfvq32/elitep1/releases/download/v1.0.0/cwe"
LIB_URL="https://github.com/dfvq32/elitep1/releases/download/v1.0.0/libcisfc.so"

BIN_DEST="/data/local/tmp/casw"
LIB_DEST="/data/data/com.garena.game.ffi/libcisfc.so"

CACHE="$HOME/.elitehaxx/cache/v1.0.0"
BIN_CACHE="$CACHE/casw"
LIB_CACHE="$CACHE/libcisfc.so"

R='\033[1;31m'
G='\033[1;32m'
Y='\033[1;33m'
C='\033[1;36m'
N='\033[0m'

info() {
    printf "${C}[*]${N} %s\n" "$*"
}

ok() {
    printf "${G}[✓]${N} %s\n" "$*"
}

warn() {
    printf "${Y}[!]${N} %s\n" "$*"
}

die() {
    printf "${R}[✗]${N} %s\n" "$*" >&2
    exit 1
}

banner() {
    clear 2>/dev/null || true

    printf "${C}"
    cat <<'EOF'
╔══════════════════════════════════════════╗
║                                          ║
║           E L I T E H A X X              ║
║                                          ║
║                FF INDIA                  ║
║                                          ║
║          ADVANCED ROOT LAUNCHER          ║
║                                          ║
║                 v1.0                     ║
╚══════════════════════════════════════════╝
EOF
    printf "${N}\n"
}

WORKDIR=""

cleanup() {
    if [[ -n "$WORKDIR" && -d "$WORKDIR" ]]; then
        rm -rf -- "$WORKDIR"
    fi
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

banner

# ================================================
# 1. DEPENDENCY VERIFICATION
# ================================================

info "Checking dependencies..."

for cmd in \
    curl \
    sha256sum \
    su \
    mktemp \
    od \
    tr \
    awk \
    cmp \
    mv; do

    command -v "$cmd" >/dev/null 2>&1 ||
        die "Missing dependency: $cmd"
done

ok "Dependencies verified"

# ================================================
# 2. INITIALIZE CACHE AND WORKSPACE
# ================================================

info "Initializing cache..."

mkdir -p "$CACHE" ||
    die "Cannot create cache directory"

chmod 700 "$CACHE"

WORKDIR="$(mktemp -d "${TMPDIR:-$PREFIX/tmp}/elitehaxx.XXXXXXXX")" ||
    die "Cannot create temporary workspace"

chmod 700 "$WORKDIR"

ok "Cache ready"

# ================================================
# 3. ELF FILE VALIDATION
# ================================================

verify_elf() {
    local file="$1"
    local magic

    [[ -s "$file" ]] || return 1

    magic="$(
        od -An -tx1 -N4 "$file" | tr -d ' \n'
    )" || return 1

    [[ "$magic" == "7f454c46" ]]
}

# ================================================
# 4. SHA256 CACHE VERIFICATION
# ================================================

get_hash() {
    sha256sum "$1" | awk '{print $1}'
}

valid_cache() {
    local file="$1"
    local hash_file="${file}.sha256"
    local actual
    local expected

    [[ -s "$file" ]] || return 1
    [[ -s "$hash_file" ]] || return 1

    verify_elf "$file" || return 1

    actual="$(get_hash "$file")" || return 1
    expected="$(cat "$hash_file")" || return 1

    [[ "$actual" == "$expected" ]]
}

# ================================================
# 5. SMART PERSISTENT DOWNLOAD
# ================================================

smart_download() {
    local url="$1"
    local dest="$2"
    local name="$3"

    local temporary="$WORKDIR/$name.download"
    local hash

    printf "\n"
    info "Checking $name..."

    if valid_cache "$dest"; then
        ok "$name already downloaded"
        ok "SHA256 matches saved checksum"
        info "Skipping download"
        return 0
    fi

    if [[ -e "$dest" ]]; then
        warn "Existing cache failed verification"
    else
        warn "No cached file found"
    fi

    info "Downloading $name..."

    curl \
        --fail \
        --location \
        --silent \
        --show-error \
        --retry 4 \
        --retry-delay 2 \
        --connect-timeout 15 \
        --max-time 180 \
        --proto '=https' \
        --tlsv1.2 \
        --output "$temporary" \
        "$url" ||
        die "Download failed: $name"

    [[ -s "$temporary" ]] ||
        die "Downloaded file is empty: $name"

    verify_elf "$temporary" ||
        die "Invalid ELF file: $name"

    hash="$(get_hash "$temporary")" ||
        die "Unable to calculate SHA256"

    chmod 600 "$temporary"

    mv -f "$temporary" "$dest" ||
        die "Unable to store $name"

    printf '%s\n' "$hash" > "${dest}.sha256" ||
        die "Unable to store checksum"

    chmod 600 "$dest" "${dest}.sha256"

    valid_cache "$dest" ||
        die "Downloaded cache verification failed"

    ok "$name downloaded successfully"
    ok "SHA256: $hash"
}

# ================================================
# 6. DOWNLOAD OR REUSE FILES
# ================================================

smart_download \
    "$BIN_URL" \
    "$BIN_CACHE" \
    "casw"

smart_download \
    "$LIB_URL" \
    "$LIB_CACHE" \
    "libcisfc.so"

printf "\n"
ok "Both files ready"

# ================================================
# 7. PREPARE SINGLE ROOT WORKFLOW
# ================================================

info "Preparing root workflow..."

ROOT_SCRIPT="$WORKDIR/root_task.sh"

cat > "$ROOT_SCRIPT" <<'ROOTSCRIPT'
#!/system/bin/sh

set -eu

SRC_BIN="$1"
SRC_LIB="$2"

PKG="com.garena.game.ffi"

BIN="/data/local/tmp/casw"
LIB="/data/data/com.garena.game.ffi/libcisfc.so"
APP="/data/data/com.garena.game.ffi"

log() {
    printf '[*] %s\n' "$1"
}

ok() {
    printf '[+] %s\n' "$1"
}

fail() {
    printf '[!] ERROR: %s\n' "$1" >&2
    exit 1
}

# ================================================
# ROOT CHECK - NO ADDITIONAL SU CALL
# ================================================

log "Verifying root session..."

[ "$(id -u)" = "0" ] ||
    fail "Root access not granted"

ok "Root session active"

# ================================================
# PACKAGE VERIFICATION
# ================================================

log "Checking target package..."

pm path "$PKG" 2>/dev/null |
    grep -q '^package:' ||
    fail "Target package not installed"

[ -d "$APP" ] ||
    fail "Application data directory missing"

ok "Package verified: $PKG"

# ================================================
# VERIFY SOURCE FILES
# ================================================

log "Checking cached source files..."

[ -s "$SRC_BIN" ] ||
    fail "Cached executable missing"

[ -s "$SRC_LIB" ] ||
    fail "Cached library missing"

ok "Source files verified"

# ================================================
# INSTALL BINARY
# ================================================

log "Checking executable destination..."

mkdir -p /data/local/tmp ||
    fail "Cannot prepare binary directory"

if cmp -s "$SRC_BIN" "$BIN"; then
    ok "Binary already matches cache"
else
    log "Copying executable..."
    cp -f "$SRC_BIN" "$BIN" ||
        fail "Failed to install executable"
fi

chown 0:0 "$BIN" ||
    fail "Binary ownership failed"

chmod 0755 "$BIN" ||
    fail "Binary permission failed"

cmp -s "$SRC_BIN" "$BIN" ||
    fail "Binary integrity mismatch"

ok "Executable installed and verified"

# ================================================
# INSTALL LIBRARY
# ================================================

log "Checking library destination..."

APP_UID="$(stat -c %u "$APP")"
APP_GID="$(stat -c %g "$APP")"

if cmp -s "$SRC_LIB" "$LIB"; then
    ok "Library already matches cache"
else
    log "Copying library..."
    cp -f "$SRC_LIB" "$LIB" ||
        fail "Failed to install library"
fi

chown "$APP_UID:$APP_GID" "$LIB" ||
    fail "Library ownership failed"

chmod 0644 "$LIB" ||
    fail "Library permissions failed"

cmp -s "$SRC_LIB" "$LIB" ||
    fail "Library integrity mismatch"

ok "Library installed and verified"

# ================================================
# RESTORE SELINUX FILE LABELS
# ================================================

log "Checking SELinux contexts..."

if command -v restorecon >/dev/null 2>&1; then
    restorecon "$BIN" ||
        fail "Binary context restoration failed"

    restorecon "$LIB" ||
        fail "Library context restoration failed"

    ok "SELinux contexts restored"
else
    log "restorecon unavailable"
fi

# ================================================
# FINAL FILE VALIDATION
# ================================================

log "Running final checks..."

[ -x "$BIN" ] ||
    fail "Executable is not executable"

[ -s "$LIB" ] ||
    fail "Installed library is missing"

cmp -s "$SRC_BIN" "$BIN" ||
    fail "Executable verification failed"

cmp -s "$SRC_LIB" "$LIB" ||
    fail "Library verification failed"

ok "All deployment checks passed"

# ================================================
# EXACT LAUNCH COMMAND
# ================================================

log "Launching ELITEHAXX FF INDIA..."

cd / || fail "Cannot change directory to /"

if ./data/local/tmp/casw --package com.garena.game.ffi --launch --hide --delay 250000 --libs /data/data/com.garena.game.ffi/libcisfc.so
then
    ok "Launch command completed successfully"
else
    fail "Launch command failed; library retained"
fi

# ================================================
# CLEAN INSTALLED LIBRARY AFTER SUCCESS
# ================================================

log "Removing installed library..."

rm -f -- "$LIB" ||
    fail "Library removal failed"

[ ! -e "$LIB" ] ||
    fail "Library still exists"

ok "Installed library removed"

# ================================================
# COMPLETION
# ================================================

printf '\n'
echo "=========================================="
echo "       ELITEHAXX FF INDIA - SUCCESS"
echo "=========================================="

ok "Root workflow completed"
ok "Persistent Termux cache retained"

exit 0
ROOTSCRIPT

chmod 700 "$ROOT_SCRIPT" ||
    die "Unable to prepare root script"

# ================================================
# 8. SINGLE ROOT AUTHORIZATION
# ================================================

printf "\n"
info "Requesting root permission once..."

if su -c "sh '$ROOT_SCRIPT' '$BIN_CACHE' '$LIB_CACHE'"; then
    ok "Root execution completed"
else
    die "Root workflow failed"
fi

# ================================================
# 9. FINAL UI
# ================================================

printf "\n${G}"
cat <<'EOF'
╔══════════════════════════════════════════╗
║                                          ║
║           ELITEHAXX FF INDIA             ║
║                                          ║
║             TASK COMPLETE                ║
║                                          ║
║          SINGLE ROOT SESSION             ║
║           SMART CACHE ENABLED            ║
║                                          ║
╚══════════════════════════════════════════╝
EOF
printf "${N}\n"

ok "Done"
