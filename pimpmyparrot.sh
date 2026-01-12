#!/bin/bash

#===============================================================================
# PimpMyParrot - Parrot OS 7 Enhancement & Tool Installation Script
# Similar to PimpMyKali but designed for Parrot OS 7
# 
# Usage: ./pimpmyparrot.sh [OPTIONS]
#
# Options:
#   -h, --help           Show help message
#   -n, --dry-run        Show what would be installed without making changes
#   -c, --category CATS  Install only specified categories (comma-separated)
#   -s, --skip CATS      Skip specified categories (comma-separated)
#   -l, --list           List all available categories
#   -a, --all            Install all tools (non-interactive)
#   -f, --fix            Run all system fixes (non-interactive)
#
# Examples:
#   ./pimpmyparrot.sh                    # Interactive menu
#   ./pimpmyparrot.sh --all              # Install all tools
#   ./pimpmyparrot.sh --dry-run --all    # Preview all installations
#   ./pimpmyparrot.sh -c recon,scanning  # Install only recon and scanning
#   ./pimpmyparrot.sh --fix              # Run system fixes only
#
# Environment:
#   GITHUB_TOKEN    GitHub API token to avoid rate limits
#===============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
SCRIPT_VERSION="1.1.0"
SCRIPT_NAME="PimpMyParrot"
LOG_DIR="$HOME/.pimpmyparrot"
LOG_FILE="$LOG_DIR/install_$(date +%Y%m%d_%H%M%S).log"
CONFIG_FILE="$LOG_DIR/config.conf"
INSTALLED_TOOLS_FILE="$LOG_DIR/installed_tools.txt"

# CLI Mode flags
DRY_RUN=false
CLI_MODE=false
RUN_ALL=false
RUN_FIX=false
SELECTED_CATEGORIES=()
SKIP_CATEGORIES=()

# Installation tracking
declare -i SUCCESS_COUNT=0
declare -i FAILED_COUNT=0
declare -i SKIPPED_COUNT=0
declare -a FAILED_TOOLS=()

# Available categories
declare -A CATEGORIES=(
    ["recon"]="Reconnaissance (whois, subfinder, amass, httpx)"
    ["scanning"]="Scanning & Enumeration (nmap, nikto, nuclei)"
    ["cms"]="CMS Scanners (wpscan, joomscan, cmseek)"
    ["fuzzing"]="Fuzzing & Brute-force (ffuf, gobuster, hydra)"
    ["vulnscan"]="Vulnerability Scanners (sqlmap, xsstrike, dalfox)"
    ["osint"]="OSINT Tools (profil3r, trufflehog, pywhat)"
    ["smb"]="SMB & AD Tools (netexec, smbmap, impacket)"
    ["wifi"]="WiFi Tools (aircrack-ng, bettercap)"
    ["postexploit"]="Post-Exploitation (linpeas, lazagne)"
)

# Create log directory
mkdir -p "$LOG_DIR"
touch "$INSTALLED_TOOLS_FILE"

# Logging functions
log() { echo -e "$1" | tee -a "$LOG_FILE"; }
info() { log "${BLUE}[INFO]${NC} $1"; }
success() { log "${GREEN}[✓]${NC} $1"; }
warning() { log "${YELLOW}[!]${NC} $1"; }
error() { log "${RED}[✗]${NC} $1"; }

header() {
    log "\n${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    log "${CYAN}║${NC} ${BOLD}$1${NC}"
    log "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}\n"
}

banner() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
    ____  _                 __  __       ____                      __ 
   / __ \(_)___ ___  ____  /  |/  /_  __/ __ \____ ______________  / /_
  / /_/ / / __ `__ \/ __ \/ /|_/ / / / / /_/ / __ `/ ___/ ___/ __ \/ __/
 / ____/ / / / / / / /_/ / /  / / /_/ / ____/ /_/ / /  / /  / /_/ / /_  
/_/   /_/_/ /_/ /_/ .___/_/  /_/\__, /_/    \__,_/_/  /_/   \____/\__/  
                 /_/            /____/                                   
EOF
    echo -e "${NC}"
    echo -e "${BOLD}Version:${NC} $SCRIPT_VERSION | ${BOLD}For:${NC} Parrot OS 7 | ${BOLD}Log:${NC} $LOG_FILE"
    $DRY_RUN && echo -e "${YELLOW}[DRY-RUN MODE]${NC}"
    echo ""
}

