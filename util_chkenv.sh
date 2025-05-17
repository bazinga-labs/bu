# -----------------------------------------------------------------------------
# File: bu/util_chkenv.sh
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

[[ -z "${BASH_UTILS_LOADED}" ]] && { 
    echo "ERROR: util_bash.sh is not loaded. check \$BASH_UTILS_LOADED and \$BASH_UTILS_SRC"
    exit 1;
}
# -----------------------------------------------------------------------------
check_path() { # Display PATH entries and check for duplicates
    if [ -z "$1" ]; then
        # No input - display all PATH entries
        info "All PATH entries:"
        echo "$PATH" | tr ":" "\n" | nl -w2 -s" : "

        # Find and display duplicates
        info "Checking for duplicates:"
        duplicates=$(echo "$PATH" | tr ":" "\n" | sort | uniq -d)

        if [ -z "$duplicates" ]; then
            info "No duplicates found in PATH"
        else
            err "Found duplicates:"
            # Process each duplicate path
            echo "$duplicates" | while read -r dup; do
                positions=""
                index=1
                
                # Find all positions of this duplicate in PATH
                while IFS= read -r entry; do
                    if [ "$entry" = "$dup" ]; then
                        if [ -z "$positions" ]; then
                            positions="$index"
                        else
                            positions="$positions, $index"
                        fi
                    fi
                    ((index++))
                done < <(echo "$PATH" | tr ":" "\n")
                
                # Print with correct format
                echo "  $dup: [$positions]"
            done
        fi
    else
        # Search input provided - only show matches
        info "\nSearching for \"$1\" in PATH:"
        while read -r line; do
            if echo "$line" | grep -q "$1"; then
                # Path contains search term - display in red
                err "$line"
            else
                # Path doesn't contain search term - display in green
                info "$line"
            fi
        done < <(echo "$PATH" | tr ":" "\n" | nl -w2 -s" : ")
    fi
}
# -----------------------------------------------------------------------------
check_ld_library_path() {   # Display LD_LIBRARY_PATH entries and check for duplicates
    if [ -z "$1" ]; then
        # No input - display all LD_LIBRARY_PATH entries
        echo -e "${BLUE}All LD_LIBRARY_PATH entries:${RESET}"
        echo "$LD_LIBRARY_PATH" | tr ":" "\n" | nl -w2 -s" : "

        # Find and display duplicates
        echo -e "${BLUE}Checking for duplicates:${RESET}"
        duplicates=$(echo "$LD_LIBRARY_PATH" | tr ":" "\n" | sort | uniq -d)

        if [ -z "$duplicates" ]; then
            echo -e -n "${GREEN}No duplicates found in LD_LIBRARY_PATH${RESET}"
        else
            echo -e "${RED}Found duplicates:${RESET}"
            # Process each duplicate path
            echo "$duplicates" | while read -r dup; do
                positions=""
                index=1
                
                # Find all positions of this duplicate in LD_LIBRARY_PATH
                while IFS= read -r entry; do
                    if [ "$entry" = "$dup" ]; then
                        if [ -z "$positions" ]; then
                            positions="$index"
                        else
                            positions="$positions, $index"
                        fi
                    fi
                    ((index++))
                done < <(echo "$LD_LIBRARY_PATH" | tr ":" "\n")
                
                # Print with correct format
                echo "  $dup: [$positions]"
            done
        fi
    else
        # Search input provided - only show matches
        echo -e "\n${BLUE}Searching for \"$1\" in LD_LIBRARY_PATH:${RESET}"
        while read -r line; do
            if echo "$line" | grep -q "$1"; then
                # Path contains search term - display in red
                echo -e "${RED}$line${RESET}"
            else
                # Path doesn't contain search term - display in green
                echo -e "${GREEN}$line${RESET}"
            fi
        done < <(echo "$LD_LIBRARY_PATH" | tr ":" "\n" | nl -w2 -s" : ")
    fi
}
# Check if an environment variable is set and non-empty
checkenvvar() {
    [ -z "$1" ] && { echo "Usage: checkenvvar VAR_NAME"; return 1; }
    val="${!1}"
    if [ -n "$val" ]; then
        return 0
    else
        return 1
    fi
}

# -----------------------------------------------------------------------------
list_bash_functions_in_file