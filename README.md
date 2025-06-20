# Bash Utility (bu) Framework

This document describes the Bash Utility (bu) framework, a system for managing and using collections of bash functions.

## Core Concepts

The `bu` framework relies on `bu.sh`, which provides the core functionality for loading, unloading, and listing bash utilities and their functions.

## Initial Setup

To use the `bu` framework:

1. Add this line as the last line of your shell profile (e.g., `~/.bashrc`, `~/.zshrc`):
    ```bash
    ################################################################################
    # Let this always be the last line in you ~/.zshrc or ~/.bashrc
    source <path-to>/bu.sh 
    ################################################################################
    ```
    
    If you want a custom BU PATH:
    ```bash
    export BU="<path-A>"
    source <path-to>/bu.sh
    ```

2. To load a utility, use:
    ```bash
    % bu load dev_py
    ```

## Managing Utilities

The `bu.sh` script provides several commands to manage your bash utilities. These commands are available once `bu.sh` is sourced:

- `bu list` - List all available utilities
- `bu loaded` or `bu ls` - List loaded utilities
- `bu load <name>` - Load a utility
- `bu unload <name>` - Unload a utility
- `bu functions [name]` - Show functions in loaded utilities (optionally for a specific utility)
- `bu reload [name]` - Reload a utility or all utilities
- `bu help` - Show help message

This will make the `bu` management commands and any loaded utility functions available in your shell.
