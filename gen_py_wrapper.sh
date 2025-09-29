#!/bin/bash

# Python Wrapper Generator Script
# Generates wrapper scripts in the format of bzl-parse-flexlmlog
# Usage: ./generate_wrapper.sh --py <python-entry-point> --envutils <path-to-envutils> --name=<wrappername>

set -euo pipefail

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Default values
DEFAULT_ENVUTILS_PATH="$PROJECT_ROOT/libs/envutils"
PYTHON_ENTRY_POINT=""
ENVUTILS_PATH=""
WRAPPER_NAME=""

# Show help
show_help() {
    cat << EOF
Python Wrapper Generator Script

Usage: $0 --py <python-entry-point> [options]

Required Arguments:
  --py <path>              Path to Python entry point (required)

Optional Arguments:
  --envutils <path>        Path to envutils directory (default: $DEFAULT_ENVUTILS_PATH)
  --name <name>            Wrapper script name (default: derived from python file)
  --help, -h               Show this help message

Examples:
  $0 --py src/my_tool.py
  $0 --py libs/parser/main.py --name my-parser
  $0 --py tools/analyzer.py --envutils ./external/envutils

Notes:
  - If envutils directory doesn't exist, the script will suggest adding it as a submodule
  - Wrapper scripts are generated in the bin/ directory
  - Generated wrappers follow the bzl-parse-flexlmlog pattern
EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --py)
                PYTHON_ENTRY_POINT="$2"
                shift 2
                ;;
            --envutils)
                ENVUTILS_PATH="$2"
                shift 2
                ;;
            --name)
                WRAPPER_NAME="$2"
                shift 2
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Validate arguments
validate_args() {
    # Check required arguments
    if [[ -z "$PYTHON_ENTRY_POINT" ]]; then
        log_error "Python entry point is required. Use --py <path>"
        show_help
        exit 1
    fi

    # Set default envutils path if not provided
    if [[ -z "$ENVUTILS_PATH" ]]; then
        ENVUTILS_PATH="$DEFAULT_ENVUTILS_PATH"
    fi

    # Make paths absolute
    if [[ ! "$PYTHON_ENTRY_POINT" = /* ]]; then
        PYTHON_ENTRY_POINT="$PROJECT_ROOT/$PYTHON_ENTRY_POINT"
    fi
    
    if [[ ! "$ENVUTILS_PATH" = /* ]]; then
        ENVUTILS_PATH="$PROJECT_ROOT/${ENVUTILS_PATH#./}"
    fi

    # Check if Python entry point exists
    if [[ ! -f "$PYTHON_ENTRY_POINT" ]]; then
        log_error "Python entry point not found: $PYTHON_ENTRY_POINT"
        exit 1
    fi

    # Generate wrapper name if not provided
    if [[ -z "$WRAPPER_NAME" ]]; then
        local python_filename=$(basename "$PYTHON_ENTRY_POINT")
        WRAPPER_NAME="${python_filename%.py}"
        WRAPPER_NAME="${WRAPPER_NAME//_/-}"  # Convert underscores to hyphens
    fi

    # Ensure wrapper name doesn't have .sh extension (we'll add it)
    WRAPPER_NAME="${WRAPPER_NAME%.sh}"
}

# Check and setup envutils
setup_envutils() {
    if [[ ! -d "$ENVUTILS_PATH" ]]; then
        log_warning "Envutils directory not found: $ENVUTILS_PATH"
        
        # Check if we're in a git repository
        if git rev-parse --git-dir >/dev/null 2>&1; then
            log_info "Detected git repository. Suggesting submodule addition..."
            echo ""
            echo "To add envutils as a submodule, run:"
            echo "  git submodule add git@github.com:bazinga-labs/bz-envutils.git ./libs/envutils"
            echo ""
            
            # Ask user if they want to add it automatically
            read -p "Add envutils submodule automatically? [y/N]: " -r response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                local relative_envutils_path
                relative_envutils_path=$(get_relative_path "$ENVUTILS_PATH" "$PROJECT_ROOT")
                
                log_info "Adding envutils submodule..."
                cd "$PROJECT_ROOT"
                if git submodule add git@github.com:bazinga-labs/bz-envutils.git "$relative_envutils_path"; then
                    log_success "Envutils submodule added successfully"
                else
                    log_error "Failed to add envutils submodule"
                    exit 1
                fi
            else
                log_error "Cannot proceed without envutils. Please add it manually and try again."
                exit 1
            fi
        else
            log_error "Not in a git repository and envutils not found. Please install envutils manually."
            exit 1
        fi
    else
        log_info "Found envutils at: $ENVUTILS_PATH"
    fi

    # Validate envutils structure
    if [[ ! -d "$ENVUTILS_PATH/bash" ]]; then
        log_error "Invalid envutils structure. Expected bash/ directory in: $ENVUTILS_PATH"
        exit 1
    fi

    local required_modules=("logging" "python_env")
    for module in "${required_modules[@]}"; do
        if [[ ! -f "$ENVUTILS_PATH/bash/$module" ]]; then
            log_error "Required envutils module not found: $ENVUTILS_PATH/bash/$module"
            exit 1
        fi
    done
}

# Generate relative path from project root
get_relative_path() {
    local target_path="$1"
    local base_path="$2"
    
    # Use Python to get relative path (more portable than realpath)
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "import os.path; print(os.path.relpath('$target_path', '$base_path'))"
    elif command -v python >/dev/null 2>&1; then
        python -c "import os.path; print(os.path.relpath('$target_path', '$base_path'))"
    else
        # Simple fallback - remove common prefix
        echo "${target_path#$base_path/}"
    fi
}

# Generate wrapper script content
generate_wrapper() {
    local wrapper_path="$PROJECT_ROOT/bin/$WRAPPER_NAME"
    
    # Get relative paths for the generated script
    local rel_python_path
    local rel_envutils_path
    
    rel_python_path=$(get_relative_path "$PYTHON_ENTRY_POINT" "$PROJECT_ROOT")
    rel_envutils_path=$(get_relative_path "$ENVUTILS_PATH" "$PROJECT_ROOT")
    
    # Extract description from Python file if possible
    local description="Python Tool Wrapper Script"
    if [[ -f "$PYTHON_ENTRY_POINT" ]]; then
        # Try to extract docstring or first comment
        local first_line
        first_line=$(head -5 "$PYTHON_ENTRY_POINT" | grep -E '^[[:space:]]*""".*"""[[:space:]]*$|^[[:space:]]*""".*|^#.*' | head -1 || echo "")
        if [[ -n "$first_line" ]]; then
            # Clean up the description
            first_line=$(echo "$first_line" | sed 's/^[[:space:]]*#[[:space:]]*//' | sed 's/^[[:space:]]*"""//' | sed 's/"""[[:space:]]*$//')
            if [[ -n "$first_line" && ${#first_line} -lt 100 ]]; then
                description="$first_line"
            fi
        fi
    fi

    log_info "Generating wrapper script: $wrapper_path"
    log_info "Python entry point: $rel_python_path"
    log_info "Envutils path: $rel_envutils_path"

    # Generate the wrapper script
    cat > "$wrapper_path" << EOF
#!/bin/bash

# $description
# Automatically manages Python virtual environment for $(basename "$PYTHON_ENTRY_POINT" .py)

set -euo pipefail

# Script directory and project root
BIN_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
BZL_TOOL_ROOT="\$(dirname "\$BIN_DIR")"
BZL_TOOL_ENV_FILE="\$BZL_TOOL_ROOT/etc/tool.env"
BZL_VENV="\$BZL_TOOL_ROOT/venv"

# This is how you load the utils
bash_env_load=(logging python_env)
for _env in "\${bash_env_load[@]}"; do
    _file="\$BZL_TOOL_ROOT/$rel_envutils_path/bash/\$_env"
    printf '\\033[34m%s\\033[0m\\n' "[INFO] Loading \$_file"
    if [[ -r "\$_file" ]]; then source "\$_file"; else printf 'Error: required bash helper not found: %s\\n' "\$_file" >&2; exit 1; fi
done

# Find Python executable
if declare -F python_find_command >/dev/null 2>&1; then
    py="\$(python_find_command)" || { err "python_find_command failed"; exit 1; }
else
    py="\$(command -v python3 || command -v python || true)"
    [[ -n "\$py" ]] || { err "No python executable found (python3 or python)"; exit 1; }
fi
cmd="\$BZL_TOOL_ROOT/$rel_python_path"

# Main execution
main() {
    # Change to project root directory
    cd "\$BZL_TOOL_ROOT"
    [[ -d "\$BZL_VENV" ]] && venv_activate || venv_create
    exec "\$py" "\$cmd" "\$@"
}

# Run main function
main "\$@"
EOF

    # Make the wrapper executable
    chmod +x "$wrapper_path"
    
    log_success "Generated wrapper script: $wrapper_path"
}

# Validate generated wrapper
validate_wrapper() {
    local wrapper_path="$PROJECT_ROOT/bin/$WRAPPER_NAME"
    
    log_info "Validating generated wrapper..."
    
    # Check if file exists and is executable
    if [[ ! -x "$wrapper_path" ]]; then
        log_error "Generated wrapper is not executable: $wrapper_path"
        return 1
    fi
    
    # Basic syntax check
    if ! bash -n "$wrapper_path"; then
        log_error "Generated wrapper has syntax errors"
        return 1
    fi
    
    log_success "Wrapper validation passed"
}

# Show completion message
show_completion() {
    local wrapper_path="$PROJECT_ROOT/bin/$WRAPPER_NAME"
    local rel_wrapper_path
    rel_wrapper_path=$(get_relative_path "$wrapper_path" "$PROJECT_ROOT")
    
    echo ""
    log_success "Python wrapper generated successfully!"
    echo ""
    echo "Generated Files:"
    echo "  Wrapper Script: $rel_wrapper_path"
    echo "  Python Entry:   $(get_relative_path "$PYTHON_ENTRY_POINT" "$PROJECT_ROOT")"
    echo "  Envutils:       $(get_relative_path "$ENVUTILS_PATH" "$PROJECT_ROOT")"
    echo ""
    echo "Usage:"
    echo "  ./$rel_wrapper_path [arguments...]"
    echo ""
    echo "The wrapper will:"
    echo "  1. Load environment utilities (logging, python_env)"
    echo "  2. Find or create a Python virtual environment"
    echo "  3. Execute your Python script with all arguments"
    echo ""
}

# Main function
main() {
    log_info "Python Wrapper Generator"
    echo "========================"
    
    # Parse and validate arguments
    parse_args "$@"
    validate_args
    
    # Setup environment
    setup_envutils
    
    # Generate the wrapper
    generate_wrapper
    
    # Validate the generated wrapper
    validate_wrapper
    
    # Show completion message
    show_completion
}

# Run main function
main "$@"