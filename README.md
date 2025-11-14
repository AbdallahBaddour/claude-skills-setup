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
3. Copy local skills from the `skills/` directory
4. Create/update `.vscode/mcp.json` in your project root

## Prerequisites

- [uv](https://github.com/astral-sh/uv) installed (for running `uvx`)
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

### 2. Local Skills

Add your custom skills to the `skills/` directory:

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

See `skills/skill-creator` for detailed instructions on creating local skills.

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
- Copy any new/updated local skills
- Preserve your MCP configuration

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

### Local Skills (`skills/` directory)

- Each skill must be in its own subdirectory
- Each skill must have a `SKILL.md` file
- Skills can include additional files and scripts
- See `skills/skill-creator` for more details

## Project Structure

```
your-project/
├── claude-skills-setup/
│   ├── setup-skillz.sh
│   ├── skills-config.json
│   ├── skills/
│   │   └── [your local skills]
│   └── README.md (this file)
├── .vscode/
│   └── mcp.json (created by script)
└── [your project files...]
```

## How It Works

1. **Find Project Root**: Searches for `.git` directory or uses parent of script directory
2. **Create Skills Directory**: Creates `~/.skillz/` if it doesn't exist
3. **Download GitHub Skills**: Clones repositories and copies specified skills
4. **Copy Local Skills**: Copies all skills from `skills/` directory
5. **Configure MCP**: Creates or merges `.vscode/mcp.json` with Skillz configuration

## Team Workflow

### For the Team Lead

1. Configure `skills-config.json` with required GitHub skills
2. Add any custom skills to `skills/` directory
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
- **MCP config issues**: Check that `.vscode/mcp.json` exists in project root
- **GitHub download fails**: 
  - Verify Git is installed
  - Check repository and branch names
  - Ensure skill paths are correct (case-sensitive)
- **Local skills not copied**: Ensure each skill has a `SKILL.md` file

## Advanced

### Manual MCP Configuration

If you need to manually configure MCP, create `.vscode/mcp.json`:

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

If a skill exists in both GitHub and local directories with the same name:
- Local skills are copied **after** GitHub skills
- Local skills will override GitHub skills

## References

- [Skillz MCP Server](https://github.com/intellectronica/skillz)
- [Anthropic Skills Repository](https://github.com/anthropics/skills)

