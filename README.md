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

These dotfiles make use of [yadm](https://yadm.io/) to handle all kinds
of stuff.

## Basic
- Install yadm: ``sudo apt install -y yadm``
- Let the bootstrap install the required stuff
- Decrypt secret files: ``sudo yadm decrypt``

## Advanced
Advanced package configuration and so on can be configured using ansible:

- Cinnamon desktop setup: `cd ~/workspace-setup && ansible-playbook cinnamon_desktop.yml`
- Complete setup (without dev): `cd ~/workspace-setup && ansible-playbook desktop_full.yml`
- Dev setup: `cd ~/workspace-setup && ansible-playbook dev.yml`

## Profiles
The following classes are planned/active:

- *work*: Work related config (also applys dev config)
- *dev*: Machine is used for development (so tools are required)

The bootstrap file executes the ansible playbooks according to the
classes.

Cinnamon setup via playbook must be executed manually, it may be
asked during the bootstrap process.

