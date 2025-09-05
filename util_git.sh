#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: bu/util_git.sh
# Author: Bazinga Labs LLC
# Email:  support@bazinga-labs.com
# -----------------------------------------------------------------------------
# Description: Utilities for git operations and file management
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Helper function for common push operation
_git_push_current_branch() {
    local current_branch
    current_branch=$(git rev-parse --abbrev-ref HEAD)
    local repo_url
    repo_url=$(git config --get remote.origin.url)
    info "Pushing changes to remote: $repo_url"
    git push origin "$current_branch"
    local push_status=$?
    if [ $push_status -ne 0 ]; then
        err "Failed to push to remote repository."
        return 1
    fi
    return 0
}

# -----------------------------------------------------------------------------
git_is_repo() { # Checks if the current directory is within a git repository
    # Check if inside a git repository
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        # Not a git directory
        echo "Not a git repo"
        return 0
    fi
    
    # Check if it's a remote repository
    remote=$(git config --get remote.origin.url 2>/dev/null)
    if [ -n "$remote" ]; then
        # It's a remote git repository
        echo "Remote git repo: $remote"
        return 2
    else
        # It's a local-only git repository
        echo "Local git repo only: $(git rev-parse --show-toplevel 2>/dev/null)"
        return 1
    fi
}

# -----------------------------------------------------------------------------
git_file_info() { # Displays version information for a given file based on git history
    local file="$1"
    [ -z "$file" ] && { err "No file specified."; return 1; }
    [ ! -f "$file" ] && { err "File '$file' does not exist."; return 1; }
    
    # Get all git info in a single call to reduce overhead
    local git_info
    git_info=$(git log -n 1 --pretty=format:"%h|%ad|%s" --date=short -- "$file" 2>/dev/null)
    [ -z "$git_info" ] && { err "File '$file' not found in git history."; return 1; }
    
    # Parse the git info
    local git_sha="${git_info%%|*}"
    local git_date="${git_info#*|}"; git_date="${git_date%%|*}"
    local git_msg="${git_info##*|}"
    
    # Calculate SHA values in parallel using command substitution
    local local_sha git_file_content
    local_sha=$(shasum -a 256 "$file" | awk '{print $1}')
    git_file_content=$(git show "$git_sha:$file" 2>/dev/null | shasum -a 256 | awk '{print $1}')
    
    # Get tags containing the commit
    local tags=$(git tag --contains "$git_sha" 2>/dev/null | tr '\n' ' ')
    
    # Display information
    info "File Version Info: $file"
    info "Version: $git_sha"
    info "Last Updated: $git_date"
    info "Last Update Message: $git_msg"
    info "Tags: ${tags:-none}"
    info "SHA (Git): $git_file_content"
    
    if [ "$local_sha" != "$git_file_content" ]; then
        info "Status: MODIFIED"
        info "SHA (Local): $local_sha (modified)"
    else
        info "Status: UNCHANGED"
        info "SHA (Local): $local_sha"
    fi
}

# -----------------------------------------------------------------------------
git_file_history() { # Outputs the git commit history for the specified file, following renames
    local file="$1"
    [ -z "$file" ] && { err "No file specified."; return 1; }
    [ ! -f "$file" ] && { err "File '$file' does not exist."; return 1; }
    
    info "Git history for file: $file"
    
    # Generate history in a single optimized git command
    local temp_file="/tmp/git-file-history-$$.csv"
    
    # Use more efficient git log format and simpler awk processing
    git log --reverse --follow --pretty=format:"%D,%h,%ad,%s" --date=format:"%Y-%m-%d %H:%M:%S" -- "$file" | 
    awk -F',' 'BEGIN{OFS=","} {
        # Determine branch from first field
        branch = "main";
        if ($1 ~ /HEAD -> /) {
            gsub(".* -> ", "", $1);
            gsub(/,.*/, "", $1);
            branch = $1;
        } else if ($1 ~ /tag: /) {
            gsub(".*tag: ", "", $1);
            gsub(/,.*/, "", $1);
            branch = $1;
        }
        # Format output with version number
        printf "%s/v%d,%s,%s,%s\n", branch, NR, $2, $3, $4;
    }' > "$temp_file"
    
    # Open the CSV file with smart_edit if available, otherwise display info
    if command -v smart_edit >/dev/null 2>&1; then
        smart_edit "$temp_file"
    else
        info "Git history saved to: $temp_file"
        head -10 "$temp_file" 2>/dev/null || true
    fi
}

