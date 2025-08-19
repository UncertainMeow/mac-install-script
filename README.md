# macOS Configuration Management System

A comprehensive solution for auditing, managing, and restoring macOS configurations across multiple machines. This system provides automated discovery of your current Mac setup and intelligent restoration on fresh installations.

## Features

### 🔍 **Complete System Discovery**
- **Homebrew packages**: Formulae, casks, taps, and services
- **Mac App Store applications**: Full inventory with app IDs
- **Direct download applications**: Popular apps not available via package managers
- **System configuration**: Git settings, dotfiles, development tools
- **File locations**: Cloud storage sync status and backup recommendations

### 🚀 **Intelligent Installation**
- **Idempotent operations**: Safe to run multiple times
- **Smart detection**: Skips already installed applications
- **Direct download support**: Automated installers for Tailscale, Discord, Notion, Figma, and more
- **Dry-run testing**: Preview changes before applying
- **Comprehensive logging**: Detailed installation records

### 🛡️ **Security First**
- **Two-file system**: Separates current state (local) from desired state (version controlled)
- **Strict data classification**: Personal information never leaves your machine
- **Bulletproof .gitignore**: Automatic protection against committing sensitive data

## Quick Start

### 1. Audit Your Current Mac
```bash
./audit.sh
```
Generates `mac-config-base.json` with your current system state.

### 2. Create Your Desired Configuration
```bash
cp mac-config-base.json mac-config-desired.json
# Edit mac-config-desired.json to customize what you want on a fresh Mac
```

### 3. Review File Locations (Optional)
```bash
./file-audit.sh
```
Analyzes your file storage and cloud sync status for backup planning.

### 4. Test Installation
```bash
./install.sh --dry-run
```
Preview what would be installed without making changes.

### 5. Deploy to Fresh Mac
```bash
./install.sh
```
Automatically installs and configures everything from your desired state.

## File Structure

```
├── audit.sh                    # Discovers current Mac state
├── install.sh                  # Installs from desired configuration
├── file-audit.sh              # Analyzes file locations and sync status
├── lib/
│   └── direct-downloads.sh     # Handlers for direct download apps
├── mac-config-desired.json     # Your customized desired state (safe to commit)
├── mac-config-base.json        # Current system state (local only)
├── file-locations.json         # File analysis results (local only)
└── CLAUDE.md                   # Comprehensive developer documentation
```

## Supported Applications

### Package Managers
- **Homebrew**: Full support for formulae, casks, taps, and services
- **Mac App Store**: Via `mas` CLI tool

### Direct Downloads
Automated installers for popular applications including:
- Tailscale, Raycast, Discord, Notion, Figma, Cursor, Arc, Linear, Postman
- Fallback guidance for unsupported applications

## Security & Privacy

This system is designed with privacy as a priority:

- **Personal data stays local**: Only curated application lists are version controlled
- **No sensitive information**: File paths, system details, and personal configurations remain on your machine
- **Transparent operation**: All actions are logged and can be previewed with dry-run mode

## Requirements

- macOS (tested on macOS 15.6+)
- Bash shell
- Internet connection for downloads
- Optional: GitHub CLI for repository management

## Documentation

- **User Guide**: This README
- **Developer Documentation**: See `CLAUDE.md` for comprehensive technical details
- **Security Guidelines**: Built-in protections detailed in `CLAUDE.md`

## Use Cases

- **Clean Mac setup**: Restore your development environment on a fresh machine
- **Multiple Macs**: Maintain consistent configurations across devices
- **System migration**: Transfer your setup when upgrading hardware
- **Backup strategy**: Maintain an inventory of your essential applications
- **Team standardization**: Share curated configurations (applications only)

## Contributing

This is a personal configuration management tool. While the scripts are open source, the configuration files are specific to individual setups.

## License

MIT License - Feel free to adapt for your own configuration management needs.

---

**Note**: This system manages application installation and basic configuration. It does not handle personal data migration, detailed application settings, or system preferences. Always review generated configurations before committing to version control.