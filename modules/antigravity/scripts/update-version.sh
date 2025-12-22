#!/usr/bin/env bash
# Auto-update script for Google Antigravity
# This script wraps itself in a nix-shell with required dependencies

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Function to extract version using chromium in headless mode
get_latest_version_chromium() {
    log_info "Fetching latest version using Chromium headless..."
    
    # Find chromium or ungoogled-chromium - check both PATH and common locations
    local browser_cmd=""
    
    # Check PATH first
    for cmd in chromium ungoogled-chromium google-chrome-stable; do
        if command -v "$cmd" &>/dev/null; then
            browser_cmd="$cmd"
            break
        fi
    done
    
    # Check common locations if not found in PATH
    if [[ -z "$browser_cmd" ]]; then
        for path in /usr/bin/chromium /usr/bin/ungoogled-chromium /usr/bin/google-chrome-stable \
                    /run/current-system/sw/bin/chromium /run/current-system/sw/bin/ungoogled-chromium; do
            if [[ -x "$path" ]]; then
                browser_cmd="$path"
                break
            fi
        done
    fi
    
    if [[ -z "$browser_cmd" ]]; then
        log_warn "No supported browser found for headless scraping"
        return 1
    fi
    
    log_info "Using browser: $browser_cmd"
    
    # Create a temporary file for output
    local tmpfile
    tmpfile=$(mktemp)
    trap "rm -f $tmpfile" EXIT
    
    # Use Chromium to dump the page DOM after JavaScript execution
    timeout 30s "$browser_cmd" \
        --headless \
        --disable-gpu \
        --disable-software-rasterizer \
        --no-sandbox \
        --dump-dom \
        "https://antigravity.google/download/linux" 2>/dev/null > "$tmpfile" || true
    
    if [[ ! -s "$tmpfile" ]]; then
        log_warn "Browser dump failed or empty"
        return 1
    fi
    
    # Extract version from the dumped DOM
    local version
    version=$(grep -oP 'antigravity/stable/\K[0-9.]+-[0-9]+' "$tmpfile" | head -1)
    
    if [[ -n "$version" ]] && [[ "$version" =~ ^[0-9.]+-[0-9]+$ ]]; then
        echo "$version"
        return 0
    fi
    
    log_warn "Could not extract version from browser output"
    return 1
}

# Function to extract version from Debian Repository (Google's official repo)
# Also extracts the actual download URL if available
get_latest_version_deb() {
    log_info "Fetching latest version from Debian Repository..."
    
    local repo_base="https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/dists/antigravity-debian/main/binary-amd64"
    local version=""
    
    # Try fetching Packages.gz
    if curl -sL "$repo_base/Packages.gz" | gzip -d > /tmp/antigravity_packages 2>/dev/null; then
        log_info "Successfully fetched Packages.gz"
    # Fallback to plain Packages
    elif curl -sL "$repo_base/Packages" > /tmp/antigravity_packages 2>/dev/null; then
         log_info "Successfully fetched Packages"
    else
        log_warn "Failed to fetch Debian repository metadata"
        return 1
    fi
    
    # Parse version: Expecting "Version: 1.2.3-456"
    version=$(grep "Version: " /tmp/antigravity_packages | awk '{print $2}' | sort -V | tail -n 1)
    
    # Also extract Filename if present (actual download path)
    local filename
    filename=$(grep "Filename: " /tmp/antigravity_packages | awk '{print $2}' | tail -n 1)
    if [[ -n "$filename" ]]; then
        # Store for later use
        echo "$filename" > /tmp/antigravity_deb_filename
    fi
    
    rm -f /tmp/antigravity_packages
    
    if [[ -n "$version" ]]; then
        echo "$version"
        return 0
    fi
    
    log_warn "Could not find Version string in Debian repository"
    return 1
}

# Function to extract version from RPM Repository (Google's official repo)
get_latest_version_rpm() {
    log_info "Fetching latest version from RPM Repository..."
    
    local repo_base="https://us-central1-yum.pkg.dev/projects/antigravity-auto-updater-dev/antigravity-rpm"
    local version=""
    
    # Try fetching repomd.xml to find primary.xml location
    local repomd
    repomd=$(curl -sL "$repo_base/repodata/repomd.xml" 2>/dev/null)
    
    if [[ -z "$repomd" ]]; then
        log_warn "Failed to fetch RPM repomd.xml"
        return 1
    fi
    
    # Extract primary.xml.gz location from repomd.xml
    local primary_href
    primary_href=$(echo "$repomd" | grep -oP 'href="repodata/\K[^"]*primary[^"]*' | head -1)
    
    if [[ -z "$primary_href" ]]; then
        log_warn "Could not find primary.xml in repomd.xml"
        return 1
    fi
    
    # Fetch and parse primary.xml
    if [[ "$primary_href" == *.gz ]]; then
        version=$(curl -sL "$repo_base/repodata/$primary_href" 2>/dev/null | gzip -d | grep -oP '<version[^>]*ver="\K[^"]+' | sort -V | tail -1)
    else
        version=$(curl -sL "$repo_base/repodata/$primary_href" 2>/dev/null | grep -oP '<version[^>]*ver="\K[^"]+' | sort -V | tail -1)
    fi
    
    # RPM version might also have rel attribute for build number, combine if present
    if [[ -n "$version" ]]; then
        echo "$version"
        return 0
    fi
    
    log_warn "Could not find version in RPM repository"
    return 1
}

