#!/bin/bash
# -----------------------------------------------------------------------------
# File: bu/util_doc.sh
#
# -----------------------------------------------------------------------------
# Description: Utility functions for generating documentation using GitHub Copilot.
# -----------------------------------------------------------------------------
# Check if util_bash is loaded
[[ -z "${BASH_UTILS_LOADED}" ]] && { echo "ERROR: util_bash.sh is not loaded. Please source it before using this script."; exit 1; }

#==============================================================================
# DOCUMENTATION GENERATION FUNCTIONS
#==============================================================================

# -----------------------------------------------------------------------------
# If loading is successful this will be executed
# Always makes sure this is the last function call
type list_bash_functions_in_file >/dev/null 2>&1 && list_bash_functions_in_file "$(realpath "$0")" || err "alias is not loaded"
# -----------------------------------------------------------------------------