# -----------------------------------------------------------------------------
git_find_modified() { # Find all files that differ from HEAD
    local include_unmanaged=false
    
    # Process command-line options
    while [ "$#" -gt 0 ]; do
        case "$1" in
            -u|--unmanaged) include_unmanaged=true ;;
            *) break ;;
        esac
        shift
    done
    
    # Get all status information in one command
    local status_output
    if [ "$include_unmanaged" = true ]; then
        status_output=$(git status --porcelain=v1 2>/dev/null)
    else
        status_output=$(git status --porcelain=v1 2>/dev/null | grep -E '^[MADRCU ]M|^M[MADRCU ]|^A[MADRCU ]|^D[MADRCU ]|^R[MADRCU ]|^C[MADRCU ]|^U[MADRCU ]')
    fi
    
    # Early exit if no changes
    if [ -z "$status_output" ]; then
        info "All files are up to date with HEAD"
        return 0
    fi
    
    info "Files not in sync with HEAD:"
    
    # Process status output more efficiently
    local has_modified=false has_unmanaged=false
    
    echo "$status_output" | while IFS= read -r line; do
        [ -z "$line" ] && continue
        
        local status="${line:0:2}"
        local file="${line:3}"
        
        case "$status" in
            ' M'|'M '|'MM'|'AM'|'AD'|'RM'|'CM')
                if [ "$has_modified" = false ]; then
                    echo -e "${YELLOW}Modified files:${RESET}"
                    has_modified=true
                fi
                echo -e " ${YELLOW}M${RESET} $file"
                ;;
            '??')
                if [ "$include_unmanaged" = true ]; then
                    if [ "$has_unmanaged" = false ]; then
                        echo -e "${ORANGE}Unmanaged files (not in git repo):${RESET}"
                        has_unmanaged=true
                    fi
                    echo -e " ${ORANGE}U${RESET} $file"
                fi
                ;;
            *)
                if [ "$has_modified" = false ]; then
                    echo -e "${YELLOW}Modified files:${RESET}"
                    has_modified=true
                fi
                echo -e " ${YELLOW}${status:0:1}${RESET} $file"
                ;;
        esac
    done
}

# -----------------------------------------------------------------------------
git_checkout_head() {   # Replace local file with HEAD version from git
    [ -z "$1" ] && { err "No file specified."; return 1; }
    local file="$1"
    [ ! -f "$file" ] && { err "File '$file' does not exist."; return 1; }
    
    info "Replacing local file with version from HEAD: $file"
    
    # Use modern git restore or fallback to checkout
    if git restore --source=HEAD "$file" 2>/dev/null; then
        info "Successfully restored '$file' from HEAD."
    elif git checkout HEAD -- "$file" 2>/dev/null; then
        info "Successfully restored '$file' from HEAD."
    else
        err "Failed to restore '$file' from HEAD."
        return 1
    fi
}

# -----------------------------------------------------------------------------
git_discard_changes() { # Discards local modifications to a specified file
    [ -z "$1" ] && { info "Usage: git_discard_changes <file>"; return 1; }
    [ ! -f "$1" ] && { err "File not found: $1"; return 1; }
    
    # Use modern git restore or fallback to checkout
    if git restore --source=HEAD "$1" 2>/dev/null; then
        info "Discarded changes to $1. File replaced with HEAD version."
    else
        git checkout HEAD -- "$1" && info "Discarded changes to $1. File replaced with HEAD version."
    fi
}