# Helper function to compare versions (returns 0 if $1 > $2, 1 if $1 <= $2)
version_gt() {
    # Use sort -V to compare versions
    local highest
    highest=$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n 1)
    [[ "$highest" == "$1" && "$1" != "$2" ]]
}

# Function to get latest version
# IMPORTANT: Debian/RPM repos return versions with SHORT build numbers (e.g., 1.12.4-1765945650)
#            but the CDN uses LONG build numbers (e.g., 1.11.14-5763785964257280).
#            Chromium scraping gets the actual CDN URL which has the correct version format.
get_latest_version() {
    local chromium_version=""
    local deb_version=""
    
    # PRIORITY 1: Chromium scraping (gets actual download URL with correct version)
    log_info "Trying Chromium scraping first (most reliable)..."
    if chromium_version=$(get_latest_version_chromium 2>/dev/null); then
        log_info "Chromium scraped version: $chromium_version"
        echo "$chromium_version"
        return 0
    fi
    log_warn "Chromium scraping failed"
    
    # PRIORITY 2: Debian Repo (may have incompatible build number format)
    log_info "Falling back to Debian repository..."
    if deb_version=$(get_latest_version_deb 2>/dev/null); then
        log_warn "Debian repo version: $deb_version"
        log_warn "Note: Debian repo versions may have incompatible build numbers!"
        log_warn "The CDN often uses different build number formats."
        echo "$deb_version"
        return 0
    fi
    log_warn "Debian repo check failed"
    
    # PRIORITY 3: RPM Repo (same issue as Debian)
    local rpm_version=""
    if rpm_version=$(get_latest_version_rpm 2>/dev/null); then
        log_warn "RPM repo version: $rpm_version"
        log_warn "Note: RPM repo versions may have incompatible build numbers!"
        echo "$rpm_version"
        return 0
    fi
    log_warn "RPM repo check failed"
    
    log_error "All version detection methods failed"
    return 1
}

# Function to get current version from flake
get_current_version() {
    grep -oP 'version = "\K[^"]+' flake.nix | head -1
}

# Function to update version in files
update_version() {
    local new_version="$1"

    log_info "Updating version to $new_version..."

    # Update flake.nix
    sed -i "s/version = \".*\"/version = \"$new_version\"/" flake.nix

    # Update package.nix
    sed -i "s/version = \".*\"/version = \"$new_version\"/" package.nix

    log_info "Version updated in flake.nix and package.nix"
}

# Function to update hash
update_hash() {
    local new_version="$1"
    local url
    
    # Use discovered URL if available, otherwise use default pattern
    if [[ -n "$DISCOVERED_DOWNLOAD_URL" ]]; then
        url="$DISCOVERED_DOWNLOAD_URL"
        log_info "Using discovered URL: $url"
    else
        url="https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/${new_version}/linux-x64/Antigravity.tar.gz"
        log_info "Using default URL pattern: $url"
    fi

    log_info "Fetching hash for new version..."

    # Create temp file for download
    local tmpfile
    tmpfile=$(mktemp)
    trap "rm -f $tmpfile" EXIT

    # Try curl first (works with most firewall configs)
    log_info "Downloading with curl..."
    if ! curl -sL "$url" -o "$tmpfile" 2>/dev/null; then
        log_error "curl download failed, trying nix-prefetch-url..."
        
        # Fallback to nix-prefetch-url
        local hash
        hash=$(nix-prefetch-url --type sha256 "$url" 2>/dev/null)
        
        if [[ -z "$hash" ]]; then
            log_error "Could not fetch hash for new version"
            return 1
        fi
        
        local sri_hash
        sri_hash=$(nix hash to-sri --type sha256 "$hash")
        log_info "New hash: $sri_hash"
        sed -i "s|sha256 = \"sha256-.*\"|sha256 = \"$sri_hash\"|" package.nix
        log_info "Hash updated in package.nix"
        return 0
    fi

    # Calculate SHA256 hash from downloaded file
    local hex_hash
    hex_hash=$(sha256sum "$tmpfile" | cut -d' ' -f1)
    
    if [[ -z "$hex_hash" ]]; then
        log_error "Could not calculate hash"
        return 1
    fi

    # Convert hex to SRI format using nix hash convert
    local sri_hash
    sri_hash=$(nix hash convert --hash-algo sha256 --to sri "$hex_hash" 2>/dev/null || \
               nix hash to-sri --type sha256 "$hex_hash" 2>/dev/null || \
               echo "sha256-$(echo "$hex_hash" | xxd -r -p | base64)")

    log_info "New hash: $sri_hash"

    # Update package.nix with new hash
    sed -i "s|sha256 = \"sha256-.*\"|sha256 = \"$sri_hash\"|" package.nix

    log_info "Hash updated in package.nix"
}

