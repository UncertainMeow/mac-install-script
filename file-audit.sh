#!/bin/bash

set -e

# macOS File Location Audit Script
# Discovers file sync status and locations - SENSITIVE DATA - DO NOT COMMIT!

OUTPUT_FILE="file-locations.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "🔍 Starting file location audit..."
echo "📝 Output will be saved to: $OUTPUT_FILE"
echo ""
echo "⚠️  WARNING: This script generates SENSITIVE DATA containing file paths"
echo "⚠️  NEVER commit $OUTPUT_FILE to version control!"
echo "⚠️  Review output carefully before sharing"
echo ""

# Security check - ensure we're not in a git repo or warn user
if git rev-parse --git-dir > /dev/null 2>&1; then
    echo "🚨 WARNING: You are in a Git repository!"
    echo "🚨 The output file $OUTPUT_FILE contains sensitive file paths"
    echo "🚨 Make sure this file is in .gitignore before proceeding"
    echo ""
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborting for security."
        exit 1
    fi
fi

# Initialize JSON structure
cat > "$OUTPUT_FILE" << 'EOF'
{
  "metadata": {
    "generated_at": "",
    "hostname": "",
    "warning": "SENSITIVE DATA - DO NOT COMMIT TO VERSION CONTROL"
  },
  "summary": {
    "total_files_scanned": 0,
    "icloud_synced_files": 0,
    "google_drive_files": 0,
    "dropbox_files": 0,
    "local_only_files": 0,
    "large_local_files": []
  },
  "directories": {
    "icloud_status": {},
    "google_drive_paths": [],
    "dropbox_paths": [],
    "local_only_important": []
  },
  "recommendations": []
}
EOF

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

# Function to safely set JSON value
set_json_value() {
    local file="$1"
    local path="$2"
    local value="$3"
    
    jq "$path = \"$value\"" "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
}

# Function to add to JSON array
add_to_json_array() {
    local file="$1"
    local path="$2"
    local value="$3"
    
    jq "$path += [\"$value\"]" "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
}

echo "📊 Collecting metadata..."

# Basic metadata
HOSTNAME=$(hostname)
set_json_value "$OUTPUT_FILE" ".metadata.generated_at" "$TIMESTAMP"
set_json_value "$OUTPUT_FILE" ".metadata.hostname" "$HOSTNAME"

echo "☁️  Checking iCloud sync status..."

# Check iCloud Drive status
ICLOUD_DRIVE_PATH="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
if [[ -d "$ICLOUD_DRIVE_PATH" ]]; then
    echo "  ✅ iCloud Drive detected"
    add_to_json_array "$OUTPUT_FILE" ".directories.google_drive_paths" "$ICLOUD_DRIVE_PATH"
    
    # Count iCloud files (limit to avoid performance issues)
    icloud_count=$(find "$ICLOUD_DRIVE_PATH" -type f 2>/dev/null | head -1000 | wc -l | xargs)
    set_json_value "$OUTPUT_FILE" ".summary.icloud_synced_files" "$icloud_count"
else
    echo "  ❌ iCloud Drive not found"
    set_json_value "$OUTPUT_FILE" ".summary.icloud_synced_files" "0"
fi

# Check Desktop and Documents sync to iCloud
for dir in "Desktop" "Documents"; do
    dir_path="$HOME/$dir"
    if [[ -L "$dir_path" ]]; then
        target=$(readlink "$dir_path")
        if [[ "$target" == *"Mobile Documents"* ]]; then
            echo "  ☁️  $dir is synced to iCloud"
            jq ".directories.icloud_status.\"$dir\" = \"synced\"" "$OUTPUT_FILE" > "${OUTPUT_FILE}.tmp" && mv "${OUTPUT_FILE}.tmp" "$OUTPUT_FILE"
        fi
    else
        echo "  💾 $dir is local only"
        jq ".directories.icloud_status.\"$dir\" = \"local\"" "$OUTPUT_FILE" > "${OUTPUT_FILE}.tmp" && mv "${OUTPUT_FILE}.tmp" "$OUTPUT_FILE"
    fi
done

echo "📁 Checking Google Drive..."

# Common Google Drive paths
GOOGLE_DRIVE_PATHS=(
    "$HOME/Google Drive"
    "$HOME/GoogleDrive"
    "/Volumes/GoogleDrive"
)

google_drive_found=false
for gd_path in "${GOOGLE_DRIVE_PATHS[@]}"; do
    if [[ -d "$gd_path" ]]; then
        echo "  ✅ Google Drive found: $gd_path"
        add_to_json_array "$OUTPUT_FILE" ".directories.google_drive_paths" "$gd_path"
        google_drive_found=true
        
        # Count Google Drive files (limit to avoid performance issues)
        gd_count=$(find "$gd_path" -type f 2>/dev/null | head -1000 | wc -l | xargs)
        set_json_value "$OUTPUT_FILE" ".summary.google_drive_files" "$gd_count"
    fi
done

if [[ "$google_drive_found" == false ]]; then
    echo "  ❌ Google Drive not found"
    set_json_value "$OUTPUT_FILE" ".summary.google_drive_files" "0"
fi

echo "📦 Checking Dropbox..."

# Common Dropbox paths
DROPBOX_PATHS=(
    "$HOME/Dropbox"
    "/Volumes/Dropbox"
)

