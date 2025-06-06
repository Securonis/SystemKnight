#!/bin/bash

# SystemKnight - Malware and Rootkit Scanner Manager for Securonis

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'


LOG_DIR="$(dirname "$(readlink -f "$0")")/logs"
CLAMAV_LOG="$LOG_DIR/clamav_scan_$(date +%Y%m%d_%H%M%S).log"
RKHUNTER_LOG="$LOG_DIR/rkhunter_scan_$(date +%Y%m%d_%H%M%S).log"

# Check if running as root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}Error: This script must be run as root${NC}"
        exit 1
    fi
}

# Check if required tools are installed
check_dependencies() {
    local missing_deps=0
    
    echo -e "${BLUE}Checking dependencies...${NC}"
    
    # Check for ClamAV
    if ! command -v clamscan &> /dev/null; then
        echo -e "${YELLOW}ClamAV is not installed.${NC}"
        missing_deps=1
    else
        echo -e "${GREEN}ClamAV is installed.${NC}"
    fi
    
    # Check for rkhunter
    if ! command -v rkhunter &> /dev/null; then
        echo -e "${YELLOW}rkhunter is not installed.${NC}"
        missing_deps=1
    else
        echo -e "${GREEN}rkhunter is installed.${NC}"
    fi
    
    # Check for lynis
    if ! command -v lynis &> /dev/null; then
        echo -e "${YELLOW}lynis is not installed.${NC}"
        missing_deps=1
    else
        echo -e "${GREEN}lynis is installed.${NC}"
    fi
    
    if [ $missing_deps -eq 1 ]; then
        echo -e "${YELLOW}Would you like to install missing dependencies? (y/n)${NC}"
        read -r install_deps
        if [[ $install_deps =~ ^[Yy]$ ]]; then
            install_dependencies
        else
            echo -e "${RED}Cannot proceed without required dependencies.${NC}"
            exit 1
        fi
    fi
}

# Install dependencies
install_dependencies() {
    echo -e "${BLUE}Installing dependencies...${NC}"
    apt-get update -y
    
    # Install ClamAV if not present
    if ! command -v clamscan &> /dev/null; then
        echo -e "${BLUE}Installing ClamAV...${NC}"
        apt-get install clamav clamav-daemon -y
        systemctl enable clamav-freshclam
        systemctl start clamav-freshclam
    fi
    
    # Install rkhunter if not present
    if ! command -v rkhunter &> /dev/null; then
        echo -e "${BLUE}Installing rkhunter...${NC}"
        apt-get install rkhunter -y
    fi
    
    # Install lynis if not present
    if ! command -v lynis &> /dev/null; then
        echo -e "${BLUE}Installing lynis...${NC}"
        apt-get install lynis -y
    fi
    
    echo -e "${GREEN}Dependencies installed successfully.${NC}"
}

# Update virus definitions
update_definitions() {
    echo -e "${BLUE}Updating virus definitions...${NC}"
    
    # Update ClamAV database
    echo -e "${BLUE}Updating ClamAV database...${NC}"
    freshclam
    
    # Update rkhunter database
    echo -e "${BLUE}Updating rkhunter database...${NC}"
    rkhunter --update
    rkhunter --propupd
    
    echo -e "${GREEN}Virus and rootkit definitions updated successfully.${NC}"
}

# Perform ClamAV scan
clamav_scan() {
    local scan_dir=$1
    local scan_options=$2
    
    echo -e "${BLUE}Starting ClamAV scan on ${scan_dir}...${NC}"
    echo -e "${YELLOW}This may take some time depending on the size of the directory.${NC}"
    
    # Create log directory if it doesn't exist
    mkdir -p "$LOG_DIR"
    
    # Run the scan
    clamscan $scan_options "$scan_dir" | tee "$CLAMAV_LOG"
    
    # Check if any viruses were found
    if grep -q "Infected files: 0" "$CLAMAV_LOG"; then
        echo -e "${GREEN}No viruses found.${NC}"
    else
        echo -e "${RED}Viruses detected! Check the log file for details: ${CLAMAV_LOG}${NC}"
    fi
}

