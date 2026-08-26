#!/usr/bin/env bash
# auto-bspwm — automated bspwm environment for Kali Linux
# Author: Juan Rivas (aka @r1vs3c)

set -euo pipefail

# ============================================================
# Constants & colors
# ============================================================
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly FONT_DIR="${HOME}/.local/share/fonts"
readonly WALLPAPER_DIR="${HOME}/Wallpapers"
readonly POLYBAR_DIR="${HOME}/.config/polybar"

readonly GREEN="\e[0;32m\033[1m"
readonly RED="\e[0;31m\033[1m"
readonly BLUE="\e[0;34m\033[1m"
readonly YELLOW="\e[0;33m\033[1m"
readonly PURPLE="\e[0;35m\033[1m"
readonly TURQUOISE="\e[0;36m\033[1m"
readonly GRAY="\e[0;37m\033[1m"
readonly RESET="\033[0m\e[0m"

# ============================================================
# Logging helpers
# ============================================================
info()    { echo -e "\n${BLUE}[*]${RESET} $*"; }
success() { echo -e "\n${GREEN}[+]${RESET} $*"; }
warn()    { echo -e "\n${YELLOW}[!]${RESET} $*"; }
error()   { echo -e "\n${RED}[-]${RESET} $*" >&2; }
step()    { echo -e "\n${PURPLE}[*]${RESET} $*"; }

# ============================================================
# Signal & error handling
# ============================================================
trap on_interrupt INT
trap 'on_error $LINENO' ERR

on_interrupt() {
	error "Exiting (Ctrl+C)..."
	exit 130
}

on_error() {
	local exit_code=$?
	error "Script failed at line $1 (exit code ${exit_code})"
	exit "${exit_code}"
}

# ============================================================
# Banner
# ============================================================
banner() {
	echo -e "\n${TURQUOISE}              _____            ______"
	sleep 0.05
	echo -e "______ ____  ___  /______      ___  /___________________      ________ ___"
	sleep 0.05
	echo -e "_  __ \`/  / / /  __/  __ \\     __  __ \\_  ___/__  __ \\_ | /| / /_  __ \`__ \\"
	sleep 0.05
	echo -e "/ /_/ // /_/ // /_ / /_/ /     _  /_/ /(__  )__  /_/ /_ |/ |/ /_  / / / / /"
	sleep 0.05
	echo -e "\\__,_/ \\__,_/ \\__/ \\____/      /_.___//____/ _  .___/____/|__/ /_/ /_/ /_/    ${RESET}${YELLOW}(${RESET}${GRAY}By ${RESET}${PURPLE}@r1vs3c${RESET}${YELLOW})${RESET}${TURQUOISE}"
	sleep 0.05
	echo -e "                                             /_/${RESET}"
}

# ============================================================
# Preflight checks
# ============================================================
preflight() {
	if [[ "${EUID}" -eq 0 ]]; then
		error "Do not run this script as root."
		exit 1
	fi

	for cmd in sudo apt curl git; do
		if ! command -v "${cmd}" >/dev/null 2>&1; then
			error "Required command not found: ${cmd}"
			exit 1
		fi
	done

	if [[ ! -f "${SCRIPT_DIR}/setup.sh" ]]; then
		error "Cannot locate the project directory (SCRIPT_DIR=${SCRIPT_DIR})."
		exit 1
	fi
}

# ============================================================
# Packages
# ============================================================
# Core packages — these must install successfully
readonly APT_CORE=(
	# Window manager / hotkey / compositor / bars
	bspwm sxhkd picom polybar
	# Terminals & shell
	kitty zsh
	# Launcher, file manager, wallpaper, locker, screenshot
	rofi thunar feh i3lock scrot flameshot imagemagick
	# System info / utilities
	fastfetch htop tty-clock cmatrix
	# Clipboard, audio, network
	xclip pamixer iproute2
	# CLI quality-of-life
	ranger fzf lsd bat
	# ZSH plugins (sourced by .zshrc)
	zsh-syntax-highlighting zsh-autosuggestions
	# Required by helper scripts / configs
	# (wmname has no standalone package in Kali/Debian; suckless-tools provides it)
	procps suckless-tools
	# Python tooling for pywal16
	python3-pip python3-venv pipx
)

