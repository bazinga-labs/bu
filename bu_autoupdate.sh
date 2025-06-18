#!/bin/env bash
# -----------------------------------------------------------------------------
# File: bu/bu_autoupdate.sh
# Author: Bazinga Labs LLC
# Email:  support@bazinga-labs.com
# -----------------------------------------------------------------------------
# Description: Automatic update system for Bazinga Labs BU utilities
# -----------------------------------------------------------------------------

# Default values
DEFAULT_CHECK_FREQUENCY=86400  # 24 hours in seconds
DEFAULT_RELEASE_BRANCH="main"  # Default release branch

# -----------------------------------------------------------------------------
bu_check_update_needed() { # Check if it's time to check for updates
    local last_check_file="$BU/.last_update_check"
    local current_time=$(date +%s)
    local check_frequency=${BU_RELEASE_CHECK_FREQUENCY:-$DEFAULT_CHECK_FREQUENCY}
    
    # If the check file doesn't exist, it's time to check
    if [ ! -f "$last_check_file" ]; then
        echo "true"
        return 0
    fi
    
    # Read the last check time
    local last_check_time=$(cat "$last_check_file" 2>/dev/null || echo 0)
    
    # Calculate elapsed time
    local elapsed_time=$((current_time - last_check_time))
    
    # Check if elapsed time exceeds the frequency
    if [ $elapsed_time -ge $check_frequency ]; then
        echo "true"
    else
        echo "false"
    fi
}

# -----------------------------------------------------------------------------
bu_update_check_timestamp() { # Update the timestamp of the last update check
    local last_check_file="$BU/.last_update_check"
    date +%s > "$last_check_file"
}

# -----------------------------------------------------------------------------
bu_is_git_repo() { # Check if BU directory is a git repository
    if [ -d "$BU/.git" ]; then
        echo "true"
    else
        echo "false"
    fi
}

