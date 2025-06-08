#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: bu/util_chkenv.sh
# Author: Bazinga Labs LLC
# Email:  support@bazinga-labs.com
# -----------------------------------------------------------------------------
# Description: Utilities for checking linux environment variables (PATH, LD_LIBRARY_PATH)
# -----------------------------------------------------------------------------
check_path() { # Display PATH entries and check for duplicates
    if [ -z "$1" ]; then
        info "All PATH entries:"
        echo "$PATH" | tr ":" "\n" | nl -w2 -s" : "
        info "Checking for duplicates:"
        duplicates=$(echo "$PATH" | tr ":" "\n" | sort | uniq -d)
        if [ -z "$duplicates" ]; then
            info "No duplicates found in PATH"
        else
            err "Found duplicates:"
            echo "$duplicates" | while read -r dup; do
                positions=""
                index=1
                while IFS= read -r entry; do
                    ((index++))
                done < <(echo "$PATH" | tr ":" "\n")
                echo "  $dup: [$positions]"
            done
        fi
    else
        info "\nSearching for \"$1\" in PATH:"
        while read -r line; do
            if echo "$line" | grep -q "$1"; then
                err "$line"
            else
                info "$line"
            fi
        done < <(echo "$PATH" | tr ":" "\n" | nl -w2 -s" : ")
    fi
}
# -----------------------------------------------------------------------------
check_ld_library_path() {   # Display LD_LIBRARY_PATH entries and check for duplicates
    if [ -z "$1" ]; then
        echo -e "${BLUE}All LD_LIBRARY_PATH entries:${RESET}"
        echo "$LD_LIBRARY_PATH" | tr ":" "\n" | nl -w2 -s" : "
        echo -e "${BLUE}Checking for duplicates:${RESET}"
        duplicates=$(echo "$LD_LIBRARY_PATH" | tr ":" "\n" | sort | uniq -d)
        if [ -z "$duplicates" ]; then
            echo -e -n "${GREEN}No duplicates found in LD_LIBRARY_PATH${RESET}"
        else
            echo -e "${RED}Found duplicates:${RESET}"
            echo "$duplicates" | while read -r dup; do
                positions=""
                index=1
                echo "  $dup: [$positions]"
            done
        fi
    else
        echo -e "\n${BLUE}Searching for \"$1\" in LD_LIBRARY_PATH:${RESET}"
        while read -r line; do
            if echo "$line" | grep -q "$1"; then
                echo -e "${RED}$line${RESET}"
            else
                echo -e "${GREEN}$line${RESET}"
            fi
        done < <(echo "$LD_LIBRARY_PATH" | tr ":" "\n" | nl -w2 -s" : ")
    fi
}
# -----------------------------------------------------------------------------
check_env_var() { # Check if an environment variable is set and non-empty
    [ -z "$1" ] && { echo "Usage: check_env_var VAR_NAME"; return 1; }
    val="${!1}"
    if [ -n "$val" ]; then
        return 0
    else
        return 1
    fi
}
# -----------------------------------------------------------------------------