# Track installation result
track_result() {
    local tool_name="$1"
    local result="$2"
    
    case "$result" in
        success) ((SUCCESS_COUNT++)) ;;
        failed) ((FAILED_COUNT++)); FAILED_TOOLS+=("$tool_name") ;;
        skipped) ((SKIPPED_COUNT++)) ;;
    esac
}

# Print summary at end
print_summary() {
    echo ""
    header "Installation Summary"
    echo -e "${GREEN}Successful:${NC} $SUCCESS_COUNT"
    echo -e "${YELLOW}Skipped:${NC}    $SKIPPED_COUNT"
    echo -e "${RED}Failed:${NC}     $FAILED_COUNT"
    
    if [[ ${#FAILED_TOOLS[@]} -gt 0 ]]; then
        echo ""
        echo -e "${RED}Failed tools:${NC}"
        for tool in "${FAILED_TOOLS[@]}"; do
            echo "  - $tool"
        done
    fi
    echo ""
    info "Log file: $LOG_FILE"
}

# Background process PID for cleanup
SUDO_REFRESH_PID=""

# Cleanup function for graceful exit
cleanup() {
    [[ -n "$SUDO_REFRESH_PID" ]] && kill "$SUDO_REFRESH_PID" 2>/dev/null
    exit
}
trap cleanup EXIT INT TERM

check_not_root() {
    if [[ $EUID -eq 0 ]]; then
        error "Run as normal user, not root. Sudo will be used when needed."
        exit 1
    fi
}

check_sudo() {
    if ! command -v sudo &> /dev/null || ! sudo -v &> /dev/null; then
        error "Sudo not available or no privileges."
        exit 1
    fi
    # Background sudo refresh with tracked PID
    ( while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) &
    SUDO_REFRESH_PID=$!
}

check_parrot_os() {
    if grep -qi "parrot" /etc/os-release 2>/dev/null; then
        success "Parrot OS detected"
    else
        warning "Not Parrot OS. Proceed with caution."
        $CLI_MODE && return 0
        read -p "Continue? (y/N): " choice
        [[ "$choice" =~ ^[Yy]$ ]] || exit 1
    fi
}

pause() { 
    $CLI_MODE && return 0
    read -p "Press Enter to continue..."
}

command_exists() { command -v "$1" &> /dev/null; }
package_installed() { dpkg -l "$1" 2>/dev/null | grep -q "^ii"; }
opt_tool_exists() { [[ -d "/opt/$1" ]]; }
mark_installed() { echo "$1" >> "$INSTALLED_TOOLS_FILE" 2>/dev/null; sort -u "$INSTALLED_TOOLS_FILE" -o "$INSTALLED_TOOLS_FILE" 2>/dev/null; }

# Check if category should run
should_run_category() {
    local category="$1"
    
    # Check skip list
    for skip in "${SKIP_CATEGORIES[@]}"; do
        [[ "$skip" == "$category" ]] && return 1
    done
    
    # If specific categories selected, only run those
    if [[ ${#SELECTED_CATEGORIES[@]} -gt 0 ]]; then
        for selected in "${SELECTED_CATEGORIES[@]}"; do
            [[ "$selected" == "$category" ]] && return 0
        done
        return 1
    fi
    
    return 0
}

install_apt_package() {
    local pkg="$1"
    
    if $DRY_RUN; then
        if package_installed "$pkg" || command_exists "$pkg"; then
            info "[DRY-RUN] $pkg already installed"
            track_result "$pkg" "skipped"
        else
            info "[DRY-RUN] Would install: $pkg"
        fi
        return 0
    fi
    
    if package_installed "$pkg" || command_exists "$pkg"; then
        success "$pkg already installed"
        mark_installed "$pkg"
        track_result "$pkg" "skipped"
        return 0
    else
        info "Installing $pkg..."
        if sudo apt-get install -y "$pkg" >> "$LOG_FILE" 2>&1; then
            success "$pkg installed"
            mark_installed "$pkg"
            track_result "$pkg" "success"
            return 0
        else
            warning "Failed: $pkg"
            track_result "$pkg" "failed"
            return 1
        fi
    fi
}

install_pipx_package() {
    local pkg="$1"
    local cmd="${2:-$1}"
    
    if $DRY_RUN; then
        if command_exists "$cmd"; then
            info "[DRY-RUN] $pkg already installed"
            track_result "$pkg" "skipped"
        else
            info "[DRY-RUN] Would install via pipx: $pkg"
        fi
        return 0
    fi
    
    if command_exists "$cmd"; then
        success "$pkg already installed"
        mark_installed "$pkg"
        track_result "$pkg" "skipped"
    else
        command_exists pipx || { info "Installing pipx..."; sudo apt-get install -y pipx >> "$LOG_FILE" 2>&1; pipx ensurepath >> "$LOG_FILE" 2>&1; }
        info "Installing $pkg..."
        if pipx install "$pkg" >> "$LOG_FILE" 2>&1; then
            success "$pkg installed"
            mark_installed "$pkg"
            track_result "$pkg" "success"
        else
            warning "Failed: $pkg"
            track_result "$pkg" "failed"
        fi
    fi
}

install_go_tool() {
    local pkg="$1"
    local cmd="$2"
    
    if $DRY_RUN; then
        if command_exists "$cmd"; then
            info "[DRY-RUN] $cmd already installed"
            track_result "$cmd" "skipped"
        else
            info "[DRY-RUN] Would install via go: $cmd"
        fi
        return 0
    fi
    
    if command_exists "$cmd"; then
        success "$cmd already installed"
        mark_installed "$cmd"
        track_result "$cmd" "skipped"
    else
        command_exists go || { info "Installing Go..."; sudo apt-get install -y golang >> "$LOG_FILE" 2>&1; }
        export GOPATH="$HOME/go"
        export PATH="$PATH:$GOPATH/bin"
        info "Installing $cmd..."
        if go install "$pkg" >> "$LOG_FILE" 2>&1; then
            success "$cmd installed"
            mark_installed "$cmd"
            track_result "$cmd" "success"
            # Add to PATH only if not already present
            if ! grep -q 'export GOPATH="\$HOME/go"' ~/.bashrc 2>/dev/null; then
                echo '' >> ~/.bashrc
                echo '# Go environment' >> ~/.bashrc
                echo 'export GOPATH="$HOME/go"' >> ~/.bashrc
                echo 'export PATH="$PATH:$GOPATH/bin"' >> ~/.bashrc
            fi
        else
            warning "Failed: $cmd"
            track_result "$cmd" "failed"
        fi
    fi
}

install_opt_python_tool() {
    local repo="$1"
    local name="$2"
    
    if $DRY_RUN; then
        if opt_tool_exists "$name"; then
            info "[DRY-RUN] $name already in /opt"
            track_result "$name" "skipped"
        else
            info "[DRY-RUN] Would clone to /opt: $name"
        fi
        return 0
    fi
    
    if opt_tool_exists "$name"; then
        success "$name already in /opt"
        mark_installed "$name"
        track_result "$name" "skipped"
    else
        info "Installing $name to /opt..."
        if sudo git clone "$repo" "/opt/$name" >> "$LOG_FILE" 2>&1; then
            sudo chown -R "$USER:$USER" "/opt/$name"
            # Use subshell to avoid cd issues
            (
                cd "/opt/$name" || exit 1
                if [[ -f "requirements.txt" ]]; then
                    python3 -m venv .venv >> "$LOG_FILE" 2>&1
                    source .venv/bin/activate
                    pip install -r requirements.txt >> "$LOG_FILE" 2>&1
                    deactivate
                fi
            ) || { warning "Failed to setup $name"; track_result "$name" "failed"; return 1; }
            success "$name installed"
            mark_installed "$name"
            track_result "$name" "success"
        else
            warning "Failed to clone: $name"
            track_result "$name" "failed"
        fi
    fi
}

#===============================================================================
# SYSTEM FIXES
#===============================================================================

fix_parrot_repos() {
    header "Fixing Parrot Repositories"
    
    # Check for custom repositories
    if grep -vE '^#|^$|deb.parrot.sh' /etc/apt/sources.list 2>/dev/null | grep -q .; then
        warning "Custom repositories detected in sources.list!"
        info "These will be removed. Check backup to restore them."
        read -p "Continue? (y/N): " choice
        [[ "$choice" =~ ^[Yy]$ ]] || { info "Aborted."; pause; return; }
    fi
    
    # Backup with timestamp
    local backup="/etc/apt/sources.list.backup.$(date +%Y%m%d_%H%M%S)"
    sudo cp /etc/apt/sources.list "$backup" 2>/dev/null
    info "Backup saved to: $backup"
    
    cat | sudo tee /etc/apt/sources.list > /dev/null << 'EOF'
# Parrot OS 7 (LTS) Official Repositories
# Generated by PimpMyParrot
deb https://deb.parrot.sh/parrot/ parrot main contrib non-free non-free-firmware
deb https://deb.parrot.sh/parrot/ parrot-security main contrib non-free non-free-firmware
deb https://deb.parrot.sh/parrot/ parrot-backports main contrib non-free non-free-firmware
deb https://deb.parrot.sh/parrot/ parrot-updates main contrib non-free non-free-firmware
EOF
    sudo apt-get update >> "$LOG_FILE" 2>&1 && success "Repositories fixed" || warning "Update failed"
    pause
}

fix_broken_packages() {
    header "Fixing Broken Packages"
    sudo dpkg --configure -a >> "$LOG_FILE" 2>&1
    sudo apt-get install -f -y >> "$LOG_FILE" 2>&1
    sudo apt-get autoremove -y >> "$LOG_FILE" 2>&1
    sudo apt-get autoclean >> "$LOG_FILE" 2>&1
    success "Packages fixed"
    pause
}

update_parrot() {
    header "Updating Parrot OS"
    sudo apt-get update >> "$LOG_FILE" 2>&1
    sudo apt-get upgrade -y >> "$LOG_FILE" 2>&1
    sudo apt-get full-upgrade -y >> "$LOG_FILE" 2>&1
    sudo apt-get autoremove -y >> "$LOG_FILE" 2>&1
    success "System updated"
    pause
}

optimize_parrot() {
    header "Parrot OS Optimizations"
    
    info "Enabling parallel apt downloads..."
    echo 'Acquire::Queue-Mode "host";' | sudo tee /etc/apt/apt.conf.d/99parallel > /dev/null
    echo 'Acquire::http::Pipeline-Depth "5";' | sudo tee -a /etc/apt/apt.conf.d/99parallel > /dev/null
    
    warning "force-unsafe-io speeds up dpkg but risks corruption on power failure."
    read -p "Enable force-unsafe-io? (y/N): " choice
    if [[ "$choice" =~ ^[Yy]$ ]]; then
        echo 'force-unsafe-io' | sudo tee /etc/dpkg/dpkg.cfg.d/99speedup > /dev/null
        info "force-unsafe-io enabled"
    else
        sudo rm -f /etc/dpkg/dpkg.cfg.d/99speedup 2>/dev/null
        info "force-unsafe-io skipped"
    fi
    
    success "Optimizations applied"
    pause
}

#===============================================================================
# TOOL INSTALLATION CATEGORIES
#===============================================================================

install_recon_tools() {
    header "Installing Reconnaissance Tools"
    install_apt_package "whois"
    install_apt_package "dnsutils"
    install_apt_package "dnsrecon"
    install_apt_package "traceroute"
    
    # theharvester - try apt, fallback to GitHub
    if command_exists theHarvester || command_exists theharvester; then
        success "theharvester already installed"
    else
        info "Installing theharvester..."
        if ! install_apt_package "theharvester"; then
            info "Trying GitHub fallback for theharvester..."
            install_opt_python_tool "https://github.com/laramies/theHarvester.git" "theHarvester"
        fi
    fi
    
    # finalrecon - install from GitHub (not on PyPI)
    install_opt_python_tool "https://github.com/thewhiteh4t/FinalRecon.git" "FinalRecon"
    install_apt_package "amass"
    install_go_tool "github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest" "subfinder"
    install_go_tool "github.com/projectdiscovery/httpx/cmd/httpx@latest" "httpx"
    install_opt_python_tool "https://github.com/IvanGlinkin/Fast-Google-Dorks-Scan.git" "Fast-Google-Dorks-Scan"
    install_opt_python_tool "https://github.com/opsdisk/pagodo.git" "pagodo"
    install_opt_python_tool "https://github.com/guelfoweb/knock.git" "knock"
    [[ -d "/opt/SecLists" ]] || sudo git clone --depth 1 https://github.com/danielmiessler/SecLists.git /opt/SecLists >> "$LOG_FILE" 2>&1
    success "Recon tools installed"
    pause
}

install_scanning_tools() {
    header "Installing Scanning Tools"
    install_apt_package "nmap"
    install_apt_package "nikto"
    
    # wapiti - try apt, fallback to pipx
    if command_exists wapiti; then
        success "wapiti already installed"
    else
        info "Installing wapiti..."
        if ! install_apt_package "wapiti"; then
            info "Trying pipx fallback for wapiti..."
            install_pipx_package "wapiti3" "wapiti"
        fi
    fi
    
    install_apt_package "skipfish"
    install_apt_package "sslscan"
    install_apt_package "wafw00f"
    install_go_tool "github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest" "nuclei"
    install_pipx_package "bbot"
    [[ -d "/usr/share/nmap/scripts/vulscan" ]] || sudo git clone https://github.com/scipag/vulscan /usr/share/nmap/scripts/vulscan >> "$LOG_FILE" 2>&1
    install_opt_python_tool "https://github.com/MrCl0wnLab/ShellShockHunter.git" "ShellShockHunter"
    success "Scanning tools installed"
    pause
}

install_cms_scanners() {
    header "Installing CMS Scanners"
    install_apt_package "wpscan"
    install_apt_package "joomscan"
    install_opt_python_tool "https://github.com/Tuhinshubhra/CMSeeK.git" "CMSeeK"
    install_opt_python_tool "https://github.com/anouarbensaad/vulnx.git" "vulnx"
    install_opt_python_tool "https://github.com/oppsec/juumla.git" "juumla"
    success "CMS scanners installed"
    pause
}

# Install feroxbuster from GitHub releases
install_feroxbuster() {
    if command_exists feroxbuster; then
        success "feroxbuster already installed"
        mark_installed "feroxbuster"
        return 0
    fi
    
    info "Installing feroxbuster from GitHub..."
    local tmp_dir=$(mktemp -d)
    
    # Use subshell to avoid cd issues and ensure cleanup
    (
        cd "$tmp_dir" || exit 1
        
        local release_url=$(curl -s https://api.github.com/repos/epi052/feroxbuster/releases/latest | grep "browser_download_url.*x86_64-linux-feroxbuster.tar.gz" | head -1 | cut -d '"' -f 4)
        
        if [[ -z "$release_url" ]]; then
            echo "Failed to get release URL" >> "$LOG_FILE"
            exit 1
        fi
        
        if ! curl -sL "$release_url" -o feroxbuster.tar.gz >> "$LOG_FILE" 2>&1; then
            echo "Failed to download feroxbuster" >> "$LOG_FILE"
            exit 1
        fi
        
        if ! tar xzf feroxbuster.tar.gz >> "$LOG_FILE" 2>&1; then
            echo "Failed to extract feroxbuster" >> "$LOG_FILE"
            exit 1
        fi
        
        if ! sudo mv feroxbuster /usr/local/bin/ 2>/dev/null; then
            echo "Failed to move feroxbuster to /usr/local/bin" >> "$LOG_FILE"
            exit 1
        fi
        
        sudo chmod +x /usr/local/bin/feroxbuster
        
    ) && {
        success "feroxbuster installed"
        mark_installed "feroxbuster"
    } || {
        warning "Failed to install feroxbuster"
    }
    
    # Cleanup always happens
    rm -rf "$tmp_dir"
}

install_fuzzing_tools() {
    header "Installing Fuzzing & Bruteforce Tools"
    install_go_tool "github.com/ffuf/ffuf/v2@latest" "ffuf"
    
    # feroxbuster - try apt, fallback to GitHub releases
    if command_exists feroxbuster; then
        success "feroxbuster already installed"
    else
        info "Installing feroxbuster..."
        if ! install_apt_package "feroxbuster"; then
            info "Trying GitHub release fallback for feroxbuster..."
            install_feroxbuster
        fi
    fi
    
    install_apt_package "gobuster"
    install_apt_package "wfuzz"
    install_apt_package "hydra"
    install_apt_package "crunch"
    install_apt_package "cewl"
    install_opt_python_tool "https://github.com/maurosoria/dirsearch.git" "dirsearch"
    
    # cook - correct Go module path with cmd subdirectory
    install_go_tool "github.com/glitchedgitz/cook/v2/cmd/cook@latest" "cook"
    success "Fuzzing tools installed"
    pause
}

install_vuln_scanners() {
    header "Installing Vulnerability Scanners"
    install_apt_package "sqlmap"
    install_go_tool "github.com/hahwul/dalfox/v2@latest" "dalfox"
    install_opt_python_tool "https://github.com/stamparm/DSSS.git" "DSSS"
    install_opt_python_tool "https://github.com/s0md3v/XSStrike.git" "XSStrike"
    success "Vulnerability scanners installed"
    pause
}

install_osint_tools() {
    header "Installing OSINT Tools"
    install_opt_python_tool "https://github.com/Greyjedix/Profil3r.git" "Profil3r"
    
    # Install trufflehog - download script first, then execute
    if ! command_exists trufflehog; then
        info "Installing trufflehog..."
        local tmp_script=$(mktemp)
        if curl -sSfL https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh -o "$tmp_script" >> "$LOG_FILE" 2>&1; then
            sudo sh "$tmp_script" -b /usr/local/bin >> "$LOG_FILE" 2>&1 && success "trufflehog installed" || warning "Failed to install trufflehog"
        else
            warning "Failed to download trufflehog installer"
        fi
        rm -f "$tmp_script"
    else
        success "trufflehog already installed"
        mark_installed "trufflehog"
    fi
    
    install_pipx_package "pywhat"
    success "OSINT tools installed"
    pause
}

install_smb_tools() {
    header "Installing SMB & AD Tools"
    # crackmapexec - skip if netexec is available (netexec is the successor)
    if command_exists nxc || command_exists netexec; then
        success "netexec (cme successor) already installed - skipping crackmapexec"
    else
        install_apt_package "crackmapexec" || install_pipx_package "crackmapexec" "cme" || info "Using netexec instead"
    fi
    install_pipx_package "netexec" "nxc"
    install_apt_package "smbmap"
    install_apt_package "python3-impacket"
    success "SMB tools installed"
    pause
}

install_wifi_tools() {
    header "Installing WiFi Tools"
    install_apt_package "aircrack-ng"
    install_apt_package "bettercap"
    install_opt_python_tool "https://github.com/D3Ext/WEF.git" "WEF"
    success "WiFi tools installed"
    pause
}

install_postexploit_tools() {
    header "Installing Post-Exploitation Tools"
    [[ -d "/opt/PEASS-ng" ]] || sudo git clone https://github.com/carlospolop/PEASS-ng.git /opt/PEASS-ng >> "$LOG_FILE" 2>&1
    [[ -f "/opt/lse.sh" ]] || { sudo curl -sL "https://github.com/diego-treitos/linux-smart-enumeration/releases/latest/download/lse.sh" -o /opt/lse.sh >> "$LOG_FILE" 2>&1; sudo chmod +x /opt/lse.sh; }
    install_opt_python_tool "https://github.com/AlessandroZ/LaZagne.git" "LaZagne"
    success "Post-exploit tools installed"
    pause
}

install_all_tools() {
    header "Installing ALL Tools"
    install_recon_tools
    install_scanning_tools
    install_cms_scanners
    install_fuzzing_tools
    install_vuln_scanners
    install_osint_tools
    install_smb_tools
    install_wifi_tools
    install_postexploit_tools
    print_summary
    pause
}

#===============================================================================
# MENUS
#===============================================================================

system_menu() {
    while true; do
        banner
        echo -e "${BOLD}${CYAN}System Fixes & Maintenance${NC}"
        echo ""
        echo -e "${GREEN}1)${NC} Fix Parrot Repositories"
        echo -e "${GREEN}2)${NC} Fix Broken Packages"
        echo -e "${GREEN}3)${NC} Update & Upgrade Parrot OS"
        echo -e "${GREEN}4)${NC} Install Missing Dependencies"
        echo -e "${GREEN}5)${NC} Optimize Parrot OS"
        echo -e "${GREEN}6)${NC} Run All System Fixes"
        echo ""
        echo -e "${RED}0)${NC} Back to Main Menu"
        echo ""
        read -p "Select option: " choice
        
        case $choice in
            1) fix_parrot_repos ;;
            2) fix_broken_packages ;;
            3) update_parrot ;;
            4) header "Installing Dependencies"; 
               for dep in git curl wget python3 python3-pip python3-venv golang ruby ruby-dev build-essential libssl-dev libffi-dev python3-dev nmap nikto unzip jq chromium libpcap-dev; do
                   install_apt_package "$dep"
               done
               pause ;;
            5) optimize_parrot ;;
            6) fix_parrot_repos; fix_broken_packages; update_parrot; optimize_parrot ;;
            0) break ;;
            *) error "Invalid option" ;;
        esac
    done
}

