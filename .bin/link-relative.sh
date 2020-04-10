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
  echo "❌ Please specify a valid relative path"
  exit 1
fi

target=$HOME/$1
source=$PWD/$1

if [ -e $target ]
then
  result=$(ask "Target already exists, want to remove it first?")
  if [ $result ]
  then
    echo "🗑️ Deleting $target"
    rm -rf $target
  fi
fi

target_dir="$(dirname $target)"
if [ ! -d "$target_dir" ]
then
  result=$(ask "One or more parent folders are missing, do you want to create them?")
  if [ $result ]
  then
    echo "🌟 Creating $target_dir ..."
    mkdir -p "$target_dir"
  fi
fi


echo "🔗 $source -> $target"
ln -s $source $target

if [ $? = 0 ]
then
  echo "✔️  Symlink for $source created!"
else
  echo "❌ Error setting symlink!"
fi