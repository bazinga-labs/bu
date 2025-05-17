-----------------------------------------------------------------------------
# Functions merged from util_run.sh
# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------
run() { # Run a Python script with arguments and save output to run.out
    clear
    local script="$1"
    local output_file=$([ -n "$PROJECT_WORKSPACE" ] && echo "${PROJECT_WORKSPACE}/run.out" || echo "/tmp/${USER}.run.out")
    # Removed local output_file assignment, using global 'output_file'
    shift
    [ -z "$script" ] && { err "No Python script specified."; return 1; }
    [ ! -f "$script" ] && { err "Python script '$script' does not exist."; return 1; }
    info "Running Python script '$script' with arguments: $*"
    python "$script" "$@" | tee "$output_file"
    if [ $? -eq 0 ]; then
        info "Script executed successfully. Output saved to '$output_file'."
    else
        err "Some tests failed. Check '$output_file' for details."
    fi
}
# -----------------------------------------------------------------------------
run_pytest() { # Run pytest on specified test files and save output to pytest.out
    clear
    local test_path="$1"
    local output_file=$([ -n "$PROJECT_WORKSPACE" ] && echo "${PROJECT_WORKSPACE}/run.out" || echo "/tmp/${USER}.run.out")
    shift
    if [ -z "$test_path" ]; then
        info "Running pytest on current directory with arguments: $*"
        pytest "$@" -v 2>&1 | tee "$output_file"
    elif [ -f "$test_path" ] || [ -d "$test_path" ]; then
        info "Running pytest on '$test_path' with arguments: $*"
        pytest "$test_path" "$@" -v 2>&1 | tee "$output_file"
    else
        err "Test path '$test_path' does not exist."
        return 1
    fi
    if [ $? -eq 0 ]; then
        info "Tests executed successfully. Output saved to '$output_file'."
    else
        err "Some tests failed. Check '$output_file' for details."
    fi
}
# -----------------------------------------------------------------------------
run_py() { # Run Python script and save output to run.out
    clear
    local script_path="$1"
    local output_file=$([ -n "$PROJECT_WORKSPACE" ] && echo "${PROJECT_WORKSPACE}/run.out" || echo "/tmp/${USER}.run.out")
    shift

    if [ -z "$script_path" ]; then
        err "No Python script specified."
        return 1
    elif [ -f "$script_path" ]; then
        info "Running Python script '$script_path' with arguments: $*"
        python "$script_path" "$@" 2>&1 | tee "$output_file"
    else
        err "Python script '$script_path' does not exist."
        return 1
    fi

    if [ $? -eq 0 ]; then
        info "Python script executed successfully. Output saved to '$output_file'."
    else
        err "Script failed. Check '$output_file' for details."
    fi
}
# -----------------------------------------------------------------------------
run_cmd() { # Run any shell command and save output to cmd.out
    clear
    local cmd="$1"
    local output_file=$([ -n "$PROJECT_WORKSPACE" ] && echo "${PROJECT_WORKSPACE}/run.out" || echo "/tmp/${USER}.run.out")
    shift
    [ -z "$cmd" ] && { err "No command specified."; return 1; }
    info "Running command: $cmd $*"
    $cmd "$@" 2>&1 | tee "$output_file"
    local exit_status=${PIPESTATUS[0]}
    if [ $exit_status -eq 0 ]; then
        info "SUCCESS: Command executed successfully. Output saved to '$output_file'."
    else
        err "Command failed with exit code $exit_status. Check '$output_file' for details."
    fi
    return $exit_status
}
# -----------------------------------------------------------------------------
run_makefile() { # Run make commands with Makefile and save output to make.out
    clear
    local target="$1"
    local output_file=$([ -n "$PROJECT_WORKSPACE" ] && echo "${PROJECT_WORKSPACE}/run.out" || echo "/tmp/${USER}.run.out")
    shift
    
    # Check if Makefile exists in the current directory
    if [ ! -f "Makefile" ] && [ ! -f "makefile" ]; then
        err "No Makefile found in the current directory."
        return 1
    fi
    
    if [ -z "$target" ]; then
        info "Running default make target with arguments: $*"
        make "$@" 2>&1 | tee "$output_file"
    else
        info "Running make target '$target' with arguments: $*"
        make "$target" "$@" 2>&1 | tee "$output_file"
    fi
    
    local exit_status=${PIPESTATUS[0]}
    if [ $exit_status -eq 0 ]; then
        info "SUCCESS: Make command executed successfully. Output saved to '$output_file'."
    else
        err "Make command failed with exit code $exit_status. Check '$output_file' for details."
    fi
    return $exit_status
}
#-----------------------------------------------------------------------------
list_bash_functions_in_file >/dev/null 2>&1 && list_bash_functions_in_file "$(realpath "$0")" || err "alias is not loaded"
#-----------------------------------------------------------------------------