dropbox_found=false
for db_path in "${DROPBOX_PATHS[@]}"; do
    if [[ -d "$db_path" ]]; then
        echo "  ✅ Dropbox found: $db_path"
        add_to_json_array "$OUTPUT_FILE" ".directories.dropbox_paths" "$db_path"
        dropbox_found=true
        
        # Count Dropbox files (limit to avoid performance issues)
        db_count=$(find "$db_path" -type f 2>/dev/null | head -1000 | wc -l | xargs)
        set_json_value "$OUTPUT_FILE" ".summary.dropbox_files" "$db_count"
    fi
done

if [[ "$dropbox_found" == false ]]; then
    echo "  ❌ Dropbox not found"
    set_json_value "$OUTPUT_FILE" ".summary.dropbox_files" "0"
fi

echo "💾 Scanning for local-only important directories..."

# Important directories that should potentially be backed up
IMPORTANT_DIRS=(
    "$HOME/Downloads"
    "$HOME/Pictures"
    "$HOME/Movies"
    "$HOME/Music"
    "$HOME/Development"
    "$HOME/Projects"
    "$HOME/Code"
    "$HOME/.ssh"
)

local_only_count=0
for dir in "${IMPORTANT_DIRS[@]}"; do
    if [[ -d "$dir" ]] && [[ ! -L "$dir" ]]; then
        # Check if it's not in a cloud sync folder
        is_cloud_synced=false
        
        # Check if it's in Google Drive
        for gd_path in "${GOOGLE_DRIVE_PATHS[@]}"; do
            if [[ -d "$gd_path" ]] && [[ "$dir" == "$gd_path"* ]]; then
                is_cloud_synced=true
                break
            fi
        done
        
        # Check if it's in Dropbox
        for db_path in "${DROPBOX_PATHS[@]}"; do
            if [[ -d "$db_path" ]] && [[ "$dir" == "$db_path"* ]]; then
                is_cloud_synced=true
                break
            fi
        done
        
        # Check if it's in iCloud
        if [[ "$dir" == *"Mobile Documents"* ]]; then
            is_cloud_synced=true
        fi
        
        if [[ "$is_cloud_synced" == false ]]; then
            echo "  📂 Local only: $dir"
            add_to_json_array "$OUTPUT_FILE" ".directories.local_only_important" "$(basename "$dir")"
            ((local_only_count++))
        fi
    fi
done

set_json_value "$OUTPUT_FILE" ".summary.local_only_files" "$local_only_count"

echo "🔍 Finding large local files that might need backup..."

# Find large files (>100MB) in specific directories only, for performance
SEARCH_DIRS=("$HOME/Downloads" "$HOME/Desktop" "$HOME/Documents" "$HOME/Movies" "$HOME/Pictures" "$HOME/Code")
large_files=()

for search_dir in "${SEARCH_DIRS[@]}"; do
    if [[ -d "$search_dir" ]]; then
        echo "  🔍 Scanning $search_dir..."
        while IFS= read -r -d '' file; do
            size=$(stat -f%z "$file" 2>/dev/null || echo 0)
            if [[ $size -gt 104857600 ]]; then # 100MB
                size_mb=$((size / 1048576))
                filename=$(basename "$file")
                dir_name=$(basename "$(dirname "$file")")
                # Don't include full paths for security - just filename and parent dir
                large_files+=("{\"name\": \"$filename\", \"directory\": \"$dir_name\", \"size_mb\": $size_mb}")
                echo "    📁 Found large file: $filename (${size_mb}MB)"
            fi
        done < <(find "$search_dir" -type f -size +100M -maxdepth 3 -print0 2>/dev/null | head -10)
    fi
done

# Add large files to JSON
for file_info in "${large_files[@]}"; do
    jq ".summary.large_local_files += [$file_info]" "$OUTPUT_FILE" > "${OUTPUT_FILE}.tmp" && mv "${OUTPUT_FILE}.tmp" "$OUTPUT_FILE"
done

echo "💡 Generating recommendations..."

# Generate recommendations based on findings
recommendations=()

if [[ $local_only_count -gt 0 ]]; then
    recommendations+=("Consider syncing important local directories to cloud storage")
fi

if [[ ${#large_files[@]} -gt 0 ]]; then
    recommendations+=("Review large local files - consider cloud storage or external backup")
fi

if [[ "$google_drive_found" == false ]] && [[ "$dropbox_found" == false ]] && [[ ! -d "$ICLOUD_DRIVE_PATH" ]]; then
    recommendations+=("No cloud storage detected - consider setting up iCloud, Google Drive, or Dropbox")
fi

for rec in "${recommendations[@]}"; do
    add_to_json_array "$OUTPUT_FILE" ".recommendations" "$rec"
done

echo ""
echo "✅ File audit complete!"
echo "📄 Results saved to: $OUTPUT_FILE"
echo ""
echo "🚨 SECURITY REMINDER:"
echo "🚨 $OUTPUT_FILE contains sensitive file paths and should NOT be committed to Git"
echo "🚨 Review the file before sharing or backing up"
echo ""
echo "📊 Summary:"
echo "   - iCloud files: $(jq -r '.summary.icloud_synced_files' "$OUTPUT_FILE")"
echo "   - Google Drive files: $(jq -r '.summary.google_drive_files' "$OUTPUT_FILE")"
echo "   - Dropbox files: $(jq -r '.summary.dropbox_files' "$OUTPUT_FILE")"
echo "   - Local-only important dirs: $local_only_count"
echo "   - Large local files: ${#large_files[@]}"