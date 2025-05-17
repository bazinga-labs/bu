#!/bin/bash
# -----------------------------------------------------------------------------
# File: bu/util_pkgs.sh
# Author: Bazinga Labs LLC
# Email:  support@bazinga-labs.com
# -----------------------------------------------------------------------------
# Description: Utilities for managing python, hombrew, and pip env 
# -----------------------------------------------------------------------------

# Check if util_bash is loaded
[[ -z "${BASH_UTILS_LOADED}" ]] && { echo "ERROR: util_bash.sh is not loaded. Please source it before using this script."; exit 1; }
# -----------------------------------------------------------------------------
mypy() {   # Display Python environment information
    pyenv_version=$(pyenv --version 2>&1)
    echo -e "${BLUE}Pyenv version: $pyenv_version${RESET}"
    python_path=$(which python)
    python_version=$(python --version 2>&1)
    echo -e "${BLUE}Python executable: $python_path${RESET}"
    echo -e "${BLUE}Python version: $python_version${RESET}"
    pip_path=$(which pip)
    pip_version=$(pip --version 2>&1)
    echo -e "${BLUE}Pip executable: $pip_path${RESET}"
    echo -e "${BLUE}Pip version: $pip_version${RESET}"
    if [ -z "$VIRTUAL_ENV" ]; then
        echo -e "${BLUE}No virtual environment is currently activated.${RESET}"
    else
        echo -e "${BLUE}Current virtual environment: $VIRTUAL_ENV${RESET}"
    fi
}
# -----------------------------------------------------------------------------
venv_init() { # Initialize and activate a Python virtual environment
    if [ -d "venv" ]; then
        info "Virtual environment already exists in the current directory."
        read -p "Do you want to recreate it? (y/n): " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            info "Operation canceled."
            return 1
        fi
        rm -rf venv
        info "Existing virtual environment removed."
    fi
    python -m venv venv
    if [ $? -eq 0 ]; then
        info "Virtual environment created successfully."
        source venv/bin/activate
        info "Virtual environment activated."
    else
        err "Failed to create virtual environment."
        return 1
    fi
}

# -----------------------------------------------------------------------------
pip_versions_report() { # Generate a report of installed pip packages and versions
    info "Package, Installed Version, Latest Version, Status" | column -t -s ','
    installed_packages=$(pip list --format=freeze)
    while IFS= read -r package_info; do
        package=$(echo "$package_info" | cut -d'=' -f1)
        installed_version=$(echo "$package_info" | cut -d'=' -f3)
        latest_version=$(pip index versions "$package" 2>&1 | grep -o 'Available versions:.*' | cut -d':' -f2 | awk '{print $1}')
        if [ "$installed_version" == "$latest_version" ]; then
            status="UP_TO_DATE"
        else
            status="NEEDS_UPGRADE"
        fi
        info "$package, $installed_version, $latest_version, $status"
    done <<< "$installed_packages" | column -t -s ','
}

# -----------------------------------------------------------------------------
pip_diff_requirements() { # Compare temporary requirements file with requirements.txt using diff
    local req_file="requirements.txt"
    local temp_req_file="tmp_requirements.txt"
    if [ ! -f "$req_file" ]; then
        err "Requirements file '$req_file' does not exist."
        return 1
    fi
    if [ -f "$temp_req_file" ]; then
        err "Temporary requirements file '$temp_req_file' already exists."
        return 1
    fi
    info "Comparing '$temp_req_file' with '$req_file'..."
    code --diff "$temp_req_file" "$req_file"
}

# -----------------------------------------------------------------------------
pip_overwrite_requirements_file() { # Overwrite requirements file with a backup
    local req_file="requirements.txt"
    local tmp_req_file="tmp_requirements.txt"
    local backup_dir=".backup_requirements.txt"
    local date=$(date +"%Y%m%d_%H%M%S")

    [ ! -f "$req_file" ] && { err "Requirements file '$req_file' does not exist."; return 1; }
    [ ! -f "$tmp_req_file" ] && { err "Temporary requirements file '$tmp_req_file' does not exist."; return 1; }
    mkdir -p "$backup_dir"
    my "$req_file" "$backup_dir/requirements_$date.txt"
    [ $? -eq 0 ] && info "Backup created at '$backup_dir/requirements_$date.txt'." || { err "Failed to create backup."; return 1; }
    info "Overwriting '$req_file'..."
    mv "$tmp_req_file" "$req_file"
    [ $? -eq 0 ] && info "'$req_file' has been overwritten successfully." || { err "Failed to overwrite '$req_file'."; return 1; }
}

# -----------------------------------------------------------------------------
pip_clean_cache() { # Clear pip cache
    pip cache purge
    info "Pip cache cleared."
}

# -----------------------------------------------------------------------------
brew_versions_report() { # Generate a report of installed Homebrew packages and versions
    if ! command -v jq &> /dev/null; then
        err "jq is required. Install it using: brew install jq"
        return 1
    fi
    info "Package, Installed Version, Latest Version, Status"
    info=$(brew info --json=v2 --installed)
    installed_versions=$(echo "$info" | jq -r '.formulae[] | .name + "," + (.installed[0].version // "Not Installed")')
    latest_versions=$(echo "$info" | jq -r '.formulae[] | .name + "," + (.versions.stable // "Unknown")')
    while IFS= read -r installed; do
        package=$(echo "$installed" | cut -d',' -f1)
        installed_version=$(echo "$installed" | cut -d',' -f2)
        latest_version=$(echo "$latest_versions" | grep "^$package," | cut -d',' -f2)
        if [ "$installed_version" == "$latest_version" ]; then
            status="UP_TO_DATE"
        else
            status="NEEDS_UPGRADE"
        fi
        info "$package, $installed_version, $latest_version, $status"
    done <<< "$installed_versions" | column -t -s ','
}

# -----------------------------------------------------------------------------
brew_clean_cache() { # Clear Homebrew cache
    brew cleanup -s
    info "Homebrew cache cleared."
}
alias clean-pycache='find . -type d -name "__pycache__" -exec rm -rf {} +'       # Clean Python cache directories
alias clean-pip-cache='pip cache purge'  # Clear pip cache

# -----------------------------------------------------------------------------
# If loading is successful this will be executed
# Always makes sure this is the last function call
type list_bash_functions_in_file >/dev/null 2>&1 && list_bash_functions_in_file "$(realpath "$0")" || err "alias is not loaded"
# -----------------------------------------------------------------------------