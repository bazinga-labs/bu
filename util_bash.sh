#!/bin/bash
# -----------------------------------------------------------------------------
# File: bu/util_bash.sh
# Author: Bazinga Labs LLC
# Email:  support@bazinga-labs.com
# ==============================================================================
# DO NOT MODIFY THIS FILE WITHOUT PRIOR AUTHORIZATION
#
# This file is managed by Bazinga Labs LLC and changes may be overwritten.
# Unauthorized edits may result in system malfunction or integration failure.
# Contact support@bazinga-labs.com for changes or exceptions.
# ==============================================================================
# Description: Utilities for checking linux environment variables (PATH, LD_LIBRARY_PATH)
# -----------------------------------------------------------------------------
# WARNING: This is the main utility file and should be loaded first.
# -----------------------------------------------------------------------------

if [ -z "$BASH_UTILS_SRC" ]; then
    echo "Error: BASH_UTILS_SRC is not defined. This variable must point to the directory containing utility scripts."
    return 1 2>/dev/null || exit 1
fi

# Export environment variable to track loaded utilities
export BASH_UTILS_LOADED=""

# Color definitions for consistent output formatting
export RED="\033[1;31m"
export ORANGE="\033[1;33m"
export BLUE="\033[1;34m"
export GREEN="\033[1;32m"
export RESET="\033[0m"

# -----------------------------------------------------------------------------
# Helper functions for formatted output
# -----------------------------------------------------------------------------
err() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] Error: $*${RESET}" >&2
}

warn() {
    echo -e "${ORANGE}[$(date '+%Y-%m-%d %H:%M:%S')] Warning: $*${RESET}" >&2
}

info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] Info: $*${RESET}"
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
    echo "$BASH_UTILS_SRC/util_${name}.sh"
}
# -----------------------------------------------------------------------------
list_bash_functions_in_file() {   # List all function definitions in a file with descriptions
    local script_path="$1"
    info "Functions defined in [$(basename "$script_path")]: "
    # Use grep to find function definitions that include an inline comment for description
    fs=$(grep -E '^[a-zA-Z0-9_]+\(\)\ *\{\ *#' "$script_path")
    
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
        printf " %-${max_len}s :%s\n" "$func_name" "$description"
    done <<< "$fs"
}
# -----------------------------------------------------------------------------
list_alias_in_file() {   # List all alias definitions in this file with descriptions
    local script_path="$1"
    info "Aliases defined in [$(basename "$script_path")]: "
    # Use grep to find alias definitions that include an inline comment for description
    as=$(grep -E '^alias [^=]+=.*#' "$script_path")
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
        printf " %-${max_len}s :%s\n" "$alias_name" "$description"
    done <<< "$as"
}
# -----------------------------------------------------------------------------
bu_list() {   # Display all available bash utilities
    info "All available BASH utilities:"
    # Find all utility files in BASH_UTILS_SRC
    ls -1 "$BASH_UTILS_SRC"/util_*.sh 2>/dev/null | while read -r util_path; do
        local util_name="$(bu_util_name "$util_path")"
        # Extract description from the utility file
        util_description="NA"; [ -f "$util_path" ] && desc=$(grep -m 1 "# Description:" "$util_path" | sed 's/# Description://' | xargs) && [ -n "$desc" ] && util_description="$desc"
        # Filter by search term if provided
        if [ -z "$1" ] || echo "$util_name" | grep -q "$1" || echo "$util_path" | grep -q "$1"; then
            echo "$util_name : $util_description"
        fi
    done
}
# -----------------------------------------------------------------------------
bu_list_loaded() {   # Display loaded bash utilities
    info "Loaded BASH utilities:"
    if [ -z "$BASH_UTILS_LOADED" ]; then
        err "No utilities currently loaded."
        return 1
    fi
    
    # Process each utility
    echo "$BASH_UTILS_LOADED" | tr ":" "\n" | while read -r util_name; do
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
        if [[ "$BASH_UTILS_LOADED" != *"$util_name"* ]]; then
            if [ -z "$BASH_UTILS_LOADED" ]; then
                BASH_UTILS_LOADED="$util_name"
            else
                BASH_UTILS_LOADED="$BASH_UTILS_LOADED:$util_name"
            fi
        fi
        info "Utility '$util_name' loaded successfully."
        return 0
    else
        err "Error loading utility '$util_name'."
        return 1
    fi
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
    if [[ "$BASH_UTILS_LOADED" != *"$util_name"* ]]; then
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
    
    # Update the BASH_UTILS_LOADED variable to remove this utility
    local new_loaded=""
    for loaded_util in $(echo "$BASH_UTILS_LOADED" | tr ":" " "); do
        if [ "$loaded_util" != "$util_name" ]; then
            if [ -z "$new_loaded" ]; then
                new_loaded="$loaded_util"
            else
                new_loaded="$new_loaded:$loaded_util"
            fi
        fi
    done
    # Set the updated list of loaded utilities
    BASH_UTILS_LOADED="$new_loaded"
    info "Utility '$util_name' unloaded successfully."
    return 0
}
# -----------------------------------------------------------------------------
bu_functions() {   # Show functions available in loaded bash utilities
    local util_name="$1"
    
    # If no utilities are loaded, inform user and exit
    if [ -z "$BASH_UTILS_LOADED" ]; then
        warn "No utilities currently loaded."
    fi
    
    # If utility name is provided, check if it's loaded and show its functions
    if [ -n "$util_name" ]; then
        if [[ "$BASH_UTILS_LOADED" != *"$util_name"* ]]; then
            warn "Utility '$util_name' is not currently loaded."
        fi
        
        local util_path="$(bu_util_path "$util_name")"
        if [ -f "$util_path" ]; then
            list_bash_functions_in_file "$util_path"
        else
            err "Utility file for '$util_name' not found at $util_path"
            return 1
        fi
        return 0
    fi
    
    # If no specific utility name is provided, show functions for all loaded utilities
    info "Functions available in loaded utilities:"
    echo "$BASH_UTILS_LOADED" | tr ":" "\n" | while read -r util; do
        [ -z "$util" ] && continue  # Skip empty entries
        util_path="$(bu_util_path "$util")"
        
        if [ -f "$util_path" ]; then
            list_bash_functions_in_file "$util_path"
        else
            err "Functions for utility '$util' cannot be shown (file missing)"
        fi
    done
}
# -----------------------------------------------------------------------------
bu_reload() {   # Reload a specified bash utility (unload and load again) or all if none specified
    local util_name="$1"
    
    # If no utility name was provided, reload all loaded utilities
    if [ -z "$util_name" ]; then
        # Check if any utilities are loaded
        if [ -z "$BASH_UTILS_LOADED" ]; then
            warn "No utilities currently loaded."
            return 0
        fi
        
        info "Reloading all loaded utilities..."
        local all_success=true
        local reloaded_count=0
        local failed_count=0
        
        # Create a temporary copy of the loaded utilities list
        local utils_to_reload=$(echo "$BASH_UTILS_LOADED" | tr ":" " ")
        
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
    if [[ "$BASH_UTILS_LOADED" != *"$util_name"* ]]; then
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
# -----------------------------------------------------------------------------
info "BashUtils loaded from $(realpath "$BASH_UTILS_SRC")"; 
BASH_UTILS_LOADED="$BASH_UTILS_LOADED:$(bu_util_name "$(realpath "$0")")"
