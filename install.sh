#!/bin/bash

set -e

# macOS Installation Script
# Reads mac-config.json and installs/configures a fresh Mac accordingly

CONFIG_FILE="mac-config-desired.json"
BASE_CONFIG_FILE="mac-config-base.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
LOG_FILE="install-log-$TIMESTAMP.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

log_info() {
    log "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    log "${GREEN}✅ $1${NC}"
}

log_warning() {
    log "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    log "${RED}❌ $1${NC}"
}

# Function to check if running with dry-run
DRY_RUN=false
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
    log_info "Running in DRY-RUN mode - no changes will be made"
fi

# Function to execute command (respects dry-run)
execute() {
    local cmd="$1"
    local description="$2"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would execute: $cmd"
        if [[ -n "$description" ]]; then
            log_info "[DRY-RUN] Description: $description"
        fi
        return 0
    else
        log_info "Executing: $description"
        eval "$cmd"
        return $?
    fi
}

log_info "🚀 Starting macOS installation from $CONFIG_FILE"
log_info "📝 Detailed log will be saved to: $LOG_FILE"

# Check if config file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    log_error "Desired configuration file $CONFIG_FILE not found!"
    if [[ -f "$BASE_CONFIG_FILE" ]]; then
        log_info "Found base config. Creating desired config from base..."
        cp "$BASE_CONFIG_FILE" "$CONFIG_FILE"
        log_success "Created $CONFIG_FILE from $BASE_CONFIG_FILE"
        log_info "Edit $CONFIG_FILE to customize your desired configuration, then run this script again"
        exit 0
    else
        log_error "No configuration files found!"
        log_error "Run ./audit.sh first to generate a base configuration file"
        exit 1
    fi
fi

# Source the direct downloads library
if [[ -f "lib/direct-downloads.sh" ]]; then
    source lib/direct-downloads.sh
else
    log_warning "Direct downloads library not found. Some applications may not install."
fi

# Check if jq is available
if ! command -v jq &> /dev/null; then
    log_warning "jq is required but not installed. Installing via Homebrew..."
    if ! command -v brew &> /dev/null; then
        log_info "Installing Homebrew first..."
        execute '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"' "Install Homebrew"
        
        # Add Homebrew to PATH for current session
        if [[ -f "/opt/homebrew/bin/brew" ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ -f "/usr/local/bin/brew" ]]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    fi
    execute "brew install jq" "Install jq for JSON processing"
fi

log_info "📋 Reading configuration from $CONFIG_FILE"

# Read and validate JSON
if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
    log_error "Invalid JSON in $CONFIG_FILE"
    exit 1
fi

# Extract configuration sections
FORMULAE=$(jq -r '.homebrew.formulae[]?' "$CONFIG_FILE" 2>/dev/null || echo "")
CASKS=$(jq -r '.homebrew.casks[]?' "$CONFIG_FILE" 2>/dev/null || echo "")
TAPS=$(jq -r '.homebrew.taps[]?' "$CONFIG_FILE" 2>/dev/null || echo "")
MAS_APPS=$(jq -r '.mac_app_store[]?' "$CONFIG_FILE" 2>/dev/null || echo "")
GIT_NAME=$(jq -r '.git_config.user_name // ""' "$CONFIG_FILE")
GIT_EMAIL=$(jq -r '.git_config.user_email // ""' "$CONFIG_FILE")

log_info "🍺 Setting up Homebrew..."

