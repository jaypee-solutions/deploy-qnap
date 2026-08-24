#!/bin/sh
# Fetches the Ansible Vault password from 1Password.
# Adjust the op:// reference to match your 1Password item.
op read "op://Private/Ansible Vault - QNAP/password"
