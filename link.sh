#!/bin/bash

ask() {
  message=$1
  
  read -r -p "🤔 $message [y/n] " input

  case $input in [yY][eE][sS]|[yY])
    echo 1
  ;; *)
    echo ""
  ;;
  esac
}

if [ -z "$1" ] || [ ! -e "$1" ]
then
  echo "Please specify the relative path"
  exit 1
fi

target=$HOME/$1
source=$PWD/$1

echo "🔗 $source -> $target"

if [ -e $target ]
then
  result=$(ask "Target already exists, want to remove it first?")
  if [ $result ]
  then
    echo "Deleting"
  fi
fi

ln -s $source $target
