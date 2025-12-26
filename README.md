# Claude Code Configuration Manager

Portable backup and restore scripts for Claude Code configuration files (agents, commands, settings).

## Quick Start

```bash
# Export your config
./export_claude_config.sh

# Import on another machine
./import_claude_config.sh claude_config_*.zip
```

## What Gets Managed

```mermaid
flowchart LR
    subgraph Config["Claude Code Config"]
        A["CLAUDE.md"]
        B["agents/*.md"]
        C["commands/*.md"]
        D["settings.json"]
        E["MCP configs"]
    end

    subgraph Scripts["This Repo"]
        F["export_claude_config.sh"]
        G["import_claude_config.sh"]
    end

    Config -->|export| F
    F -->|creates| H["claude_config_*.zip"]
    H -->|restore| G
    G -->|imports| Config
```

## File Locations

| Component | Location | Description |
|-----------|----------|-------------|
| Global CLAUDE.md | `~/.claude/CLAUDE.md` | Global agent behavior rules |
| Agents | `~/.claude/agents/*.md` | Custom agent definitions |
| Commands | `~/.claude/commands/*.md` | Slash commands/skills |
| Settings | `~/.claude/settings.json` | Claude Code preferences |
| MCP (Windsurf) | `~/.codeium/windsurf/mcp_config.json` | Windsurf MCP servers |
| MCP (Global) | `~/.mcp.json` | Global MCP servers |

---

## Export Script

### Usage

```bash
./export_claude_config.sh
```

### What It Does

1. Copies global `CLAUDE.md` from `~/.claude/`
2. Copies project `CLAUDE.md` from current directory (if exists)
3. Copies all agents from `~/.claude/agents/`
4. Copies all commands from `~/.claude/commands/`
5. Copies `settings.json`
6. Copies global MCP configurations (not project-specific)
7. Creates timestamped zip file

### Output

```
claude_config_YYYYMMDD_HHMMSS.zip
```

---

## Import Script

### Usage

```bash
# Auto-detect zip in current directory
./import_claude_config.sh

# Or specify zip file
./import_claude_config.sh /path/to/claude_config_*.zip
```

### What It Does

1. Extracts the zip archive
2. Creates `~/.claude/agents/` and `~/.claude/commands/` if needed
3. Backs up existing files before overwriting
4. Imports CLAUDE.md, agents, commands, and settings
5. Warns about MCP configs (requires manual import due to API keys)

### Features

- **Auto-backup**: Existing files are backed up with `.bak` extension
- **Safe MCP handling**: MCP configs are NOT auto-imported (contain API keys)
- **Color output**: Clear status indicators
- **Temp directory cleanup**: Automatic cleanup on exit

---

## Archive Structure

```
claude_config_YYYYMMDD_HHMMSS/
├── CLAUDE_global.md          # Global instructions
├── CLAUDE_project.md         # Project instructions (if present)
├── agents/
│   ├── Explorer.md
│   ├── ai-engineering-expert.md
│   ├── security-expert.md
│   └── ... (more agents)
├── commands/
│   ├── commit.md
│   ├── search.md
│   └── ... (more commands)
├── settings.json
├── mcp_config_windsurf.json  # If present (NOT auto-imported)
├── mcp_config_global.json    # If present (NOT auto-imported)
└── README.md
```

---

## MCP Configuration

MCP configs contain API keys and are **NOT auto-imported** for security.

### Manual MCP Import

```bash
# Extract the zip first
unzip claude_config_*.zip
cd claude_config_export_*

# For Windsurf
mkdir -p ~/.codeium/windsurf
cp mcp_config_windsurf.json ~/.codeium/windsurf/mcp_config.json

# For global MCP
cp mcp_config_global.json ~/.mcp.json

# IMPORTANT: Update API keys in the copied files!
```

---

## Cross-Machine Migration

### On Source Machine

```bash
git clone https://github.com/lehidalgo/claude-settings-zip.git
cd claude-settings-zip
./export_claude_config.sh
# Transfer the zip file to target machine
```

### On Target Machine

```bash
# Install Claude Code first
git clone https://github.com/lehidalgo/claude-settings-zip.git
cd claude-settings-zip
# Copy your zip file here
./import_claude_config.sh claude_config_*.zip
# Restart Claude Code
```

---

## Requirements

- Bash shell
- `zip` / `unzip` commands
- Claude Code installed (for import to work)

---

## Security Notes

The exported archive may contain:

- **MCP API keys** in `mcp_config_*.json` files
- **Custom instructions** that reference internal systems

**Recommendations**:
- Review MCP configs before sharing
- Store exports in secure locations
- Regenerate API keys after sharing
- The `.gitignore` prevents accidental zip commits

---

## License

MIT
