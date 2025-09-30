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
alias git-add-submodule='util_git_add_submodule' # Add a git submodule with specific naming convention and update it
alias git-update='util_git_update'  # Update main repo and/or submodules
alias git-set-branch='util_git_set_branch' # Create/set feature/bug branch in main and submodules
alias git-get-branches='util_git_get_branches' # Create/set feature/bug branch in main and submodules
alias git-checkin='util_git_checkin' # Commit changes to main repo and all submodules