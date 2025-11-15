#!/bin/bash
# setup-skillz.sh - Setup Skillz MCP for VS Code

echo "Setting up Skillz MCP for VS Code..."
echo ""

# Find the repo root (where .git exists or parent of script directory)
find_repo_root() {
    local script_dir="$1"
    # Start searching from the parent directory of the script
    # This ensures we skip any .git folder within claude-skills-setup itself
    local dir="$(dirname "$script_dir")"
    
    while [ "$dir" != "/" ]; do
        if [ -d "$dir/.git" ]; then
            echo "$dir"
            return 0
        fi
        dir=$(dirname "$dir")
    done
    
    # If no .git found, use the parent directory of the script
    # (assuming script is in a subdirectory like claude-skills-setup/)
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

# Check for uvx and install if needed
echo ""
echo "Checking for uvx..."

UVX_FOUND=false
if command -v uvx &> /dev/null; then
    UVX_FOUND=true
elif [ -n "$USERPROFILE" ]; then
    # On Windows, check if uvx.exe exists at expected location
    WIN_USERPROFILE=$(powershell -Command "[Environment]::GetFolderPath('UserProfile')" 2>/dev/null | tr -d '\r\n')
    if [ -n "$WIN_USERPROFILE" ]; then
        UVX_WIN_PATH="${WIN_USERPROFILE}\\.local\\bin\\uvx.exe"
        UVX_EXISTS=$(powershell -Command "Test-Path '$UVX_WIN_PATH'" 2>/dev/null | tr -d '\r\n')
        if [ "$UVX_EXISTS" = "True" ]; then
            UVX_FOUND=true
        fi
    fi
else
    # On Unix/macOS, check if uvx exists at expected location (~/.cargo/bin/uvx)
    if [ -f "$HOME/.cargo/bin/uvx" ]; then
        UVX_FOUND=true
    fi
fi

if [ "$UVX_FOUND" = true ]; then
    echo "uvx is already installed"
else
    echo "uvx not found. Installing uv (which includes uvx)..."
    echo ""
    
    # Detect platform and install uv
    if [ -n "$USERPROFILE" ]; then
        # Windows (Git Bash)
        echo "Detected Windows environment"
        echo "Installing uv using PowerShell installer..."
        
        # Check and set execution policy if needed
        echo "Checking PowerShell execution policy..."
        current_policy=$(powershell -Command "Get-ExecutionPolicy -Scope CurrentUser" 2>/dev/null)
        
        # Check if policy needs to be changed
        if [ -n "$current_policy" ]; then
            case "$current_policy" in
                Unrestricted|RemoteSigned|Bypass)
                    echo "Execution policy is already set to: $current_policy"
                    ;;
                *)
                    echo "Setting execution policy to RemoteSigned (required for uv installation)..."
                    powershell -Command "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force" 2>/dev/null
                    policy_result=$?
                    if [ $policy_result -ne 0 ]; then
                        echo "WARNING: Could not set execution policy automatically"
                        echo "Please run this command manually:"
                        echo "  Set-ExecutionPolicy RemoteSigned -Scope CurrentUser"
                    fi
                    ;;
            esac
        fi
        
        # Install uv
        powershell -Command "irm https://astral.sh/uv/install.ps1 | iex"
        install_result=$?
    else
        # Unix/macOS
        echo "Detected Unix/macOS environment"
        echo "Installing uv using shell installer..."
        curl -LsSf https://astral.sh/uv/install.sh | sh
        install_result=$?
    fi
    
    if [ $install_result -eq 0 ]; then
        echo ""
        echo "✓ uv installed successfully"
        
        # Add uv to PATH for current session if needed
        if [ -n "$USERPROFILE" ]; then
            # Windows: uv installs to %USERPROFILE%\.local\bin
            UV_BIN_DIR="$USERPROFILE/.local/bin"
            if [ -d "$UV_BIN_DIR" ] && [[ ":$PATH:" != *":$UV_BIN_DIR:"* ]]; then
                export PATH="$UV_BIN_DIR:$PATH"
                echo "Added $UV_BIN_DIR to PATH for this session"
            fi
        else
            # Unix/macOS: uv installs to ~/.cargo/bin
            if [ -d "$HOME/.cargo/bin" ] && [[ ":$PATH:" != *":$HOME/.cargo/bin:"* ]]; then
                export PATH="$HOME/.cargo/bin:$PATH"
                echo "Added $HOME/.cargo/bin to PATH for this session"
            fi
        fi
        
        # Verify uvx installation
        if [ -n "$USERPROFILE" ]; then
            # On Windows, check if uvx.exe exists (we'll use full path in MCP config)
            WIN_USERPROFILE=$(powershell -Command "[Environment]::GetFolderPath('UserProfile')" 2>/dev/null | tr -d '\r\n')
            if [ -n "$WIN_USERPROFILE" ]; then
                UVX_WIN_PATH="${WIN_USERPROFILE}\\.local\\bin\\uvx.exe"
                UVX_EXISTS=$(powershell -Command "Test-Path '$UVX_WIN_PATH'" 2>/dev/null | tr -d '\r\n')
                if [ "$UVX_EXISTS" = "True" ]; then
                    echo "✓ uvx installed at: $UVX_WIN_PATH"
                    echo "  (Will be used via full path in MCP configuration)"
                else
                    echo "WARNING: uvx.exe not found at expected location"
                fi
            fi
        else
            # Unix/macOS: verify it's in PATH
            if command -v uvx &> /dev/null; then
                echo "✓ uvx is now available"
            else
                echo "WARNING: uvx was installed but is not in PATH"
                echo "You may need to restart your terminal or add ~/.cargo/bin to your PATH"
            fi
        fi
    else
        echo "ERROR: Failed to install uv"
        echo ""
        echo "Please install uv manually:"
        echo "  Visit: https://docs.astral.sh/uv/getting-started/installation/"
        echo ""
        echo "Or run one of these commands:"
        if [ -n "$USERPROFILE" ]; then
            echo "  PowerShell: irm https://astral.sh/uv/install.ps1 | iex"
        else
            echo "  curl -LsSf https://astral.sh/uv/install.sh | sh"
        fi
        echo ""
    fi