# -----------------------------------------------------------------------------
git_checkin() { # Commit multiple files to GitHub repo using a commit message provided via --m option and push flag -p
    local push_flag=""
    local commit_msg=""
    local files=()
    
    # Process arguments
    while [ "$#" -gt 0 ]; do
        case "$1" in
            -p|--push)
                push_flag="push"
                ;;
            -m|--m)
                shift
                commit_msg="$1"
                ;;
            *)
                files+=("$1")
                ;;
        esac
        shift
    done
    
    [ -z "$commit_msg" ] && { err "No commit message provided. Usage: git_checkin --m \"message\" [-p|--push] <file1> [file2 ...]"; return 1; }
    [ ${#files[@]} -eq 0 ] && { err "No files specified. Usage: git_checkin --m \"message\" [-p|--push] <file1> [file2 ...]"; return 1; }
    
    # Add each file to staging area
    for file in "${files[@]}"; do
        if [ ! -f "$file" ]; then
            warn "File '$file' does not exist, skipping."
            continue
        fi
        info "Adding '$file' to git staging area..."
        git add "$file"
    done
    
    # Commit the files using the provided commit message
    info "Committing files with message:"
    info "$commit_msg"
    git commit -m "$commit_msg"
    local commit_status=$?
    
    if [ $commit_status -ne 0 ]; then
        err "Failed to commit the files."
        return 1
    fi
    
    # Push if requested
    if [ "$push_flag" = "push" ]; then
        _git_push_current_branch
    fi
    
    info "Files committed successfully."
    return 0
}

# -----------------------------------------------------------------------------
git_update_files() { # Update files from git repository with various options
    # Assuming we're in a remote git repository
    local force=false
    local only_unmodified=false
    local files_to_update=()
    
    # Process command-line options
    while [ "$#" -gt 0 ]; do
        case "$1" in
            -f|--force) force=true ;;
            -nm|--not-modified) only_unmodified=true ;;
            *) files_to_update+=("$1") ;;
        esac
        shift
    done
    
    # Fetch latest changes from remote
    local repo_url=$(git config --get remote.origin.url)
    info "Fetching latest changes from remote: $repo_url"
    git fetch origin
    
    # If no specific files were provided
    if [ ${#files_to_update[@]} -eq 0 ]; then
        # If force flag is set, update all tracked files
        if [ "$force" = true ]; then
            info "Force updating all tracked files..."
            git checkout -f HEAD
            info "All files updated to latest version from HEAD."
            return 0
        fi
        
            # If only_unmodified flag is set, update only unmodified files
        if [ "$only_unmodified" = true ]; then
            info "Updating only unmodified files..."
            # Get modified and all files in single operation
            local modified_files=$(git diff --name-only HEAD)
            
            # Use git ls-files to get all tracked files, filter out modified ones
            git ls-files | while read -r file; do
                if ! echo "$modified_files" | grep -q "^${file}$"; then
                    info "Updating unmodified file: $file"
                    git restore --source=HEAD "$file" 2>/dev/null || git checkout HEAD -- "$file"
                fi
            done
            info "Unmodified files updated successfully."
            return 0
        fi
        
        # If no flags are set and no files specified, update everything safely
        info "Safely updating repository. Stashing local changes first..."
        git stash
        git pull --rebase
        git stash pop
        info "Repository updated successfully."
        return 0
    fi
    
    # If specific files were provided, update them according to the flags
    for file in "${files_to_update[@]}"; do
        # Check if file exists and is tracked by git
        if ! git ls-files --error-unmatch "$file" &>/dev/null; then
            warn "File not tracked by git, skipping: $file"
            continue
        fi
        
        # Check if file is modified locally (more efficient check)
        if git diff --quiet HEAD -- "$file"; then
            # File is not modified
            info "Updating file: $file"
            git restore --source=HEAD "$file" 2>/dev/null || git checkout HEAD -- "$file"
        elif [ "$force" = true ]; then
            # File is modified but force flag is set
            info "Force updating modified file: $file"
            git restore --source=HEAD "$file" 2>/dev/null || git checkout HEAD -- "$file"
        elif [ "$only_unmodified" = true ]; then
            # File is modified and only_unmodified is true
            info "Skipping modified file: $file"
        else
            # File is modified and no force flag
            warn "File has local modifications. Use --force to overwrite: $file"
        fi
    done
    
    info "File update process completed."
    return 0
}

# -----------------------------------------------------------------------------
git_delete_file() { # Remove a file from git repository
    local file=""
    local commit_msg=""
    local remove_local=false
    local push_flag=false
    
    # Process command-line options
    while [ "$#" -gt 0 ]; do
        case "$1" in
            -l|--local) remove_local=true ;;
            -p|--push) push_flag=true ;;
            -m|--message) 
                shift
                commit_msg="$1" 
                ;;
            *)
                if [ -z "$file" ]; then
                    file="$1"
                else
                    err "Unexpected argument: $1"
                    err "Usage: git_delete_file <file> [-l|--local] [-p|--push] [-m|--message <commit_message>]"
                    return 1
                fi
                ;;
        esac
        shift
    done
    
    # Check if file was specified
    [ -z "$file" ] && { 
        err "No file specified." 
        err "Usage: git_delete_file <file> [-l|--local] [-p|--push] [-m|--message <commit_message>]"
        return 1 
    }
    
    # Check if file exists in git repo
    if ! git ls-files --error-unmatch "$file" &>/dev/null; then
        err "File '$file' is not tracked by git."
        return 1
    fi
    
    # Set default commit message if not provided
    if [ -z "$commit_msg" ]; then
        commit_msg="Deleted $(basename "$file") from repository"
    fi
    
    # Remove the file from git tracking
    info "Removing '$file' from git tracking..."
    git rm --cached "$file"
    
    # Remove the local file if requested
    if [ "$remove_local" = true ]; then
        info "Removing local file '$file'..."
        rm -f "$file"
    else
        info "Local file '$file' left untouched. It's now only in your local filesystem."
        info "Add it to .gitignore if you don't want it to show as untracked."
    fi
    
    # Commit the change
    info "Committing removal with message: $commit_msg"
    git commit -m "$commit_msg"
    local commit_status=$?
    
    if [ $commit_status -ne 0 ]; then
        err "Failed to commit the removal."
        return 1
    fi
    
    # Push if requested
    if [ "$push_flag" = true ]; then
        _git_push_current_branch
    fi
    
    info "File '$file' has been removed from git repository."
    return 0
}

