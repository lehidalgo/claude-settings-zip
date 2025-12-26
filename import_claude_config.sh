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

echo "[1/8] Extracting archive..."
unzip -q "$ZIP_FILE" -d "$TEMP_DIR"

# Find the extracted directory
EXPORT_DIR=$(find "$TEMP_DIR" -maxdepth 1 -type d -name "claude_config_export_*" | head -1)
if [ -z "$EXPORT_DIR" ]; then
    echo -e "${RED}Error: Invalid archive structure${NC}"
    exit 1
fi

echo "[2/8] Configuring path translation..."
# Check if source_home.txt exists for reference
SOURCE_HOME=""
if [ -f "$EXPORT_DIR/source_home.txt" ]; then
    SOURCE_HOME=$(cat "$EXPORT_DIR/source_home.txt")
    echo -e "      ${YELLOW}Source home path from export: $SOURCE_HOME${NC}"
fi

# Prompt user for source home path
echo ""
echo -e "      ${YELLOW}Path Translation Required${NC}"
echo "      Config files may contain absolute paths that need to be updated."
echo ""
if [ -n "$SOURCE_HOME" ]; then
    echo -n "      Enter source home path [$SOURCE_HOME]: "
    read USER_SOURCE_HOME
    if [ -z "$USER_SOURCE_HOME" ]; then
        USER_SOURCE_HOME="$SOURCE_HOME"
    fi
else
    echo -n "      Enter source home path (e.g., /Users/olduser): "
    read USER_SOURCE_HOME
    if [ -z "$USER_SOURCE_HOME" ]; then
        echo -e "      ${RED}Error: Source home path is required${NC}"
        exit 1
    fi
fi

CURRENT_HOME="$HOME"
echo -e "      ${GREEN}Will replace: $USER_SOURCE_HOME → $CURRENT_HOME${NC}"
echo ""

# Function to replace paths in a file
replace_paths_in_file() {
    local file="$1"
    if [ -f "$file" ] && [ "$USER_SOURCE_HOME" != "$CURRENT_HOME" ]; then
        # Count occurrences before replacement
        local count=$(grep -o "$USER_SOURCE_HOME" "$file" 2>/dev/null | wc -l | tr -d ' ')
        if [ "$count" -gt 0 ]; then
            # Use sed to replace paths (macOS compatible)
            sed -i '' "s|$USER_SOURCE_HOME|$CURRENT_HOME|g" "$file" 2>/dev/null || \
            sed -i "s|$USER_SOURCE_HOME|$CURRENT_HOME|g" "$file" 2>/dev/null || true
            echo "        - Replaced $count path(s) in $(basename "$file")"
        fi
    fi
}

echo "[3/8] Replacing paths in extracted files..."
TOTAL_REPLACEMENTS=0

# Replace paths in all extracted files
if [ -f "$EXPORT_DIR/CLAUDE_global.md" ]; then
    replace_paths_in_file "$EXPORT_DIR/CLAUDE_global.md"
fi

if [ -d "$EXPORT_DIR/agents" ]; then
    for file in "$EXPORT_DIR/agents"/*.md 2>/dev/null; do
        [ -f "$file" ] && replace_paths_in_file "$file"
    done
fi

if [ -d "$EXPORT_DIR/commands" ]; then
    for file in "$EXPORT_DIR/commands"/*.md 2>/dev/null; do
        [ -f "$file" ] && replace_paths_in_file "$file"
    done
fi

if [ -f "$EXPORT_DIR/settings.json" ]; then
    replace_paths_in_file "$EXPORT_DIR/settings.json"
fi

if [ -f "$EXPORT_DIR/claude.json" ]; then
    replace_paths_in_file "$EXPORT_DIR/claude.json"
fi

echo -e "      ${GREEN}✓ Path translation complete${NC}"

echo "[4/8] Creating directories..."
mkdir -p "$CLAUDE_DIR/agents"
mkdir -p "$CLAUDE_DIR/commands"

# Track what was imported
IMPORTED_COUNT=0

echo "[5/8] Importing CLAUDE.md..."
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

echo "[6/8] Importing agents..."
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

echo "[7/8] Importing commands..."
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

echo "[8/8] Importing settings and claude.json..."
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

if [ -f "$EXPORT_DIR/claude.json" ]; then
    # Merge exported config into existing config
    python3 -c "
import json, os

# Load exported config
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

# Merge exported config into existing (exported takes precedence for global settings)
# But preserve existing projects
existing_projects = existing.get('projects', {})

# Update all keys from exported config
for key, value in exported.items():
    if key == 'mcpServers':
        # Merge MCP servers (exported takes precedence)
        if 'mcpServers' not in existing:
            existing['mcpServers'] = {}
        existing['mcpServers'].update(value)
        print(f'      \033[0;32m✓ Merged {len(value)} global MCP server(s)\033[0m')
    else:
        existing[key] = value

# Restore existing projects
if existing_projects:
    existing['projects'] = existing_projects
    print(f'      \033[1;33mPreserved {len(existing_projects)} existing project(s)\033[0m')

# Save merged config
with open(existing_path, 'w') as f:
    json.dump(existing, f, indent=2)

print('      \033[0;32m✓ claude.json merged successfully\033[0m')
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
