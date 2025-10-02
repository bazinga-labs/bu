#!/usr/bin/env bash
# Check for large files being added to git
# Usage: check-large-files.sh [--maxkb=SIZE] [files...]

set -e

# Default max size: 100MB = 102400KB
MAX_KB=97280 #95MB


# Parse arguments
FILES=()
for arg in "$@"; do
    if [[ "$arg" == --maxkb=* ]]; then
        MAX_KB="${arg#*=}"
    else
        FILES+=("$arg")
    fi
done

# If no files specified, check all staged files
if [[ ${#FILES[@]} -eq 0 ]]; then
    # Get list of added files (A = added, not deleted or renamed)
    mapfile -t FILES < <(git diff --cached --name-only --diff-filter=A)
fi

EXIT_CODE=0

# Check each file
for file in "${FILES[@]}"; do
    if [[ -f "$file" ]]; then
        # Get file size in KB
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            FILE_SIZE=$(stat -f %z "$file")
        else
            # Linux
            FILE_SIZE=$(stat -c %s "$file")
        fi

        # Convert bytes to KB (rounded up)
        FILE_KB=$(( (FILE_SIZE + 1023) / 1024 ))

        if [[ $FILE_KB -gt $MAX_KB ]]; then
            echo "$file ($FILE_KB KB) exceeds $MAX_KB KB."
            EXIT_CODE=1
        fi
    fi
done

exit $EXIT_CODE
