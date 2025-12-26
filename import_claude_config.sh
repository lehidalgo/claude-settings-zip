#!/bin/bash

# Import Claude Code Configuration
# This script restores Claude Code configuration from an exported zip file
# NOTE: Run with bash, not sh: ./import_claude_config.sh or bash import_claude_config.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

printf "=== Claude Code Configuration Importer ===\n"
printf "\n"

# Check for zip file argument
if [ -z "$1" ]; then
    # Try to find a zip file in current directory
    ZIP_FILE=$(ls -t claude_config_*.zip 2>/dev/null | head -1)
    if [ -z "$ZIP_FILE" ]; then
        printf "${RED}Error: No zip file specified and no claude_config_*.zip found${NC}\n"
        printf "\n"
        printf "Usage: $0 <path_to_zip_file>\n"
        printf "   or: $0  (auto-detect zip in current directory)\n"
        exit 1
    fi
    printf "${YELLOW}Auto-detected: $ZIP_FILE${NC}\n"
else
    ZIP_FILE="$1"
fi

# Verify zip file exists
if [ ! -f "$ZIP_FILE" ]; then
    printf "${RED}Error: File not found: $ZIP_FILE${NC}\n"
    exit 1
fi

# Configuration
CLAUDE_DIR="$HOME/.claude"
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

printf "[1/8] Extracting archive...\n"
unzip -q "$ZIP_FILE" -d "$TEMP_DIR"

# Find the extracted directory
EXPORT_DIR=$(find "$TEMP_DIR" -maxdepth 1 -type d -name "claude_config_export_*" | head -1)
if [ -z "$EXPORT_DIR" ]; then
    printf "${RED}Error: Invalid archive structure${NC}\n"
    exit 1
fi

printf "[2/8] Configuring path translation...\n"
# Check if source_home.txt exists for reference
SOURCE_HOME=""
if [ -f "$EXPORT_DIR/source_home.txt" ]; then
    SOURCE_HOME=$(cat "$EXPORT_DIR/source_home.txt")
    printf "      ${YELLOW}Source home path from export: $SOURCE_HOME${NC}\n"
fi

# Prompt user for source home path
printf "\n"
printf "      ${YELLOW}Path Translation Required${NC}\n"
printf "      Config files may contain absolute paths that need to be updated.\n"
printf "\n"
if [ -n "$SOURCE_HOME" ]; then
    printf "      Enter source home path [$SOURCE_HOME]: "
    read USER_SOURCE_HOME
    if [ -z "$USER_SOURCE_HOME" ]; then
        USER_SOURCE_HOME="$SOURCE_HOME"
    fi
else
    printf "      Enter source home path (e.g., /Users/olduser): "
    read USER_SOURCE_HOME
    if [ -z "$USER_SOURCE_HOME" ]; then
        printf "      ${RED}Error: Source home path is required${NC}\n"
        exit 1
    fi
fi

CURRENT_HOME="$HOME"
printf "      ${GREEN}Will replace: $USER_SOURCE_HOME → $CURRENT_HOME${NC}\n"
printf "\n"

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
            printf "        - Replaced $count path(s) in $(basename "$file")\n"
        fi
    fi
}

printf "[3/8] Replacing paths in extracted files...\n"

# Replace paths in all extracted files
if [ -f "$EXPORT_DIR/CLAUDE_global.md" ]; then
    replace_paths_in_file "$EXPORT_DIR/CLAUDE_global.md"
fi

