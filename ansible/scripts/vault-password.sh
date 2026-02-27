#!/usr/bin/env bash
# Provides the ansible-vault password.
# - In CI: reads ANSIBLE_VAULT_PASSWORD environment variable
# - Locally: reads from macOS Keychain (service: ansible-vault-k3s)
set -euo pipefail

if [ -n "${ANSIBLE_VAULT_PASSWORD:-}" ]; then
    printf '%s' "$ANSIBLE_VAULT_PASSWORD"
else
    security find-generic-password -a "$USER" -s ansible-vault-k3s -w
fi
