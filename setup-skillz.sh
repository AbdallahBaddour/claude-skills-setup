#!/bin/bash
# setup-skillz.sh - Setup Skillz MCP for VS Code

echo "Setting up Skillz MCP for VS Code..."
echo ""

# Find the repo root (where .git exists or parent of script directory)
find_repo_root() {
    local dir="$1"
    while [ "$dir" != "/" ]; do
        if [ -d "$dir/.git" ]; then
            echo "$dir"
            return 0
        fi
        dir=$(dirname "$dir")
    done
    # If no .git found, use the parent directory of the script
    # (assuming script is in a subdirectory like claude-skills-setup/)
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    echo "$(dirname "$script_dir")"
}

# Clone or update a GitHub repository
clone_or_update_repo() {
    local repo="$1"
    local branch="$2"
    local temp_dir="$3"
    
    local repo_url="https://github.com/${repo}.git"
    # Replace '/' with '_' to create unique temp dir including org name (e.g., anthropics_skills)
    local temp_repo_dir="${temp_dir}/$(echo "$repo" | tr '/' '_')"
    
    # Check if git is available
    if ! command -v git &> /dev/null; then
        echo "  WARNING: Git is not installed. Please install Git to download skills from GitHub." >&2
        return 1
    fi
    
    # Clone or update the repo (always get latest version)
    if [ ! -d "$temp_repo_dir" ]; then
        echo "  Cloning ${repo}..." >&2
        if ! git clone --depth 1 --branch "$branch" --progress "$repo_url" "$temp_repo_dir" 2>&1 | grep --line-buffered -E "Receiving|Resolving|Cloning" | sed 's/^/    /' >&2; then
            if ! git clone --depth 1 --progress "$repo_url" "$temp_repo_dir" 2>&1 | grep --line-buffered -E "Receiving|Resolving|Cloning" | sed 's/^/    /' >&2; then
                echo "  ERROR: Failed to clone ${repo}" >&2
                return 1
            fi
        fi
    else
        # Update existing clone to get latest changes (silent)
        cd "$temp_repo_dir"
        git fetch --depth 1 origin "$branch" > /dev/null 2>&1 || git fetch --depth 1 origin > /dev/null 2>&1 || true
        git reset --hard "origin/$branch" > /dev/null 2>&1 || git reset --hard origin/HEAD > /dev/null 2>&1 || true
        cd - > /dev/null
    fi
    
    # Echo the path to stdout so it can be captured
    echo "$temp_repo_dir"
    return 0
}

# Copy a specific skill from a cloned repository
copy_skill_from_repo() {
    local temp_repo_dir="$1"
    local skill_name="$2"
    local dest_dir="$3"
    
    # Check if skill exists in the repo
    if [ ! -d "$temp_repo_dir/$skill_name" ]; then
        echo "     WARNING: Skill '$skill_name' not found in repository"
        return 1
    fi
    
    # Check if skill has SKILL.md
    if [ ! -f "$temp_repo_dir/$skill_name/SKILL.md" ]; then
        echo "     WARNING: Skill '$skill_name' does not contain SKILL.md, skipping"
        return 1
    fi
    
    # Copy skill to destination (override if exists to get updates)
    # Use only the basename for the destination (flatten the structure)
    local skill_basename=$(basename "$skill_name")
    local dest_path="$dest_dir/$skill_basename"
    
    if [ -e "$dest_path" ]; then
        rm -rf "$dest_path"
    fi
    
    cp -r "$temp_repo_dir/$skill_name" "$dest_path"
    echo "     ✓ Done"
    return 0
}

# Get script location and find repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT=$(find_repo_root "$SCRIPT_DIR")

echo "Project root: $REPO_ROOT"

# Determine the skillz directory (~/.skillz on Unix, %USERPROFILE%\.skillz on Windows)
if [ -n "$USERPROFILE" ]; then
    # Windows (Git Bash or WSL)
    SKILLZ_DIR="$USERPROFILE/.skillz"
    TEMP_DIR="${TMP:-/tmp}/skillz-downloads"
else
    # Unix/macOS
    SKILLZ_DIR="$HOME/.skillz"
    TEMP_DIR="${TMPDIR:-/tmp}/skillz-downloads"
fi

# Create .skillz directory if it doesn't exist
if [ ! -d "$SKILLZ_DIR" ]; then
    mkdir -p "$SKILLZ_DIR"
    echo "Created skills directory: $SKILLZ_DIR"
else
    echo "Skills directory: $SKILLZ_DIR"
