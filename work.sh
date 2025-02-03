#!/bin/bash

# Configuration
BASE_URL="https://9607.play.gamezop.com"
HTML_FILE="input.html"
MAX_CONCURRENT=4                # Parallel downloads
RETRIES=3                       # Wget retry attempts
USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
LOG_FILE="download.log"
TMP_DIR="/tmp/asset_downloader"

# Initialize environment
mkdir -p "$TMP_DIR"
echo "=== Download Session $(date) ===" > "$LOG_FILE"

# Extract URLs with proper HTML parsing
url_list=$(
  grep -o -E '(href|src)="[^"]+"' "$HTML_FILE" | 
  awk -F '"' '{print $2}' |
  sort | uniq | 
  grep -vE '(data:|blob:|mailto:|javascript:)' 
)

# Generate download commands
generate_commands() {
  while read -r path; do
    # Build full URL
    full_url="${BASE_URL%/}/${path#/}"
    
    # Calculate local path
    url_path=$(python3 -c "from urllib.parse import urlparse; print(urlparse('$path').path)")
    local_path="${url_path#/}"
    [[ -z "$local_path" ]] && continue
    
    # Create output filename
    output_file="$local_path"
    directory=$(dirname "$output_file")
    filename=$(basename "$output_file")
    
    # Skip existing complete files
    if [[ -f "$output_file" ]]; then
      echo "Skipping existing file: $output_file" >> "$LOG_FILE"
      continue
    fi
    
    # Create wget command
    echo "mkdir -p '$directory'; wget --user-agent='$USER_AGENT' --tries=$RETRIES --no-check-certificate --quiet --show-progress -O '$output_file' '$full_url'"
  done <<< "$url_list"
}

# Main execution
echo "🔄 Found $(echo "$url_list" | wc -l) unique assets to download"
echo "🚀 Starting parallel downloads (max $MAX_CONCURRENT concurrent)..."
generate_commands | xargs -P $MAX_CONCURRENT -I {} bash -c "{} && echo '✅ Success: $full_url' >> $LOG_FILE || echo '❌ Failed: $full_url' >> $LOG_FILE"

# Cleanup and report
success_count=$(grep -c '✅ Success:' "$LOG_FILE")
fail_count=$(grep -c '❌ Failed:' "$LOG_FILE")
echo -e "\n📊 Download Summary:"
echo "✅ $success_count successful downloads"
echo "❌ $fail_count failed downloads"
echo "📋 Detailed log available at: $LOG_FILE"

# Optional: Clean temporary files
# rm -rf "$TMP_DIR"
