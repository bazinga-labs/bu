#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# File: bu/util_projectaliases.sh
# Author: Bazinga Labs LLC
# Email:  support@bazinga-labs.com
# -----------------------------------------------------------------------------
# Description: Utility functions for generating project aliases and loading project environments
# -----------------------------------------------------------------------------
# Check if WORK environment variable is set
check_work_var() {
  if [ -z "$WORK" ]; then
    err "WORK environment variable is not set."
    info "Please set WORK variable to your projects directory: export WORK=/path/to/project-workareas"
    return 1
  fi
  
  if [ ! -d "$WORK" ]; then
    err "WORK directory does not exist: $WORK"
    info "Please create the directory or set WORK to an existing directory"
    return 1
  fi
  
  info "WORK:$WORK "
  return 0
}

# Run checks when this script is sourced
# -----------------------------------------------------------------------------
change_prompt() { # Change the shell prompt to show project name
    #local current_dir=$(basename "$PWD")
    prompt_prefix=${PROJECT_NAME:-"NONE"}
    export PROMPT="($prompt_prefix) %~> "
    return 0
}

gen_vscode_workspace_file() { # Generate a VSCode workspace file for a project
  local project_name="$1"
  local workspace_file="${project_name}.code-workspace"
  
  if [ -z "$project_name" ]; then
    err "No project name provided."
    info "Usage: gen_vscode_workspace <project_name>"
    return 1
  fi
  
  if [ -f "$workspace_file" ]; then
    info "VSCode workspace file already exists: $workspace_file"
    return 0
  fi
  
  info "Generating VSCode workspace file for $project_name"
  
  # Create a basic workspace file
  cat > "$workspace_file" << EOF
{
  "folders": [
    {
      "path": "."
    }
  ],
  "settings": {}
}
EOF
  
  if [ $? -eq 0 ]; then
    info "Created VSCode workspace file: $workspace_file"
    return 0
  else
    err "Failed to create VSCode workspace file: $workspace_file"
    return 1
  fi
}
# -----------------------------------------------------------------------------
go_project() { # Navigate to a project directory and set up its environment
  if [ -z "$1" ]; then
    err "No project name provided."
    info "Usage: go_project <project_name>"
    return 1
  fi
  local project_name="$1"
  if [ -z "$WORK" ] || [ ! -d "$WORK" ]; then
    err "\$WORK directory is not defined or doesn't exist: '$WORK'"
    return 1
  fi
  if [ ! -d "$WORK/$project_name" ]; then
    err "Project '$project_name' does not exist under $WORK."
    return 1
  fi
  if [ -n "$PROJECT_NAME" ]; then
    info "Deactivating current project: $PROJECT_NAME"
    deactivate 2>/dev/null || info "No virtual environment to deactivate."
    unset PROJECT_NAME
    unset PROJECT_WORKSPACE
  fi
  # This is the new project name
  export PROJECT_NAME="$project_name"
  export PROJECT_WORKSPACE="$WORK/$project_name"

  cd "$PROJECT_WORKSPACE" || err "Failed to change directory to $PROJECT_WORKSPACE"


  # Load the project environment
  [ -f "${project_name}.env" ] && source "${project_name}.env"
  [ -f venv/bin/activate ] && source venv/bin/activate
  [ -n "$VIRTUAL_ENV" ] && bu_load pydev || warn "no python env set"
  # Check if workspace file exists, create if it doesn't
  if [ ! -f "${project_name}.code-workspace" ]; then
    info "No workspace file found, generating one"
    gen_vscode_workspace_file "$project_name"
  fi
  # Load bash utility required for code-development
  [ -d .git ] && bu_load git
  # Load editor utility
  bu_load editiors
  # Open workspace file if it exists
  [ -f "${project_name}".code-workspace ] && smart_edit "${project_name}".code-workspace
  change_prompt
  info "Switched to project: $PROJECT_NAME at $PROJECT_WORKSPACE"
  return 0
}
# -----------------------------------------------------------------------------
gen_project_aliases() { # Generate aliases for all projects in the WORK directory
   [ "${BU_VERBOSE_LEVEL:-1}" -ne 0 ] && info "Generating project aliases"
  for dir in "$WORK"/*/; do
    [ -d "$dir" ] || continue
    local project_name=$(basename "$dir")
    alias "go-$project_name"="go_project $project_name"
    [ "${BU_VERBOSE_LEVEL:-1}" -ne 0 ] && info "  go-$project_name: $WORK/$project_name" 
  done
  return 0
}
# -----------------------------------------------------------------------------
list_project_aliases() { # List all available project aliases
  info "Available project aliases:"
  alias | grep "go-" | sed 's/^alias //; s/=.*$//' | sort | while read -r alias_name; do
    local project_name=${alias_name#go-}
    info "   $alias_name → $WORK/$project_name"
  done
  return 0
}
# -----------------------------------------------------------------------------
open_dev_env() {
  # Find a .code-workspace file in the current directory
  local ws_file
  ws_file=$(ls *.code-workspace 2>/dev/null | head -n 1)
  if [ -n "$ws_file" ]; then
    info "Opening VS Code workspace: $ws_file"
    code "$ws_file"
    return 0
  else
    warn "No VS Code workspace file found in $(pwd)"
    return 1
  fi
}

# Create alias for open_dev_env
alias dev="open_dev_env"
# -----------------------------------------------------------------------------
# Adding functions to autogenerate aliases
check_work_var || { err "Some functions may not work properly without WORK being set"; return 1; }
gen_project_aliases
# -----------------------------------------------------------------------------