fi

# Create temp directory for downloads
mkdir -p "$TEMP_DIR"

# Check for config file (look in script directory first, then repo root)
CONFIG_FILE=""
if [ -f "$SCRIPT_DIR/skills-config.json" ]; then
    CONFIG_FILE="$SCRIPT_DIR/skills-config.json"
elif [ -f "$REPO_ROOT/skills-config.json" ]; then
    CONFIG_FILE="$REPO_ROOT/skills-config.json"
fi

if [ -n "$CONFIG_FILE" ] && [ -f "$CONFIG_FILE" ]; then
    echo ""
    echo "Reading configuration: $CONFIG_FILE"
    echo "Downloading skills from GitHub repositories..."
    echo ""
    
    # Parse JSON using grep and sed
    # Extract from "github_repos" to the closing bracket with minimal indentation (the github_repos array closer)
    # Match ] with 0-3 spaces of indentation
    repos_content=$(sed -n '/"github_repos"/,/^[[:space:]]\{0,3\}\][[:space:]]*$/p' "$CONFIG_FILE" | grep -v '"github_repos"')
    
    if [ -z "$repos_content" ]; then
        echo "WARNING: No repositories found in configuration"
    fi
    
    # Process each repository block
    current_repo=""
    current_branch="main"
    skills_list=""
    in_skills_array=false
    repo_count=0
    
    while IFS= read -r line; do
        # Extract repo
        if echo "$line" | grep -q '"repo"'; then
            current_repo=$(echo "$line" | sed 's/.*"repo"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
        fi
        
        # Extract branch
        if echo "$line" | grep -q '"branch"'; then
            current_branch=$(echo "$line" | sed 's/.*"branch"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
        fi
        
        # Start of skills array
        if echo "$line" | grep -q '"skills"'; then
            in_skills_array=true
            skills_list=""
            continue
        fi
        
        # Extract skill names from array
        if [ "$in_skills_array" = true ]; then
            # Check if line contains closing bracket (either standalone or with other content)
            if echo "$line" | grep -q '\]'; then
                in_skills_array=false
                
                # Process this repository's skills
                if [ -n "$current_repo" ] && [ -n "$skills_list" ]; then
                    # Count total skills
                    skill_array=($skills_list)
                    total_skills=${#skill_array[@]}
                    
                    echo "Repository: ${current_repo} (${current_branch}) - ${total_skills} skill(s)"
                    
                    repo_count=$((repo_count + 1))
                    
                    # Clone or update the repository once
                    temp_repo_dir=$(clone_or_update_repo "$current_repo" "$current_branch" "$TEMP_DIR")
                    clone_result=$?
                    
                    if [ $clone_result -eq 0 ] && [ -n "$temp_repo_dir" ]; then
                        echo ""
                        # Process each skill from the cloned repo
                        skill_num=0
                        for skill in $skills_list; do
                            skill_num=$((skill_num + 1))
                            echo "  [$skill_num/$total_skills] Installing $(basename "$skill")..."
                            copy_skill_from_repo "$temp_repo_dir" "$skill" "$SKILLZ_DIR" || true
                        done
                    else
                        if [ $clone_result -ne 0 ]; then
                            echo "  ERROR: Failed to clone/update repository (exit code: $clone_result)"
                        else
                            echo "  ERROR: Repository path not set after cloning"
                        fi
                    fi
                    echo ""
                fi
                
                # Reset for next repo
                current_repo=""
                current_branch="main"
                skills_list=""
            else
                # Extract skill name from line
                skill=$(echo "$line" | sed 's/.*"\([^"]*\)".*/\1/' | tr -d ',' | xargs)
                if [ -n "$skill" ]; then
                    skills_list="$skills_list $skill"
                fi
            fi
        fi
    done <<< "$repos_content"
    
    if [ $repo_count -eq 0 ]; then
        echo "WARNING: No repositories were processed. Check your configuration format."
    fi
else
    echo ""
    echo "No skills-config.json found, skipping GitHub downloads"
fi

# Clean up temp directory
if [ -d "$TEMP_DIR" ]; then
    rm -rf "$TEMP_DIR"
fi

# Copy local skills if they exist
LOCAL_SKILLS_DIR="$SCRIPT_DIR/skills"
if [ -d "$LOCAL_SKILLS_DIR" ]; then
    echo ""
    echo "Copying local skills..."
    
    # Count local skills
    local_skill_count=0
    for skill_dir in "$LOCAL_SKILLS_DIR"/*; do
        if [ -d "$skill_dir" ] && [ -f "$skill_dir/SKILL.md" ]; then
            ((local_skill_count++))
        fi
    done
    
    if [ $local_skill_count -gt 0 ]; then
        echo "Found $local_skill_count local skill(s)"
        
        skill_index=0
        for skill_dir in "$LOCAL_SKILLS_DIR"/*; do
            if [ -d "$skill_dir" ] && [ -f "$skill_dir/SKILL.md" ]; then
                ((skill_index++))
                skill_name=$(basename "$skill_dir")
                echo "  [$skill_index/$local_skill_count] Installing $skill_name..."
                
                # Remove existing skill if it exists
                if [ -d "$SKILLZ_DIR/$skill_name" ]; then
                    rm -rf "$SKILLZ_DIR/$skill_name"
                fi
                
                # Copy the skill
                cp -r "$skill_dir" "$SKILLZ_DIR/$skill_name"
                echo "     ✓ Done"
            fi
        done
    else
        echo "No local skills found (skills must contain SKILL.md)"
    fi
fi

# Setup VS Code MCP configuration
echo ""
echo "Configuring Skillz MCP server..."

# Check if VS Code CLI is available
if command -v code &> /dev/null; then
    # Check if skillz is already configured
    VSCODE_DIR="$REPO_ROOT/.vscode"
    MCP_CONFIG_PATH="$VSCODE_DIR/mcp.json"
    
    if [ -f "$MCP_CONFIG_PATH" ] && grep -q '"skillz"' "$MCP_CONFIG_PATH" 2>/dev/null; then
        echo "Skillz MCP server is already configured"
    else
        # Use VS Code CLI to add the MCP server
        echo "Adding Skillz MCP server using VS Code CLI..."
        if code --add-mcp "{\"name\":\"skillz\",\"command\":\"uvx\",\"args\":[\"skillz@latest\"]}" 2>/dev/null; then
            echo "Successfully added Skillz MCP server"
        else
            echo "Note: VS Code CLI method failed, creating config file manually..."
            
            # Fallback: Create .vscode directory and mcp.json manually
            mkdir -p "$VSCODE_DIR"
            
            if [ -f "$MCP_CONFIG_PATH" ]; then
                echo "MCP configuration exists at: $MCP_CONFIG_PATH"
                echo "Please manually add Skillz server to your mcp.json:"
                echo ""
                echo '  "skillz": {'
                echo '    "command": "uvx",'
                echo '    "args": ["skillz@latest"]'
                echo '  }'
            else
                # Create new mcp.json
                cat > "$MCP_CONFIG_PATH" << 'EOF'
{
  "servers": {
    "skillz": {
      "command": "uvx",
      "args": ["skillz@latest"]
    }
  }
}
EOF
                echo "Created MCP configuration: $MCP_CONFIG_PATH"
            fi
        fi
    fi
else
    # VS Code CLI not available, fall back to manual file creation
    echo "VS Code CLI not found, creating config file manually..."
    VSCODE_DIR="$REPO_ROOT/.vscode"
    MCP_CONFIG_PATH="$VSCODE_DIR/mcp.json"
    mkdir -p "$VSCODE_DIR"
    
    if [ -f "$MCP_CONFIG_PATH" ]; then
        if grep -q '"skillz"' "$MCP_CONFIG_PATH" 2>/dev/null; then
            echo "Skillz is already configured in: $MCP_CONFIG_PATH"
        else
            echo "MCP configuration exists at: $MCP_CONFIG_PATH"
            echo "Please manually add Skillz server to the 'servers' section:"
            echo ""
            echo '  "skillz": {'
            echo '    "command": "uvx",'
            echo '    "args": ["skillz@latest"]'
            echo '  }'
        fi
    else
        # Create new mcp.json
        cat > "$MCP_CONFIG_PATH" << 'EOF'
{
  "servers": {
    "skillz": {
      "command": "uvx",
      "args": ["skillz@latest"]
    }
  }
}
EOF
        echo "Created MCP configuration: $MCP_CONFIG_PATH"
    fi
fi

echo ""
echo "Setup complete!"
echo "Skills are installed in: $SKILLZ_DIR"
echo ""
echo "Next steps:"
echo "  1. Restart VS Code to load the MCP server"
echo "  2. Open the Command Palette (Ctrl+Shift+P) and search for 'MCP: List Servers'"
echo "  3. Select 'Skillz' from the list of servers"
echo "  4. Click on start server option"
echo ""
echo "Press Enter to exit..."
read