tools_menu() {
    while true; do
        banner
        echo -e "${BOLD}${CYAN}Tool Installation Categories${NC}"
        echo ""
        echo -e "${GREEN} 1)${NC} Reconnaissance Tools (whois, subfinder, amass, etc.)"
        echo -e "${GREEN} 2)${NC} Scanning & Enumeration (nmap, nikto, nuclei, etc.)"
        echo -e "${GREEN} 3)${NC} CMS Scanners (wpscan, joomscan, cmseek, etc.)"
        echo -e "${GREEN} 4)${NC} Fuzzing & Bruteforce (ffuf, gobuster, hydra, etc.)"
        echo -e "${GREEN} 5)${NC} Vulnerability Scanners (sqlmap, xsstrike, dalfox, etc.)"
        echo -e "${GREEN} 6)${NC} OSINT Tools (profil3r, trufflehog, etc.)"
        echo -e "${GREEN} 7)${NC} SMB & Active Directory (cme, impacket, etc.)"
        echo -e "${GREEN} 8)${NC} WiFi Tools (aircrack-ng, bettercap, etc.)"
        echo -e "${GREEN} 9)${NC} Post-Exploitation (linpeas, lazagne, etc.)"
        echo ""
        echo -e "${YELLOW}10)${NC} Install ALL Tools"
        echo ""
        echo -e "${RED} 0)${NC} Back to Main Menu"
        echo ""
        read -p "Select option: " choice
        
        case $choice in
            1) install_recon_tools ;;
            2) install_scanning_tools ;;
            3) install_cms_scanners ;;
            4) install_fuzzing_tools ;;
            5) install_vuln_scanners ;;
            6) install_osint_tools ;;
            7) install_smb_tools ;;
            8) install_wifi_tools ;;
            9) install_postexploit_tools ;;
            10) install_all_tools ;;
            0) break ;;
            *) error "Invalid option" ;;
        esac
    done
}