# -----------------------------------------------------------------------------
bu_has_remote_updates() { # Check if there are updates available in the remote repository
    local release_branch="${BU_RELEASE:-$DEFAULT_RELEASE_BRANCH}"
    
    # Fetch the latest changes
    (cd "$BU" && git fetch origin "$release_branch" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        # Failed to fetch, might be network issue
        warn "Failed to fetch updates from remote repository."
        return 1
    fi
    
    # Compare local and remote HEADs
    local local_head=$(cd "$BU" && git rev-parse HEAD)
    local remote_head=$(cd "$BU" && git rev-parse "origin/$release_branch")
    
    if [ "$local_head" != "$remote_head" ]; then
        echo "true"
    else
        echo "false"
    fi
}

# -----------------------------------------------------------------------------
bu_has_local_changes() { # Check if there are uncommitted changes
    local has_changes=$(cd "$BU" && git status --porcelain)
    
    if [ -n "$has_changes" ]; then
        echo "true"
    else
        echo "false"
    fi
}

# -----------------------------------------------------------------------------
bu_do_update() { # Perform the actual update
    local release_branch="${BU_RELEASE:-$DEFAULT_RELEASE_BRANCH}"
    local stash_needed=$(bu_has_local_changes)
    local stash_message="BU Auto-update stash $(date)"
    local updated=false
    local stashed=false
    
    # Stash local changes if needed
    if [ "$stash_needed" = "true" ]; then
        if [ "${BU_AUTO_STASH:-false}" != "true" ]; then
            warn "Not updating due to local changes. Set BU_AUTO_STASH=true to enable automatic stashing."
            bu_update_check_timestamp
            return 1
        fi
        
        info "Stashing local changes before update..."
        (cd "$BU" && git stash push -m "$stash_message")
        if [ $? -eq 0 ]; then
            stashed=true
        else
            err "Failed to stash local changes. Update aborted."
            return 1
        fi
    fi
    
    # Pull the latest changes
    info "Updating from branch $release_branch..."
    (cd "$BU" && git pull origin "$release_branch")
    
    if [ $? -eq 0 ]; then
        updated=true
        info "BU utilities updated successfully to latest version of branch $release_branch."
    else
        err "Failed to update BU utilities."
    fi
    
    # Apply stashed changes back if we stashed them
    if [ "$stashed" = "true" ]; then
        info "Applying stashed changes back..."
        (cd "$BU" && git stash pop)
        if [ $? -ne 0 ]; then
            warn "Failed to apply stashed changes. They remain in the stash."
            warn "Use 'git stash list' and 'git stash apply' to recover them."
        fi
    fi
    
    # Update the timestamp regardless of success to avoid repeated failures
    bu_update_check_timestamp
    
    if [ "$updated" = "true" ]; then
        return 0
    else
        return 1
    fi
}

# -----------------------------------------------------------------------------
bu_check_updates() { # Check for updates (exposed as 'bu check-updates')
    if [ "$(bu_is_git_repo)" != "true" ]; then
        warn "BU directory is not a git repository. Cannot check for updates."
        return 1
    fi
    
    local release_branch="${BU_RELEASE:-$DEFAULT_RELEASE_BRANCH}"
    info "Checking for updates on branch $release_branch..."
    
    # Force fetch from remote
    (cd "$BU" && git fetch origin "$release_branch" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        err "Failed to fetch updates from remote repository."
        return 1
    fi
    
    # Compare local and remote HEADs
    local local_head=$(cd "$BU" && git rev-parse HEAD)
    local remote_head=$(cd "$BU" && git rev-parse "origin/$release_branch")
    
    # Get the current commit date
    local local_date=$(cd "$BU" && git log -1 --format=%cd --date=relative)
    
    if [ "$local_head" != "$remote_head" ]; then
        # Get number of commits behind
        local commits_behind=$(cd "$BU" && git rev-list --count HEAD..origin/$release_branch)
        local latest_commit_msg=$(cd "$BU" && git log -1 --format=%s origin/$release_branch)
        
        info "Updates available for BU utilities."
        info "Your version: $local_head ($local_date)"
        info "Latest version: $remote_head"
        info "You are $commits_behind commit(s) behind the latest version."
        info "Latest commit: $latest_commit_msg"
        info "Run 'bu update' to update to the latest version."
        
        # Update the timestamp
        bu_update_check_timestamp
        return 0
    else
        info "BU utilities are up-to-date (branch $release_branch)."
        info "Current version: $local_head ($local_date)"
        
        # Update the timestamp
        bu_update_check_timestamp
        return 0
    fi
}

# -----------------------------------------------------------------------------
bu_update() { # Update BU utilities (exposed as 'bu update')
    local custom_branch="$1"
    local release_branch="${custom_branch:-${BU_RELEASE:-$DEFAULT_RELEASE_BRANCH}}"
    
    if [ "$(bu_is_git_repo)" != "true" ]; then
        err "BU directory is not a git repository. Cannot update."
        return 1
    fi
    
    # Set the release branch to use (temporarily if custom branch provided)
    local original_release="$BU_RELEASE"
    if [ -n "$custom_branch" ]; then
        export BU_RELEASE="$custom_branch"
    fi
    
    info "Updating BU utilities to latest version of branch $release_branch..."
    
    # Check if there are uncommitted changes
    local has_changes=$(bu_has_local_changes)
    if [ "$has_changes" = "true" ]; then
        warn "You have uncommitted changes in the BU directory."
        # Use a safer approach than interactive prompt
        if [ "${BU_AUTO_STASH:-false}" = "true" ]; then
            info "Auto-stashing changes before update (BU_AUTO_STASH=true)..."
            (cd "$BU" && git stash push -m "BU Auto-update stash $(date)")
        else
            warn "Update aborted. Please commit or stash your changes manually."
            warn "Or set BU_AUTO_STASH=true to allow automatic stashing."
            
            # Restore original release branch if necessary
            if [ -n "$custom_branch" ]; then
                export BU_RELEASE="$original_release"
            fi
            
            return 1
        fi
    fi
    
    # Do the update
    bu_do_update
    local update_status=$?
    
    # Restore original release branch if necessary
    if [ -n "$custom_branch" ]; then
        export BU_RELEASE="$original_release"
    fi
    
    if [ $update_status -eq 0 ]; then
        info "Would you like to reload all BU utilities with the new version?"
        read -p "Reload now? (Y/n): " reload_confirm
        if [[ ! "$reload_confirm" =~ ^[Nn]$ ]]; then
            if type bu_reload &>/dev/null; then
                bu_reload
            else
                warn "bu_reload function not found. Please restart your shell to load the updated utilities."
            fi
        else
            info "Please restart your shell or reload BU manually to use the updated utilities."
        fi
    fi
    
    return $update_status
}

# -----------------------------------------------------------------------------
bu_auto_update_check() { # Entry point for automatic update checks
    # Only proceed if auto-updates are enabled
    if [ "${BU_AUTO_UPDATE:-true}" != "true" ]; then
        return 0
    fi
    
    # Check if we need to check for updates
    local check_needed=$(bu_check_update_needed)
    if [ "$check_needed" != "true" ]; then
        return 0
    fi
    
    # Check if the BU directory is a git repository
    if [ "$(bu_is_git_repo)" != "true" ]; then
        return 0
    fi
    
    # Check if there are updates available
    local has_updates=$(bu_has_remote_updates)
    if [ "$has_updates" != "true" ]; then
        # No updates, update timestamp and exit
        bu_update_check_timestamp
        return 0
    fi
    
    # Updates are available
    info "Updates are available for BU utilities."
    
    # Auto-update if configured, otherwise just notify
    if [ "${BU_AUTO_UPDATE_SILENT:-false}" = "true" ]; then
        # Silent auto-update
        if [ "$(bu_has_local_changes)" = "true" ] && [ "${BU_AUTO_STASH:-false}" != "true" ]; then
            info "Not updating due to local changes. Set BU_AUTO_STASH=true to enable automatic stashing."
            bu_update_check_timestamp
            return 0
        fi
        
        bu_do_update >/dev/null
        if [ $? -eq 0 ]; then
            info "BU utilities have been automatically updated."
            if type bu_reload &>/dev/null; then
                bu_reload >/dev/null
                info "BU utilities have been reloaded with the new version."
            fi
        fi
    else
        # Just notify about updates, don't attempt interactive prompts
        info "Updates are available. Run 'bu update' when you're ready to update."
        # Update the timestamp to avoid repeated notifications
        bu_update_check_timestamp
    fi
    
    return 0
}

# Functions are automatically available after sourcing
# No need to export them as they're defined in the current shell environment
