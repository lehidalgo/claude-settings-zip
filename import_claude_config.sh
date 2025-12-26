#!/bin/bash

# Import Claude Code Configuration
# This script restores Claude Code configuration from an exported zip file

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== Claude Code Configuration Importer ==="
echo ""

# Check for zip file argument
if [ -z "$1" ]; then
    # Try to find a zip file in current directory
    ZIP_FILE=$(ls -t claude_config_*.zip 2>/dev/null | head -1)
    if [ -z "$ZIP_FILE" ]; then
        echo -e "${RED}Error: No zip file specified and no claude_config_*.zip found${NC}"
        echo ""
        echo "Usage: $0 <path_to_zip_file>"
        echo "   or: $0  (auto-detect zip in current directory)"
        exit 1
    fi
    echo -e "${YELLOW}Auto-detected: $ZIP_FILE${NC}"
else
    ZIP_FILE="$1"
fi

# Verify zip file exists
if [ ! -f "$ZIP_FILE" ]; then
    echo -e "${RED}Error: File not found: $ZIP_FILE${NC}"
    exit 1
fi

# Configuration
CLAUDE_DIR="$HOME/.claude"
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

echo "[1/7] Extracting archive..."
unzip -q "$ZIP_FILE" -d "$TEMP_DIR"

# Find the extracted directory
EXPORT_DIR=$(find "$TEMP_DIR" -maxdepth 1 -type d -name "claude_config_export_*" | head -1)
if [ -z "$EXPORT_DIR" ]; then
    echo -e "${RED}Error: Invalid archive structure${NC}"
    exit 1
fi

echo "[2/7] Creating directories..."
mkdir -p "$CLAUDE_DIR/agents"
mkdir -p "$CLAUDE_DIR/commands"

# Track what was imported
IMPORTED_COUNT=0

echo "[3/7] Importing CLAUDE.md..."
if [ -f "$EXPORT_DIR/CLAUDE_global.md" ]; then
    if [ -f "$CLAUDE_DIR/CLAUDE.md" ]; then
        echo -e "      ${YELLOW}Backing up existing CLAUDE.md to CLAUDE.md.bak${NC}"
        cp "$CLAUDE_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md.bak"
    fi
    cp "$EXPORT_DIR/CLAUDE_global.md" "$CLAUDE_DIR/CLAUDE.md"
    echo -e "      ${GREEN}✓ CLAUDE.md imported${NC}"
    ((IMPORTED_COUNT++))
else
    echo "      - No global CLAUDE.md in archive"
fi

echo "[4/7] Importing agents..."
if [ -d "$EXPORT_DIR/agents" ]; then
    agent_count=$(ls -1 "$EXPORT_DIR/agents"/*.md 2>/dev/null | wc -l | tr -d ' ')
    if [ "$agent_count" -gt 0 ]; then
        for agent in "$EXPORT_DIR/agents"/*.md; do
            agent_name=$(basename "$agent")
            if [ -f "$CLAUDE_DIR/agents/$agent_name" ]; then
                echo -e "      ${YELLOW}Overwriting: $agent_name${NC}"
            fi
            cp "$agent" "$CLAUDE_DIR/agents/"
        done
        echo -e "      ${GREEN}✓ $agent_count agent(s) imported${NC}"
        ((IMPORTED_COUNT+=agent_count))
    else
        echo "      - No agents in archive"
    fi
else
    echo "      - No agents directory in archive"
fi

echo "[5/7] Importing commands..."
if [ -d "$EXPORT_DIR/commands" ]; then
    cmd_count=$(ls -1 "$EXPORT_DIR/commands"/*.md 2>/dev/null | wc -l | tr -d ' ')
    if [ "$cmd_count" -gt 0 ]; then
        for cmd in "$EXPORT_DIR/commands"/*.md; do
            cmd_name=$(basename "$cmd")
            if [ -f "$CLAUDE_DIR/commands/$cmd_name" ]; then
                echo -e "      ${YELLOW}Overwriting: $cmd_name${NC}"
            fi
            cp "$cmd" "$CLAUDE_DIR/commands/"
        done
        echo -e "      ${GREEN}✓ $cmd_count command(s) imported${NC}"
        ((IMPORTED_COUNT+=cmd_count))
    else
        echo "      - No commands in archive"
    fi
else
    echo "      - No commands directory in archive"
fi

echo "[6/7] Importing settings..."
if [ -f "$EXPORT_DIR/settings.json" ]; then
    if [ -f "$CLAUDE_DIR/settings.json" ]; then
        echo -e "      ${YELLOW}Backing up existing settings.json to settings.json.bak${NC}"
        cp "$CLAUDE_DIR/settings.json" "$CLAUDE_DIR/settings.json.bak"
    fi
    cp "$EXPORT_DIR/settings.json" "$CLAUDE_DIR/settings.json"
    echo -e "      ${GREEN}✓ settings.json imported${NC}"
    ((IMPORTED_COUNT++))
else
    echo "      - No settings.json in archive"
fi

echo "[7/7] Checking MCP configurations..."
MCP_FILES=$(find "$EXPORT_DIR" -maxdepth 1 -name "mcp_config*.json" 2>/dev/null)
if [ -n "$MCP_FILES" ]; then
    echo ""
    echo -e "      ${YELLOW}⚠ MCP config files found but NOT auto-imported:${NC}"
    for mcp_file in $MCP_FILES; do
        echo "         - $(basename "$mcp_file")"
    done
    echo ""
    echo -e "      ${YELLOW}MCP configs contain API keys that are machine-specific.${NC}"
    echo "      To import manually, extract the zip and copy the MCP config:"
    echo ""
    echo "      # For Windsurf:"
    echo "      mkdir -p ~/.codeium/windsurf"
    echo "      cp mcp_config_windsurf.json ~/.codeium/windsurf/mcp_config.json"
    echo ""
    echo "      # For global MCP:"
    echo "      cp mcp_config_global.json ~/.mcp.json"
    echo ""
    echo -e "      ${RED}Remember to update API keys after copying!${NC}"
else
    echo "      - No MCP configs in archive"
fi

echo ""
echo "=== Import Complete ==="
echo -e "${GREEN}Successfully imported $IMPORTED_COUNT item(s)${NC}"
echo ""
echo "Imported to: $CLAUDE_DIR"
echo ""
echo "Directory contents:"
echo "  agents/   : $(ls -1 "$CLAUDE_DIR/agents"/*.md 2>/dev/null | wc -l | tr -d ' ') file(s)"
echo "  commands/ : $(ls -1 "$CLAUDE_DIR/commands"/*.md 2>/dev/null | wc -l | tr -d ' ') file(s)"
echo ""
echo -e "${GREEN}Restart Claude Code to use the imported configuration.${NC}"
