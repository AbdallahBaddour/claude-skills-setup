# Claude Skills Setup

Automated setup for Claude skills via the Skillz MCP server in VS Code.

## Quick Start

```bash
cd claude-skills-setup
./setup-skillz.sh
```

This will:
1. Create `~/.skillz` directory
2. Download skills from GitHub repositories (specified in `skills-config.json`)
3. Copy custom skills from the `skills/` directory
4. Configure Skillz MCP server using VS Code CLI (or create `.vscode/mcp.json` if CLI unavailable)

## Prerequisites

- [uv](https://github.com/astral-sh/uv) (for running `uvx`) - **will be installed automatically by the script if not present**
- VS Code installed (the script uses VS Code CLI to configure MCP)
- Bash shell (Git Bash/WSL for Windows, native shell for macOS/Linux)
- Git (for downloading skills from GitHub)

## Features

### 1. GitHub Skills

Download skills from GitHub repositories by configuring `skills-config.json`:

```json
{
  "github_repos": [
    {
      "repo": "anthropics/skills",
      "branch": "main",
      "skills": [
        "canvas-design",
        "document-skills/docx",
        "document-skills/pdf"
      ]
    },
    {
      "repo": "your-org/custom-skills",
      "branch": "main",
      "skills": [
        "skill-name"
      ]
    }
  ]
}
```

### 2. Custom Skills

Create your own team-specific skills and add them to the `skills/` directory:

```
claude-skills-setup/
├── skills/
│   ├── my-custom-skill/
│   │   ├── SKILL.md
│   │   └── helpers.py
│   └── another-skill/
│       └── SKILL.md
```

These will be automatically copied to `~/.skillz/` when you run the setup.

#### Creating Custom Skills

**Using the Skill Creator (Recommended):**

After running the setup, use the included `skill-creator` skill via Copilot:

1. In VS Code, ask Copilot: "Use skill-creator to create a new skill for [your use case]"
2. Follow the interactive prompts to define your skill
3. The skill will be generated with proper structure and formatting
4. Save it to the `skills/` directory
5. Run `./setup-skillz.sh` to install it

**Manual Creation:**

See `skills/skill-creator/SKILL.md` for detailed instructions and templates.

## Usage

### Initial Setup

```bash
cd claude-skills-setup
./setup-skillz.sh
```

### After Updates

Run the setup script again to update skills:

```bash
cd claude-skills-setup
./setup-skillz.sh
```

This will:
- Update all GitHub-based skills to the latest versions
- Copy any new/updated custom skills
- Automatically detect and skip MCP configuration if Skillz is already configured

### Activate in VS Code

After running setup:

1. Restart VS Code to load the MCP server
2. Open the Command Palette (Ctrl+Shift+P or Cmd+Shift+P) and search for 'MCP: List Servers'
3. Select 'Skillz' from the list of servers
4. Click on start server option
5. Start using your Claude skills!

## Configuration

### GitHub Skills (`skills-config.json`)

- **`github_repos`**: Array of repositories to download from
  - **`repo`**: GitHub repository in format `owner/repo`
  - **`branch`**: Branch to clone from (defaults to `main`)
  - **`skills`**: Array of skill paths to download

### Custom Skills (`skills/` directory)

- Each skill must be in its own subdirectory
- Each skill must have a `SKILL.md` file with frontmatter (name, description)
- Skills can include additional files and scripts
- Use the `skill-creator` skill via Copilot for guided creation
- See `skills/skill-creator/SKILL.md` for manual creation details

## Project Structure

```
your-project/
├── claude-skills-setup/
│   ├── setup-skillz.sh
│   ├── skills-config.json
│   ├── skills/
│   │   ├── skill-creator/      # Helper skill for creating new skills
│   │   └── [your custom skills]
│   └── README.md (this file)
├── .vscode/
│   └── mcp.json (created by script)
└── [your project files...]
```

## How It Works

1. **Find Project Root**: Searches for `.git` directory or uses parent of script directory
2. **Create Skills Directory**: Creates `~/.skillz/` if it doesn't exist
3. **Download GitHub Skills**: Clones repositories and copies specified skills
4. **Copy Custom Skills**: Copies all skills from `skills/` directory (including skill-creator)
5. **Configure MCP**: Uses VS Code CLI (`code --add-mcp`) to add Skillz server
   - Automatically merges with existing MCP servers
   - Falls back to manual file creation if CLI is unavailable

## Team Workflow

### For the Team Lead

1. Configure `skills-config.json` with required GitHub skills
2. Create custom skills:
   - Run the setup first to install skill-creator
   - Ask Copilot: "Use skill-creator to create a skill for [use case]"
   - Save generated skills to `skills/` directory
3. Commit to repository
4. Share with team

### For Team Members

1. Clone/pull the project repository
2. Run `cd claude-skills-setup && ./setup-skillz.sh`
3. Restart VS Code
4. Start using Claude skills!

### Updating Skills

When skills are updated:
1. Pull latest changes: `git pull`
2. Re-run setup: `cd claude-skills-setup && ./setup-skillz.sh`
3. Restart VS Code

## Troubleshooting

- **Skills not appearing**: Restart VS Code after running setup
- **uvx not found**: Install uv from https://github.com/astral-sh/uv
- **Permission errors**: Check write access to `~/.skillz`
- **Script won't run on Windows**: Use Git Bash or WSL, not PowerShell
- **VS Code CLI not found**: 
  - Make sure VS Code is installed and accessible via `code` command
  - On Windows: Ensure "Add to PATH" was selected during VS Code installation
  - Alternatively: The script will create `mcp.json` manually for new setups
- **MCP config issues**: 
  - If you have existing MCP servers and `code` CLI isn't available, manually add Skillz to your `.vscode/mcp.json`:
    ```json
    "skillz": {
      "command": "uvx",
      "args": ["skillz@latest"]
    }
    ```
- **GitHub download fails**: 
  - Verify Git is installed
  - Check repository and branch names
  - Ensure skill paths are correct (case-sensitive)
- **Custom skills not copied**: Ensure each skill has a `SKILL.md` file with proper frontmatter

## Advanced

### Manual MCP Configuration

The setup script uses VS Code CLI to configure MCP automatically. If you need to do it manually:

**Using VS Code CLI:**
```bash
code --add-mcp "{\"name\":\"skillz\",\"command\":\"uvx\",\"args\":[\"skillz@latest\"]}"
```

**Or create `.vscode/mcp.json` manually:**
```json
{
  "servers": {
    "skillz": {
      "command": "uvx",
      "args": ["skillz@latest"]
    }
  }
}
```

### Skill Priority

If a skill exists in both GitHub and custom directories with the same name:
- Custom skills are copied **after** GitHub skills
- Custom skills will override GitHub skills

This allows you to customize or extend GitHub skills for your team's specific needs.

## References

- [Skillz MCP Server](https://github.com/intellectronica/skillz)
- [Anthropic Skills Repository](https://github.com/anthropics/skills)