if [ -d "$EXPORT_DIR/agents" ]; then
    for file in "$EXPORT_DIR/agents"/*.md; do
        if [ -f "$file" ]; then
            replace_paths_in_file "$file"
        fi
    done
fi

if [ -d "$EXPORT_DIR/commands" ]; then
    for file in "$EXPORT_DIR/commands"/*.md; do
        if [ -f "$file" ]; then
            replace_paths_in_file "$file"
        fi
    done
fi

if [ -f "$EXPORT_DIR/settings.json" ]; then
    replace_paths_in_file "$EXPORT_DIR/settings.json"
fi

if [ -f "$EXPORT_DIR/claude.json" ]; then
    replace_paths_in_file "$EXPORT_DIR/claude.json"
fi

printf "      ${GREEN}✓ Path translation complete${NC}\n"

printf "[4/8] Creating directories...\n"
mkdir -p "$CLAUDE_DIR/agents"
mkdir -p "$CLAUDE_DIR/commands"

# Track what was imported
IMPORTED_COUNT=0

printf "[5/8] Importing CLAUDE.md...\n"
if [ -f "$EXPORT_DIR/CLAUDE_global.md" ]; then
    if [ -f "$CLAUDE_DIR/CLAUDE.md" ]; then
        printf "      ${YELLOW}Backing up existing CLAUDE.md to CLAUDE.md.bak${NC}\n"
        cp "$CLAUDE_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md.bak"
    fi
    cp "$EXPORT_DIR/CLAUDE_global.md" "$CLAUDE_DIR/CLAUDE.md"
    printf "      ${GREEN}✓ CLAUDE.md imported${NC}\n"
    IMPORTED_COUNT=$((IMPORTED_COUNT + 1))
else
    printf "      - No global CLAUDE.md in archive\n"
fi

printf "[6/8] Importing agents...\n"
if [ -d "$EXPORT_DIR/agents" ]; then
    agent_count=$(ls -1 "$EXPORT_DIR/agents"/*.md 2>/dev/null | wc -l | tr -d ' ')
    if [ "$agent_count" -gt 0 ]; then
        for agent in "$EXPORT_DIR/agents"/*.md; do
            if [ -f "$agent" ]; then
                agent_name=$(basename "$agent")
                if [ -f "$CLAUDE_DIR/agents/$agent_name" ]; then
                    printf "      ${YELLOW}Overwriting: $agent_name${NC}\n"
                fi
                cp "$agent" "$CLAUDE_DIR/agents/"
            fi
        done
        printf "      ${GREEN}✓ $agent_count agent(s) imported${NC}\n"
        IMPORTED_COUNT=$((IMPORTED_COUNT + agent_count))
    else
        printf "      - No agents in archive\n"
    fi
else
    printf "      - No agents directory in archive\n"
fi

printf "[7/8] Importing commands...\n"
if [ -d "$EXPORT_DIR/commands" ]; then
    cmd_count=$(ls -1 "$EXPORT_DIR/commands"/*.md 2>/dev/null | wc -l | tr -d ' ')
    if [ "$cmd_count" -gt 0 ]; then
        for cmd in "$EXPORT_DIR/commands"/*.md; do
            if [ -f "$cmd" ]; then
                cmd_name=$(basename "$cmd")
                if [ -f "$CLAUDE_DIR/commands/$cmd_name" ]; then
                    printf "      ${YELLOW}Overwriting: $cmd_name${NC}\n"
                fi
                cp "$cmd" "$CLAUDE_DIR/commands/"
            fi
        done
        printf "      ${GREEN}✓ $cmd_count command(s) imported${NC}\n"
        IMPORTED_COUNT=$((IMPORTED_COUNT + cmd_count))
    else
        printf "      - No commands in archive\n"
    fi
else
    printf "      - No commands directory in archive\n"
fi

printf "[8/8] Importing settings and claude.json...\n"
if [ -f "$EXPORT_DIR/settings.json" ]; then
    if [ -f "$CLAUDE_DIR/settings.json" ]; then
        printf "      ${YELLOW}Backing up existing settings.json to settings.json.bak${NC}\n"
        cp "$CLAUDE_DIR/settings.json" "$CLAUDE_DIR/settings.json.bak"
    fi
    cp "$EXPORT_DIR/settings.json" "$CLAUDE_DIR/settings.json"
    printf "      ${GREEN}✓ settings.json imported${NC}\n"
    IMPORTED_COUNT=$((IMPORTED_COUNT + 1))
else
    printf "      - No settings.json in archive\n"
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
    IMPORTED_COUNT=$((IMPORTED_COUNT + 1))
else
    printf "      - No claude.json in archive\n"
fi

printf "\n"
printf "=== Import Complete ===\n"
printf "${GREEN}Successfully imported $IMPORTED_COUNT item(s)${NC}\n"
printf "\n"
printf "Imported to: $CLAUDE_DIR\n"
printf "\n"
printf "Directory contents:\n"
printf "  agents/   : $(ls -1 "$CLAUDE_DIR/agents"/*.md 2>/dev/null | wc -l | tr -d ' ') file(s)\n"
printf "  commands/ : $(ls -1 "$CLAUDE_DIR/commands"/*.md 2>/dev/null | wc -l | tr -d ' ') file(s)\n"
printf "\n"
printf "${GREEN}Restart Claude Code to use the imported configuration.${NC}\n"
