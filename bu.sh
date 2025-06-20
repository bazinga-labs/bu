#!/bin/bash
# -----------------------------------------------------------------------------
# File: bu/bu.sh
# Author: Bazinga Labs LLC
# Email:  support@bazinga-labs.com
# -----------------------------------------------------------------------------
# Description:
#   Main Bash Utilities loader and manager. Provides a framework for loading,
#   unloading, listing, and managing modular bash utility scripts and project-specific
#   aliases. Ensures consistent output formatting, error handling, and utility
#   discoverability. Supports utilities in both the main directory and a user alias
#   directory ($BU_PROJECT_ALIAS).
#
#   Key Features:
#     - Color-coded info, warning, and error output
#     - Dynamic loading/unloading of utility scripts
#     - Support for project-specific aliases
#     - Utility listing, function/alias introspection, and reload support
#     - Robust error handling and environment validation
#
# USAGE:
# -----------------------------------------------------------------------------
#   Usage:
#     Source this file in your shell or scripts to enable the 'bu' command and
#     related utility management functions.
#
#   Environment Variables:
#     BU                           : Main utilities directory (auto-detected)
#     BU_LOADED                    : Colon-separated list of loaded utilities
#     BU_VERBOSE_LEVEL             : Default verbosity level = 1
#                                   -1 = No Errors
#                                    0 = Show info 
#                                    1 = Show info and warnings
#                                    2 = show info, warnings, and debug messages
#   Main Function:
#     bu                            : Command-line handler for all utility management operations
#       - list                      : List all available utilities and aliases
#       - loaded, ls                : List currently loaded utilities
#       - load <name>               : Load a utility or alias
#       - loadall                   : Load all available utilities and aliases
#       - unload <name>             : Unload a utility
#       - functions, funcs [name]   : Show functions/aliases in loaded utilities or a specific utility
#       - allfunctions [filter]     : Show all functions in loaded utilities, optionally filter by name
#       - reload [name]             : Reload a utility or all loaded utilities
#       - gen_alias [p|n]           : Generate project (p) and/or navigation (n) aliases
#       - check-updates, check      : Check for updates to the utilities framework
#       - update                    : Update the utilities framework
#       - help, -h, --help, ""      : Show help message (also shown if no command is given)
#
#   Examples:
#     bu list                       # List all available utilities and aliases
#     bu loaded                     # List currently loaded utilities
#     bu load dev_py                # Load the 'dev_py' utility
#     bu loadall                    # Load all available utilities and aliases
#     bu unload git                 # Unload the 'git' utility
#     bu functions dev_sw           # Show functions/aliases in the 'dev_sw' utility
#     bu allfunctions run           # Show all functions in loaded utilities, filter by 'run'
#     bu reload p4                  # Reload the 'p4' utility
#     bu reload                     # Reload all loaded utilities
#     bu gen_alias p                # Generate project aliases only
#     bu gen_alias n                # Generate navigation aliases only
#     bu gen_alias                  # Generate both project and navigation aliases
#     bu check-updates              # Check for updates to the utilities framework
#     bu update                     # Update the utilities framework
#     bu help                       # Show help message
#     bu                            # Show help message (no command)
# -----------------------------------------------------------------------------
# END_OF_USAGE
# -----------------------------------------------------------------------------
#   Helper Functions:
#     err, warn, info   : Consistent color-coded output
#     bu_util_name      : Extract utility name from file path
#     bu_util_path      : Resolve utility/alias file path
#     list_bash_functions_in_file, list_alias_in_file : Introspection helpers
# -----------------------------------------------------------------------------
# DO NOT MODIFY THIS FILE WITHOUT PRIOR AUTHORIZATION
# This file is managed by Bazinga Labs LLC and changes may be overwritten.
# Unauthorized edits may result in system malfunction or integration failure.
# Contact support@bazinga-labs.com for changes or exceptions.
# -----------------------------------------------------------------------------
# Description: Utilities for checking linux environment variables (PATH, LD_LIBRARY_PATH)
# -----------------------------------------------------------------------------
# WARNING: This is the main utility file and should be loaded first.
# -----------------------------------------------------------------------------
# Set BU to the parent directory of this script
# Check if BU is already set
# Color definitions for consistent output formatting
# Regular colors
export BLACK="\033[0;30m"
export RED="\033[0;31m"
export GREEN="\033[0;32m"
export YELLOW="\033[0;33m"
export BLUE="\033[0;34m"
export MAGENTA="\033[0;35m"
export CYAN="\033[0;36m"
export WHITE="\033[0;37m"

