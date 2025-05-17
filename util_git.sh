#!/bin/bash
# -----------------------------------------------------------------------------
# File: bu/util_git.sh
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
[[ -z "${BASH_UTILS_LOADED}" ]] && { echo "ERROR: util_bash.sh is not loaded. Please source it before using this script."; exit 1; }

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

#==============================================================================
# INFORMATION/STATUS FUNCTIONS
#==============================================================================

# -----------------------------------------------------------------------------
git_file_info() { # Displays version information for a given file based on git history
    local file="$1"
    [ -z "$file" ] && { err "No file specified."; return 1; }
    [ ! -f "$file" ] && { err "File '$file' does not exist."; return 1; }
    
    # Assuming we're in a git repository
    info "File Version Info: $file"
    info "Version: $(git log -n 1 --pretty=format:"%h" -- "$file")"
    info "Last Updated: $(git log -n 1 --pretty=format:"%ad" --date=short -- "$file")"
    info "Last Update Message: $(git log -n 1 --pretty=format:"%s" -- "$file")"
    local git_sha=$(git log -n 1 --pretty=format:"%h" -- "$file")
    local local_sha=$(shasum -a 256 "$file" | awk '{print $1}')
    local git_file_content=$(git show "$git_sha:$file" 2>/dev/null | shasum -a 256 | awk '{print $1}')
    info "Tags: $(git tag --contains $git_sha | tr '\n' ' ')"
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
    
    # Assuming we're in a git repository
    info "Git history for file: $file"
    # Get total number of commits for this file
    local total=$(git log --follow --oneline -- "$file" | wc -l | tr -d ' ')
    # Show history with version numbering
    git log --reverse --follow --pretty=format:"%C(green)%D%C(reset)/v%H,%C(yellow)%h%C(reset),%ad,%s" --date=format:"%Y-%m-%d %H:%M:%S" -- "$file" | 
    awk -v total="$total" '{
        # Extract branch info
        branch = "";
        if ($0 ~ /,/) {
            split($0, parts, ",");
            if (parts[1] ~ /HEAD -> /) {
                gsub(".*HEAD -> ", "", parts[1]);
                branch = parts[1];
            } else if (parts[1] ~ /tag: /) {
                gsub(".*tag: ", "", parts[1]);
                branch = parts[1];
            }
            if (branch == "") branch = "main";
        }
        # Replace version hash with version number
        gsub("v[0-9a-f]+", "v" NR, $0);
        # Print with branch prefix for version number
        if (branch != "") {
            sub("v" NR, branch "/v" NR, $0);
        }
        print $0;
    }' > /tmp/git-file-history.csv
    # Open the CSV file with VS Code
    code /tmp/git-file-history.csv
}

# -----------------------------------------------------------------------------
git_find_modified() { # Find all files that differ from HEAD
    # Assuming we're in a git repository
    local include_unmanaged=false
    
    # Process command-line options
    while [ "$#" -gt 0 ]; do
        case "$1" in
            -u|--unmanaged) include_unmanaged=true ;;
            *) break ;;
        esac
        shift
    done
    
    # Check if there are any changes
    if git diff-index --quiet HEAD -- && [ "$include_unmanaged" = false ]; then
        info "All tracked files are up to date with HEAD"
        return 0
    fi
    
    # Header
    info "Files not in sync with HEAD:"
    
    # Show modified files
    local modified_files=$(git diff --name-only HEAD)
    if [ -n "$modified_files" ]; then
        info "${YELLOW}Modified files:${RESET}"
        echo "$modified_files" | sort | while read -r file; do
            echo -e " ${YELLOW}M${RESET} $file"
        done
    else
        info "${GREEN}No modified tracked files${RESET}"
    fi
    
    # Show unmanaged files if requested - these respect .gitignore by default
    if [ "$include_unmanaged" = true ]; then
        # Git's ls-files --others --exclude-standard excludes files in .gitignore
        local unmanaged_files=$(git ls-files --others --exclude-standard)
        if [ -n "$unmanaged_files" ]; then
            info "${ORANGE}Unmanaged files (not in git repo):${RESET}"
            echo "$unmanaged_files" | sort | while read -r file; do
                echo -e " ${ORANGE}U${RESET} $file"
            done
        else
            info "${GREEN}No unmanaged files${RESET}"
        fi
    fi
}

#==============================================================================
# FILE OPERATIONS FUNCTIONS
#==============================================================================

# -----------------------------------------------------------------------------
git_checkout_head() {   # Replace local file with HEAD version from git
    [ -z "$1" ] && { echo -e "${RED}Error: No file specified.${RESET}"; return 1; }
    local file="$1"
    [ ! -f "$file" ] && { echo -e "${RED}Error: File '$file' does not exist.${RESET}"; return 1; }
    
    # Assuming we're in a git repository
    echo -e "${BLUE}Replacing local file with version from HEAD:${RESET} $file"
    
    # Try newer git restore command first, fall back to checkout if not available
    if git help restore &>/dev/null; then
        git restore --source=HEAD "$file"
    else
        git checkout HEAD -- "$file"
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Successfully restored '$file' from HEAD.${RESET}"
    else
        echo -e "${RED}Failed to restore '$file' from HEAD.${RESET}"
        return 1
    fi
}

