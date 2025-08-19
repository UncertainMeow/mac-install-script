#!/bin/bash

set -e

# macOS System Audit Script
# Discovers current Mac state and outputs to mac-config.json

OUTPUT_FILE="mac-config-base.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "🔍 Starting macOS system audit..."
echo "📝 Output will be saved to: $OUTPUT_FILE"

# Initialize JSON structure
cat > "$OUTPUT_FILE" << 'EOF'
{
  "metadata": {
    "generated_at": "",
    "hostname": "",
    "os_version": "",
    "hardware": ""
  },
  "homebrew": {
    "formulae": [],
    "casks": [],
    "taps": [],
    "services": []
  },
  "mac_app_store": [],
  "applications": [],
  "direct_downloads": [],
  "system_preferences": {},
  "dotfiles": [],
  "ssh_config": {},
  "git_config": {},
  "mounted_drives": [],
  "network_locations": [],
  "development_tools": {}
}
EOF

# Function to safely add to JSON array
add_to_json_array() {
    local file="$1"
    local path="$2"
    local value="$3"
    
    # Use jq to safely add to array
    jq "$path += [\"$value\"]" "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
}

# Function to safely set JSON value
set_json_value() {
    local file="$1"
    local path="$2"
    local value="$3"
    
    jq "$path = \"$value\"" "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
}

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "❌ jq is required but not installed. Installing via Homebrew..."
    if command -v brew &> /dev/null; then
        brew install jq
    else
        echo "❌ Homebrew not found. Please install jq manually: brew install jq"
        exit 1
    fi
fi

echo "📊 Collecting system metadata..."

# System metadata
HOSTNAME=$(hostname)
OS_VERSION=$(sw_vers -productVersion)
HARDWARE=$(system_profiler SPHardwareDataType | grep "Model Name" | awk -F': ' '{print $2}' | xargs)

set_json_value "$OUTPUT_FILE" ".metadata.generated_at" "$TIMESTAMP"
set_json_value "$OUTPUT_FILE" ".metadata.hostname" "$HOSTNAME"
set_json_value "$OUTPUT_FILE" ".metadata.os_version" "$OS_VERSION"
set_json_value "$OUTPUT_FILE" ".metadata.hardware" "$HARDWARE"

echo "🍺 Discovering Homebrew packages..."

# Homebrew discovery
if command -v brew &> /dev/null; then
    echo "  📦 Finding formulae..."
    brew list --formula 2>/dev/null | while read -r formula; do
        add_to_json_array "$OUTPUT_FILE" ".homebrew.formulae" "$formula"
    done
    
    echo "  📱 Finding casks..."
    brew list --cask 2>/dev/null | while read -r cask; do
        add_to_json_array "$OUTPUT_FILE" ".homebrew.casks" "$cask"
    done
    
    echo "  🚰 Finding taps..."
    brew tap 2>/dev/null | while read -r tap; do
        add_to_json_array "$OUTPUT_FILE" ".homebrew.taps" "$tap"
    done
    
    echo "  ⚙️  Finding services..."
    brew services list 2>/dev/null | tail -n +2 | awk '{print $1}' | while read -r service; do
        add_to_json_array "$OUTPUT_FILE" ".homebrew.services" "$service"
    done
else
    echo "  ❌ Homebrew not found"
fi

echo "🏪 Discovering Mac App Store applications..."

# Mac App Store apps
if command -v mas &> /dev/null; then
    mas list 2>/dev/null | while IFS= read -r line; do
        app_id=$(echo "$line" | awk '{print $1}')
        app_name=$(echo "$line" | cut -d' ' -f2-)
        app_entry="{\"id\": \"$app_id\", \"name\": \"$app_name\"}"
        jq ".mac_app_store += [$app_entry]" "$OUTPUT_FILE" > "${OUTPUT_FILE}.tmp" && mv "${OUTPUT_FILE}.tmp" "$OUTPUT_FILE"
    done
else
    echo "  ❌ mas (Mac App Store CLI) not found. Install with: brew install mas"
fi

echo "💾 Discovering installed applications..."

# Applications in /Applications
find /Applications -maxdepth 1 -name "*.app" -type d 2>/dev/null | while read -r app; do
    app_name=$(basename "$app" .app)
    add_to_json_array "$OUTPUT_FILE" ".applications" "$app_name"
done

echo "📥 Discovering direct download applications..."

# Applications that are typically direct downloads (not in Homebrew/MAS)
DIRECT_DOWNLOAD_APPS=(
    "Tailscale"
    "UGREEN NAS"
    "Raycast"
    "CleanMyMac"
    "Parallels Desktop"
    "VMware Fusion"
    "Discord"
    "Slack"
    "Teams"
    "Notion"
    "Linear"
    "Arc"
    "Chrome"
    "Firefox"
    "Copilot"
    "Cursor"
    "Figma"
    "Sketch"
    "Adobe"
    "Photoshop"
    "Illustrator"
    "InDesign"
    "Premiere"
    "After Effects"
    "Lightroom"
    "Acrobat"
    "Microsoft"
    "Logitech"
    "Steam"
    "Epic Games"
    "Unity"
    "Xcode"
    "Android Studio"
    "IntelliJ"
    "PyCharm"
    "WebStorm"
    "DataGrip"
    "GoLand"
    "RubyMine"
    "PhpStorm"
    "CLion"
    "AppCode"
    "Rider"
    "Postman"
    "Insomnia"
    "TablePlus"
    "Sequel Pro"
    "MongoDB Compass"
    "Docker Desktop"
    "VirtualBox"
    "UTM"
    "Proxyman"
    "Charles"
    "Wireshark"
    "Network Radar"
    "SSH Files"
    "Termius"
    "Royal TSX"
    "Remote Desktop"
    "VNC Viewer"
    "TeamViewer"
    "AnyDesk"
    "Soulver"
    "Calculator"
    "Kaleidoscope"
    "Beyond Compare"
    "Finder"
    "Path Finder"
    "Commander One"
    "ForkLift"
    "Transmit"
    "Cyberduck"
    "FileZilla"
    "CloudMounter"
    "Mountain Duck"
)

