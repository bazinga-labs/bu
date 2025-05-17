#!/bin/bash
#-----------------------------------------------------------------------------
# File: util_prjalias.sh
# Author: Bazinga Labs LLC
# Email:  support@bazinga-labs.com
# Description: Utility functions for generating project aliases and loading project environments
#-----------------------------------------------------------------------------
[[ -z "${BASH_UTILS_LOADED}" ]] && { echo "ERROR: util_bash.sh is not loaded. Please source it before using this script."; exit 1; }
# -----------------------------------------------------------------------------
change_prompt() { # Change the shell prompt to show project name
    #local current_dir=$(basename "$PWD")
    prompt_prefix=${PROJECT_NAME:-"NONE"}
    export PROMPT="($prompt_prefix) %~> "
    return 0
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
  
  # Load bash utility required for code-development
  [ -d .git ] && bu_load git
  if [[ "$TERM_PROGRAM" != "vscode" ]]; then
    [ -f "${project_name}".code-workspace ] && code "${project_name}".code-workspace
  fi
  change_prompt
  info "Switched to project: $PROJECT_NAME at $PROJECT_WORKSPACE"
  return 0
}
# -----------------------------------------------------------------------------
gen_project_aliases() { # Generate aliases for all projects in the WORK directory
  info "Generating project aliases"
  for dir in "$WORK"/*/; do
    [ -d "$dir" ] || continue
    local project_name=$(basename "$dir")
    alias "go-$project_name"="go_project $project_name"
    #   info "  go-$project_name: $WORK/$project_name" # Optional: uncomment to list generated aliases
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
# Adding functions to autogenerate aliases
gen_project_aliases
#------------------------------------------------------------------------------
list_bash_functions_in_file >/dev/null 2>&1 && list_bash_functions_in_file "$(realpath "$0")" || err "alias is not loaded"
#------------------------------------------------------------------------------