
# -----------------------------------------------------------------------------
# File: bu/util_git.sh
# Author: Bazinga Labs LLC
# Email:  support@bazinga-labs.com
# -----------------------------------------------------------------------------
# Description: Utilities for git operations and file management
# -----------------------------------------------------------------------------
# Verify Bash Utilities environment is properly initialized
if ! type info &>/dev/null; then
    echo "ERROR: bu.sh is not loaded. Please source bu.sh first."
    return 1 2>/dev/null || exit 1
fi
# Ensure this file is sourced, not executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
        echo "ERROR: This script should be sourced, not executed."
        echo "Usage: source ${BASH_SOURCE[0]}"
        exit 1
fi
# -----------------------------------------------------------------------------
# START_OF_USAGE
# Utility: Git operations for main repo and submodules
#
# Env Variables:
#   None required
#
# Main Functions:
#   git_update [-r] [submodule1 ...]      : Update main repo and/or submodules
#   git_set_branch -f|-b <branch-name>    : Create/set feature/bug branch in main and submodules
#   git_checkin                              : Commit changes to main repo and all submodules
#
# Examples:
#   git_update -r                          # Update main repo and all submodules
#   git_update                             # Update main repo only, warn if submodules exist
#   git_update submod1 submod2             # Update only specified submodules
#   git_set_branch -f myfeature            # Create/set feature/myfeature branch everywhere
#   git_set_branch -b fix123               # Create/set bug/fix123 branch everywhere
#   git_checkin                              # Commit changes to main repo and all submodules with the same message
# END_OF_USAGE
# -----------------------------------------------------------------------------
util_git_update() {  # Git update for main repo and submodules
    local usage="Usage: git_update [-r] [submodule1 submodule2 ...]"
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        info "$usage"
        info "  -r: update all submodules"
        info "  no args: update main repo only, warn if submodules exist"
        info "  submodule names: update only those submodules"
        return 0
    fi

    # Get submodule list
    local submods
    submods=$(git config --file .gitmodules --get-regexp path | awk '{print $2}')
    if [[ "$1" == "-r" ]]; then
        info "Updating main repository..."
        if ! git pull; then
            err "Main repo update failed."
            return 1
        fi
        if [[ -n "$submods" ]]; then
            info "Updating all submodules..."
            if ! git submodule update --remote --merge; then
                err "Submodule update failed."
                return 2
            fi
        else
            info "No submodules found."
        fi
        return 0
    fi
    if [[ $# -eq 0 ]]; then
        info "Updating main repository only..."
        if ! git pull; then
            err "Main repo update failed."
            return 1
        fi
        if [[ -n "$submods" ]]; then
            warn "Submodules present: $submods"
            warn "NOTE: Submodules NOT updated. Use 'git_update -r' or specify submodules."
        fi
        return 0
    fi
    # Update only specified submodules
    local found=0
    for sm in "$@"; do
        if echo "$submods" | grep -qx "$sm"; then
            info "Updating submodule: $sm"
            if ! git submodule update --remote --merge "$sm"; then
                err "Update failed for submodule: $sm"
            fi
            found=1
        else
            err "Submodule not found: $sm"
        fi
    done
    if [[ $found -eq 0 ]]; then
        warn "No valid submodules specified."
    fi
}
#----------------------------------------------------------------------------
util_git_set_branch() { # Create/set feature/bug branch in main and submodules
    local usage="Usage: git_set_branch -f <branch-name> | -b <branch-name>"
    local type branch prefix
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        info "$usage"
        info "  -f: feature branch"
        info "  -b: bug branch"
        return 0
    fi

    if [[ "$1" == "-f" && -n "$2" ]]; then
        prefix="feature"
        branch="$2"
    elif [[ "$1" == "-b" && -n "$2" ]]; then
        prefix="bug"
        branch="$2"
    else
        err "$usage"
        return 1
    fi

    local full_branch="$prefix/$branch"
    info "Target branch: $full_branch"


    # Check if branch exists locally; create if missing
    if git show-ref --verify --quiet "refs/heads/$full_branch"; then
        info "Branch $full_branch exists locally."
    else
        info "Creating local branch $full_branch..."
        if ! git checkout -b "$full_branch"; then
            err "Failed to create local branch $full_branch."
            return 2
        fi
    fi

    # Check if branch exists remotely; push if missing
    if git ls-remote --exit-code --heads origin "$full_branch" &>/dev/null; then
        info "Branch $full_branch exists on remote."
    else
        info "Pushing branch $full_branch to remote..."
        if ! git push -u origin "$full_branch"; then
            err "Failed to push branch $full_branch to remote."
            return 3
        fi
    fi

    # Switch to the branch
    info "Checking out $full_branch..."
    if ! git checkout "$full_branch"; then
        err "Failed to checkout $full_branch."
        return 4
    fi

    # Submodules
    local submods
    submods=$(git config --file .gitmodules --get-regexp path | awk '{print $2}')
    if [[ -n "$submods" ]]; then
        for sm in $submods; do
            info "Processing submodule: $sm"
            (cd "$sm" && \
                if git show-ref --verify --quiet "refs/heads/$full_branch"; then
                    info "Submodule $sm: branch $full_branch exists locally."
                else
                    info "Submodule $sm: creating local branch $full_branch..."
                    if ! git checkout -b "$full_branch"; then
                        err "Submodule $sm: failed to create local branch $full_branch."
                        return 2
                    fi
                fi
                if git ls-remote --exit-code --heads origin "$full_branch" &>/dev/null; then
                    info "Submodule $sm: branch $full_branch exists on remote."
                else
                    info "Submodule $sm: pushing branch $full_branch to remote..."
                    if ! git push -u origin "$full_branch"; then
                        err "Submodule $sm: failed to push branch $full_branch to remote."
                        return 3
                    fi
                fi
                info "Submodule $sm: checking out $full_branch..."
                if ! git checkout "$full_branch"; then
                    err "Submodule $sm: failed to checkout $full_branch."
                    return 4
                fi
            )
        done
    fi
}
# ----------------------------------------------------------------------------
util_git_checkin() { # Commit changes to main repo and all submodules
    local usage="Usage: git_checkin"
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        info "$usage"
        return 0
    fi

    # Get the current branch of the main repository
    local main_branch
    main_branch=$(git rev-parse --abbrev-ref HEAD)
    if [[ -z "$main_branch" ]]; then
        err "Failed to determine the current branch of the main repository."
        return 1
    fi

    # Get the list of submodules
    local submods
    submods=$(git config --file .gitmodules --get-regexp path | awk '{print $2}')

    # Display branches and ask for confirmation
    info "Main repository branch: $main_branch"
    if [[ -n "$submods" ]]; then
        info "Submodules and their branches:"
        for sm in $submods; do
            local sm_branch
            sm_branch=$(cd "$sm" && git rev-parse --abbrev-ref HEAD)
            info "  $sm: $sm_branch"
        done
    else
        info "No submodules found."
    fi

    read -p "Do you want to proceed with the check-in? (y/n): " confirm
    if [[ "$confirm" != "y" ]]; then
        info "Check-in aborted by the user."
        return 0
    fi

    # Ask for commit message
    read -p "Enter commit message: " commit_msg
    if [[ -z "$commit_msg" ]]; then
        err "Commit message cannot be empty."
        return 1
    fi

    # Commit changes in the main repository
    info "Committing changes in the main repository..."
    if ! git add . && git commit -m "$commit_msg"; then
        err "Failed to commit changes in the main repository."
        return 1
    fi

    # Commit changes in each submodule
    if [[ -n "$submods" ]]; then
        for sm in $submods; do
            info "Committing changes in submodule: $sm"
            (cd "$sm" && git add . && git commit -m "$commit_msg") || {
                err "Failed to commit changes in submodule: $sm"
                return 1
            }
        done
    fi

    info "Check-in completed successfully."
    return 0
}
util_git_add_submodule() { # Add a git submodule with specific naming convention and update it
    local usage="Usage: git_add_submodule <repo-url>"
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        info "$usage"
        info "  Adds submodule to ./libs/<bar> where repo is <foo>-<bar>.git"
        return 0
    fi

    if [[ $# -ne 1 ]]; then
        err "$usage"
        return 1
    fi

    local repo_url="$1"
    # Extract <bar> from <foo>-<bar>.git
    local repo_name
    repo_name=$(basename "$repo_url" .git)
    if [[ "$repo_name" != *-* ]]; then
        err "Repo name must be in <foo>-<bar>.git format."
        return 1
    fi
    local bar="${repo_name#*-}"
    local submodule_path="libs/$bar"

    info "Adding submodule: $repo_url to $submodule_path"
    if ! git submodule add "$repo_url" "$submodule_path"; then
        err "Failed to add submodule."
        return 1
    fi

    info "Updating submodule: $submodule_path"
    if ! git submodule update --init --recursive "$submodule_path"; then
        err "Failed to update submodule."
        return 1
    fi

    info "Submodule added and updated successfully."
}
# Convenience aliases: expose user-friendly comma
util_git_get_branches() {
    # Usage: util_git_get_branches [-r] [searchterm]
    local recursive=0
    local searchterm=""
    if [[ "$1" == "-r" ]]; then
        recursive=1
        shift
    fi
    searchterm="$1"

    # ANSI colors
    local YELLOW="\033[33m"
    local GREEN="\033[32m"
    local RESET="\033[0m"

    # Helper to print branches for a given repo path
    _print_branches() {
        local repo_path="$1"
        (
            cd "$repo_path" || return
            local repo_disp
            repo_disp=$(basename "$(pwd)")
            # Get current branch
            local current_branch
            current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
            # Local branches
            git branch --list | sed 's/^..//' | while read -r branch; do
                if [[ -z "$searchterm" || "$branch" == *"$searchterm"* ]]; then
                    if [[ "$branch" == "$current_branch" ]]; then
                        # Current branch: default color
                        echo "$branch : local"
                    else
                        # Other local branches: yellow
                        echo -e "${YELLOW}$branch${RESET} : local"
                    fi
                fi
            done
            # Remote branches (filter out symbolic refs like origin/HEAD -> origin/main)
            git branch -r | sed 's/^..//' | while read -r branch; do
                # Skip symbolic refs
                if [[ "$branch" == *'->'* ]]; then
                    continue
                fi
                if [[ -z "$searchterm" || "$branch" == *"$searchterm"* ]]; then
                    # Remote branches: green
                    echo -e "${GREEN}$branch${RESET} : remote"
                fi
            done
        )
    }

    # Print for main repo
    _print_branches "."

    # If recursive, print for each submodule
    if [[ $recursive -eq 1 ]]; then
        # For each submodule, get path and url from .gitmodules
        git config --file .gitmodules --get-regexp '^submodule\..*\.path$' | while read -r pathline; do
            local sm_dir sm_url
            sm_dir=$(echo "$pathline" | awk '{print $2}')
            # Get the submodule name from the config key
            local sm_name
            sm_name=$(echo "$pathline" | sed -E 's/^submodule\.([^.]*)\.path.*/\1/')
            # Get the url for this submodule
            sm_url=$(git config --file .gitmodules --get submodule."$sm_name".url)
            if [[ -n "$sm_dir" && -d "$sm_dir" ]]; then
                info "git submodule $sm_dir $sm_url"
                _print_branches "$sm_dir"
            fi
        done
    fi
}
# -----------------------------------------------------------------------------
util_git_install_precommit_hook() { # Install pre-commit hook to block files over specified size
    local usage="Usage: git_install_precommit_hook [repo-dir] [--maxmb=SIZE]"
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        info "$usage"
        info "  repo-dir: Target repository (default: current directory)"
        info "  --maxmb: Maximum file size in MB (default: 100)"
        info "  Requires 'pre-commit' to be installed (pip install pre-commit)"
        return 0
    fi

    local REPO_DIR="."
    local MAX_MB=100

    # Parse arguments
    for arg in "$@"; do
        if [[ "$arg" == --maxmb=* ]]; then
            MAX_MB="${arg#*=}"
        elif [[ -d "$arg" ]]; then
            REPO_DIR="$arg"
        fi
    done

    # Validate repo
    if [[ ! -d "$REPO_DIR/.git" ]]; then
        err "Directory $REPO_DIR is not a Git repository"
        return 1
    fi

    # Check for pre-commit
    if ! command -v pre-commit &>/dev/null; then
        err "'pre-commit' not found. Install with: pip install pre-commit"
        return 1
    fi

    local MAX_KB=$((MAX_MB * 1024))

    (
        cd "$REPO_DIR" || { err "Cannot access $REPO_DIR"; return 1; }

        info "Installing pre-commit hook in: $(pwd)"
        info "Maximum file size: ${MAX_MB}MB (${MAX_KB}KB)"

        # Create hooks directory
        mkdir -p .pre-commit-hooks

        # Create bash script
        cat > .pre-commit-hooks/check-large-files.sh <<'EOF_SCRIPT'
#!/usr/bin/env bash
# Check for large files being added to git
# Usage: check-large-files.sh [--maxkb=SIZE] [files...]

set -e

# Default max size: 100MB = 102400KB
MAX_KB=102400

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
EOF_SCRIPT

        chmod +x .pre-commit-hooks/check-large-files.sh

        # Create config file
        cat > .pre-commit-config.yaml <<EOF_CONFIG
repos:
  - repo: local
    hooks:
      - id: check-added-large-files
        name: Check for files larger than ${MAX_MB}MB
        entry: .pre-commit-hooks/check-large-files.sh
        language: system
        args: ['--maxkb=${MAX_KB}']  # ${MAX_MB}MB = ${MAX_KB}KB
EOF_CONFIG

        # Install hook
        if pre-commit install; then
            info "Pre-commit hook installed successfully!"
            info "Files: .pre-commit-config.yaml, .pre-commit-hooks/check-large-files.sh"
        else
            err "Failed to install pre-commit hook"
            return 1
        fi
    )
}
# -----------------------------------------------------------------------------
alias git-install-precommit-hook='util_git_install_precommit_hook' # Install pre-commit hook to block large files
alias git-add-submodule='util_git_add_submodule' # Add a git submodule with specific naming convention and update it
alias git-update='util_git_update'  # Update main repo and/or submodules
alias git-set-branch='util_git_set_branch' # Create/set feature/bug branch in main and submodules
alias git-get-branches='util_git_get_branches' # Create/set feature/bug branch in main and submodules
alias git-checkin='util_git_checkin' # Commit changes to main repo and all submodules
# -----------------------------------------------------------------------------