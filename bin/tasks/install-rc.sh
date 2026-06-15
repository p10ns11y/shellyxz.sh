#!/usr/bin/env bash
# Install managed rc and login dotfiles from templates.

T="$CONFIG_DIR/templates"

install_managed_rc "$T/zshrc" "$HOME/.zshrc" "$HOME/.zshrc"
install_managed_rc "$T/bashrc" "$HOME/.bashrc" "$HOME/.bashrc"
install_managed_rc "$T/fish.config.fish" "$HOME/.config/fish/config.fish" "fish config"
install_managed_rc "$T/login/zprofile" "$HOME/.zprofile" "zprofile"
install_managed_rc "$T/login/zshenv" "$HOME/.zshenv" "zshenv"
install_managed_rc "$T/login/profile" "$HOME/.profile" "profile"
install_managed_rc "$T/login/bash_profile" "$HOME/.bash_profile" "bash_profile"