# Install Homebrew if not present
if ! command -v brew &> /dev/null; then
    log_info "Installing Homebrew..."
    execute '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"' "Install Homebrew"
    
    # Add Homebrew to PATH
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    elif [[ -f "/usr/local/bin/brew" ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
        echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile
    fi
else
    log_success "Homebrew already installed"
fi

# Update Homebrew
execute "brew update" "Update Homebrew"

log_info "🚰 Installing Homebrew taps..."

# Install taps
if [[ -n "$TAPS" ]]; then
    while IFS= read -r tap; do
        if [[ -n "$tap" ]]; then
            if brew tap | grep -q "^$tap$"; then
                log_success "Tap $tap already installed"
            else
                execute "brew tap '$tap'" "Install tap: $tap"
            fi
        fi
    done <<< "$TAPS"
else
    log_info "No taps to install"
fi

log_info "📦 Installing Homebrew formulae..."

# Install formulae
if [[ -n "$FORMULAE" ]]; then
    formulae_to_install=()
    while IFS= read -r formula; do
        if [[ -n "$formula" ]]; then
            if brew list --formula | grep -q "^$formula$"; then
                log_success "Formula $formula already installed"
            else
                formulae_to_install+=("$formula")
            fi
        fi
    done <<< "$FORMULAE"
    
    if [[ ${#formulae_to_install[@]} -gt 0 ]]; then
        execute "brew install ${formulae_to_install[*]}" "Install formulae: ${formulae_to_install[*]}"
    else
        log_success "All formulae already installed"
    fi
else
    log_info "No formulae to install"
fi

log_info "📱 Installing Homebrew casks..."

# Install casks
if [[ -n "$CASKS" ]]; then
    casks_to_install=()
    while IFS= read -r cask; do
        if [[ -n "$cask" ]]; then
            if brew list --cask | grep -q "^$cask$"; then
                log_success "Cask $cask already installed"
            else
                casks_to_install+=("$cask")
            fi
        fi
    done <<< "$CASKS"
    
    if [[ ${#casks_to_install[@]} -gt 0 ]]; then
        execute "brew install --cask ${casks_to_install[*]}" "Install casks: ${casks_to_install[*]}"
    else
        log_success "All casks already installed"
    fi
else
    log_info "No casks to install"
fi

log_info "🏪 Installing Mac App Store applications..."

# Install mas if not present and we have MAS apps to install
if [[ -n "$MAS_APPS" ]]; then
    if ! command -v mas &> /dev/null; then
        log_info "Installing mas (Mac App Store CLI)..."
        execute "brew install mas" "Install mas CLI"
    fi
    
    # Check if signed into Mac App Store
    if ! mas account &> /dev/null; then
        log_warning "Not signed into Mac App Store"
        log_warning "Please sign in to the Mac App Store and run this script again"
        log_warning "Skipping Mac App Store installations for now"
    else
        while IFS= read -r app_line; do
            if [[ -n "$app_line" ]]; then
                app_id=$(echo "$app_line" | jq -r '.id // empty')
                app_name=$(echo "$app_line" | jq -r '.name // empty')
                
                if [[ -n "$app_id" ]]; then
                    if mas list | grep -q "^$app_id"; then
                        log_success "App $app_name ($app_id) already installed"
                    else
                        execute "mas install '$app_id'" "Install: $app_name"
                    fi
                fi
            fi
        done <<< "$(jq -c '.mac_app_store[]?' "$CONFIG_FILE" 2>/dev/null || echo "")"
    fi
else
    log_info "No Mac App Store apps to install"
fi

log_info "📥 Installing direct download applications..."

# Install direct download apps
DIRECT_DOWNLOADS=$(jq -c '.direct_downloads[]?' "$CONFIG_FILE" 2>/dev/null || echo "")
if [[ -n "$DIRECT_DOWNLOADS" ]]; then
    while IFS= read -r app_line; do
        if [[ -n "$app_line" ]]; then
            app_name=$(echo "$app_line" | jq -r '.name // empty')
            
            if [[ -n "$app_name" ]]; then
                # Check if already installed
                if is_direct_download_app_installed "$app_name"; then
                    log_success "Direct download app $app_name already installed"
                else
                    # Try to install
                    if install_direct_download_app "$app_name"; then
                        log_success "Successfully installed $app_name"
                    else
                        log_warning "Could not automatically install $app_name"
                        log_info "You may need to install this manually"
                    fi
                fi
            fi
        fi
    done <<< "$DIRECT_DOWNLOADS"
else
    log_info "No direct download apps to install"
fi

log_info "🌐 Configuring Git..."

# Configure Git
if [[ -n "$GIT_NAME" ]] && [[ "$GIT_NAME" != "null" ]]; then
    current_name=$(git config --global user.name 2>/dev/null || echo "")
    if [[ "$current_name" != "$GIT_NAME" ]]; then
        execute "git config --global user.name '$GIT_NAME'" "Set Git user name: $GIT_NAME"
    else
        log_success "Git user name already configured"
    fi
fi

if [[ -n "$GIT_EMAIL" ]] && [[ "$GIT_EMAIL" != "null" ]]; then
    current_email=$(git config --global user.email 2>/dev/null || echo "")
    if [[ "$current_email" != "$GIT_EMAIL" ]]; then
        execute "git config --global user.email '$GIT_EMAIL'" "Set Git user email: $GIT_EMAIL"
    else
        log_success "Git user email already configured"
    fi
fi

log_info "🔧 Post-installation tasks..."

# Clean up Homebrew
execute "brew cleanup" "Clean up Homebrew cache"

# Check for any issues
execute "brew doctor" "Run Homebrew diagnostics"

# Update base config to reflect what's now installed
log_info "📝 Updating base configuration..."

if [[ "$DRY_RUN" == false ]]; then
    if [[ -f "$BASE_CONFIG_FILE" ]]; then
        # Create a backup of the old base config
        cp "$BASE_CONFIG_FILE" "${BASE_CONFIG_FILE}.backup-$TIMESTAMP"
        log_info "Backed up previous base config to ${BASE_CONFIG_FILE}.backup-$TIMESTAMP"
    fi
    
    # Run a quick audit to update the base config
    if [[ -f "./audit.sh" ]]; then
        log_info "Running quick audit to update base configuration..."
        execute "./audit.sh >/dev/null 2>&1" "Update base configuration"
        log_success "Base configuration updated"
    else
        log_warning "Could not find audit.sh to update base configuration"
    fi
else
    log_info "[DRY-RUN] Would update base configuration after installation"
fi

log_success "🎉 Installation complete!"
log_info "📄 Detailed log saved to: $LOG_FILE"

echo ""
log_info "📋 Next Steps:"
log_info "1. Restart your terminal to ensure all PATH changes take effect"
log_info "2. Sign into your cloud storage services (iCloud, Google Drive, etc.)"
log_info "3. Configure your applications with personal settings"
log_info "4. Copy over any dotfiles or configuration files"
log_info "5. Set up SSH keys if needed"

echo ""
log_info "🔍 To verify installation:"
log_info "• Run: brew list"
log_info "• Run: mas list"
log_info "• Check: git config --global --list"
log_info "• Compare: diff mac-config-base.json mac-config-desired.json"

if [[ "$DRY_RUN" == true ]]; then
    echo ""
    log_info "🧪 This was a dry-run. To actually install, run: ./install.sh"
fi