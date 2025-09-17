#!/bin/bash

# This script enables NVIDIA drivers on Fedora Atomic Spins (e.g., Silverblue, Kinoite).
# Source: https://github.com/Comprehensive-Wall28/Nvidia-Fedora-Guide?tab=readme-ov-file#2-set-up-the-secure-boot-key-secure-boot-enabled-only

set -euo pipefail

# Global constants
REPO_URL="https://github.com/CheariX/silverblue-akmods-keys"
CLONE_DIR="/tmp/silverblue-akmods-keys"
KEY_PATH="/etc/pki/akmods/certs/public_key.der"
KARGS_OPTIONS=(
    "rd.driver.blacklist=nouveau,nova_core"
    "modprobe.blacklist=nouveau,nova_core"
    "nvidia-drm.modeset=1"
    "mitigations=off"
)

# Logging with timestamps
log() {
    printf "[%s] %s\n" "$(date +'%F %T')" "$*"
}

# Error handler
fail() {
    printf "[%s] ERROR: %s\n" "$(date +'%F %T')" "$*" >&2
    return 1
}

# Ensure script runs as root
require_root() {
    if [[ "$EUID" -ne 0 ]]; then
        fail "This script must be run with sudo or as root."
    fi
}

# Import secure boot key
import_secure_boot_key() {
    log "Importing secure boot key..."
    if ! command -v mokutil >/dev/null; then
        log "mokutil not found. Skipping key import."
        return 0
    fi

    local sb_state
    if ! sb_state=$(mokutil --sb-state 2>/dev/null); then
        fail "Failed to query Secure Boot state"
    fi
    if ! grep -qi "enabled" <<<"$sb_state"; then
        log "Secure Boot not enabled. Skipping key import."
        return 0
    fi

    if ! command -v kmodgenca >/dev/null; then
        fail "Missing command: kmodgenca"
    fi
    if ! kmodgenca; then
        fail "kmodgenca failed"
    fi
    if [[ ! -f "$KEY_PATH" ]]; then
        fail "Key file not found: $KEY_PATH"
    fi
    if ! mokutil --import "$KEY_PATH"; then
        fail "Failed to import secure boot key"
    fi
}

# Clone helper repository
clone_helper_repo() {
    log "Cloning helper repository..."
    rm -rf -- "$CLONE_DIR"
    if ! git clone --depth=1 -- "$REPO_URL" "$CLONE_DIR"; then
        fail "Failed to clone repository: $REPO_URL"
    fi
}

# Run setup script
run_setup_script_from_dir() {
    log "Running setup script from cloned repository..."
    if [[ ! -f "$CLONE_DIR/setup.sh" ]]; then
        fail "Setup script not found in repo directory"
    fi
    if ! ( cd "$CLONE_DIR" && bash ./setup.sh ); then
        fail "Failed to execute setup script"
    fi
}

# Install RPM packages
install_rpms() {
    log "Installing akmods keys RPM..."
    local rpm_matches
    if ! rpm_matches=$(find "$CLONE_DIR" -maxdepth 1 -type f -name "akmods-keys-*.rpm"); then
        fail "Error while searching for akmods keys RPM in $CLONE_DIR"
    fi
    local count
    count=$(printf "%s\n" "$rpm_matches" | grep -c . || true)
    if [[ "$count" -eq 0 ]]; then
        fail "akmods keys RPM not found in $CLONE_DIR"
    elif [[ "$count" -gt 1 ]]; then
        fail "Multiple akmods keys RPM files found in $CLONE_DIR"
    fi
    local rpm_file
    rpm_file=$(printf "%s\n" "$rpm_matches")

    if ! rpm-ostree install "$rpm_file"; then
        fail "Failed to install akmods keys RPM"
    fi
}

# Append kernel arguments
append_kernel_args() {
    log "Appending kernel arguments..."
    local args=()
    local opt
    for opt in "${KARGS_OPTIONS[@]}"; do
        args+=( "--append=$opt" )
    done
    if [[ ${#args[@]} -eq 0 ]]; then
        fail "No kernel arguments to append"
    fi

    if ! rpm-ostree kargs "${args[@]}"; then
        fail "Failed to append kernel arguments"
    fi
}

# Prompt reboot
reboot_prompt() {
    log "Reboot required to apply changes."
    local answer
    read -r -p "Reboot now? [y/n]: " answer
    answer=$(printf "%s" "$answer" | tr -d '[:space:]')
    case "$answer" in
        [Yy] ) log "Caller should handle reboot now."; return 20 ;;
        [Nn] ) log "Reboot skipped. Please reboot manually."; return 1 ;;
        * ) log "Invalid input. Skipping reboot."; return 1 ;;
    esac
}

main() {
    if ! require_root; then return 1; fi
    log "Starting NVIDIA driver installation (part two)..."
    if ! import_secure_boot_key; then return 1; fi
    if ! clone_helper_repo; then return 1; fi
    if ! run_setup_script_from_dir; then return 1; fi
    if ! install_rpms; then return 1; fi
    if ! append_kernel_args; then return 1; fi
    if reboot_prompt; then return 20; fi
}

main "$@"
