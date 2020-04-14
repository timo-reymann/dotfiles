# Function to get branch of current directory or empty string if no git folder
git_branch() {
  output="$(git branch 2> /dev/null | grep '^*' | colrm 1 2)"
  if [ ! -z $output ]
    then
    echo "  🌳 $output"
  fi
}

# Alias definition
alias ls="ls --color=auto"
alias ll="ls -lisah"
alias update="sudo apt update && sudo apt upgrade -y"
alias diff="git diff \$(git branch | grep \* | cut -d ' ' -f2)"
alias commit="git stage . && git commit -m"
alias gpush="git push"
alias gpull="git pull --rebase --all --recurse-submodules"
alias gpull-all="find . -maxdepth 3 -name .git -type d | rev | cut -c 6- | rev | xargs -I {} git -C {} pull"
alias suvi="sudo vim"
alias pls="sudo \$(fc -n -l -1 -1)"
alias flush-dns="sudo systemd-resolve --flush-caches"
alias hsearch="history | peco"
alias pdoc="docker ps | peco | awk '{print \$1;}' | tr '\n' ' ' | xargs docker"

# shell bookmarks
if [ -f ~/.local/bin/bashmarks.sh ]
then
    source ~/.local/bin/bashmarks.sh
fi

# Add bin
export PATH="$PATH:$HOME/.bin:/usr/local/go/bin"

# Customize bash colors
export PS1='\n🦄 \[\e[1m\]\[\e[38;5;202m\]\u@\h 📂 \[\033[92m\]\w\[\033[00;96m\]\[\e[1m\]$(git_branch)\[\033[00m\] ⏰ $(date "+%H:%m:%S") \[\033[00m\]\n$ '

# Environment variables
export EDITOR=vim

# Run neofetch
neofetch