# -----------------------------------------------------------------------------
git_tkdiff_remote() { # Compares a local file to its counterpart on the remote origin
    [ -z "$1" ] && { info "Usage: git_tkdiff_remote <file>"; return 1; }
    
    local file="$1"
    
    # Verify prerequisites in parallel
    if ! command -v tkdiff >/dev/null 2>&1; then
        err "tkdiff is not installed. Please install tkdiff to use this function."
        return 1
    fi
    
    # Get branch and remote info efficiently
    local branch repo_url
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || { err "Not in a git repository."; return 1; }
    repo_url=$(git config --get remote.origin.url 2>/dev/null) || { err "No remote origin configured."; return 1; }
    
    info "Remote repository: $repo_url"
    info "Current branch: $branch"
    info "Comparing local '$file' with remote 'origin/$branch:$file'"
    
    # Validate remote accessibility and file existence in one operation
    if ! git cat-file -e "origin/$branch:$file" 2>/dev/null; then
        # Fetch first in case remote is stale
        git fetch origin "$branch" &>/dev/null
        if ! git cat-file -e "origin/$branch:$file" 2>/dev/null; then
            err "File '$file' not found in origin/$branch or remote not accessible."
            return 1
        fi
    fi
    
    # Create temporary file and run diff
    local temp_file
    temp_file=$(mktemp "/tmp/git-remote-$$.XXXXXX") || { err "Failed to create temporary file."; return 1; }
    
    if git show "origin/$branch:$file" > "$temp_file" 2>/dev/null; then
        info "Running tkdiff..."
        tkdiff "$file" "$temp_file"
        rm -f "$temp_file"
        return 0
    else
        err "Failed to retrieve remote file content."
        rm -f "$temp_file"
        return 1
    fi
}

# -----------------------------------------------------------------------------
git_stash_named() { # Creates a new git stash with the provided name/message
    # Assuming we're in a git repository
    
    # Validate input parameter
    [ -z "$1" ] && { info "Usage: git_stash_named <stash_name>"; return 1; }
    # Create a git stash with the provided name
    git stash push -m "$1"
}

# -----------------------------------------------------------------------------
git_stash_list() { # Lists all git stashes in the repository
    # Assuming we're in a git repository
    git stash list
}