# Function to test build
test_build() {
    log_info "Testing build..."

    if nix build .#default --no-link; then
        log_info "Build test successful!"
        return 0
    else
        log_error "Build test failed!"
        return 1
    fi
}

# Global variable to store discovered working URL
DISCOVERED_DOWNLOAD_URL=""

# Function to discover and validate download URL
# Tries multiple URL patterns and stores the working one
discover_download_url() {
    local version="$1"
    
    log_info "Discovering download URL for version $version..."
    
    # Array of URL patterns to try (most likely first)
    local urls=(
        # Standard CDN pattern
        "https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/${version}/linux-x64/Antigravity.tar.gz"
        # Alternative patterns (in case Google changes the structure)
        "https://dl.google.com/release2/antigravity/stable/${version}/linux-x64/Antigravity.tar.gz"
        "https://storage.googleapis.com/antigravity-releases/stable/${version}/linux-x64/Antigravity.tar.gz"
    )
    
    # Check if we have a Debian package filename that might contain the URL
    if [[ -f /tmp/antigravity_deb_filename ]]; then
        local deb_file
        deb_file=$(cat /tmp/antigravity_deb_filename)
        log_info "Found Debian package reference: $deb_file"
        rm -f /tmp/antigravity_deb_filename
    fi
    
    # Try each URL pattern
    for url in "${urls[@]}"; do
        log_info "Trying: $url"
        
        # Use HEAD request first (fast)
        local http_code
        http_code=$(curl -sI -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
        
        if [[ "$http_code" == "200" ]]; then
            log_info "✓ Found valid URL (HTTP $http_code)"
            DISCOVERED_DOWNLOAD_URL="$url"
            return 0
        elif [[ "$http_code" == "302" ]] || [[ "$http_code" == "301" ]]; then
            # Follow redirects and check final destination
            local final_code
            final_code=$(curl -sIL -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
            if [[ "$final_code" == "200" ]]; then
                log_info "✓ Found valid URL via redirect (HTTP $final_code)"
                DISCOVERED_DOWNLOAD_URL="$url"
                return 0
            fi
        fi
        
        log_info "  ✗ HTTP $http_code"
    done
    
    # If all patterns fail, try to download the Debian package and see what URL it points to
    log_warn "All standard URL patterns failed. Version $version may not be available on CDN yet."
    log_warn "The Debian/RPM repos may have metadata before the actual tarball is published."
    
    return 1
}

# Backward compatibility alias
validate_download_url() {
    discover_download_url "$@"
}

# Main script
main() {
    cd "$(dirname "$0")/.."

    log_info "Starting Google Antigravity update check..."

    # Get current version
    local current_version
    current_version=$(get_current_version)
    log_info "Current version: $current_version"

    # Get latest version
    local latest_version
    if ! latest_version=$(get_latest_version); then
        log_warn "Could not fetch latest version. Keeping current version."
        exit 0
    fi

    # Validate we got a version
    if [[ -z "$latest_version" ]]; then
        log_error "get_latest_version returned empty string"
        exit 1
    fi

    log_info "Latest version: $latest_version"

    # Check if update is needed
    if [[ "$current_version" == "$latest_version" ]]; then
        log_info "Already at latest version. No update needed."
        exit 0
    fi

    log_warn "New version available: $latest_version"

    # CRITICAL: Validate download URL exists BEFORE updating any files
    if ! validate_download_url "$latest_version"; then
        log_error "Download URL validation failed! Version $latest_version may not be available yet."
        log_error "Skipping update to prevent broken configuration."
        exit 0
    fi

    # Backup current files before making changes
    cp flake.nix flake.nix.bak 2>/dev/null || true
    cp package.nix package.nix.bak 2>/dev/null || true

    # Update version
    update_version "$latest_version"

    # Update hash
    if ! update_hash "$latest_version"; then
        log_error "Hash update failed! Rolling back..."
        mv flake.nix.bak flake.nix 2>/dev/null || true
        mv package.nix.bak package.nix 2>/dev/null || true
        exit 1
    fi

    # Test build
    if ! test_build; then
        log_error "Build failed after update. Rolling back..."
        mv flake.nix.bak flake.nix 2>/dev/null || true
        mv package.nix.bak package.nix 2>/dev/null || true
        log_info "Rolled back to version $current_version"
        exit 1
    fi

    # Cleanup backups on success
    rm -f flake.nix.bak package.nix.bak

    log_info "Update complete! Version updated from $current_version to $latest_version"

    # Optionally commit changes
    if command -v git &> /dev/null && [[ -d .git ]]; then
        log_info "Committing changes..."
        git add flake.nix package.nix
        git commit -m "chore: update Google Antigravity to version $latest_version"
        log_info "Changes committed. Don't forget to push!"
    fi
}

main "$@"
