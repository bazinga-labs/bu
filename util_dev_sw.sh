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
  local has_work=0
  local has_analysis=0
  
  if [ -n "$WORK" ] && [ -d "$WORK" ]; then
    has_work=1
  fi
  
  if [ -n "$ANALYSIS" ] && [ -d "$ANALYSIS" ]; then
    has_analysis=1
  fi
  
  if [ $has_work -eq 0 ] && [ $has_analysis -eq 0 ]; then
    err "Neither WORK nor ANALYSIS environment variables are properly set."
    info "Please set at least one variable to your projects directory:"
    info "  export WORK=/path/to/project-workareas"
    info "  export ANALYSIS=/path/to/analysis-projects"
    return 1
  fi
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
    warn "No project name provided."
  project_name="${PWD##*/}"
  if [ -z "$project_name" ]; then
    err "Cannot determine project name from current directory."
    return 1
  fi
  workspace_file="${project_name}.code-workspace"
  info "Using current directory name as project: $project_name"
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
  local project_path=""
  
  # Check if either WORK or ANALYSIS environment variables are set
  if [ -z "$WORK" ] && [ -z "$ANALYSIS" ]; then
    err "Neither \$WORK nor \$ANALYSIS directory is defined."
    info "Please set either WORK or ANALYSIS variable to your projects directory."
    return 1
  fi
  
  # Try to find the project in WORK first, then ANALYSIS
  if [ -n "$WORK" ] && [ -d "$WORK" ] && [ -d "$WORK/$project_name" ]; then
    project_path="$WORK/$project_name"
    info "Found project in WORK directory: $project_path"
  elif [ -n "$ANALYSIS" ] && [ -d "$ANALYSIS" ] && [ -d "$ANALYSIS/$project_name" ]; then
    project_path="$ANALYSIS/$project_name"
    info "Found project in ANALYSIS directory: $project_path"
  else
    err "Project '$project_name' does not exist under WORK or ANALYSIS directories."
    [ -n "$WORK" ] && [ -d "$WORK" ] && info "Checked WORK: $WORK"
    [ -n "$ANALYSIS" ] && [ -d "$ANALYSIS" ] && info "Checked ANALYSIS: $ANALYSIS"
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
  export PROJECT_WORKSPACE="$project_path"

  cd "$PROJECT_WORKSPACE" || err "Failed to change directory to $PROJECT_WORKSPACE"


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
gen_project_aliases() { # Generate aliases for all projects in the WORK and ANALYSIS directories
   [ "${BU_VERBOSE_LEVEL:-1}" -ne 0 ] && info "Generating project aliases"
  
  # Process WORK directory if it exists
  if [ -n "$WORK" ] && [ -d "$WORK" ]; then
    [ "${BU_VERBOSE_LEVEL:-1}" -ne 0 ] && info "Scanning WORK directory: $WORK"
    for dir in "$WORK"/*/; do
      [ -d "$dir" ] || continue
      local project_name=$(basename "$dir")
      alias "go-$project_name"="go_project $project_name"
      [ "${BU_VERBOSE_LEVEL:-1}" -ne 0 ] && info "  go-$project_name: $WORK/$project_name" 
    done
  fi
  
  # Process ANALYSIS directory if it exists
  if [ -n "$ANALYSIS" ] && [ -d "$ANALYSIS" ]; then
    [ "${BU_VERBOSE_LEVEL:-1}" -ne 0 ] && info "Scanning ANALYSIS directory: $ANALYSIS"
    for dir in "$ANALYSIS"/*/; do
      [ -d "$dir" ] || continue
      local project_name=$(basename "$dir")
      # Only create alias if it doesn't already exist (WORK takes precedence)
      if ! alias "go-$project_name" >/dev/null 2>&1; then
        alias "go-$project_name"="go_project $project_name"
        [ "${BU_VERBOSE_LEVEL:-1}" -ne 0 ] && info "  go-$project_name: $ANALYSIS/$project_name" 
      else
        [ "${BU_VERBOSE_LEVEL:-1}" -ne 0 ] && info "  go-$project_name: skipped (already exists from WORK)" 
      fi
    done
  fi
  return 0
}
# -----------------------------------------------------------------------------
list_project_aliases() { # List all available project aliases
  info "Available project aliases:"
  alias | grep "go-" | sed 's/^alias //; s/=.*$//' | sort | while read -r alias_name; do
    local project_name=${alias_name#go-}
    # Check which directory contains the project
    if [ -n "$WORK" ] && [ -d "$WORK" ] && [ -d "$WORK/$project_name" ]; then
      info "   $alias_name → $WORK/$project_name"
    elif [ -n "$ANALYSIS" ] && [ -d "$ANALYSIS" ] && [ -d "$ANALYSIS/$project_name" ]; then
      info "   $alias_name → $ANALYSIS/$project_name"
    else
      info "   $alias_name → (project not found)"
    fi
  done
  return 0
}
# -----------------------------------------------------------------------------
open_dev_env() { # Find a .code-workspace file in the current directory
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
alias gen-py-wrapper='./generate_py_wrapper.sh'
# -----------------------------------------------------------------------------
# Define aliases for convenience
check_work_var || { err "Some functions may not work properly without WORK being set"; return 1; }
gen_project_aliases
# -----------------------------------------------------------------------------