fi

# Setup VS Code MCP configuration
echo ""
echo "Configuring Skillz MCP server..."

# Determine the correct uvx command path
UVX_CMD="uvx"
if [ -n "$USERPROFILE" ]; then
    # On Windows, always use full path if uvx.exe exists in .local/bin
    # (VS Code may not have the same PATH as the current shell session)
    # Get Windows path format of USERPROFILE using PowerShell
    WIN_USERPROFILE=$(powershell -Command "[Environment]::GetFolderPath('UserProfile')" 2>/dev/null | tr -d '\r\n')
    
    if [ -n "$WIN_USERPROFILE" ]; then
        # Check if uvx.exe exists using PowerShell (more reliable on Windows)
        UVX_WIN_PATH="${WIN_USERPROFILE}\\.local\\bin\\uvx.exe"
        UVX_EXISTS=$(powershell -Command "Test-Path '$UVX_WIN_PATH'" 2>/dev/null | tr -d '\r\n')
        
        if [ "$UVX_EXISTS" = "True" ]; then
            UVX_CMD="$UVX_WIN_PATH"
            echo "Using full path to uvx: $UVX_CMD"
        fi
    else
        # Fallback: try to construct path from USERPROFILE variable
        UVX_PATH_UNIX="$USERPROFILE/.local/bin/uvx.exe"
        if [ -f "$UVX_PATH_UNIX" ]; then
            # Convert USERPROFILE to Windows format
            if echo "$USERPROFILE" | grep -q '^[A-Z]:'; then
                # Already in Windows format
                UVX_CMD="$USERPROFILE\\.local\\bin\\uvx.exe"
            elif echo "$USERPROFILE" | grep -q '^/[a-z]'; then
                # Git Bash format: /c/Users/... -> C:\Users\...
                DRIVE_LETTER=$(echo "$USERPROFILE" | sed 's|^/\([a-z]\)|\1|' | cut -c1 | tr '[:lower:]' '[:upper:]')
                REST_PATH=$(echo "$USERPROFILE" | sed 's|^/[a-z]||' | sed 's|/|\\|g')
                UVX_CMD="${DRIVE_LETTER}:${REST_PATH}\\.local\\bin\\uvx.exe"
            fi
            echo "Using full path to uvx: $UVX_CMD"
        fi
    fi
else
    # On Unix/macOS, use full path if uvx is not in PATH but exists at ~/.cargo/bin/uvx
    # (for consistency and reliability, even though PATH usually works)
    if ! command -v uvx &> /dev/null && [ -f "$HOME/.cargo/bin/uvx" ]; then
        UVX_CMD="$HOME/.cargo/bin/uvx"
        echo "Using full path to uvx: $UVX_CMD"
    fi
fi