# Optional packages — install if available, warn otherwise
readonly APT_OPTIONAL=(
	firefox-esr
	burpsuite
	scrub
)

install_packages() {
	info "Updating apt cache..."
	sudo apt update

	info "Installing ${#APT_CORE[@]} core packages..."
	sudo apt install -y "${APT_CORE[@]}"

	info "Installing optional packages (failures are non-fatal)..."
	for pkg in "${APT_OPTIONAL[@]}"; do
		if ! sudo apt install -y "${pkg}"; then
			warn "Optional package not available: ${pkg} (skipped)"
		fi
	done

	install_pywal16
}

install_pywal16() {
	if command -v wal >/dev/null 2>&1; then
		info "pywal already installed: $(command -v wal)"
		return 0
	fi

	step "Installing pywal16 (maintained fork of pywal)..."
	# pipx is the modern way to install user-level CLI tools (PEP 668 friendly)
	if command -v pipx >/dev/null 2>&1; then
		pipx install pywal16 || pipx install --force pywal16
		pipx ensurepath
	else
		# Fallback: pip3 with --break-system-packages if needed
		pip3 install --user --break-system-packages pywal16 \
			|| pip3 install --user pywal16
	fi
	export PATH="${HOME}/.local/bin:${PATH}"
}

# ============================================================
# Fonts
# ============================================================
install_fonts() {
	step "Installing fonts to ${FONT_DIR}..."
	mkdir -p "${FONT_DIR}"
	cp -rf "${SCRIPT_DIR}/fonts/"* "${FONT_DIR}/"
	fc-cache -f "${FONT_DIR}" >/dev/null 2>&1 || true
}

# ============================================================
# Oh My Zsh + Powerlevel10k (idempotent)
# ============================================================
install_omz_for_user() {
	local home_dir=$1
	local sudo_prefix=$2  # "" for current user, "sudo" for root

	if [[ -d "${home_dir}/.oh-my-zsh" ]]; then
		info "Oh My Zsh already present in ${home_dir}, skipping installer."
	else
		# --keep-zshrc prevents the installer from overwriting our config
		${sudo_prefix} sh -c \
			"$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
			"" --unattended --keep-zshrc
	fi

	local p10k_dir="${home_dir}/.oh-my-zsh/custom/themes/powerlevel10k"
	if [[ -d "${p10k_dir}" ]]; then
		info "Powerlevel10k present in ${home_dir}, pulling latest..."
		${sudo_prefix} git -C "${p10k_dir}" pull --depth=1 --quiet || true
	else
		${sudo_prefix} git clone --depth=1 \
			https://github.com/romkatv/powerlevel10k.git "${p10k_dir}"
	fi
}

install_zsh_setup() {
	step "Installing Oh My Zsh & Powerlevel10k for $(whoami)..."
	install_omz_for_user "${HOME}" ""

	step "Installing Oh My Zsh & Powerlevel10k for root..."
	install_omz_for_user "/root" "sudo"
}

# ============================================================
# Wallpapers + pywal color extraction
# ============================================================
configure_wallpaper() {
	step "Configuring wallpapers..."
	mkdir -p "${WALLPAPER_DIR}"
	cp -rf "${SCRIPT_DIR}/wallpapers/"* "${WALLPAPER_DIR}/"

	if command -v wal >/dev/null 2>&1; then
		wal -nqi "${WALLPAPER_DIR}/archkali.png" || warn "pywal failed (user)"
		sudo -E env "PATH=${PATH}" wal -nqi "${WALLPAPER_DIR}/archkali.png" \
			|| warn "pywal failed (root)"
	else
		warn "'wal' command not found, skipping color generation."
	fi
}