# -----------------------------------------------------------------------------
git_discard_changes() { # Discards local modifications to a specified file
    # Assuming we're in a remote git repository
    # Validate input parameter
    [ -z "$1" ] && { info "Usage: git_discard_changes <file>"; return 1; }
    [ ! -f "$1" ] && { err "File not found: $1"; return 1; }
    
    # Discard local changes and replace the file with version from HEAD
    git checkout HEAD -- "$1"
    info "Discarded changes to $1. File replaced with HEAD version."
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
            # Get list of tracked files
            local all_files=$(git ls-files)
            # Get list of modified files
            local modified_files=$(git diff --name-only HEAD)
            
            # Process each file
            echo "$all_files" | while read -r file; do
                if ! echo "$modified_files" | grep -q "^$file$"; then
                    # This file is not modified, update it
                    info "Updating unmodified file: $file"
                    if git help restore &>/dev/null; then
                        git restore --source=origin/HEAD "$file" 2>/dev/null || 
                        git restore --source=HEAD "$file"
                    else
                        git checkout HEAD -- "$file"
                    fi
                else
                    info "Skipping modified file: $file"
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
        
        # Check if file is modified locally
        local is_modified=false
        git diff --quiet HEAD -- "$file" || is_modified=true
        
        # Apply update logic
        if [ "$is_modified" = true ] && [ "$only_unmodified" = true ] && [ "$force" = false ]; then
            info "Skipping modified file: $file"
        else
            if [ "$is_modified" = true ] && [ "$force" = false ]; then
                warn "File has local modifications. Use --force to overwrite: $file"
                continue
            fi
            
            info "Updating file: $file"
            # Try to get from origin/HEAD first, fall back to HEAD
            if git help restore &>/dev/null; then
                git restore --source=origin/HEAD "$file" 2>/dev/null || 
                git restore --source=HEAD "$file"
            else
                git checkout HEAD -- "$file"
            fi
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
        local current_branch
        current_branch=$(git rev-parse --abbrev-ref HEAD)
        local repo_url=$(git config --get remote.origin.url)
        info "Pushing changes to remote: $repo_url"
        git push origin "$current_branch"
        local push_status=$?
        
        if [ $push_status -ne 0 ]; then
            err "Failed to push to remote repository."
            return 1
        fi
    fi
    
    info "File '$file' has been removed from git repository."
    return 0
}

#==============================================================================
# COMPARISON FUNCTIONS
#==============================================================================

# -----------------------------------------------------------------------------
git_tkdiff_remote() { # Compares a local file to its counterpart on the remote origin
  if [ -z "$1" ]; then
    info "Usage: git_tkdiff_remote <file>"
    return 1
  fi

  local file="$1"
  
  # Check if tkdiff is installed
  if ! command -v tkdiff >/dev/null 2>&1; then
    err "tkdiff is not installed. Please install tkdiff to use this function."
    return 1
  fi
  
  # Get branch and remote information
  local branch
  branch=$(git rev-parse --abbrev-ref HEAD)
  local repo_url=$(git config --get remote.origin.url)
  
  info "Remote repository: $repo_url"
  info "Current branch: $branch"
  info "Comparing local '$file' with remote 'origin/$branch:$file'"

  # Check if remote is accessible
  if ! git ls-remote --exit-code origin &>/dev/null; then
    err "Remote 'origin' not found or not accessible."
    return 1
  fi

  # Check if the branch exists on the remote
  if ! git ls-remote --heads origin "$branch" | grep -q "$branch"; then
    err "Branch '$branch' does not exist on remote 'origin'."
    return 1
  fi

  # Check if file exists on the remote
  if ! git ls-tree -r "origin/$branch" --name-only | grep -q "^$file$"; then
    err "File '$file' not found in origin/$branch."
    return 1
  fi

  # Create a temporary file for the remote version
  local temp_file=$(mktemp /tmp/git-remote-XXXXXX)
  
  # Save remote file content to the temporary file
  git show "origin/$branch:$file" > "$temp_file"
  
  # Check if we successfully retrieved the remote file content
  if [ ! -s "$temp_file" ]; then
    err "Failed to retrieve remote file content."
    rm -f "$temp_file"
    return 1
  fi
  
  # Run tkdiff with local and temporary remote files
  info "Running tkdiff..."
  tkdiff "$file" "$temp_file"
  
  # Clean up the temporary file
  rm -f "$temp_file"
  
  return 0
}

#==============================================================================
# STASH MANAGEMENT FUNCTIONS
#==============================================================================

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
# Create aliases for backwards compatibility
# -----------------------------------------------------------------------------
# If loading is successful this will be executed
# Always makes sure this is the last function call
type list_bash_functions_in_file >/dev/null 2>&1 && list_bash_functions_in_file "$(realpath "$0")" || err "alias is not loaded"
# -----------------------------------------------------------------------------