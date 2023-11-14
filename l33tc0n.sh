#!/bin/bash

# Enable or disable debug mode
DEBUG_MODE="enable"
LOG_FILE="/var/log/l33tc0n_setup.log"
CURRENT_USER=$(logname)
HOME_DIR=$(eval echo ~$CURRENT_USER)

log_message() {
  local GREEN="\033[0;32m"
  local NO_COLOR="\033[0m" # No Color
  local message="${GREEN}$@${NO_COLOR}"

  if [ "$DEBUG_MODE" = "enable" ]; then
    echo -e "$message" | tee -a "$LOG_FILE"
  else
    echo -e "$message"
  fi
}

# Function to execute a command and log it
execute() {
  if [ "$DEBUG_MODE" = "enable" ]; then
    "$@" | tee -a "$LOG_FILE"
  else
    "$@"
  fi
}

# Clear the log file at the beginning of the script
> "$LOG_FILE"

# Check if the script is running as root
if [ "$(id -u)" != "0" ]; then
  log_message "This script must be run as root. Try running this script with sudo."
  exit 1
fi

# Detect the Linux distribution and run updates
os_check_and_update() {
  if grep -q 'Arch' /etc/os-release; then
    # Install reflector for Arch and run it with specified parameters
    execute pacman -Sy --noconfirm reflector
    execute reflector --country 'United States' --protocol http --protocol https --sort rate --threads 7 --latest 42 --save /etc/pacman.d/mirrorlist
    # Now run the system update
    execute pacman -Syu --noconfirm
  elif grep -q 'Red Hat\|Fedora\|CentOS' /etc/os-release; then
    execute yum update -y
  elif grep -q 'SUSE' /etc/os-release; then
    execute zypper update
  elif grep -q 'Debian\|Ubuntu' /etc/os-release; then
    execute apt update && apt upgrade -y
  elif grep -q 'Kali' /etc/os-release; then
    execute apt update && apt upgrade -y
  else
    log_message "Distribution not supported"
    exit 1
  fi
}

# Function to install VMware Tools
install_vmware_tools() {
    log_message "Installing VMware Tools..."
    if command -v pacman &> /dev/null; then
        execute pacman -S open-vm-tools --noconfirm
    elif command -v apt &> /dev/null; then
        execute apt install open-vm-tools -y
    elif command -v yum &> /dev/null; then
        execute yum install open-vm-tools -y
    elif command -v zypper &> /dev/null; then
        execute zypper install open-vm-tools
    fi
    execute systemctl enable vmtoolsd.service
    execute systemctl start vmtoolsd.service
    log_message "VMware Tools installation completed."
}

# Function to install git
install_git() {
    log_message "Installing Git..."
    if command -v pacman &> /dev/null; then
        execute pacman -S git --noconfirm
    elif command -v apt &> /dev/null; then
        execute apt install git -y
    elif command -v yum &> /dev/null; then
        execute yum install git -y
    elif command -v zypper &> /dev/null; then
        execute zypper install git
    fi
    log_message "Git installation completed."
}

# Function to install Alacritty
install_alacritty() {
    log_message "Installing Alacritty..."
    if command -v pacman &> /dev/null; then
        execute pacman -S alacritty --noconfirm
    elif command -v apt &> /dev/null; then
        # Alacritty might not be available in the default repositories for all distributions
        execute add-apt-repository ppa:mmstick76/alacritty
        execute apt install alacritty -y
    elif command -v yum &> /dev/null; then
        # Instructions for Fedora-like distributions
        execute dnf copr enable pschyska/alacritty
        execute dnf install alacritty -y
    elif command -v zypper &> /dev/null; then
        # OpenSUSE might require additional repositories or manual installation
        log_message "Alacritty installation for OpenSUSE needs to be handled manually."
    fi
    log_message "Alacritty installation completed."
}

