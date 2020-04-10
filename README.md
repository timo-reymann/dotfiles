dotfiles
===

Welcome to my home directory (or at least the important gears).

# Whats in the box?

## Config!
Config for stuff i would like to share on every machine i am using!

## Home-Directory-Stuff
- custom helper scripts
- custom fonts
- my cinnamon de configuration
- bash stuff

# How to get started

## Basic
- Install yadm: ``sudo apt install -y yadm``
- Let the bootstrap install the required stuff
- Decrypt secret files: ``sudo yadm decrypt``

## Advanced
Advanced package configuration and so on can be configured using ansible:

- Cinnamon desktop setup: `cd ~/workspace-setup && ansible-playbook cinnamon_desktop.yml`
- Complete setup (without dev): `cd ~/workspace-setup && ansible-playbook desktop_full.yml`
- Dev setup: `cd ~/workspace-setup && ansible-playbook dev.yml`

