dotfiles
===
[![LICENSE](https://img.shields.io/github/license/timo-reymann/dotfiles)](https://github.com/timo-reymann/dotfiles/blob/main/LICENSE)

<p align="center">
	<img width="300" src=".github/logo.png">
    <br />
	Welcome to my home directory (or at least the important gears).
</p>

## Features
- configurations for toolings
- custom helper scripts
- custom fonts
- my cinnamon de configuration
- bash stuff

# Requirements
- [yadm](https://yadm.io/)

## Installation
### Basic
Before initializing yadm stuff, you need to do different stuff,
depending on the platform.

#### Ubuntu
- Install yadm: ``sudo curl -fLo /usr/local/bin/yadm https://github.com/TheLocehiliosan/yadm/raw/master/yadm && sudo chmod a+x /usr/local/bin/yadm``
- Let the bootstrap install the required stuff

#### MacOS
- Install brew
- Install git using brew: `brew install git`
- Install yadm using brew: `brew install yadm`
- Install ansible using brew: `brew install ansible`
- Run bootstrap script
- Enable keyboard layouts manually, they were copied from
  `.osx-keyboardlayouts` and are available under `System Settings >
Keyboard > Input Sources`
- Download and install [VEER](http://veeer.io) to make macos window manager usable

### Advanced (Ubuntu only)
Advanced package configuration and so on can be configured using ansible.

For every class there is a playbook including the basic operations. If
anything special is required, just execute the playbooks seperately.

#### Classes
The following classes are planned/active:

- *work*: Work related config (also applys dev config)
- *dev*: Machine is used for development (so tools are required)
- *mobile*: Device without the need for cinnamon desktop, only basic
  packages will be configured and no devtools installed

The bootstrap file executes the ansible playbooks according to the
class, the convention is `class_<classname>.yml`.

## Motivation
Cause thats what the cool kids do!

## Contributing
There is no real thing to contribute, if you find something strange or
have a question feel free to open a discussion or file an issue :)

