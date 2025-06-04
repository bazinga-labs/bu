#!/bin/bash
# -----------------------------------------------------------------------------
# File: bu/util_p4.sh
# Author: Bazinga Labs LLC
# Email:  support@bazinga-labs.com
# -----------------------------------------------------------------------------
# Description: This utility provides functions for Perforce operations and workarea management.
# -----------------------------------------------------------------------------
[[ -z "${BASH_UTILS_LOADED}" || "${BASH_SOURCE[0]}" == "${0}" ]] && {
  [[ -z "${BASH_UTILS_LOADED}" ]] && echo "ERROR: bu.sh is not loaded. Please source it before using this script."
  [[ "${BASH_SOURCE[0]}" == "${0}" ]] && echo "ERROR: This script must be sourced through Bash Utilities, not executed directly."
  [[ "${BASH_SOURCE[0]}" != "${0}" ]] && return 1 || exit 1
}
# -----------------------------------------------------------------------------
p4_new_workspace() { # Create a new Perforce workspace (client) interactively
  # Parameters: None (uses interactive input)
  read -rp "Enter new client name: " client
  read -rp "Enter workspace root path: " root

  if [[ -z "$client" || -z "$root" ]]; then
    err "Client name and root path cannot be empty."
    return 1
  fi

  # Grab default client spec, edit fields, and submit
  p4 client -o "$client" | \\
    sed -e "s/^Client: .*$/Client: $client/" \\
        -e "s|^Root: .*|Root: $root|" | \\
    p4 client -i
  
  if [[ $? -eq 0 ]]; then
    info "Created client '$client' with root '$root'."
    return 0
  else
    err "Failed to create client '$client'."
    return 1
  fi
}
# -----------------------------------------------------------------------------
p4_clone_workspace() { # Clone an existing workspace spec to a new one
  # $1: source_client - The name of the existing client to clone.
  # $2: new_client    - The name for the new client.
  if [ -z "$1" ] || [ -z "$2" ]; then
    info "Usage: p4_clone_workspace <source_client> <new_client>"
    return 1
  fi
  local src="$1" 
  local dst="$2"
  p4 client -o "$src" | \\
    sed -e "s/^Client: .*$/Client: $dst/" \\
        -e "s|^Root: .*|Root: $PWD|" | \\
    p4 client -i
  
  if [[ $? -eq 0 ]]; then
    info "Cloned client '$src' to '$dst' with root set to $(pwd)."
    return 0
  else
    err "Failed to clone client '$src' to '$dst'."
    return 1
  fi
}
# -----------------------------------------------------------------------------
p4_set_workspace() { # Set the current workspace
  # $1: client_name - The name of the client to set as current.
  if [ -z "$1" ]; then
    info "Usage: p4_set_workspace <client_name>"
    return 1
  fi
  p4 set P4CLIENT="$1"
  if [[ $? -eq 0 ]]; then
    info "Set current workspace to '$1'."
    return 0
  else
    err "Failed to set current workspace to '$1'."
    return 1
  fi
}
# -----------------------------------------------------------------------------
p4_my_changes() { # List pending changelists for current user
  # Parameters: None
  p4 changes -u "$USER" -s pending
  return $? # Return status of p4 command
}
# -----------------------------------------------------------------------------
p4_describe() { # Describe a changelist
  # $1: changelist_number - The changelist number to describe.
  if [ -z "$1" ]; then
    info "Usage: p4_describe <changelist_number>"
    return 1
  else
    p4 describe -du "$1"
    return $? # Return status of p4 command
  fi
}
# -----------------------------------------------------------------------------
p4_submit() { # Submit a changelist
  # $1: changelist_number - The changelist number to submit.
  if [ -z "$1" ]; then
    info "Usage: p4_submit <changelist_number>"
    return 1
  else
    p4 submit -c "$1"
    return $? # Return status of p4 command
  fi
}
# -----------------------------------------------------------------------------
p4_opened() { # List all files opened in current workspace
  # Parameters: None
  p4 opened
  return $? # Return status of p4 command
}
# -----------------------------------------------------------------------------
p4_sync() { # Sync to latest
  # Parameters: None
  p4 sync
  return $? # Return status of p4 command
}
# -----------------------------------------------------------------------------
p4_sync_file() { # Sync a specific file or directory
  # $1: file_or_dir - The file or directory path to sync.
  if [ -z "$1" ]; then
    info "Usage: p4_sync_file <file_or_dir>"
    return 1
  else
    p4 sync "$1"
    return $? # Return status of p4 command
  fi
}
# -----------------------------------------------------------------------------
p4_revert() { # Revert a file or all files
  # $1: file - The file path to revert. Can be a specific file or //... for all.
  if [ -z "$1" ]; then
    info "Usage: p4_revert <file>"
    return 1
  else
    p4 revert "$1"
    return $? # Return status of p4 command
  fi
}
# -----------------------------------------------------------------------------
p4_diff_opened() { # Diff opened files
  # Parameters: None
  p4 diff
  return $? # Return status of p4 command
}
# -----------------------------------------------------------------------------
# File History & Annotation
# -----------------------------------------------------------------------------
p4_filelog() { # Show file history
  # $1: file - The file path to show history for.
  if [ -z "$1" ]; then
    info "Usage: p4_filelog <file>"
    return 1
  else
    p4 filelog "$1"
    return $? # Return status of p4 command
  fi
}
# -----------------------------------------------------------------------------
p4_annotate() { # Annotate (blame) a file
  # $1: file - The file path to annotate.
  if [ -z "$1" ]; then
    info "Usage: p4_annotate <file>"
    return 1
  else
    p4 annotate "$1"
    return $? # Return status of p4 command
  fi
}
# -----------------------------------------------------------------------------
p4_files_in_change() { # List files in a changelist
  # $1: changelist_number - The changelist number.
  if [ -z "$1" ]; then
    info "Usage: p4_files_in_change <changelist_number>"
    return 1
  else
    p4 describe -s "$1" \\
      | sed -n '/Affected files/,/^$/p' \\
      | sed '1d;$d'
    return $? # Return status of p4/sed pipeline
  fi
}
# -----------------------------------------------------------------------------
p4_show_client_spec() { # Show the current client spec
  # Parameters: None (uses P4CLIENT environment variable)
  local client=${P4CLIENT:-$(p4 set -q P4CLIENT | awk '{print $3}')}
  if [ -z "$client" ]; then
    info "P4CLIENT is not set."
    return 1
  fi
  p4 client -o "$client"
  return $? # Return status of p4 command
}
# -----------------------------------------------------------------------------
p4_edit_client_spec() { # Edit the current client spec in $EDITOR
  # Parameters: None (uses P4CLIENT and EDITOR environment variables)
  local client=${P4CLIENT:-$(p4 set -q P4CLIENT | awk '{print $3}')}
  if [ -z "$client" ]; then
    info "P4CLIENT is not set."
    return 1
  fi
  local tmpfile
  tmpfile=$(mktemp /tmp/p4client.XXXXXX)
  if [[ -z "$tmpfile" ]]; then
    err "Failed to create temporary file."
    return 1
  fi
  p4 client -o "$client" > "$tmpfile"
  "${EDITOR:-vi}" "$tmpfile"
  p4 client -i < "$tmpfile"
  local status=$?
  rm -f "$tmpfile"
  if [[ $status -eq 0 ]]; then
    info "Client spec for '$client' updated."
    return 0
  else
    err "Failed to update client spec for '$client'."
    return 1
  fi
}
# -----------------------------------------------------------------------------
p4_backup_client_spec() { # Backup the current client spec to a file
  # $1: backup_file (optional) - The file to save the backup to. Defaults to <client_name>.p4client.bak.
  local client=${P4CLIENT:-$(p4 set -q P4CLIENT | awk '{print $3}')}
  if [ -z "$client" ]; then
    info "P4CLIENT is not set."
    return 1
  fi
  local backup_file="${1:-$client.p4client.bak}"
  p4 client -o "$client" > "$backup_file"
  if [[ $? -eq 0 ]]; then
    info "Client spec for '$client' backed up to '$backup_file'."
    return 0
  else
    err "Failed to back up client spec for '$client' to '$backup_file'."
    return 1
  fi
}
# -----------------------------------------------------------------------------
p4_restore_client_spec() { # Restore the client spec from a backup file
  # $1: backup_file - The backup file to restore the client spec from.
  local client=${P4CLIENT:-$(p4 set -q P4CLIENT | awk '{print $3}')}
  if [ -z "$client" ]; then
    info "P4CLIENT is not set." # Technically, we might be restoring *to* a new client name if the file has a different one.
                               # However, the message refers to the currently set P4CLIENT for context.
    # return 1 # Allowing to proceed even if P4CLIENT isn't set, as the file itself defines the client.
  fi
  if [ -z "$1" ]; then
    info "Usage: p4_restore_client_spec <backup_file>"
    return 1
  fi
  if [ ! -f "$1" ]; then
    err "Backup file '$1' not found."
    return 1
  fi
  p4 client -i < "$1"
  if [[ $? -eq 0 ]]; then
    # The client name is inside the backup file. We don't know it for sure here unless we parse it.
    info "Client spec restored from '$1'. You may need to set P4CLIENT to the restored client name."
    return 0
  else
    err "Failed to restore client spec from '$1'."
    return 1
  fi
}
# -----------------------------------------------------------------------------
list_bash_functions_in_file >/dev/null 2>&1 && list_bash_functions_in_file "$(realpath "$0")" || err "alias is not loaded"
