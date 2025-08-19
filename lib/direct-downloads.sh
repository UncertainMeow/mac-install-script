#!/bin/bash

# Direct Download Handlers Library
# Functions to install applications that require direct downloads

# Function to download and install .dmg files
install_dmg() {
    local app_name="$1"
    local download_url="$2"
    local app_bundle_name="$3"  # The .app name inside the DMG
    local temp_dir="/tmp/mac-install-$$"
    
    log_info "Installing $app_name from DMG..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would download: $download_url"
        log_info "[DRY-RUN] Would install: $app_bundle_name to /Applications"
        return 0
    fi
    
    # Create temp directory
    mkdir -p "$temp_dir"
    
    # Download DMG
    local dmg_file="$temp_dir/$app_name.dmg"
    log_info "Downloading $app_name..."
    curl -L -o "$dmg_file" "$download_url"
    
    # Mount DMG
    log_info "Mounting DMG..."
    local mount_point=$(hdiutil attach "$dmg_file" | tail -1 | awk '{print $3}')
    
    # Copy app to Applications
    if [[ -d "$mount_point/$app_bundle_name" ]]; then
        log_info "Installing $app_bundle_name to /Applications..."
        cp -R "$mount_point/$app_bundle_name" /Applications/
        log_success "$app_name installed successfully"
    else
        log_error "Could not find $app_bundle_name in DMG"
        return 1
    fi
    
    # Cleanup
    hdiutil detach "$mount_point" >/dev/null 2>&1
    rm -rf "$temp_dir"
}

# Function to download and install .pkg files
install_pkg() {
    local app_name="$1"
    local download_url="$2"
    local temp_dir="/tmp/mac-install-$$"
    
    log_info "Installing $app_name from PKG..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would download: $download_url"
        log_info "[DRY-RUN] Would run installer for: $app_name"
        return 0
    fi
    
    # Create temp directory
    mkdir -p "$temp_dir"
    
    # Download PKG
    local pkg_file="$temp_dir/$app_name.pkg"
    log_info "Downloading $app_name..."
    curl -L -o "$pkg_file" "$download_url"
    
    # Install PKG
    log_info "Installing $app_name..."
    sudo installer -pkg "$pkg_file" -target /
    
    if [[ $? -eq 0 ]]; then
        log_success "$app_name installed successfully"
    else
        log_error "Failed to install $app_name"
        return 1
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
}

# Function to install from ZIP files
install_zip() {
    local app_name="$1"
    local download_url="$2"
    local app_bundle_name="$3"  # The .app name inside the ZIP
    local temp_dir="/tmp/mac-install-$$"
    
    log_info "Installing $app_name from ZIP..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would download: $download_url"
        log_info "[DRY-RUN] Would install: $app_bundle_name to /Applications"
        return 0
    fi
    
    # Create temp directory
    mkdir -p "$temp_dir"
    
    # Download ZIP
    local zip_file="$temp_dir/$app_name.zip"
    log_info "Downloading $app_name..."
    curl -L -o "$zip_file" "$download_url"
    
    # Extract ZIP
    log_info "Extracting $app_name..."
    unzip -q "$zip_file" -d "$temp_dir"
    
    # Find and copy app to Applications
    local app_path=$(find "$temp_dir" -name "$app_bundle_name" -type d | head -1)
    if [[ -n "$app_path" ]]; then
        log_info "Installing $app_bundle_name to /Applications..."
        cp -R "$app_path" /Applications/
        log_success "$app_name installed successfully"
    else
        log_error "Could not find $app_bundle_name in ZIP"
        return 1
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
}

# Specific installer functions for known applications

install_tailscale() {
    local latest_url="https://pkgs.tailscale.com/stable/Tailscale-latest.dmg"
    install_dmg "Tailscale" "$latest_url" "Tailscale.app"
}

install_ugreen_nas() {
    # Note: This URL may need to be updated - UGREEN changes their download links
    local download_url="https://www.ugreen.com/pages/download"
    log_warning "UGREEN NAS requires manual download from: $download_url"
    log_warning "Please download and install manually, then update your base config"
    return 1
}

install_raycast() {
    local latest_url="https://releases.raycast.com/releases/latest/download"
    install_dmg "Raycast" "$latest_url" "Raycast.app"
}

install_discord() {
    local download_url="https://discord.com/api/downloads/distributions/app/installers/latest?channel=stable&platform=osx&arch=x64"
    install_dmg "Discord" "$download_url" "Discord.app"
}

install_notion() {
    local download_url="https://www.notion.so/desktop/mac/download"
    install_dmg "Notion" "$download_url" "Notion.app"
}

install_figma() {
    local download_url="https://desktop.figma.com/mac/Figma.zip"
    install_zip "Figma" "$download_url" "Figma.app"
}

install_cursor() {
    local download_url="https://downloader.cursor.sh/darwin/arm64"
    install_zip "Cursor" "$download_url" "Cursor.app"
}

install_arc() {
    local download_url="https://releases.arc.net/release/Arc-latest.dmg"
    install_dmg "Arc" "$download_url" "Arc.app"
}

install_linear() {
    local download_url="https://desktop.linear.app/mac/dmg"
    install_dmg "Linear" "$download_url" "Linear.app"
}

install_postman() {
    local download_url="https://dl.pstmn.io/download/latest/osx_64"
    install_zip "Postman" "$download_url" "Postman.app"
}

# Main function to install a direct download app
install_direct_download_app() {
    local app_name="$1"
    
    case "$app_name" in
        "Tailscale")
            install_tailscale
            ;;
        "UGREEN NAS")
            install_ugreen_nas
            ;;
        "Raycast")
            install_raycast
            ;;
        "Discord")
            install_discord
            ;;
        "Notion")
            install_notion
            ;;
        "Figma")
            install_figma
            ;;
        "Cursor")
            install_cursor
            ;;
        "Arc")
            install_arc
            ;;
        "Linear")
            install_linear
            ;;
        "Postman")
            install_postman
            ;;
        *)
            log_warning "No installer available for: $app_name"
            log_warning "Please download and install manually from the vendor's website"
            return 1
            ;;
    esac
}

# Function to check if direct download app is already installed
is_direct_download_app_installed() {
    local app_name="$1"
    
    # Check for exact match or partial match
    if find /Applications -maxdepth 1 -name "*${app_name}*" -type d 2>/dev/null | grep -q .; then
        return 0  # Found
    else
        return 1  # Not found
    fi
}