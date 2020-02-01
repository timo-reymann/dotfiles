#!/bin/bash
#
# Shell script for setting up a host with my basic preferences on Debian-based OS
#
# basic packages
sudo apt-get -y install \
    neofetch \
    vim

# vim customization
curl -L https://bit.ly/janus-bootstrap | bash

# install shell bookmarks
cd /tmp && \
rm -rf bashmarks && \
git clone git://github.com/huyng/bashmarks.git && \
cd /tmp/bashmarks && \
make install