# ============================================================
# Dotfiles
# ============================================================
configure_dotfiles() {
	step "Installing config files to ~/.config/..."
	mkdir -p "${HOME}/.config"
	cp -rf "${SCRIPT_DIR}/config/"* "${HOME}/.config/"

	step "Installing .zshrc and .p10k.zsh..."
	cp -f "${SCRIPT_DIR}/.zshrc" "${HOME}/.zshrc"
	cp -f "${SCRIPT_DIR}/.p10k.zsh" "${HOME}/.p10k.zsh"

	# Symlink to root so both users share the same source of truth
	sudo ln -sf "${HOME}/.zshrc" /root/.zshrc
	sudo ln -sf "${HOME}/.p10k.zsh" /root/.p10k.zsh
}

# ============================================================
# Helper scripts + polybar HTB target (shared across themes)
# ============================================================
install_scripts() {
	step "Installing helper scripts..."

	sudo install -m 0755 "${SCRIPT_DIR}/scripts/whichSystem.py" \
		/usr/local/bin/whichSystem.py

	# Blurred-screenshot screen locker (replaces abandoned i3lock-fancy)
	sudo install -m 0755 "${SCRIPT_DIR}/scripts/lockscreen.sh" \
		/usr/local/bin/lockscreen

	# Single source of truth for the current HTB target (theme-independent)
	local target_file="${POLYBAR_DIR}/target"
	mkdir -p "${POLYBAR_DIR}"
	touch "${target_file}"

	# Copy polybar shell scripts into each theme's scripts/ directory
	# and symlink the central target file so all themes share state.
	for theme_dir in "${POLYBAR_DIR}"/*/; do
		local scripts_dir="${theme_dir}scripts"
		if [[ -d "${scripts_dir}" ]]; then
			cp -f "${SCRIPT_DIR}"/scripts/*.sh "${scripts_dir}/" 2>/dev/null || true
			ln -sf "${target_file}" "${scripts_dir}/target"
		fi
	done

	# Mirror the central target file for root so settarget works there too
	sudo mkdir -p /root/.config/polybar
	sudo ln -sf "${target_file}" /root/.config/polybar/target
}

# ============================================================
# Permissions
# ============================================================
fix_permissions() {
	step "Adjusting permissions..."
	[[ -d "${HOME}/.config/bspwm" ]] && chmod -R +x "${HOME}/.config/bspwm/"
	[[ -f "${POLYBAR_DIR}/launch.sh" ]] && chmod +x "${POLYBAR_DIR}/launch.sh"
	find "${POLYBAR_DIR}" -type f -name '*.sh' -exec chmod +x {} +

	# zsh completion for bspc, shipped by the bspwm package
	if [[ -f /usr/share/zsh/vendor-completions/_bspc ]] \
		|| [[ -f /usr/share/zsh/site-functions/_bspc ]]; then
		info "bspc zsh completion already in place."
	fi
}

# ============================================================
# Cleanup hint (never auto-delete the repo we ran from)
# ============================================================
cleanup_hint() {
	echo
	info "Repo not auto-removed for safety."
	echo -e "    To remove the cloned project, run: ${GRAY}rm -rf '${SCRIPT_DIR}'${RESET}"
}

# ============================================================
# Reboot prompt
# ============================================================
prompt_reboot() {
	while true; do
		read -rp "$(echo -e "\n${YELLOW}[?]${RESET} Restart the system now? ([y]/n) ")" -n 1 reply
		echo
		reply=${reply:-y}
		case "${reply}" in
			[Yy]) info "Restarting..."; sleep 1; sudo reboot ;;
			[Nn]) success "Skipping reboot. Manual reboot recommended."; exit 0 ;;
			*)    warn "Invalid response." ;;
		esac
	done
}

# ============================================================
# Main
# ============================================================
main() {
	banner
	sleep 1

	preflight

	info "Starting installation. This may take several minutes..."
	install_packages
	install_fonts
	install_zsh_setup
	configure_dotfiles
	configure_wallpaper
	install_scripts
	fix_permissions

	success "Environment configured. ✅"
	cleanup_hint
	prompt_reboot
}

main "$@"
