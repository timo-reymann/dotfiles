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
Before initializing yadm stuff, you need to do different stuff,
depending on the platform.

### Ubuntu
- Install yadm: ``sudo curl -fLo /usr/local/bin/yadm https://github.com/TheLocehiliosan/yadm/raw/master/yadm && sudo chmod a+x /usr/local/bin/yadm``
- Let the bootstrap install the required stuff

### MacOS
- Install brew
- Install git using brew: `brew install git`
- Install yadm using brew: `brew install yadm`
- Install ansible using brew: `brew install ansible`
- Run bootstrap script
- Enable keyboard layouts manually

## Advanced (Ubuntu only)
Advanced package configuration and so on can be configured using ansible.

For every class there is a playbook including the basic operations. If
anything special is required, just execute the playbooks seperately.

### Classes
The following classes are planned/active:

- *work*: Work related config (also applys dev config)
- *dev*: Machine is used for development (so tools are required)
- *mobile*: Device without the need for cinnamon desktop, only basic
  packages will be configured and no devtools installed

The bootstrap file executes the ansible playbooks according to the
class, the convention is `class_<classname>.yml`.

