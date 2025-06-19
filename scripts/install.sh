#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[94m'  # Light blue for links
NC='\033[0m' # No Color
CYAN_RGB='\033[38;2;61;181;255m'

echo -e "${CYAN_RGB}"
cat << "EOF"
    ____  __  _____  ___            ____           __        ____
   / __ )/  |/  /  |/  /           /  _/___  _____/ /_____ _/ / /
  / __  / /|_/ / /|_/ /  ______    / // __ \/ ___/ __/ __ `/ / /
 / /_/ / /  / / /  / /  /_____/  _/ // / / (__  ) /_/ /_/ / / /
/_____/_/  /_/_/  /_/           /___/_/ /_/____/\__/\__,_/_/_/

EOF
echo -e "${NC}"

echo -e "${GREEN}Balatro Mod Manager Builder${NC}"
echo "----------------------------------------"
echo "Build started at $(date)"

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}Error: This builder is for macOS only.${NC}"
    exit 1
fi

# Check for required tools
echo "Checking dependencies..."

if ! command -v git &> /dev/null; then
    echo -e "${RED}Error: git not found. Please install git first.${NC}"
    echo -e "${BLUE}https://git-scm.com/downloads${NC}"  # Light blue hyperlink
    exit 1
fi

if ! command -v cargo &> /dev/null; then
    echo -e "${RED}Error: cargo not found. Please install Rust/Cargo first.${NC}"
    echo -e "${BLUE}https://www.rust-lang.org/tools/install${NC}"  # Light blue hyperlink
    exit 1
fi

if ! command -v bun &> /dev/null; then
    echo -e "${RED}Error: bun not found. Please install bun first.${NC}"
    echo -e "${BLUE}https://bun.sh/${NC}"  # Light blue hyperlink
    exit 1
fi

if ! command -v cargo-tauri &> /dev/null; then
    echo -e "${RED}Error: cargo-tauri not found. Please install tauri-cli first.${NC}"
    echo -e "${BLUE}https://crates.io/crates/tauri-cli${NC}"
    exit 1
fi

# Check cargo-tauri version
echo -e "${YELLOW}Checking Tauri CLI version...${NC}"
TAURI_VERSION=$(cargo tauri --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
REQUIRED_VERSION="2.3.1"

if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$TAURI_VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]; then
    echo -e "${RED}Error: cargo-tauri version $TAURI_VERSION is too old. Please update to at least version $REQUIRED_VERSION${NC}"
    exit 1
fi
echo -e "${GREEN}cargo-tauri version $TAURI_VERSION ✓${NC}"

# Create a temporary directory
BUILD_DIR=$(mktemp -d)
echo -e "${YELLOW}Creating temporary build directory: ${BUILD_DIR}${NC}"

# Clone the repository
echo -e "${YELLOW}1. Cloning repository...${NC}"
git clone https://github.com/skyline69/balatro-mod-manager.git "${BUILD_DIR}/balatro-mod-manager" || { 
    echo -e "${RED}Git clone failed${NC}"
    rm -rf "${BUILD_DIR}"
    exit 1
}

# Change to repository directory
cd "${BUILD_DIR}/balatro-mod-manager" || {
    echo -e "${RED}Failed to enter repository directory${NC}"
    rm -rf "${BUILD_DIR}"
    exit 1
}

# Build steps
echo -e "${YELLOW}2. Installing bun dependencies...${NC}"
bun install || {
    echo -e "${RED}Bun install failed${NC}"
    rm -rf "${BUILD_DIR}"
    exit 1
}

echo -e "${YELLOW}3. Building frontend...${NC}"
bun run build || {
    echo -e "${RED}Frontend build failed${NC}"
    rm -rf "${BUILD_DIR}"
    exit 1
}

echo -e "${YELLOW}4. Building Rust backend...${NC}"
cd src-tauri && SKIP_BUILD_SCRIPT=1 cargo build --release || {
    echo -e "${RED}Cargo build failed${NC}"
    rm -rf "${BUILD_DIR}"
    exit 1
}

cd ..

echo -e "${YELLOW}5. Creating app bundle...${NC}"
cargo tauri build || {
    echo -e "${RED}Tauri build failed${NC}"
    rm -rf "${BUILD_DIR}"
    exit 1
}

# Cleanup
echo -e "${YELLOW}6. Cleaning up...${NC}"
rm -rf "${BUILD_DIR}"

echo -e "${GREEN}Installation completed successfully!${NC}"
echo
echo -e "${YELLOW}Note: Security dialog might appear on first launch${NC}"

exit 0