# Perform rkhunter scan
rkhunter_scan() {
    local scan_options=$1
    
    echo -e "${BLUE}Starting rkhunter scan...${NC}"
    echo -e "${YELLOW}This may take some time.${NC}"
    
    # Create log directory if it doesn't exist
    mkdir -p "$LOG_DIR"
    
    # Run the scan
    rkhunter $scan_options | tee "$RKHUNTER_LOG"
    
    echo -e "${GREEN}rkhunter scan completed. Check the log file for details: ${RKHUNTER_LOG}${NC}"
}

# ClamAV scan menu
clamav_menu() {
    clear
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}          SystemKnight - ClamAV Scan        ${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo -e "1. Quick scan (home directory)"
    echo -e "2. Full system scan"
    echo -e "3. Custom directory scan"
    echo -e "4. Scan and remove infected files"
    echo -e "5. Update virus definitions"
    echo -e "6. Back to main menu"
    echo -e "${BLUE}============================================${NC}"
    echo -e "Enter your choice [1-6]: "
    read -r choice
    
    case $choice in
        1)
            clamav_scan "$HOME" "--recursive"
            ;;
        2)
            clamav_scan "/" "--recursive --exclude-dir=/proc --exclude-dir=/sys --exclude-dir=/dev"
            ;;
        3)
            echo -e "Enter the directory path to scan: "
            read -r custom_dir
            if [ -d "$custom_dir" ]; then
                clamav_scan "$custom_dir" "--recursive"
            else
                echo -e "${RED}Invalid directory path.${NC}"
            fi
            ;;
        4)
            echo -e "${YELLOW}WARNING: This will remove infected files. Are you sure? (y/n)${NC}"
            read -r confirm
            if [[ $confirm =~ ^[Yy]$ ]]; then
                echo -e "Enter the directory path to scan and clean: "
                read -r clean_dir
                if [ -d "$clean_dir" ]; then
                    clamav_scan "$clean_dir" "--recursive --remove"
                else
                    echo -e "${RED}Invalid directory path.${NC}"
                fi
            fi
            ;;
        5)
            freshclam
            ;;
        6)
            return
            ;;
        *)
            echo -e "${RED}Invalid option. Please try again.${NC}"
            ;;
    esac
    
    echo -e "\nPress Enter to continue..."
    read -r
    clamav_menu
}

# rkhunter scan menu
rkhunter_menu() {
    clear
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}        SystemKnight - rkhunter Scan        ${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo -e "1. Standard system check"
    echo -e "2. Check with only warnings displayed"
    echo -e "3. Thorough system check"
    echo -e "4. Update rootkit definitions"
    echo -e "5. Configure rkhunter"
    echo -e "6. Back to main menu"
    echo -e "${BLUE}============================================${NC}"
    echo -e "Enter your choice [1-6]: "
    read -r choice
    
    case $choice in
        1)
            rkhunter_scan "--check"
            ;;
        2)
            rkhunter_scan "--check --rwo"
            ;;
        3)
            rkhunter_scan "--check --sk"
            ;;
        4)
            rkhunter --update
            rkhunter --propupd
            ;;
        5)
            echo -e "Opening rkhunter configuration file..."
            ${EDITOR:-nano} /etc/rkhunter.conf
            ;;
        6)
            return
            ;;
        *)
            echo -e "${RED}Invalid option. Please try again.${NC}"
            ;;
    esac
    
    echo -e "\nPress Enter to continue..."
    read -r
    rkhunter_menu
}

# Display ASCII art logo
cat << "EOF"

            _
 _         | |
| | _______| |---------------------------------------------\
| -)_______|==[]============================================>
|_|        | |---------------------------------------------/
           |_|  

EOF

# Install SystemKnight dependencies
install_systemknight() {
    clear
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}       SystemKnight Installation Menu       ${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo -e "Installing dependencies..."
    
    # Install dependencies
    apt-get update -y
    apt-get install clamav clamav-daemon rkhunter -y
    
    # Enable and start services
    systemctl enable clamav-freshclam
    systemctl start clamav-freshclam
    
    # Update virus definitions
    freshclam
    rkhunter --update
    rkhunter --propupd

    echo -e "${GREEN}Installation completed successfully!${NC}"
    echo -e "\nPress Enter to continue..."
    read -r
}

# Setup systemd service functionality was removed