view_installed() {
    banner
    header "Installed Tools"
    if [[ -f "$INSTALLED_TOOLS_FILE" ]] && [[ -s "$INSTALLED_TOOLS_FILE" ]]; then
        cat "$INSTALLED_TOOLS_FILE" | column
    else
        info "No tools tracked yet"
    fi
    echo ""
    info "Total tools: $(wc -l < "$INSTALLED_TOOLS_FILE" 2>/dev/null || echo 0)"
    pause
}

#===============================================================================
# UNINSTALL FUNCTIONS
#===============================================================================

uninstall_opt_tool() {
    local name="$1"
    if [[ -d "/opt/$name" ]]; then
        info "Removing /opt/$name..."
        sudo rm -rf "/opt/$name"
        # Remove from tracked list
        sed -i "/^$name$/d" "$INSTALLED_TOOLS_FILE" 2>/dev/null
        success "$name removed"
    else
        warning "$name not found in /opt"
    fi
}

uninstall_menu() {
    while true; do
        banner
        echo -e "${BOLD}${RED}Uninstall Tools${NC}"
        echo ""
        
        # List /opt tools
        echo -e "${CYAN}Tools in /opt:${NC}"
        local opt_tools=()
        local i=1
        for dir in /opt/*/; do
            if [[ -d "$dir" ]]; then
                local name=$(basename "$dir")
                # Skip system directories
                [[ "$name" == "VBoxGuestAdditions-"* ]] && continue
                opt_tools+=("$name")
                echo -e "${GREEN}$i)${NC} $name"
                ((i++))
            fi
        done
        
        if [[ ${#opt_tools[@]} -eq 0 ]]; then
            info "No tools found in /opt"
        fi
        
        echo ""
        echo -e "${YELLOW}A)${NC} Remove ALL /opt tools"
        echo -e "${YELLOW}C)${NC} Clear installed tools list"
        echo ""
        echo -e "${RED}0)${NC} Back to Main Menu"
        echo ""
        read -p "Select tool number to remove (or A/C/0): " choice
        
        case $choice in
            0) break ;;
            [Aa])
                warning "This will remove ALL tools from /opt!"
                read -p "Are you sure? (yes/N): " confirm
                if [[ "$confirm" == "yes" ]]; then
                    for tool in "${opt_tools[@]}"; do
                        uninstall_opt_tool "$tool"
                    done
                    success "All /opt tools removed"
                fi
                pause
                ;;
            [Cc])
                > "$INSTALLED_TOOLS_FILE"
                success "Installed tools list cleared"
                pause
                ;;
            [0-9]*)
                if [[ $choice -ge 1 && $choice -le ${#opt_tools[@]} ]]; then
                    local tool="${opt_tools[$((choice-1))]}"
                    read -p "Remove $tool? (y/N): " confirm
                    [[ "$confirm" =~ ^[Yy]$ ]] && uninstall_opt_tool "$tool"
                else
                    error "Invalid selection"
                fi
                pause
                ;;
            *) error "Invalid option"; pause ;;
        esac
    done
}

main_menu() {
    while true; do
        banner
        echo -e "${BOLD}${MAGENTA}Main Menu${NC}"
        echo ""
        echo -e "${GREEN}1)${NC} System Fixes & Maintenance"
        echo -e "${GREEN}2)${NC} Install Tools (by category)"
        echo -e "${GREEN}3)${NC} View Installed Tools"
        echo -e "${GREEN}4)${NC} View Logs"
        echo -e "${GREEN}5)${NC} Uninstall Tools"
        echo ""
        echo -e "${RED}0)${NC} Exit"
        echo ""
        read -p "Select option: " choice
        
        case $choice in
            1) system_menu ;;
            2) tools_menu ;;
            3) view_installed ;;
            4) less "$LOG_FILE" ;;
            5) uninstall_menu ;;
            0) echo -e "\n${CYAN}Thanks for using $SCRIPT_NAME!${NC}\n"; exit 0 ;;
            *) error "Invalid option"; pause ;;
        esac
    done
}

#===============================================================================
# CLI FUNCTIONS
#===============================================================================

show_help() {
    echo -e "${BOLD}$SCRIPT_NAME v$SCRIPT_VERSION${NC} - Parrot OS 7 Enhancement Tool"
    echo ""
    echo -e "${BOLD}USAGE:${NC}"
    echo "    $0 [OPTIONS]"
    echo ""
    echo -e "${BOLD}OPTIONS:${NC}"
    echo "    -h, --help           Show this help message"
    echo "    -n, --dry-run        Preview what would be installed (no changes)"
    echo "    -c, --category CATS  Install only specified categories (comma-separated)"
    echo "    -s, --skip CATS      Skip specified categories (comma-separated)"
    echo "    -l, --list           List all available categories"
    echo "    -a, --all            Install all tools (non-interactive)"
    echo "    -f, --fix            Run all system fixes (non-interactive)"
    echo ""
    echo -e "${BOLD}CATEGORIES:${NC}"
    echo "    recon, scanning, cms, fuzzing, vulnscan, osint, smb, wifi, postexploit"
    echo ""
    echo -e "${BOLD}EXAMPLES:${NC}"
    echo "    $0                              # Interactive menu"
    echo "    $0 --all                        # Install all tools"
    echo "    $0 --dry-run --all              # Preview all installations"
    echo "    $0 -c recon,scanning            # Install only recon and scanning"
    echo "    $0 -s wifi,postexploit          # Install all except wifi and postexploit"
    echo "    $0 --fix                        # Run system fixes only"
    echo ""
    echo -e "${BOLD}ENVIRONMENT:${NC}"
    echo "    GITHUB_TOKEN    Set to avoid GitHub API rate limits"
    echo ""
}

list_categories() {
    echo -e "${BOLD}Available Categories:${NC}"
    echo ""
    for key in "${!CATEGORIES[@]}"; do
        echo -e "  ${CYAN}$key${NC}: ${CATEGORIES[$key]}"
    done | sort
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -n|--dry-run)
                DRY_RUN=true
                CLI_MODE=true
                shift
                ;;
            -a|--all)
                RUN_ALL=true
                CLI_MODE=true
                shift
                ;;
            -f|--fix)
                RUN_FIX=true
                CLI_MODE=true
                shift
                ;;
            -c|--category)
                [[ -z "$2" || "$2" == -* ]] && { error "-c/--category requires a category list"; exit 1; }
                IFS=',' read -ra SELECTED_CATEGORIES <<< "$2"
                CLI_MODE=true
                shift 2
                ;;
            -s|--skip)
                [[ -z "$2" || "$2" == -* ]] && { error "-s/--skip requires a category list"; exit 1; }
                IFS=',' read -ra SKIP_CATEGORIES <<< "$2"
                CLI_MODE=true
                shift 2
                ;;
            -l|--list)
                list_categories
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                echo "Use --help for usage information."
                exit 1
                ;;
        esac
    done
}

# Run selected categories in CLI mode
run_cli_install() {
    banner
    
    if $RUN_FIX; then
        header "Running System Fixes"
        $DRY_RUN && info "[DRY-RUN] Would run all system fixes" || {
            fix_parrot_repos
            fix_broken_packages
            update_parrot
            optimize_parrot
        }
    fi
    
    if $RUN_ALL || [[ ${#SELECTED_CATEGORIES[@]} -gt 0 ]]; then
        should_run_category "recon" && install_recon_tools
        should_run_category "scanning" && install_scanning_tools
        should_run_category "cms" && install_cms_scanners
        should_run_category "fuzzing" && install_fuzzing_tools
        should_run_category "vulnscan" && install_vuln_scanners
        should_run_category "osint" && install_osint_tools
        should_run_category "smb" && install_smb_tools
        should_run_category "wifi" && install_wifi_tools
        should_run_category "postexploit" && install_postexploit_tools
    fi
    
    print_summary
}

#===============================================================================
# MAIN
#===============================================================================

main() {
    parse_args "$@"
    
    check_not_root
    check_sudo
    check_parrot_os
    
    if $CLI_MODE; then
        run_cli_install
    else
        main_menu
    fi
}

main "$@"