# Check if VS Code CLI is available
if command -v code &> /dev/null; then
    # Check if skillz is already configured
    VSCODE_DIR="$REPO_ROOT/.vscode"
    MCP_CONFIG_PATH="$VSCODE_DIR/mcp.json"
    
    if [ -f "$MCP_CONFIG_PATH" ] && grep -q '"skillz"' "$MCP_CONFIG_PATH" 2>/dev/null; then
        # Check if it's using just "uvx" instead of full path (needs update if we determined a full path)
        if [ "$UVX_CMD" != "uvx" ] && grep -q '"command"[[:space:]]*:[[:space:]]*"uvx"' "$MCP_CONFIG_PATH" 2>/dev/null; then
            echo "Skillz MCP server is configured but using 'uvx' instead of full path"
            echo "Updating configuration to use full path..."
            
            # Update the mcp.json file to use the full path
            UVX_CMD_JSON=$(echo "$UVX_CMD" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
            # Create a temporary file with the updated content
            if command -v mktemp &> /dev/null; then
                TEMP_MCP=$(mktemp)
            else
                # Fallback for systems without mktemp (use a fixed temp name)
                TEMP_MCP="${MCP_CONFIG_PATH}.tmp"
            fi
            sed "s|\"command\"[[:space:]]*:[[:space:]]*\"uvx\"|\"command\": \"$UVX_CMD_JSON\"|g" "$MCP_CONFIG_PATH" > "$TEMP_MCP"
            mv "$TEMP_MCP" "$MCP_CONFIG_PATH"
            echo "Updated MCP configuration to use full path: $UVX_CMD"
        else
            echo "Skillz MCP server is already configured"
        fi
    else
        # Use VS Code CLI to add the MCP server
        echo "Adding Skillz MCP server using VS Code CLI..."
        # Escape the command for JSON
        UVX_CMD_ESCAPED=$(echo "$UVX_CMD" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
        if code --add-mcp "{\"name\":\"skillz\",\"command\":\"$UVX_CMD_ESCAPED\",\"args\":[\"skillz@latest\"]}" 2>/dev/null; then
            echo "Successfully added Skillz MCP server"
        else
            echo "Note: VS Code CLI method failed, creating config file manually..."
            
            # Fallback: Create .vscode directory and mcp.json manually
            mkdir -p "$VSCODE_DIR"
            
            if [ -f "$MCP_CONFIG_PATH" ]; then
                echo "MCP configuration exists at: $MCP_CONFIG_PATH"
                echo "Please manually add Skillz server to your mcp.json:"
                echo ""
                echo "  \"skillz\": {"
                echo "    \"command\": \"$UVX_CMD\","
                echo "    \"args\": [\"skillz@latest\"]"
                echo "  }"
            else
                # Create new mcp.json with proper escaping
                UVX_CMD_JSON=$(echo "$UVX_CMD" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
                cat > "$MCP_CONFIG_PATH" << EOF
{
  "servers": {
    "skillz": {
      "command": "$UVX_CMD_JSON",
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
            # Check if it's using just "uvx" instead of full path (needs update if we determined a full path)
            if [ "$UVX_CMD" != "uvx" ] && grep -q '"command"[[:space:]]*:[[:space:]]*"uvx"' "$MCP_CONFIG_PATH" 2>/dev/null; then
                echo "Skillz is configured but using 'uvx' instead of full path"
                echo "Updating configuration to use full path..."
                
                # Update the mcp.json file to use the full path
                UVX_CMD_JSON=$(echo "$UVX_CMD" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
                # Create a temporary file with the updated content
                if command -v mktemp &> /dev/null; then
                    TEMP_MCP=$(mktemp)
                else
                    # Fallback for systems without mktemp (use a fixed temp name)
                    TEMP_MCP="${MCP_CONFIG_PATH}.tmp"
                fi
                sed "s|\"command\"[[:space:]]*:[[:space:]]*\"uvx\"|\"command\": \"$UVX_CMD_JSON\"|g" "$MCP_CONFIG_PATH" > "$TEMP_MCP"
                mv "$TEMP_MCP" "$MCP_CONFIG_PATH"
                echo "Updated MCP configuration to use full path: $UVX_CMD"
            else
                echo "Skillz is already configured in: $MCP_CONFIG_PATH"
            fi
        else
            echo "MCP configuration exists at: $MCP_CONFIG_PATH"
            echo "Please manually add Skillz server to the 'servers' section:"
            echo ""
            echo "  \"skillz\": {"
            echo "    \"command\": \"$UVX_CMD\","
            echo "    \"args\": [\"skillz@latest\"]"
            echo "  }"
        fi
    else
        # Create new mcp.json with proper escaping
        UVX_CMD_JSON=$(echo "$UVX_CMD" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
        cat > "$MCP_CONFIG_PATH" << EOF
{
  "servers": {
    "skillz": {
      "command": "$UVX_CMD_JSON",
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