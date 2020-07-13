# Function to get branch of current directory or empty string if no git folder
git_branch() {
  branch_name=$((git symbolic-ref HEAD 2>/dev/null || echo "")|cut -d/ -f3-)
  if [ ! -z "$branch_name" ]
    then
    echo "  🌳 $branch_name"
  fi
}

virtualenv_info() {
    if [[ -n "$VIRTUAL_ENV" ]]
    then
        # Strip out the path and just leave the env name
        echo "  🐍 ${VIRTUAL_ENV##*/}"
    else
        echo ""
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
alias pdoc="docker ps | peco | awk '{print \$1;}' | tr '\n' ' ' | xargs docker"
alias find-bigboi="sudo du -cks * | sort -rn | head"
alias grep="grep --color=auto"
alias venv="python3 -m venv .venv"
alias venv-activate="source ./.venv/bin/activate"

# shell bookmarks
if [ -f ~/.local/bin/bashmarks.sh ]
then
    source ~/.local/bin/bashmarks.sh
fi

# set gopath
export GOPATH="$HOME/go"
# disable venv prompt
export VIRTUAL_ENV_DISABLE_PROMPT=1
# Add bin
export PATH="$PATH:$HOME/.bin:/usr/local/go/bin:$GOPATH/bin"
# Customize bash colors
export PS1='\n🦄 \[\e[1m\]\[\e[38;5;202m\]\u@\h\[\033[92m\]  📂 \w\[\033[00;96m\]\[\e[1m\]$(git_branch)\[\e[33m\]$(virtualenv_info)\[\033[00m\]  ⏰ $(date "+%H:%m:%S") \[\033[00m\]\n$ '
# Environment variables
export EDITOR=vim

source ~/.bash_completion

# Run neofetch
neofetch

