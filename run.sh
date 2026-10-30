
#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

# ===============================================
#             ELITEHAXX FF INDIA
#           ROOT LAUNCHER | VERSION 2.0
# ===============================================

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
B='\033[1;34m'
N='\033[0m'

info() {
    printf "${C}[*]${N} %s\n" "$*"
}

success() {
    printf "${G}[✓]${N} %s\n" "$*"
}

warning() {
    printf "${Y}[!]${N} %s\n" "$*"
}

error() {
    printf "${R}[✗]${N} %s\n" "$*" >&2
    exit 1
}

banner() {
    clear 2>/dev/null || true

    printf "${C}"
    cat <<'EOF'
╔══════════════════════════════════════════╗
║                                          ║
║          E L I T E H A X X               ║
║                                          ║
║               FF INDIA                   ║
║                                          ║
║       ADVANCED ROOT LAUNCHER             ║
║                                          ║
║                v2.0                      ║
╚══════════════════════════════════════════╝
EOF
    printf "${N}\n"
}

WORKDIR=""

cleanup_temp() {
    if [[ -n "$WORKDIR" && -d "$WORKDIR" ]]; then
        rm -rf -- "$WORKDIR"
    fi
}

trap cleanup_temp EXIT

trap 'warning "Interrupted"; exit 130' INT TERM

banner

# ===============================================
# 1. DEPENDENCY CHECK
# ===============================================

info "Checking Termux dependencies..."

for cmd in \
    curl \
    sha256sum \
    su \
    mktemp \
    od \
    cmp \
    awk \
    mv; do

    command -v "$cmd" >/dev/null 2>&1 ||
        error "Missing command: $cmd"
done

success "Dependencies verified"

# ===============================================
# 2. ROOT CHECK
# ===============================================

info "Checking root access..."

ROOT_UID="$(su -c 'id -u' 2>/dev/null)" ||
    error "Root access denied"

[[ "$ROOT_UID" == "0" ]] ||
    error "Root UID is not 0"

success "Root access verified"

# ===============================================
# 3. PACKAGE CHECK
# ===============================================

info "Checking Free Fire India package..."

if ! su -c "pm path '$PKG'" 2>/dev/null |
    grep -q '^package:'; then

    error "Package not installed: $PKG"
fi

if ! su -c "test -d '/data/data/$PKG'"; then
    error "Package data directory missing"
fi

success "Package found: $PKG"

# ===============================================
# 4. CACHE INITIALIZATION
# ===============================================

info "Initializing persistent cache..."

mkdir -p "$CACHE" ||
    error "Cannot create cache directory"

chmod 700 "$CACHE"

WORKDIR="$(mktemp -d "${TMPDIR:-$PREFIX/tmp}/elitehaxx.XXXXXXXX")" ||
    error "Unable to create workspace"

chmod 700 "$WORKDIR"

success "Cache initialized"

# ===============================================
# 5. ELF FORMAT VALIDATION
# ===============================================

verify_elf() {
    local file="$1"
    local magic

    [[ -s "$file" ]] || return 1

    magic="$(od -An -tx1 -N4 "$file" |
        tr -d ' \n')" || return 1

    [[ "$magic" == "7f454c46" ]]
}

# ===============================================
# 6. SHA256 CACHE VALIDATION
# ===============================================

get_hash() {
    sha256sum "$1" | awk '{print $1}'
}