# Check which direct download apps are installed
for app_pattern in "${DIRECT_DOWNLOAD_APPS[@]}"; do
    # Check if any application name contains this pattern
    if find /Applications -maxdepth 1 -name "*${app_pattern}*" -type d 2>/dev/null | grep -q .; then
        actual_app=$(find /Applications -maxdepth 1 -name "*${app_pattern}*" -type d 2>/dev/null | head -1)
        app_name=$(basename "$actual_app" .app)
        
        # Get app version if possible
        version=""
        info_plist="$actual_app/Contents/Info.plist"
        if [[ -f "$info_plist" ]]; then
            version=$(plutil -p "$info_plist" 2>/dev/null | grep CFBundleShortVersionString | awk -F'"' '{print $4}' || echo "")
        fi
        
        # Add to direct downloads with metadata
        app_entry="{\"name\": \"$app_name\", \"version\": \"$version\", \"path\": \"$actual_app\"}"
        jq ".direct_downloads += [$app_entry]" "$OUTPUT_FILE" > "${OUTPUT_FILE}.tmp" && mv "${OUTPUT_FILE}.tmp" "$OUTPUT_FILE"
        
        echo "  📥 Found: $app_name${version:+ v$version}"
    fi
done

echo "🔧 Discovering dotfiles..."

# Common dotfiles
for dotfile in .bashrc .bash_profile .zshrc .zsh_profile .vimrc .gitconfig .gitignore_global .ssh/config .tmux.conf .profile; do
    if [[ -f "$HOME/$dotfile" ]]; then
        add_to_json_array "$OUTPUT_FILE" ".dotfiles" "$dotfile"
    fi
done

echo "🔑 Checking SSH configuration..."

# SSH config
if [[ -f "$HOME/.ssh/config" ]]; then
    set_json_value "$OUTPUT_FILE" ".ssh_config.config_exists" "true"
    ssh_hosts=$(grep -E "^Host " "$HOME/.ssh/config" 2>/dev/null | awk '{print $2}' | tr '\n' ',' | sed 's/,$//')
    set_json_value "$OUTPUT_FILE" ".ssh_config.hosts" "$ssh_hosts"
else
    set_json_value "$OUTPUT_FILE" ".ssh_config.config_exists" "false"
fi

# SSH keys
ssh_keys=$(find "$HOME/.ssh" -name "*.pub" 2>/dev/null | wc -l | xargs)
set_json_value "$OUTPUT_FILE" ".ssh_config.public_keys_count" "$ssh_keys"

echo "🌐 Checking Git configuration..."

# Git config
if command -v git &> /dev/null; then
    git_name=$(git config --global user.name 2>/dev/null || echo "")
    git_email=$(git config --global user.email 2>/dev/null || echo "")
    set_json_value "$OUTPUT_FILE" ".git_config.user_name" "$git_name"
    set_json_value "$OUTPUT_FILE" ".git_config.user_email" "$git_email"
fi

echo "💿 Discovering mounted drives..."

# Mounted drives
ls /Volumes 2>/dev/null | while read -r volume; do
    add_to_json_array "$OUTPUT_FILE" ".mounted_drives" "$volume"
done

echo "🌍 Discovering network locations..."

# Network locations
networksetup -listlocations 2>/dev/null | while read -r location; do
    add_to_json_array "$OUTPUT_FILE" ".network_locations" "$location"
done

echo "👨‍💻 Checking development tools..."

# Development tools
dev_tools_json="{}"

# Node.js
if command -v node &> /dev/null; then
    node_version=$(node --version 2>/dev/null)
    dev_tools_json=$(echo "$dev_tools_json" | jq ".node_version = \"$node_version\"")
fi

# Python
if command -v python3 &> /dev/null; then
    python_version=$(python3 --version 2>/dev/null | awk '{print $2}')
    dev_tools_json=$(echo "$dev_tools_json" | jq ".python_version = \"$python_version\"")
fi

# Ruby
if command -v ruby &> /dev/null; then
    ruby_version=$(ruby --version 2>/dev/null | awk '{print $2}')
    dev_tools_json=$(echo "$dev_tools_json" | jq ".ruby_version = \"$ruby_version\"")
fi

# Docker
if command -v docker &> /dev/null; then
    docker_version=$(docker --version 2>/dev/null | awk '{print $3}' | sed 's/,//')
    dev_tools_json=$(echo "$dev_tools_json" | jq ".docker_version = \"$docker_version\"")
fi

# Update the main JSON with development tools
jq ".development_tools = $dev_tools_json" "$OUTPUT_FILE" > "${OUTPUT_FILE}.tmp" && mv "${OUTPUT_FILE}.tmp" "$OUTPUT_FILE"

echo "✅ Audit complete!"
echo "📄 Base configuration saved to: $OUTPUT_FILE"
echo ""
echo "Next steps:"
echo "1. Copy $OUTPUT_FILE to mac-config-desired.json"
echo "2. Edit mac-config-desired.json to customize your desired Mac configuration"
echo "3. Remove any applications or configurations you don't want from the desired file"
echo "4. Commit ONLY mac-config-desired.json to your repository (base file tracks current state)"
echo "5. Use install.sh on a fresh Mac to restore this configuration"