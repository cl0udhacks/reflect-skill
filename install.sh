#!/bin/bash
# reflect-skill installer
# Installs /reflect and /done skills for AI coding assistants
# Tested with Claude Code — works with any harness that loads skill files

set -e

BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[32m'
YELLOW='\033[33m'
CYAN='\033[36m'
RESET='\033[0m'

echo ""
echo -e "${BOLD}reflect-skill installer${RESET}"
echo -e "${DIM}Teach your AI coding assistant to learn from its mistakes${RESET}"
echo ""

# ─── Detect harness ──────────────────────────────────────────────

CLAUDE_CODE=false
SKILLS_DIR=""
MEMORY_DIR=""

if [ -d "$HOME/.claude" ]; then
    CLAUDE_CODE=true
    echo -e "${GREEN}Detected Claude Code${RESET}"
    echo ""
fi

# ─── Step 1: Skills directory ────────────────────────────────────

if [ "$CLAUDE_CODE" = true ]; then
    # Check for project-level .claude/skills first
    if [ -d ".claude" ]; then
        DEFAULT_SKILLS=".claude/skills"
    else
        DEFAULT_SKILLS="$HOME/.claude/skills"
    fi
    echo -e "${BOLD}Step 1: Where should the skills be installed?${RESET}"
    echo ""
    echo "  Skills directory determines which projects can use /reflect."
    echo "  - Project-level (.claude/skills): only this project"
    echo "  - User-level (~/.claude/skills): all your projects"
    echo ""
    read -p "Skills directory [$DEFAULT_SKILLS]: " SKILLS_DIR
    SKILLS_DIR="${SKILLS_DIR:-$DEFAULT_SKILLS}"
else
    echo -e "${BOLD}Step 1: Where are your AI skill files stored?${RESET}"
    echo ""
    echo "  This is the directory where your AI harness loads skill/prompt files from."
    echo "  Examples: .claude/skills, .cursor/skills, .ai/prompts"
    echo ""
    read -p "Skills directory: " SKILLS_DIR

    if [ -z "$SKILLS_DIR" ]; then
        echo "Error: skills directory is required."
        exit 1
    fi
fi

# ─── Step 2: Memory directory ────────────────────────────────────

echo ""
echo -e "${BOLD}Step 2: Where should experience files be stored?${RESET}"
echo ""
echo "  This is where /reflect will save lessons learned from your sessions."
echo "  It needs a persistent directory that survives between conversations."
echo ""

if [ "$CLAUDE_CODE" = true ]; then
    # Try to find the project memory directory
    PROJECT_HASH=$(echo "$PWD" | sed 's|/|-|g')
    CLAUDE_MEMORY="$HOME/.claude/projects/$PROJECT_HASH/memory"
    if [ -d "$CLAUDE_MEMORY" ]; then
        DEFAULT_MEMORY="$CLAUDE_MEMORY"
    else
        DEFAULT_MEMORY="$HOME/.claude/memory"
    fi
    echo -e "  ${DIM}Claude Code stores memory at:${RESET}"
    echo -e "  ${DIM}~/.claude/projects/<project-hash>/memory/${RESET}"
    echo ""
    read -p "Memory directory [$DEFAULT_MEMORY]: " MEMORY_DIR
    MEMORY_DIR="${MEMORY_DIR:-$DEFAULT_MEMORY}"
else
    echo "  This should be a directory that persists between AI sessions."
    echo "  Examples: .ai/memory, .agent/memory, memory/"
    echo ""
    read -p "Memory directory: " MEMORY_DIR

    if [ -z "$MEMORY_DIR" ]; then
        echo "Error: memory directory is required."
        exit 1
    fi
fi

# ─── Step 3: Optional hook ──────────────────────────────────────

INSTALL_HOOK=false

echo ""
echo -e "${BOLD}Step 3: Install auto-trigger hook? (Claude Code only)${RESET}"
echo ""
echo "  This hook nudges your assistant to run /reflect after git commits"
echo "  and deploys. It's optional — you can always run /reflect manually"
echo "  or use /done at the end of a session."
echo ""

if [ "$CLAUDE_CODE" = true ]; then
    read -p "Install hook? [y/N]: " HOOK_ANSWER
    if [ "$HOOK_ANSWER" = "y" ] || [ "$HOOK_ANSWER" = "Y" ]; then
        INSTALL_HOOK=true
    fi
else
    echo -e "  ${DIM}Skipped — hook installation is Claude Code specific.${RESET}"
    echo -e "  ${DIM}See README.md for manual hook configuration.${RESET}"
fi

# ─── Install ─────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo -e "${CYAN}Installing...${RESET}"
echo ""

# Copy skill files
mkdir -p "$SKILLS_DIR/reflect" "$SKILLS_DIR/done"
cp "$SCRIPT_DIR/skills/reflect/SKILL.md" "$SKILLS_DIR/reflect/SKILL.md"
cp "$SCRIPT_DIR/skills/done/SKILL.md" "$SKILLS_DIR/done/SKILL.md"
echo "  Copied skills/reflect/SKILL.md → $SKILLS_DIR/reflect/SKILL.md"
echo "  Copied skills/done/SKILL.md    → $SKILLS_DIR/done/SKILL.md"

# Create memory directories
mkdir -p "$MEMORY_DIR/experiences/archived"
mkdir -p "$MEMORY_DIR/state"
echo "  Created $MEMORY_DIR/experiences/"
echo "  Created $MEMORY_DIR/experiences/archived/"
echo "  Created $MEMORY_DIR/state/"

# Create MEMORY.md index if it doesn't exist
if [ ! -f "$MEMORY_DIR/MEMORY.md" ]; then
    cat > "$MEMORY_DIR/MEMORY.md" << 'MEMEOF'
# Memory

## Experiences

<!-- /reflect will add entries here automatically -->

## State

<!-- Project-specific context files go here -->
MEMEOF
    echo "  Created $MEMORY_DIR/MEMORY.md (index file)"
else
    # Check if Experiences section exists, add if not
    if ! grep -q "## Experiences" "$MEMORY_DIR/MEMORY.md"; then
        TEMP=$(mktemp)
        echo "" >> "$TEMP"
        echo "## Experiences" >> "$TEMP"
        echo "" >> "$TEMP"
        echo "<!-- /reflect will add entries here automatically -->" >> "$TEMP"
        echo "" >> "$TEMP"
        cat "$MEMORY_DIR/MEMORY.md" >> "$TEMP"
        mv "$TEMP" "$MEMORY_DIR/MEMORY.md"
        echo "  Added ## Experiences section to existing MEMORY.md"
    else
        echo "  MEMORY.md already has ## Experiences section — skipped"
    fi
fi

# Install hook
if [ "$INSTALL_HOOK" = true ]; then
    SETTINGS="$HOME/.claude/settings.json"
    if [ -f "$SETTINGS" ]; then
        # Check if hook already exists
        if grep -q "Session marker detected" "$SETTINGS" 2>/dev/null; then
            echo "  Hook already installed — skipped"
        else
            # Check if jq is available
            if ! command -v jq &> /dev/null; then
                echo ""
                echo -e "  ${YELLOW}Warning: jq is required for the hook but not installed.${RESET}"
                echo "  Install it with: brew install jq"
                echo "  Hook installation skipped."
            else
                # Add the hook using jq
                HOOK_CMD='INPUT=$(cat); COMMAND=$(echo "$INPUT" | jq -r '"'"'.tool_input.command // empty'"'"'); SUCCEEDED=$(echo "$INPUT" | jq -r '"'"'.tool_succeeded // false'"'"'); if [ "$SUCCEEDED" = "true" ] && echo "$COMMAND" | grep -qE '"'"'(git commit|wrangler deploy)'"'"'; then echo '"'"'Session marker detected - run /reflect before ending.'"'"'; fi'

                cp "$SETTINGS" "$SETTINGS.bak"

                jq --arg cmd "$HOOK_CMD" '
                    .hooks.PostToolUse += [{
                        "matcher": "Bash",
                        "hooks": [{
                            "type": "command",
                            "command": $cmd,
                            "timeout": 5
                        }]
                    }]
                ' "$SETTINGS.bak" > "$SETTINGS"

                if jq . "$SETTINGS" > /dev/null 2>&1; then
                    rm "$SETTINGS.bak"
                    echo "  Added PostToolUse hook to $SETTINGS"
                else
                    mv "$SETTINGS.bak" "$SETTINGS"
                    echo -e "  ${YELLOW}Warning: Hook installation failed — settings.json restored from backup${RESET}"
                fi
            fi
        fi
    else
        echo -e "  ${YELLOW}Warning: $SETTINGS not found — hook skipped${RESET}"
        echo "  Create the file or run Claude Code first, then re-run this installer."
    fi
fi

# ─── Done ────────────────────────────────────────────────────────

echo ""
echo -e "${GREEN}${BOLD}Installation complete!${RESET}"
echo ""
echo "  Usage:"
echo "    /reflect    — Extract experiences from the current session"
echo "    /done       — End session (runs /reflect + summary + progress)"
echo ""
echo "  Your experiences will be saved to:"
echo "    $MEMORY_DIR/experiences/"
echo ""
if [ "$INSTALL_HOOK" = true ]; then
    echo "  Auto-trigger: enabled (fires after git commit / deploy)"
else
    echo "  Auto-trigger: not installed (use /reflect or /done manually)"
fi
echo ""