valid_hash() {
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

# ===============================================
# 7. SMART DOWNLOAD AND CACHE
# ===============================================

smart_download() {
    local url="$1"
    local dest="$2"
    local name="$3"

    local temp_file="$WORKDIR/$name.download"
    local current_hash

    printf "\n"
    info "Checking cached $name..."

    if valid_hash "$dest"; then

        success "$name cache is valid"
        success "SHA256 matched"

        printf "${G}[CACHE HIT]${N} Download skipped\n"

        return 0
    fi

    if [[ -e "$dest" ]]; then
        warning "$name cache invalid or hash mismatch"
    else
        warning "$name not found in cache"
    fi

    info "Downloading fresh $name..."

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
        --output "$temp_file" \
        "$url" ||
        error "Download failed: $name"

    [[ -s "$temp_file" ]] ||
        error "Downloaded file is empty: $name"

    verify_elf "$temp_file" ||
        error "Invalid ELF format: $name"

    current_hash="$(get_hash "$temp_file")" ||
        error "SHA256 calculation failed"

    chmod 600 "$temp_file"

    # Atomically replace cache contents and hash.
    mv -f "$temp_file" "$dest" ||
        error "Failed to save $name"

    printf '%s\n' "$current_hash" > "${dest}.sha256" ||
        error "Cannot save SHA256"

    chmod 600 "$dest" "${dest}.sha256"

    valid_hash "$dest" ||
        error "Cache verification failed: $name"

    success "$name downloaded and cached"
    success "SHA256: $current_hash"
}

# ===============================================
# 8. PREPARE BOTH FILES
# ===============================================

smart_download \
    "$BIN_URL" \
    "$BIN_CACHE" \
    "casw"

smart_download \
    "$LIB_URL" \
    "$LIB_CACHE" \
    "libcisfc.so"

printf "\n"
success "All required files ready"

# ===============================================
# 9. CREATE ROOT DEPLOY SCRIPT
# ===============================================

info "Preparing root deployment..."

cat > "$WORKDIR/root_deploy.sh" <<'ROOT'
#!/system/bin/sh

set -eu

SRC_BIN="$1"
SRC_LIB="$2"

BIN="/data/local/tmp/casw"
LIB="/data/data/com.garena.game.ffi/libcisfc.so"
APP="/data/data/com.garena.game.ffi"

test -d "$APP" || exit 20
test -s "$SRC_BIN" || exit 21
test -s "$SRC_LIB" || exit 22

mkdir -p /data/local/tmp

APP_UID="$(stat -c %u "$APP")"
APP_GID="$(stat -c %g "$APP")"

# -----------------------------------------------
# Copy binary only when content differs.
# -----------------------------------------------

if ! cmp -s "$SRC_BIN" "$BIN"; then
    cp -f "$SRC_BIN" "$BIN"
fi

chown 0:0 "$BIN"
chmod 0755 "$BIN"

# -----------------------------------------------
# Copy library only when content differs.
# -----------------------------------------------

if ! cmp -s "$SRC_LIB" "$LIB"; then
    cp -f "$SRC_LIB" "$LIB"
fi

chown "$APP_UID:$APP_GID" "$LIB"
chmod 0644 "$LIB"

# -----------------------------------------------
# Restore SELinux contexts.
# -----------------------------------------------

if command -v restorecon >/dev/null 2>&1; then
    restorecon "$BIN" || exit 23
    restorecon "$LIB" || exit 24
fi

# -----------------------------------------------
# Verify deployed content.
# -----------------------------------------------

test -s "$BIN" || exit 25
test -s "$LIB" || exit 26

test -x "$BIN" || exit 27
test -r "$LIB" || exit 28

cmp -s "$SRC_BIN" "$BIN" || exit 29
cmp -s "$SRC_LIB" "$LIB" || exit 30

exit 0
ROOT

chmod 700 "$WORKDIR/root_deploy.sh"

# ===============================================
# 10. INSTALL FILES WITH ROOT
# ===============================================

info "Deploying files to required paths..."

su -c "sh '$WORKDIR/root_deploy.sh' '$BIN_CACHE' '$LIB_CACHE'" ||
    error "Root deployment failed"

success "Binary: $BIN_DEST"
success "Library: $LIB_DEST"

# ===============================================
# 11. FINAL CHECK
# ===============================================

info "Performing final checks..."

su -c "test -x '$BIN_DEST' && test -s '$LIB_DEST'" ||
    error "Installed file verification failed"

success "Final verification passed"

printf "\n${G}"
echo "╔══════════════════════════════════════════╗"
echo "║           INSTALLATION READY             ║"
echo "╚══════════════════════════════════════════╝"
printf "${N}\n"

# ===============================================
# 12. EXACT EXECUTION COMMAND
# ===============================================

info "Starting ELITEHAXX FF INDIA..."

if su -c 'cd / && ./data/local/tmp/casw --package com.garena.game.ffi --launch --hide --delay 250000 --libs /data/data/com.garena.game.ffi/libcisfc.so'; then

    success "Launch command completed"

else

    error "Launch failed; library retained"

fi

# ===============================================
# 13. REMOVE INSTALLED LIBRARY AFTER SUCCESS
# ===============================================

info "Cleaning installed library..."

if su -c 'rm -f -- /data/data/com.garena.game.ffi/libcisfc.so && test ! -e /data/data/com.garena.game.ffi/libcisfc.so'; then

    success "Installed library removed"

else

    error "Library cleanup failed"

fi

# ===============================================
# 14. KEEP PERSISTENT CACHE
# ===============================================

success "Downloaded files preserved in cache"

printf "\n${C}"
echo "╔══════════════════════════════════════════╗"
echo "║             PROCESS COMPLETE             ║"
echo "║                                          ║"
echo "║          ELITEHAXX FF INDIA              ║"
echo "╚══════════════════════════════════════════╝"
printf "${N}\n"
