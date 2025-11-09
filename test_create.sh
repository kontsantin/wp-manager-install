#!/bin/bash
# Test create project without Docker and WordPress download

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Simulate create_project variables
THEME_NAME="testtheme"
DOMAIN="testtheme.local"
WP_PATH="/tmp/wp-test-full"

# Normalize THEME_NAME as in wpmanager
THEME_NAME=$(echo "$THEME_NAME" | { iconv -f UTF-8 -t UTF-8 -c 2>/dev/null || cat; } )
THEME_NAME=$(echo "$THEME_NAME" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
THEME_NAME=$(echo "$THEME_NAME" | sed 's/[[:space:]]\+/-/g')
THEME_NAME=$(echo "$THEME_NAME" | sed 's/[^a-zA-Z0-9_-]//g' | tr '[:upper:]' '[:lower:]')
THEME_NAME=$(echo "$THEME_NAME" | sed 's/[-_]\+/-/g' | sed 's/^-//' | sed 's/-$//')
if [[ $THEME_NAME =~ ^[0-9] ]]; then
    THEME_NAME="t_${THEME_NAME}"
fi

echo "Using THEME_NAME: $THEME_NAME"

# Create structure
mkdir -p "$WP_PATH/wp-content/themes"
mkdir -p "$WP_PATH/wp-content/plugins"
mkdir -p "$WP_PATH/wp-content/uploads"

# Create theme
THEME_DIR="$WP_PATH/wp-content/themes/$THEME_NAME"

if [[ -f "/usr/local/bin/theme-template.sh" ]]; then
    source /usr/local/bin/theme-template.sh
    create_theme_files "$THEME_DIR" "$THEME_NAME" "$WP_PATH" || true
elif [[ -f "$SCRIPT_DIR/theme-template.sh" ]]; then
    source "$SCRIPT_DIR/theme-template.sh"
    create_theme_files "$THEME_DIR" "$THEME_NAME" "$WP_PATH" || true
else
    mkdir -p "$THEME_DIR"
fi

echo "Theme created at $THEME_DIR"
echo "Listing theme files:"
find "$THEME_DIR" -type f | sort