# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a complete macOS configuration management system that provides both audit and installation capabilities:

1. **Audit Phase**: Scripts to discover and inventory the current state of a Mac (installed apps, configurations, mounted drives, etc.)
2. **Configuration Phase**: User edits the generated inventory to define their desired state
3. **Installation Phase**: Scripts that read the desired state and configure a fresh Mac accordingly

## Workflow

1. Run `audit.sh` on current Mac to generate `mac-config-base.json` (current state)
2. Copy base config to `mac-config-desired.json` and edit to customize desired state
3. Commit ONLY the desired config to this repository (base config stays local)
4. On a new Mac, run `install.sh` which reads `mac-config-desired.json` and sets up the system
5. After installation, base config is automatically updated to reflect new system state

## Architecture

### Core Scripts
- `audit.sh` - Discovers current Mac state and outputs to `mac-config-base.json`
- `install.sh` - Main installation script that reads `mac-config-desired.json`
- `file-audit.sh` - Discovers file locations and sync status (separate sensitive output)
- `lib/direct-downloads.sh` - Handlers for applications requiring direct downloads

### Data Format - Two-File System
- `mac-config-base.json` - **CURRENT state** (auto-generated, not committed to Git)
- `mac-config-desired.json` - **DESIRED state** (manually edited, safe to commit)
- Structured sections for: Homebrew packages, Mac App Store apps, direct downloads, system preferences, dotfiles

### Direct Download Support
The system now handles applications that aren't available via Homebrew or Mac App Store:
- Tailscale, Raycast, Discord, Notion, Figma, Cursor, Arc, Linear, Postman
- Automatic detection during audit
- Smart installation with DMG/PKG/ZIP support
- Fallback to manual installation with guidance

### Discovery Categories
The audit script should capture:
- Homebrew formulae and casks
- Mac App Store applications
- System preferences and settings
- Dotfiles and configuration files
- SSH keys and Git configuration
- Mounted drives and network locations
- Browser bookmarks and extensions
- Development environment setup

## Key Tools and Commands

### Homebrew Discovery
- `brew list --formula` - List installed formulae
- `brew list --cask` - List installed casks
- `brew services list` - List running services

### Mac App Store Discovery
- `mas list` - List installed Mac App Store apps (requires `mas` CLI tool)

### System Information
- `system_profiler` - Hardware and software information
- `defaults read` - System preferences and app settings
- `pmset -g` - Power management settings
- `networksetup -listallnetworkservices` - Network configuration

### File Discovery
- Look in `~/.*` for dotfiles
- Check `~/.ssh/` for SSH configuration
- Scan `/Volumes/` for mounted drives

## Development Patterns

- Use JSON for the configuration format (easy to parse and edit)
- Implement both discovery and installation for each category
- Include dry-run mode for testing installation scripts
- Provide detailed logging during both audit and install phases
- Handle errors gracefully and provide rollback capabilities
- Support incremental updates (don't reinstall what's already installed)

## Security Best Practices

### CRITICAL: Data Classification
- `audit.sh` output (`mac-config-base.json`) - **NEVER COMMIT** (contains current system state)
- `mac-config-desired.json` - **SAFE** to commit (manually curated, no sensitive data)
- `file-audit.sh` output (`file-locations.json`) - **NEVER COMMIT** (contains file paths, personal info)
- Personal configurations - **NEVER COMMIT** (SSH keys, passwords, tokens)

### CRITICAL: .gitignore Rules
- **ALWAYS** review `.gitignore` before first commit
- **NEVER** commit `mac-config-base.json` (blocked by .gitignore)
- **NEVER** commit files ending in `-personal.json`, `-private.json`, `-secrets.json`
- **NEVER** commit `file-locations.json` or any file-audit outputs
- **VERIFY** no sensitive data in `mac-config-desired.json` before committing

### Safe Repository Contents
- ✅ Scripts (audit.sh, file-audit.sh, install.sh, lib/)
- ✅ Desired configuration (mac-config-desired.json after review)
- ✅ Documentation (README.md, CLAUDE.md)
- ✅ .gitignore file
- ❌ Base configuration (mac-config-base.json)
- ❌ Personal file locations
- ❌ SSH keys or certificates
- ❌ Environment files with secrets
- ❌ Personal data or file paths

### Pre-Commit Checklist
1. Run `git status` and review all files to be committed
2. Verify no file paths or personal data in committed files
3. Confirm `mac-config-base.json` and `file-locations.json` are NOT being committed
4. Double-check that `mac-config-desired.json` contains only app names, not personal data
5. Ensure only desired configuration is committed, never base configuration

## Testing

- Test audit script on current system
- Test install script in VM or on spare Mac
- Verify idempotency (running scripts multiple times should be safe)
- Test with various macOS versions and hardware configurations