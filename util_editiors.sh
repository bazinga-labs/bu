#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: bu/util_edit.sh
# Author: Bazinga Labs LLC
# Email:  support@bazinga-labs.com
# -----------------------------------------------------------------------------
# Description: Utilities for file editing and opening files in appropriate editors
# -----------------------------------------------------------------------------
# Ensure proper Bash Utilities environment
if ! type info &>/dev/null; then
    echo "ERROR: bu.sh is not loaded. Please source bu.sh first."
    return 1 2>/dev/null || exit 1
fi
# Ensure this file is sourced, not executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "ERROR: This script should be sourced, not executed."
    echo "Usage: source ${BASH_SOURCE[0]}"
    exit 1
fi
# -----------------------------------------------------------------------------
smart_edit() { # Open a file with appropriate editor based on terminal environment
    local file="$1"
    
    # Check if file is provided
    if [ -z "$file" ]; then
        err "No file specified."
        info "Usage: smart_edit <file_path>"
        return 1
    fi
    
    # Create parent directory if it doesn't exist (for new files)
    local dir=$(dirname "$file")
    if [ ! -d "$dir" ]; then
        info "Creating directory: $dir"
        mkdir -p "$dir" || { err "Failed to create directory: $dir"; return 1; }
    fi
    
    # Check if we're in VS Code terminal
    if [[ "$TERM_PROGRAM" == "vscode" ]]; then
        info "Opening file in VS Code: $file"
        code "$file"
        return $?
    fi
    
    # Not in VS Code, use default editor in this order: $EDITOR, vim, nano, or vi
    local editor="${EDITOR:-}"
    
    if [ -z "$editor" ]; then
        # No EDITOR set, try to find a suitable one
        if command -v vim >/dev/null 2>&1; then
            editor="vim"
        elif command -v nano >/dev/null 2>&1; then
            editor="nano"
        elif command -v vi >/dev/null 2>&1; then
            editor="vi"
        else
            err "No suitable editor found. Please set the EDITOR environment variable."
            return 1
        fi
    fi
    
    info "Opening file with $editor: $file"
    $editor "$file"
    return $?
}
# -----------------------------------------------------------------------------
open_code_workspace() { # Open a .code-workspace file in the appropriate editor
    local workspace_file="$1"
    
    if [ -z "$workspace_file" ]; then
        err "No workspace file specified."
        info "Usage: open_code_workspace <workspace_file.code-workspace>"
        return 1
    fi
    
    if [ ! -f "$workspace_file" ]; then
        err "Workspace file does not exist: $workspace_file"
        return 1
    fi
    
    # Use smart_edit to open the workspace file
    smart_edit "$workspace_file"
    return $?
}
# -----------------------------------------------------------------------------
# Alias for convenience
alias edit='smart_edit'
# -----------------------------------------------------------------------------