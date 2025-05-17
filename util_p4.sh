#!/bin/bash
# -----------------------------------------------------------------------------
# File: bu/util_p4.sh
# Author: Bazinga Labs LLC
# Email:  support@bazinga-labs.com
# Description: This utility provides functions for Perforce operations.
# -----------------------------------------------------------------------------
[[ -z "${BASH_UTILS_LOADED}" ]] && { echo "ERROR: util_bash.sh is not loaded. Please source it before using this script."; exit 1; }

#------------------------------------------------------------------------------
p4_new_workspace() { # Create a new Perforce workspace (client) interactively
  read -rp "Enter new client name: " client
  read -rp "Enter workspace root path: " root
  # Grab default client spec, edit fields, and submit
  p4 client -o "$client" | \
    sed -e "s/^Client: .*$/Client: $client/" \
        -e "s|^Root: .*|Root: $root|" | \
    p4 client -i
  info "Created client '$client' with root '$root'."
}
# -----------------------------------------------------------------------------
p4_clone_workspace() { # Clone an existing workspace spec to a new one
  if [ -z "$1" ] || [ -z "$2" ]; then
    info "Usage: p4_clone_workspace <source_client> <new_client>"
    return 1
  fi
  local src="$1" dst="$2"
  p4 client -o "$src" | \
    sed -e "s/^Client: .*$/Client: $dst/" \
        -e "s|^Root: .*|Root: $PWD|" | \
    p4 client -i
  info "Cloned client '$src' to '$dst' with root set to $(pwd)."
}
# -----------------------------------------------------------------------------
p4_set_workspace() { # Set the current workspace
  if [ -z "$1" ]; then
    info "Usage: p4_set_workspace <client_name>"
    return 1
  fi
  p4 set P4CLIENT="$1"
  info "Set current workspace to '$1'."
}
p4_my_changes() { # List pending changelists for current user
  p4 changes -u "$USER" -s pending
}
# -----------------------------------------------------------------------------
p4_describe() { # Describe a changelist
  if [ -z "$1" ]; then
    info "Usage: p4_describe <changelist_number>"
    return 1
  else
    p4 describe -du "$1"
  fi
}
# -----------------------------------------------------------------------------
p4_submit() { # Submit a changelist
  if [ -z "$1" ]; then
    info "Usage: p4_submit <changelist_number>"
    return 1
  else
    p4 submit -c "$1"
  fi
}
p4_opened() { # List all files opened in current workspace
  p4 opened
}
# -----------------------------------------------------------------------------
p4_sync() { # Sync to latest
  p4 sync
}
# -----------------------------------------------------------------------------
p4_sync_file() { # Sync a specific file or directory
  if [ -z "$1" ]; then
    info "Usage: p4_sync_file <file_or_dir>"
    return 1
  else
    p4 sync "$1"
  fi
}
# -----------------------------------------------------------------------------
p4_revert() { # Revert a file or all files
  if [ -z "$1" ]; then
    info "Usage: p4_revert <file>"
    return 1
  else
    p4 revert "$1"
  fi
}
# -----------------------------------------------------------------------------
p4_diff_opened() { # Diff opened files
  p4 diff
}

# -----------------------------
# File History & Annotation
# -----------------------------

p4_filelog() { # Show file history
  if [ -z "$1" ]; then
    info "Usage: p4_filelog <file>"
    return 1
  else
    p4 filelog "$1"
  fi
}
# -----------------------------------------------------------------------------
p4_annotate() { # Annotate (blame) a file
  if [ -z "$1" ]; then
    info "Usage: p4_annotate <file>"
    return 1
  else
    p4 annotate "$1"
  fi
}
# -----------------------------------------------------------------------------
p4_files_in_change() { # List files in a changelist
  if [ -z "$1" ]; then
    info "Usage: p4_files_in_change <changelist_number>"
    return 1
  else
    p4 describe -s "$1" \
      | sed -n '/Affected files/,/^$/p' \
      | sed '1d;$d'
  fi
}
# -----------------------------------------------------------------------------
p4_show_client_spec() { # Show the current client spec
  local client=${P4CLIENT:-$(p4 set -q P4CLIENT | awk '{print $3}')}
  if [ -z "$client" ]; then
    info "P4CLIENT is not set."
    return 1
  fi
  p4 client -o "$client"
}
# -----------------------------------------------------------------------------
p4_edit_client_spec() { # Edit the current client spec in $EDITOR
  local client=${P4CLIENT:-$(p4 set -q P4CLIENT | awk '{print $3}')}
  if [ -z "$client" ]; then
    info "P4CLIENT is not set."
    return 1
  fi
  local tmpfile
  tmpfile=$(mktemp /tmp/p4client.XXXXXX)
  p4 client -o "$client" > "$tmpfile"
  "${EDITOR:-vi}" "$tmpfile"
  p4 client -i < "$tmpfile"
  rm -f "$tmpfile"
  info "Client spec for '$client' updated."
}
# -----------------------------------------------------------------------------
p4_backup_client_spec() { # Backup the current client spec to a file
  local client=${P4CLIENT:-$(p4 set -q P4CLIENT | awk '{print $3}')}
  if [ -z "$client" ]; then
    info "P4CLIENT is not set."
    return 1
  fi
  local backup_file="${1:-$client.p4client.bak}"
  p4 client -o "$client" > "$backup_file"
  info "Client spec for '$client' backed up to '$backup_file'."
}
# -----------------------------------------------------------------------------
p4_restore_client_spec() { # Restore the client spec from a backup file
  local client=${P4CLIENT:-$(p4 set -q P4CLIENT | awk '{print $3}')}
  if [ -z "$client" ]; then
    info "P4CLIENT is not set."
    return 1
  fi
  if [ -z "$1" ]; then
    info "Usage: p4_restore_client_spec <backup_file>"
    return 1
  fi
  p4 client -i < "$1"
  info "Client spec for '$client' restored from '$1'."
}
# -----------------------------------------------------------------------------
list_bash_functions_in_file "$(realpath "$0")"
# -----------------------------------------------------------------------------