# Bright (bold) colors
export BBLACK="\033[1;30m"
export BRED="\033[1;31m"
export BGREEN="\033[1;32m"
export BYELLOW="\033[1;33m"   # same as your ORANGE
export BBLUE="\033[1;34m"
export BMAGENTA="\033[1;35m"
export BCYAN="\033[1;36m"
export BWHITE="\033[1;37m"

# Background colors
export ON_BLACK="\033[40m"
export ON_RED="\033[41m"
export ON_GREEN="\033[42m"
export ON_YELLOW="\033[43m"
export ON_BLUE="\033[44m"
export ON_MAGENTA="\033[45m"
export ON_CYAN="\033[46m"
export ON_WHITE="\033[47m"

# Text styles
export BOLD="\033[1m"
export DIM="\033[2m"
export UNDERLINE="\033[4m"
export BLINK="\033[5m"
export REVERSED="\033[7m"

# Reset
export RESET="\033[0m"

export ERR_COLOR="${BRED}"
export WARN_COLOR="${YELLOW}"
export INFO_COLOR="${CYAN}"
export BOLD_INFO_COLOR="B${INFO_COLOR}"
export DEBUG_COLOR="${MAGENTA}"

# -----------------------------------------------------------------------------
# Helper functions for formatted output
# -----------------------------------------------------------------------------
err() {
    if [ "${BU_VERBOSE_LEVEL:-1}" -gt -1 ]; then
        echo -e "${ERR_COLOR}[$(date '+%Y-%m-%d %H:%M:%S')] Error: $*${RESET}" >&2
    fi
}
warn() {
    if [ "${BU_VERBOSE_LEVEL:-1}" -ge 1 ]; then
        echo -e "${WARN_COLOR}[$(date '+%Y-%m-%d %H:%M:%S')] Warning: $*${RESET}" >&2
    fi
}
info() {
    if [ "${BU_VERBOSE_LEVEL:-1}" -ge 0 ]; then
        echo -e "${INFO_COLOR}[$(date '+%Y-%m-%d %H:%M:%S')] Info: $*${RESET}"
    fi
}
info_bold() {
    if [ "${BU_VERBOSE_LEVEL:-1}" -ge 0 ]; then
        echo -e "${BOLD}${INFO_COLOR}[$(date '+%Y-%m-%d %H:%M:%S')] Info: $*${RESET}"
    fi
}
debug() {
    if [ "${BU_VERBOSE_LEVEL:-1}" -ge 2 ]; then
        echo -e "${DEBUG_COLOR}[$(date '+%Y-%m-%d %H:%M:%S')] Debug: $*${RESET}"
    fi
}
usage() {
    # Print the Usage section from the script header using awk for robustness
    local script_file=""
    if [ -n "${BASH_SOURCE[0]}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
        script_file="${BASH_SOURCE[0]}"
    elif [ -n "$0" ] && [ -f "$0" ]; then
        script_file="$0"
    elif [ -n "$BU_SH" ] && [ -f "$BU_SH" ]; then
        script_file="$BU_SH"
    else
        err "Cannot display usage: script file not found (tried BASH_SOURCE[0], $0, BU_SH)"
        return 1
    fi
    awk '/^# *USAGE:|^# *START_OF_USAGE/ {show=1; next} /^# *END_OF_USAGE/ {show=0} show { sub(/^# ?/, ""); print }' "$script_file"
}
# -----------------------------------------------------------------------------
bu_util_name() { # Extracts utility name from full path
    local full_path="$1"
    local base="$(basename "$full_path")"
    base="${base#util_}"
    base="${base%.sh}"
    echo "$base"
}
# -----------------------------------------------------------------------------
bu_util_path() { # Constructs the full path for a given utility name
    local name="$1"
    # Special case for main utility
    if [ "$name" = "bu" ]; then
        echo "$BU/bu.sh"
        return
    fi
    # Check for standard util_<name>.sh in $BU
    if [ -f "$BU/util_${name}.sh" ]; then
        echo "$BU/util_${name}.sh"
        return
    fi
    # Default to $BU/util_<name>.sh for error reporting
    echo "$BU/util_${name}.sh"
}
# -----------------------------------------------------------------------------
list_bash_functions_in_file() {   # List all function definitions in a file with descriptions
    local script_path="$1"
    
    # Check if script_path is valid
    if [ -z "$script_path" ] || [ ! -f "$script_path" ]; then
        err "Invalid file path: $script_path"
        return 1
    fi
    
    # Use grep to find function definitions that include an inline comment for description
    fs=$(grep -E '^[a-zA-Z0-9_]+\(\)\ *\{\ *#' "$script_path")
    [ -z "$fs" ] || [ "$fs" = ":" ] && { warn "No functions found."; return 0; }
    info "Functions defined in [$(basename "$script_path")]: "
    # Find the maximum length of function names for proper alignment
    max_len=0
    while IFS= read -r line; do
        # Extract function name (removing parentheses and braces)
        func_name=$(echo "$line" | sed -E 's/^([a-zA-Z0-9_]+)\(\).*$/\1/' | xargs)
        if [ ${#func_name} -gt $max_len ]; then
            max_len=${#func_name}
        fi
    done <<< "$fs"
    
    # Print function names with aligned descriptions
    while IFS= read -r line; do
        func_name=$(echo "$line" | sed -E 's/^([a-zA-Z0-9_]+)\(\).*$/\1/' | xargs)
        description=$(echo "$line" | sed 's/.*#//')
        info "$(printf " %-${max_len}s :%s" "$func_name" "$description")"
    done <<< "$fs"
}
# -----------------------------------------------------------------------------
list_alias_in_file() {   # List all alias definitions in this file with descriptions
    local script_path="$1"
    as=$(grep -E '^alias [^=]+=.*#' "$script_path")
    [ -z "$as" ] || [ "$as" = ":" ] && { warn "  No aliases found."; return 0; }
    info "Aliases defined in [$(basename "$script_path")]: "
    # Find the maximum length of alias names
    max_len=0
    while IFS= read -r line; do
        # Extract alias name located between 'alias' and the '=' sign
        alias_name=$(echo "$line" | sed -E 's/^alias[[:space:]]+([^=]+)=.*$/\1/' | xargs)
        if [ ${#alias_name} -gt $max_len ]; then
            max_len=${#alias_name}
        fi
    done <<< "$as"
    
    # Print alias names with aligned descriptions
    while IFS= read -r line; do
        alias_name=$(echo "$line" | sed -E 's/^alias[[:space:]]+([^=]+)=.*$/\1/' | xargs)
        description=$(echo "$line" | sed 's/.*#//')
        info "$(printf " %-${max_len}s :%s" "$alias_name" "$description")"
    done <<< "$as"
}
# -----------------------------------------------------------------------------
bu_list() {   # Display all available bash utilities
    info "All available BASH utilities:"
    local seen_utils=""
    # List from $BU (util_*.sh)
    for util_path in "$BU"/util_*.sh; do
        [ ! -f "$util_path" ] && continue
        local util_name="$(bu_util_name "$util_path")"
        if echo ":$seen_utils:" | grep -q ":$util_name:"; then continue; fi
        seen_utils="$seen_utils:$util_name"
        util_description="NA"; [ -f "$util_path" ] && desc=$(grep -m 1 "# Description:" "$util_path" | sed 's/# Description://' | xargs) && [ -n "$desc" ] && util_description="$desc"
        if [ -z "$1" ] || echo "$util_name" | grep -q "$1" || echo "$util_path" | grep -q "$1"; then
            printf "  %-25s : %s\n" "$util_name" "$util_description"
        fi
    done
}
# -----------------------------------------------------------------------------
bu_list_loaded() {   # Display loaded bash utilities
    if [ -z "$BU_LOADED" ]; then
        err "No utilities currently loaded."
        return 1
    fi
    info "Loaded BASH utilities:"
    # Process each utility
    echo "$BU_LOADED" | tr ":" "\n" | while read -r util_name; do
        [ -z "$util_name" ] && continue  # Skip empty entries
        util_path="$(bu_util_path "$util_name")"
        
        # Check if utility file still exists
        if [ -f "$util_path" ]; then
            # If search term provided, filter results
            if [ -z "$1" ] || echo "$util_name" | grep -q "$1" || echo "$util_path" | grep -q "$1"; then
                echo -e "${GREEN}[OK]${RESET} $util_name"
            fi
        else
            # If search term provided, filter results
            if [ -z "$1" ] || echo "$util_name" | grep -q "$1" || echo "$util_path" | grep -q "$1"; then
                err "$util_name (FILE MISSING)"
            fi
        fi
    done
}
# -----------------------------------------------------------------------------
bu_load() {   # Load a specified bash utility
    local util_name="$1"
    local util_path="$(bu_util_path "$util_name")"
    
    # Check if utility name was provided
    if [ -z "$util_name" ]; then 
        err "No utility name specified."
        return 1
    fi
    
    # Check if utility file exists
    if [ ! -f "$util_path" ]; then
        err "Utility '$util_name' not found at $util_path"
        return 1
    fi
    # Source the utility file
    source "$util_path"
    # Check if sourcing was successful
    if [ $? -eq 0 ]; then
        # Append to the list of loaded utilities if not already in the list
        if [[ "$BU_LOADED" != *"$util_name"* ]]; then
            if [ -z "$BU_LOADED" ]; then
                BU_LOADED="$util_name"
            else
                BU_LOADED="$BU_LOADED:$util_name"
            fi
        fi
        if [ "${BU_VERBOSE_LEVEL:-1}" -ne 0 ]; then
            info "Utility '$util_name' loaded successfully."
            list_bash_functions_in_file "$util_path"
            list_alias_in_file "$util_path"
        fi
        return 0
    else
        err "Error loading utility '$util_name'."
        return 1
    fi
}
# -----------------------------------------------------------------------------
bu_load_all_utils() {   # Load all available bash utilities
    local loaded_count=0
    local failed_count=0
    local seen_utils=""
    export BU_VERBOSE_LEVEL=0
    # Load all util_*.sh from $BU
    for util_path in "$BU"/util_*.sh; do
        [ ! -f "$util_path" ] && continue
        local util_name="$(bu_util_name "$util_path")"
        if echo ":$seen_utils:" | grep -q ":$util_name:"; then continue; fi
        seen_utils="$seen_utils:$util_name"
        bu_load "$util_name"
        if [ $? -eq 0 ]; then
            loaded_count=$((loaded_count+1))
        else
            failed_count=$((failed_count+1))
        fi
    done
    info "Loaded $loaded_count utilities. $failed_count failed."
    export BU_VERBOSE_LEVEL=1  # Reset verbosity level to default
    [ $failed_count -eq 0 ] && return 0 || return 1
}
# -----------------------------------------------------------------------------
bu_unload() {   # Unload a specified bash utility and remove its functions
    local util_name="$1"
    local util_path="$(bu_util_path "$util_name")"
    
    # Check if utility name was provided
    if [ -z "$util_name" ]; then
        err "No utility name specified."
        return 1
    fi
    
    # Check if the utility is currently loaded
    if [[ "$BU_LOADED" != *"$util_name"* ]]; then
        warn "Utility '$util_name' is not currently loaded."
        return 1
    fi
    
    # Check if utility file exists
    if [ ! -f "$util_path" ]; then
        warn "Utility file '$util_path' not found, but will attempt to unload from memory."
    fi
    
    info "Unloading utility '$util_name'..."
    
    # Get all function names from the utility file
    local fs=""
    if [ -f "$util_path" ]; then
        # Extract functions with their descriptions
        fs=$(grep -E '^[a-zA-Z0-9_]+\(\)\ *\{\ *#' "$util_path")
    else
        warn "Cannot extract function names from missing file. Manual cleanup might be needed."
        return 1
    fi
    # Calculate maximum function name length for formatting
    local max_len=0
    while IFS= read -r line; do
        # Extract function name (before #) and remove (), {}
        local func_name=$(echo "$line" | sed 's/#.*$//' | tr -d '(){}' | xargs)
        if [ ${#func_name} -gt $max_len ]; then
            max_len=${#func_name}
        fi
    done <<< "$fs"
    # Unset each function and print what was unset
    info "Unsetting functions from utility '$util_name':"
    while IFS= read -r line; do
        local func_name=$(echo "$line" | sed 's/#.*$//' | tr -d '(){}' | xargs)
        local description=$(echo "$line" | sed 's/^[^#]*#//')
        
        # Attempt to unset the function
        unset -f "$func_name" 2>/dev/null
        local unset_status=$?
        
        # Report the result
        if [ $unset_status -eq 0 ]; then
            printf " %-${max_len}s :%-40s [UNSET]\n" "$func_name" "$description"
        else
            printf " %-${max_len}s :%-40s [FAILED]\n" "$func_name" "$description"
        fi
    done <<< "$fs"
    
    # Update the BU_LOADED variable to remove this utility
    local new_loaded=""
    for loaded_util in $(echo "$BU_LOADED" | tr ":" " "); do
        if [ "$loaded_util" != "$util_name" ]; then
            if [ -z "$new_loaded" ]; then
                new_loaded="$loaded_util"
            else
                new_loaded="$new_loaded:$loaded_util"
            fi
        fi
    done
    # Set the updated list of loaded utilities
    BU_LOADED="$new_loaded"
    info "Utility '$util_name' unloaded successfully."
    return 0
}
# -----------------------------------------------------------------------------
bu_functions() {   # Show functions available in loaded bash utilities
    local util_name="$1"
    
    # If no utilities are loaded, inform user and exit
    [ -z "$BU_LOADED" ] && err "No utilities currently loaded."

    # If utility name is provided, check if it's loaded and show its functions
    if [ -n "$util_name" ]; then
        if [[ "$BU_LOADED" != *"$util_name"* ]]; then
            warn "Utility '$util_name' is not currently loaded."
            warn "Use bu load '$util_name' to load it first."
            return 1
        fi
        
        local util_path="$(bu_util_path "$util_name")"
        if [ -f "$util_path" ]; then
            list_bash_functions_in_file "$util_path"
            list_alias_in_file "$util_path"
        else
            err "Utility file for '$util_name' not found at $util_path"
            return 1
        fi
        return 0
    fi
    
    # If no specific utility name is provided, show functions for all loaded utilities
    info "Functions and aliases available in loaded utilities:"
    echo "$BU_LOADED" | tr ":" "\n" | while read -r util; do
        [ -z "$util" ] && continue  # Skip empty entries
        util_path="$(bu_util_path "$util")"
        
        if [ -f "$util_path" ]; then
            list_bash_functions_in_file "$util_path"
            list_alias_in_file "$util_path"
        else
            err "Functions and aliases for utility '$util' cannot be shown (file missing)"
        fi
    done
}
# -----------------------------------------------------------------------------
bu_reload() {   # Reload a specified bash utility (unload and load again) or all if none specified
    local util_name="$1"
    
    # If no utility name was provided, reload all loaded utilities
    if [ -z "$util_name" ]; then
        # Check if any utilities are loaded
        if [ -z "$BU_LOADED" ]; then
            warn "No utilities currently loaded."
            return 0
        fi
        
        info "Reloading all loaded utilities..."
        local all_success=true
        local reloaded_count=0
        local failed_count=0
        
        # Create a temporary copy of the loaded utilities list
        local utils_to_reload=$(echo "$BU_LOADED" | tr ":" " ")
        
        for util in $utils_to_reload; do
            [ -z "$util" ] && continue  # Skip empty entries
            
            info "Reloading utility '$util'..."
            
            # Unload the utility
            bu_unload "$util"
            local unload_status=$?
            
            if [ $unload_status -ne 0 ]; then
                err "Failed to unload utility '$util'. Continuing with next utility."
                all_success=false
                failed_count=$((failed_count + 1))
                continue
            fi
            
            # Load the utility again
            bu_load "$util"
            local load_status=$?
            
            if [ $load_status -eq 0 ]; then
                info "Utility '$util' successfully reloaded."
                reloaded_count=$((reloaded_count + 1))
            else
                err "Failed to reload utility '$util'."
                all_success=false
                failed_count=$((failed_count + 1))
            fi
        done
        
        # Summarize reload operation
        info "Reload complete: $reloaded_count utilities reloaded successfully, $failed_count failed."
        [ "$all_success" = true ] && return 0 || return 1
    fi
    
    # Otherwise reload a specific utility (existing functionality)
    # Check if the utility is currently loaded
    if [[ "$BU_LOADED" != *"$util_name"* ]]; then
        warn "Utility '$util_name' is not currently loaded. Will attempt to load it."
        bu_load "$util_name"
        return $?
    fi
    
    info "Reloading utility '$util_name'..."
    
    # Unload the utility first
    bu_unload "$util_name"
    local unload_status=$?
    
    if [ $unload_status -ne 0 ]; then
        err "Failed to unload utility '$util_name'. Reload aborted."
        return 1
    fi
    
    # Then load it again
    bu_load "$util_name"
    local load_status=$?
    
    if [ $load_status -eq 0 ]; then
        info "Utility '$util_name' successfully reloaded."
        return 0
    else
        err "Failed to reload utility '$util_name'."
        return 1
    fi
}

export_BU_VARS() {   # Export BU environment variables
    export BU_LOADED=""
    export BU_RELEASE="main" # Default to main branch
    export BU_VERBOSE_LEVEL=1
    
    # Auto-update related variables with sensible defaults
    if [ -z "${BU_AUTO_UPDATE+x}" ]; then export BU_AUTO_UPDATE="true"; fi
    if [ -z "${BU_AUTO_UPDATE_SILENT+x}" ]; then export BU_AUTO_UPDATE_SILENT="false"; fi
    if [ -z "${BU_AUTO_STASH+x}" ]; then export BU_AUTO_STASH="false"; fi
    if [ -z "${BU_RELEASE_CHECK_FREQUENCY+x}" ]; then export BU_RELEASE_CHECK_FREQUENCY="86400"; fi
}

rollback_BU_VARS() {   # Rollback BU environment variables to pre-export state
    # Unset the variables that were exported by export_BU_VARS
    unset BU
    unset BU_SH
    unset BU_LOADED
    unset BU_RELEASE
    unset BU_VERBOSE_LEVEL
    unset BU_AUTO_UPDATE
    unset BU_AUTO_UPDATE_SILENT
    unset BU_AUTO_STASH
    unset BU_RELEASE_CHECK_FREQUENCY
    info "BU environment variables have been rolled back"
}


# -----------------------------------------------------------------------------
# bu command handler at the bottom
bu() {   # Handle bu command-line interface
    local cmd="$1"
    if [ $# -gt 0 ]; then
        shift  # Only shift if there are arguments left
    fi
    case "$cmd" in
        "list")
            bu_list "$@"
            ;;
        "loaded"|"ls")
            bu_list_loaded "$@"
            ;;
        "load")
            bu_load "$@"
            ;;
        "loadall")
            bu_load_all_utils
            ;;
        "unload")
            bu_unload "$@"
            ;;
        "functions"|"fn")
            bu_functions "$@"
            ;;
        "allfunctions"|"allfns"|"fns")
            if [ -z "$1" ]; then
                bu_functions
            else
                BU_VERBOSE_LEVEL_SAVED=${BU_VERBOSE_LEVEL:-1}
                export BU_VERBOSE_LEVEL=0  # Temporarily disable warnings
                bu_functions | grep -i "$1"
                export BU_VERBOSE_LEVEL=$BU_VERBOSE_LEVEL_SAVED  # Restore original verbosity
            fi
            ;;
        "reload")
            bu_reload "$@"
            ;;
        "gen_alias")
            local mode="$1"
            case "$mode" in
                p)
                    shift
                    gen_project_aliases "$@"
                    ;;
                n)
                    shift
                    bu_load alias
                    bu_load dev_sw
                    gen_nav_aliases "$@"
                    ;;
                *)
                    gen_project_aliases "$@"
                    bu_load alias
                    bu_load dev_sw
                    gen_nav_aliases "$@"
                    ;;
            esac
            ;;
        "check-updates"|"check")
            bu_check_updates "$@"
            ;;
        "update")
            bu_update "$@"
            ;;
        "help"|"--help"|"-h"|"")
            if typeset -f usage >/dev/null 2>&1; then
                usage
            else
                err "usage function not found!"
            fi
            return 0
            ;;
        *)
            err "Unknown command: $cmd"
            err "Use 'bu help' to see available commands"
            return 1
            ;;
    esac
}

# -----------------------------------------------------------------------------
# main
# -----------------------------------------------------------------------------
export BU_SH=$0
if printenv BU &>/dev/null; then
    info "BU is already set to: $BU"
    export BU
else
    info "BU is not set, setting based on $BU_SH"
    export BU="$(dirname $0)"
fi
[ ! -d "$BU" ] && \
    { err "BU directory does not exist: $BU"; 
    [ -n "$ZSH_VERSION" ] && unexport BU || export -n BU; 
    return 1; 
}
export_BU_VARS
info "$BU_SH: BU environment initialized successfully \$BU=$BU"



