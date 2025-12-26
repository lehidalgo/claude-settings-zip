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

echo "[7/7] Importing claude.json (global MCP servers config)..."
if [ -f "$EXPORT_DIR/claude.json" ]; then
    # Merge global MCP servers into existing config (preserve existing projects)
    python3 -c "
import json, re, os

# Load exported config (global only, no projects)
with open('$EXPORT_DIR/claude.json', 'r') as f:
    exported = json.load(f)

# Load existing config if present
existing_path = os.path.expanduser('~/.claude.json')
if os.path.exists(existing_path):
    with open(existing_path, 'r') as f:
        existing = json.load(f)
    # Backup
    with open(existing_path + '.bak', 'w') as f:
        json.dump(existing, f, indent=2)
    print('      \033[1;33mBacking up existing .claude.json to .claude.json.bak\033[0m')
else:
    existing = {}

# Detect source home directory for path translation
content = json.dumps(exported)
match = re.search(r'(/(?:Users|home)/[^/\"]+)', content)
source_home = match.group(1) if match else None
current_home = os.path.expanduser('~')

# Merge global MCP servers (with path translation)
if 'mcpServers' in exported:
    mcp_json = json.dumps(exported['mcpServers'])
    if source_home and source_home != current_home:
        mcp_json = mcp_json.replace(source_home, current_home)
        print(f'      \033[1;33mTranslating paths: {source_home} → {current_home}\033[0m')
    exported['mcpServers'] = json.loads(mcp_json)

    # Merge into existing (exported MCP servers take precedence)
    if 'mcpServers' not in existing:
        existing['mcpServers'] = {}
    existing['mcpServers'].update(exported['mcpServers'])
    print(f'      \033[0;32m✓ Imported {len(exported[\"mcpServers\"])} global MCP server(s)\033[0m')

# Preserve existing projects (don't overwrite)
# Only update global settings from exported config
for key in ['theme', 'autoUpdates']:
    if key in exported:
        existing[key] = exported[key]

# Save merged config
with open(existing_path, 'w') as f:
    json.dump(existing, f, indent=2)

print('      \033[0;32m✓ claude.json merged (global config imported, projects preserved)\033[0m')
"
    ((IMPORTED_COUNT++))
else
    echo "      - No claude.json in archive"
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