# -----------------------------------------------------------------------------
setup_ssh_git() { # Sets up SSH keys for GitHub authentication
    local email=${1:-$(git config user.email 2>/dev/null)}
    local key=${2:-id_ed25519}
    local remote=${3:-origin}
    local repo=${4:-git@github.com:bazinga-labs/bu.git}
    [[ -z $email ]] && { info "Usage: setup_ssh_git your.email@example.com [key_name] [remote_name] [repo_ssh_url]"; return 1; }

    info "Setting up SSH authentication for Git with email: $email"
    mkdir -p ~/.ssh
    [[ ! -f ~/.ssh/$key ]] && { 
        info "Creating new SSH key: ~/.ssh/$key"
        ssh-keygen -t ed25519 -C "$email" -f ~/.ssh/$key -N ""
    } || info "Using existing SSH key: ~/.ssh/$key"
    
    info "Starting SSH agent and adding key"
    eval "$(ssh-agent -s)" >/dev/null
    ssh-add ~/.ssh/$key

    info "=== Public key: upload to GitHub SSH keys ==="
    cat ~/.ssh/$key.pub
    info "============================================"
    read -rp "Press Enter when done..." _

    grep -q "Host github.com" ~/.ssh/config 2>/dev/null || {
        info "Adding GitHub configuration to ~/.ssh/config"
        printf "\nHost github.com\n  HostName github.com\n  User git\n  IdentityFile ~/.ssh/%s\n  AddKeysToAgent yes\n" "$key" >> ~/.ssh/config
        chmod 600 ~/.ssh/config
    }

    if git rev-parse --is-inside-work-tree &>/dev/null; then
        info "Setting remote URL to $repo"
        git remote set-url "$remote" "$repo"
        info "Testing SSH connection to GitHub"
        ssh -T git@github.com || true
        info "Pushing to remote repository"
        git push -u "$remote" HEAD
    else
        warn "Not in a git repository. Remotes not set or pushed."
    fi
    
    info "SSH setup for Git completed successfully."
    return 0
}
# -----------------------------------------------------------------------------
git_update() { # Updates the git working directory with latest changes from remote
    local branch=${1:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null)}
    local remote=${2:-origin}
    local stash_changes=true
    
    # Process command-line options
    while [ "$#" -gt 0 ]; do
        case "$1" in
            -n|--no-stash) stash_changes=false ;;
            --branch=*) branch="${1#*=}" ;;
            --remote=*) remote="${1#*=}" ;;
            *) break ;;
        esac
        shift
    done
    
    # Check if we're in a git repository
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        err "Not in a git repository."
        return 1
    fi
    
    info "Updating git repository from remote: $remote/$branch"
    
    # Check for local changes
    if ! git diff-index --quiet HEAD --; then
        if [ "$stash_changes" = true ]; then
            info "Local changes detected. Stashing changes..."
            git stash save "Auto-stash before git_update on $(date)"
            local stashed=true
        else
            warn "Local changes detected but --no-stash option was used."
            warn "The update may fail if there are conflicts."
        fi
    fi
    
    # Fetch latest changes
    info "Fetching latest changes..."
    git fetch "$remote" || { err "Failed to fetch from remote."; return 1; }
    
    # Check if branch exists locally
    if ! git show-ref --verify --quiet refs/heads/"$branch"; then
        info "Branch $branch doesn't exist locally. Creating tracking branch..."
        git checkout -b "$branch" "$remote/$branch" || { 
            err "Failed to create tracking branch for $branch."; 
            return 1; 
        }
    else
        # Make sure we're on the right branch
        git checkout "$branch" || { err "Failed to checkout branch $branch."; return 1; }
        
        # Pull changes
        info "Pulling latest changes for $branch..."
        git pull --ff-only "$remote" "$branch" || {
            warn "Fast-forward pull failed. Trying rebase..."
            git pull --rebase "$remote" "$branch" || {
                err "Failed to update branch. Please resolve conflicts manually.";
                return 1;
            }
        }
    fi
    
    # Apply stashed changes if any
    if [ "${stashed:-false}" = true ] && [ "$stash_changes" = true ]; then
        info "Reapplying stashed changes..."
        git stash pop || {
            warn "Failed to reapply stashed changes automatically."
            warn "Your changes are saved in the stash. Use 'git stash list' and 'git stash apply' to recover them."
        }
    fi
    
    info "Git repository updated successfully to latest $remote/$branch."
    return 0
}
# -----------------------------------------------------------------------------