# Perform lynis scan
lynis_scan() {
    local scan_options=$1
    
    echo -e "${BLUE}Starting Lynis scan...${NC}"
    echo -e "${YELLOW}This may take some time.${NC}"
    
    # Create log directory if it doesn't exist
    mkdir -p "$LOG_DIR"
    
    # Set log file path
    LYNIS_LOG="$LOG_DIR/lynis_scan_$(date +%Y%m%d_%H%M%S).log"
    
    # Run the scan
    lynis $scan_options | tee "$LYNIS_LOG"
    
    echo -e "${GREEN}Lynis scan completed. Check the log file for details: ${LYNIS_LOG}${NC}"
}

# Lynis scan menu
lynis_menu() {
    clear
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}          SystemKnight - Lynis Scan         ${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo -e "1. Basic System Audit"
    echo -e "2. Quick Scan (No Pause)"
    echo -e "3. Update Lynis"
    echo -e "4. Check Lynis Controls"
    echo -e "5. Show Lynis Version"
    echo -e "6. Back to Main Menu"
    echo -e "${BLUE}============================================${NC}"
    echo -e "Enter your choice [1-6]: "
    read -r choice
    
    case $choice in
        1)
            lynis_scan "audit system"
            ;;
        2)
            lynis_scan "audit system --quick"
            ;;
        3)
            echo -e "${BLUE}Updating Lynis...${NC}"
            apt-get update
            apt-get install --only-upgrade lynis -y
            ;;
        4)
            lynis show controls | less
            ;;
        5)
            lynis show version
            ;;
        6)
            return
            ;;
        *)
            echo -e "${RED}Invalid option. Please try again.${NC}"
            ;;
    esac
    
    echo -e "\nPress Enter to continue..."
    read -r
    lynis_menu
}

# Main menu
main_menu() {
    while true; do
        clear
        display_logo
        echo -e "${BLUE}============================================${NC}"
        echo -e "${BLUE}                SystemKnight               ${NC}"
        echo -e "${BLUE}     Malware and Rootkit Scan Manager      ${NC}"
        echo -e "${BLUE}============================================${NC}"
        echo -e "1. ClamAV Scan (Malware Detection)"
        echo -e "2. rkhunter Scan (Rootkit Detection)"
        echo -e "3. Lynis Scan (Security Audit)"
        echo -e "4. Update All Definitions"
        echo -e "5. System Information"
        echo -e "6. View Logs"
        echo -e "7. Install Dependencies"
        echo -e "8. Exit"
        echo -e "${BLUE}============================================${NC}"
        echo -e "Enter your choice [1-8]: "
        read -r choice
        
        case $choice in
            1)
                clamav_menu
                ;;
            2)
                rkhunter_menu
                ;;
            3)
                lynis_menu
                ;;
            4)
                update_definitions
                echo -e "\nPress Enter to continue..."
                read -r
                ;;
            5)
                clear
                echo -e "${BLUE}============================================${NC}"
                echo -e "${BLUE}           System Information              ${NC}"
                echo -e "${BLUE}============================================${NC}"
                echo -e "${YELLOW}Hostname:${NC} $(hostname)"
                echo -e "${YELLOW}Kernel:${NC} $(uname -r)"
                echo -e "${YELLOW}OS:${NC} $(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '\"')"
                echo -e "${YELLOW}ClamAV Version:${NC} $(clamscan --version)"
                echo -e "${YELLOW}rkhunter Version:${NC} $(rkhunter --version)"
                echo -e "${YELLOW}Lynis Version:${NC} $(lynis show version)"
                echo -e "${BLUE}============================================${NC}"
                echo -e "\nPress Enter to continue..."
                read -r
                ;;
            6)
                if [ -d "$LOG_DIR" ] && [ "$(ls -A "$LOG_DIR")" ]; then
                    echo -e "${BLUE}Available log files:${NC}"
                    ls -1 "$LOG_DIR"
                    echo -e "\nEnter the log file name to view (or press Enter to go back): "
                    read -r log_file
                    if [ -n "$log_file" ] && [ -f "$LOG_DIR/$log_file" ]; then
                        ${PAGER:-less} "$LOG_DIR/$log_file"
                    fi
                else
                    echo -e "${YELLOW}No log files available.${NC}"
                    echo -e "\nPress Enter to continue..."
                    read -r
                fi
                ;;
            7)
                install_systemknight
                ;;
            8)
                echo -e "${GREEN}Thank you for using SystemKnight. Goodbye!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option. Please try again.${NC}"
                sleep 2
                ;;
        esac
    done
}

# Main execution
check_root
check_dependencies
main_menu
