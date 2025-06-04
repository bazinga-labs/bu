#!/bin/bash
# -----------------------------------------------------------------------------
# File: bu/util_alias.sh
# Author: Bazinga Labs LLC
# Email:  support@bazinga-labs.com
# -----------------------------------------------------------------------------
# Description: File system operation aliases and functions
# -----------------------------------------------------------------------------
[[ -z "${BASH_UTILS_LOADED}" || "${BASH_SOURCE[0]}" == "${0}" ]] && {
  [[ -z "${BASH_UTILS_LOADED}" ]] && echo "ERROR: bu.sh is not loaded. Please source it before using this script."
  [[ "${BASH_SOURCE[0]}" == "${0}" ]] && echo "ERROR: This script must be sourced through Bash Utilities, not executed directly."
  [[ "${BASH_SOURCE[0]}" != "${0}" ]] && return 1 || exit 1
}
# -----------------------------------------------------------------------------

alias lr='ls -lrt'               # List files in long format, sorted by modification time
alias la='ls -a'                 # List all files including hidden files
alias l1='ls -1'                 # List files in single column
alias lock='chmod -R 700'        # Set restrictive permissions (700) on files/directories
alias unlock='chmod -R 755'      # Set standard permissions (755) on files/directories
alias mkexe='chmod -R 755'       # Make files executable with permission 755
alias clean-temp-files='rm -f *~ .*~ *.swp *.swo *.bak *.tmp *.orig *.rej'  # Remove backup and temporary files
alias fname='realpath'           # Get the full real path of a file/directory
alias up='cd ..'                 # Navigate up one directory
alias x='exit'                   # Exit the terminal
alias c='clear'                  # Clear the terminal screen
alias cls='clear'                # Clear the terminal screen
alias m='more'                   # View file content page by page
alias h='head -20'               # Show first 20 lines of a file
alias t='tail -20'               # Show last 20 lines of a file
alias g='grep -i'                # Case-insensitive text search with grep

# -----------------------------------------------------------------------------
goto() { # Navigate to directory set in environment variable name
    local var_name="$1"
    if [ -z "${!var_name}" ]; then
        err "Error: $var_name environment variable is not set"
        return 1
    fi
    cd "${!var_name}"
}
# -----------------------------------------------------------------------------

# Directory navigation shortcuts
alias w='goto "WORK"'
alias docs='goto "DOCS"'
alias dl='goto "DL"'
alias idl='goto "iDL"'
alias idoc='goto "iDOCS"'

# -----------------------------------------------------------------------------
dname() { # Get the directory name of a file/directory
    [ -z "$1" ] && { err "Usage: dname <path>"; return 1; } || dirname "$(realpath "$1")"
}
# -----------------------------------------------------------------------------

setup_markdown_editor_alias() {  # Check if Markdown Editor app exists in standard locations
    if [[ -d "/Applications/Markdown Editor.app" ]] || [[ -d "$HOME/Applications/Markdown Editor.app" ]]; then
        alias mde='/usr/bin/open -a "Markdown Editor"' # Open with Markdown Editor
        return 0
    fi
    return 1
}
# -----------------------------------------------------------------------------
setup_open_alias() {  # Sets up the 'open' command to behave differently based on terminal environment
    if [[ "$TERM_PROGRAM" == "vscode" ]]; then
        alias open="code"
    else
        unalias open &>/dev/null
    fi
}
# -----------------------------------------------------------------------------
setup_macos_aliases() {   # Set up all macOS-specific aliases
    local os_type=$(util_get_os)
    if [[ "$os_type" != "MacOS" ]]; then
        info "Not running on macOS, skipping macOS-specific aliases."
        return 1
    fi
    info "Setting up macOS-specific aliases..."
    setup_markdown_editor_alias
    setup_open_alias
    alias showfiles='defaults write com.apple.finder AppleShowAllFiles YES; killall Finder' # Show hidden files
    alias hidefiles='defaults write com.apple.finder AppleShowAllFiles NO; killall Finder'  # Hide hidden files
    alias flushdns='sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder'         # Flush DNS cache
    alias cleanup='find . -name "*.DS_Store" -type f -delete'                             # Clean up .DS_Store files
    alias pbcp='pbcopy'                                                # Copy to clipboard
    alias pbps='pbpaste'                                              # Paste from clipboard
    info "macOS aliases setup complete."
    return 0
}
# -----------------------------------------------------------------------------
if [[ "$(util_get_os)" == "MacOS" ]]; then
    setup_macos_aliases
fi
# -----------------------------------------------------------------------------
list_bash_functions_in_file >/dev/null 2>&1 && list_bash_functions_in_file "$(realpath "$0")" || err "alias is not loaded"