# Function to install zsh
install_zsh() {
    log_message "Installing Zsh..."
    if command -v pacman &> /dev/null; then
        execute pacman -S zsh --noconfirm
    elif command -v apt &> /dev/null; then
        execute apt install zsh -y
    elif command -v yum &> /dev/null; then
        execute yum install zsh -y
    elif command -v zypper &> /dev/null; then
        execute zypper install zsh
    fi
    log_message "Zsh installation completed."
}

# Function to install Oh My Zsh and plugins
install_oh_my_zsh() {
  log_message "Installing Oh My Zsh and plugins..."

  # Download Oh My Zsh install script
  execute wget https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O install_ohmyzsh.sh

  # Modify the script to skip changing the shell
  sed -i 's/env zsh -l//g' install_ohmyzsh.sh

  # Run the modified script as the current user
  execute runuser -l $CURRENT_USER -c 'sh install_ohmyzsh.sh --unattended'

  ZSH_CUSTOM="$HOME_DIR/.oh-my-zsh/custom"
  execute runuser -l $CURRENT_USER -c "git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
  execute runuser -l $CURRENT_USER -c "git clone https://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions"
  execute runuser -l $CURRENT_USER -c "git clone https://github.com/zsh-users/zsh-completions $ZSH_CUSTOM/plugins/zsh-completions"
  execute runuser -l $CURRENT_USER -c "git clone https://github.com/zsh-users/zsh-history-substring-search $ZSH_CUSTOM/plugins/zsh-history-substring-search"
  execute runuser -l $CURRENT_USER -c "git clone https://github.com/zsh-users/zsh-docker $ZSH_CUSTOM/plugins/zsh-docker"
  
  execute sed -i 's/plugins=(git)/plugins=(git zsh-syntax-highlighting zsh-autosuggestions zsh-completions zsh-history-substring-search zsh-docker)/' "$HOME_DIR/.zshrc"
  log_message "Oh My Zsh and plugins installation completed."
}

# Function to change the default shell to zsh
change_shell_to_zsh() {
  local user_home=$(eval echo ~$CURRENT_USER)
  local zsh_path=$(which zsh)

  if [ -z "$zsh_path" ]; then
    log_message "Zsh is not installed. Skipping shell change."
    return
  fi

  if [ "$(getent passwd $CURRENT_USER | cut -d: -f7)" != "$zsh_path" ]; then
    log_message "Changing default shell to Zsh for user $CURRENT_USER..."
    sudo usermod -s "$zsh_path" "$CURRENT_USER"
    log_message "Default shell changed to Zsh."
  else
    log_message "Default shell is already Zsh."
  fi
}

# Function to install Neovim and packer.nvim
install_neovim() {
  log_message "Installing Neovim and packer.nvim..."
  if command -v pacman &> /dev/null; then
      execute pacman -S neovim --noconfirm
  elif command -v apt &> /dev/null; then
      execute apt install neovim -y
  elif command -v yum &> /dev/null; then
      execute yum install neovim -y
  elif command -v zypper &> /dev/null; then
      execute zypper install neovim
  fi

  NVIM_PACKER_PATH="$HOME_DIR/.local/share/nvim/site/pack/packer/start/packer.nvim"
  execute runuser -l $CURRENT_USER -c "git clone --depth 1 https://github.com/wbthomason/packer.nvim $NVIM_PACKER_PATH"
  
  ROOT_NVIM_PACKER_PATH="/root/.local/share/nvim/site/pack/packer/start/packer.nvim"
  execute git clone --depth 1 https://github.com/wbthomason/packer.nvim $ROOT_NVIM_PACKER_PATH
  
  log_message "Neovim and packer.nvim installation completed."
}

# Run the OS check and update
os_check_and_update

# Call the installation functions
install_vmware_tools
install_git
install_alacritty
install_zsh
install_oh_my_zsh
install_neovim

# Change the shell to zsh
change_shell_to_zsh

log_message "Setup script completed. Rebooting in 7 seconds. Press Ctrl+C to abort reboot..."

# Countdown for 7 seconds
for i in {7..1}; do
    echo -ne "$i... "
    sleep 1
done
echo "!!!REBOOTING!!!"

# Force a reboot
reboot
