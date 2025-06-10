#!/bin/env bash
# -----------------------------------------------------------------------------
# File: bu/util_fileformats.sh
# Author: Amit
# Date: June 10, 2025
# -----------------------------------------------------------------------------
# Description: Utilities for converting text file formats (line endings)
# -----------------------------------------------------------------------------
# Ensure proper Bash Utilities environment
if ! type info &>/dev/null; then
    echo "ERROR: bu.sh is not loaded. Please source bu.sh first."
    return 1 2>/dev/null || exit 1
fi
# Ensure this file is sourced, not executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "ERROR: This script should be sourced, not executed."
    exit 1
fi
# -----------------------------------------------------------------------------
fileformats_dos2unix() { # Convert DOS/Windows line endings (CRLF) to Unix (LF)
    local file="$1"
    
    if [ -z "$file" ]; then
        err "No file specified."
        info "Usage: fileformats_dos2unix <filename>"
        return 1
    fi
    
    if [ ! -f "$file" ]; then
        err "File not found: $file"
        return 1
    fi
    
    info "Converting $file from DOS to Unix format..."
    local tmp_file=$(mktemp)
    
    tr -d '\r' < "$file" > "$tmp_file" && mv "$tmp_file" "$file"
    local status=$?
    
    if [ $status -eq 0 ]; then
        info "Successfully converted $file to Unix format."
        return 0
    else
        err "Failed to convert $file to Unix format."
        [ -f "$tmp_file" ] && rm "$tmp_file"
        return 1
    fi
}

# -----------------------------------------------------------------------------
fileformats_unix2dos() { # Convert Unix line endings (LF) to DOS/Windows (CRLF)
    local file="$1"
    
    if [ -z "$file" ]; then
        err "No file specified."
        info "Usage: fileformats_unix2dos <filename>"
        return 1
    fi
    
    if [ ! -f "$file" ]; then
        err "File not found: $file"
        return 1
    fi
    
    info "Converting $file from Unix to DOS format..."
    local tmp_file=$(mktemp)
    
    awk 'BEGIN{ORS="\r\n"} {print}' "$file" > "$tmp_file" && mv "$tmp_file" "$file"
    local status=$?
    
    if [ $status -eq 0 ]; then
        info "Successfully converted $file to DOS format."
        return 0
    else
        err "Failed to convert $file to DOS format."
        [ -f "$tmp_file" ] && rm "$tmp_file"
        return 1
    fi
}

# -----------------------------------------------------------------------------
fileformats_check() { # Check file line ending format (DOS/Unix)
    local file="$1"
    
    if [ -z "$file" ]; then
        err "No file specified."
        info "Usage: fileformats_check <filename>"
        return 1
    fi
    
    if [ ! -f "$file" ]; then
        err "File not found: $file"
        return 1
    fi
    
    info "Checking line endings for $file..."
    
    # Count occurrences of CR characters
    local cr_count=$(tr -d -c '\r' < "$file" | wc -c)
    # Count total lines
    local line_count=$(wc -l < "$file")
    
    # Output formatting
    cr_count=$(echo "$cr_count" | tr -d ' ')
    line_count=$(echo "$line_count" | tr -d ' ')
    
    if [ "$cr_count" -eq 0 ]; then
        info "File has Unix-style line endings (LF only)."
    elif [ "$cr_count" -eq "$line_count" ]; then
        info "File has DOS/Windows-style line endings (CRLF)."
    else
        warn "File has mixed line endings (${cr_count}/${line_count} lines have CR characters)."
    fi
    
    return 0
}

# -----------------------------------------------------------------------------
fileformats_batch_convert() { # Convert multiple files matching a pattern
    local mode="$1"  # dos2unix or unix2dos
    local pattern="$2"
    
    if [ -z "$pattern" ] || [ -z "$mode" ]; then
        err "Missing arguments."
        info "Usage: fileformats_batch_convert <file_pattern> <mode>"
        info "  mode: dos2unix or unix2dos"
        return 1
    fi
    
    if [[ "$mode" != "dos2unix" && "$mode" != "unix2dos" ]]; then
        err "Invalid mode: $mode. Use 'dos2unix' or 'unix2dos'."
        return 1
    fi
    
    local count=0
    local failed=0
    
    info "Converting files matching pattern: $pattern"
    for file in $pattern; do
        if [ -f "$file" ]; then
            if [ "$mode" = "dos2unix" ]; then
                fileformats_dos2unix "$file"
            else
                fileformats_unix2dos "$file"
            fi
            
            if [ $? -eq 0 ]; then
                count=$((count + 1))
            else
                failed=$((failed + 1))
            fi
        fi
    done
    
    if [ $count -eq 0 ] && [ $failed -eq 0 ]; then
        warn "No files matched the pattern: $pattern"
        return 1
    else
        info "Conversion complete: $count files converted, $failed failed."
        [ $failed -eq 0 ] && return 0 || return 1
    fi
}

# -----------------------------------------------------------------------------
# Create aliases for easier use
# -----------------------------------------------------------------------------
alias dos2unix='fileformats_dos2unix' # Convert DOS/Windows line endings to Unix
alias unix2dos='fileformats_unix2dos' # Convert Unix line endings to DOS/Windows
alias check_format='fileformats_check' # Check file line ending format
# -----------------------------------------------------------------------------
