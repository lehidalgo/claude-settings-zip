#!/bin/bash

# Export Claude Code Configuration
# This script creates a zip file containing all Claude Code configuration files

set -e

# Configuration
CLAUDE_DIR="$HOME/.claude"
OUTPUT_DIR="$(pwd)/claude_config_export_$(date +%Y%m%d_%H%M%S)"
ZIP_NAME="claude_config_$(date +%Y%m%d_%H%M%S).zip"

echo "=== Claude Code Configuration Exporter ==="
echo ""

# Create output directory structure
echo "[1/6] Creating export directory structure..."
mkdir -p "$OUTPUT_DIR"/{agents,commands}

# Copy global CLAUDE.md
echo "[2/6] Copying global CLAUDE.md..."
if [ -f "$CLAUDE_DIR/CLAUDE.md" ]; then
    cp "$CLAUDE_DIR/CLAUDE.md" "$OUTPUT_DIR/CLAUDE_global.md"
    echo "      - CLAUDE_global.md copied"
else
    echo "      - WARNING: Global CLAUDE.md not found"
fi

# Copy project CLAUDE.md (if exists in current directory)
echo "[3/6] Copying project CLAUDE.md..."
if [ -f "CLAUDE.md" ]; then
    cp "CLAUDE.md" "$OUTPUT_DIR/CLAUDE_project.md"
    echo "      - CLAUDE_project.md copied"
else
    echo "      - INFO: No project CLAUDE.md in current directory"
fi

# Copy all agent definitions
echo "[4/6] Copying agent definitions..."
if [ -d "$CLAUDE_DIR/agents" ]; then
    agent_count=$(ls -1 "$CLAUDE_DIR/agents"/*.md 2>/dev/null | wc -l | tr -d ' ')
    if [ "$agent_count" -gt 0 ]; then
        cp "$CLAUDE_DIR/agents"/*.md "$OUTPUT_DIR/agents/"
        echo "      - $agent_count agent(s) copied"
    else
        echo "      - No agents found"
    fi
else
    echo "      - WARNING: Agents directory not found"
fi

# Copy all command/skill definitions
echo "[5/6] Copying command definitions..."
if [ -d "$CLAUDE_DIR/commands" ]; then
    cmd_count=$(ls -1 "$CLAUDE_DIR/commands"/*.md 2>/dev/null | wc -l | tr -d ' ')
    if [ "$cmd_count" -gt 0 ]; then
        cp "$CLAUDE_DIR/commands"/*.md "$OUTPUT_DIR/commands/"
        echo "      - $cmd_count command(s) copied"
    else
        echo "      - No commands found"
    fi
else
    echo "      - WARNING: Commands directory not found"
fi

# Copy settings and MCP config
echo "[6/6] Copying settings and MCP configuration..."
if [ -f "$CLAUDE_DIR/settings.json" ]; then
    cp "$CLAUDE_DIR/settings.json" "$OUTPUT_DIR/"
    echo "      - settings.json copied"
fi

# Copy Claude Code main config (contains MCP servers and other settings)
if [ -f "$HOME/.claude.json" ]; then
    cp "$HOME/.claude.json" "$OUTPUT_DIR/claude.json"
    echo "      - claude.json copied (contains MCP servers config)"
fi

# Create a README for the export
cat > "$OUTPUT_DIR/README.md" << 'EOF'
# Claude Code Configuration Export

This archive contains your Claude Code configuration files.

## Contents

### CLAUDE.md Files
- `CLAUDE_global.md` - Global instructions from `~/.claude/CLAUDE.md`
- `CLAUDE_project.md` - Project-specific instructions (if present)

### Agents (`agents/`)
Custom agent definitions that extend Claude Code's capabilities.
Place these in `~/.claude/agents/` to use them.

### Commands (`commands/`)
Custom slash commands/skills for Claude Code.
Place these in `~/.claude/commands/` to use them.

### Settings
- `settings.json` - Claude Code settings
- `claude.json` - Claude Code main config (includes MCP servers, user preferences)

## Installation

To restore these configurations:

```bash
# Copy global CLAUDE.md
cp CLAUDE_global.md ~/.claude/CLAUDE.md

# Copy agents
cp agents/*.md ~/.claude/agents/

# Copy commands
cp commands/*.md ~/.claude/commands/

# Copy settings
cp settings.json ~/.claude/
```

## Export Date
EOF

echo "Exported on: $(date)" >> "$OUTPUT_DIR/README.md"

# Create the zip file
echo ""
echo "Creating zip archive..."
cd "$(dirname "$OUTPUT_DIR")"
zip -r "$ZIP_NAME" "$(basename "$OUTPUT_DIR")" -x "*.DS_Store"

# Cleanup the temporary directory
rm -rf "$OUTPUT_DIR"

echo ""
echo "=== Export Complete ==="
echo "Zip file created: $(pwd)/$ZIP_NAME"
echo ""

# List contents
echo "Archive contents:"
unzip -l "$ZIP_NAME" | grep -E "^\s+[0-9]+" | grep -v "^-"
