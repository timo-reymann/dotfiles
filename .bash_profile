# Function to get branch of current directory or empty string if no git folder
__git_branch() {
  branch_name=$((git symbolic-ref HEAD 2>/dev/null || echo "")|cut -d/ -f3-)
  if [ ! -z "$branch_name" ]
    then
    echo "  🌳 $branch_name"
  fi
}

__virtualenv_info() {
    if [[ -n "$VIRTUAL_ENV" ]]
    then
        # Strip out the path and just leave the env name
        echo "  🐍 ${VIRTUAL_ENV##*/}"
    else
        echo ""
    fi
}

__secrets_loaded() {
    if [[ -n "$LOADED_SECRETS" ]]
    then
        echo "  🔑${LOADED_SECRETS}"
    else
        echo ""
    fi
}

__load_secret() {
    if [[ ! -f "${HOME}/.secrets/${1}.env" ]]
    then
        echo "Secret not found"
        return
    fi

    . _load-env-file "${HOME}/.secrets/${1}.env"

    if  ! echo $LOADED_SECRETS | grep -w -q $1
    then
        export LOADED_SECRETS="$LOADED_SECRETS $1"
    fi
}

__awsume_active_profile() {
    if [[ -n "$AWSUME_PROFILE" ]]
    then
        echo "  ☁️  ${AWSUME_PROFILE}"
    else
        echo ""
    fi
}

__awsume_with_retry() {
    . awsume "$@"
    if [[ $? -gt 0 ]] && [[ ! -z "$1" ]]; then
        echo " * Awsume called and profile specified, running initial login"
        aws-sso-util login --profile "$1"
        echo " * Running awsume again"
        awsume "$@"
    fi
}

# Alias definition
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
alias webp-convert="docker run -v \$PWD:/workspace --rm -it timoreymann/webp-utils cwebp --config /etc/webp-utils/default_configuration.json --file-glob "
alias webp-convert="docker run -v \$PWD:/workspace --rm -it timoreymann/webp-utils cwebp --config /etc/webp-utils/default.json --file-glob "
alias awsume="__awsume_with_retry"
alias load-env-file=". _load-env-file"
alias load-secret="__load_secret"

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
export PS1='\n🦄 \[\e[1m\]\[\e[38;5;202m\]\u@\h\[\033[36m\]  📂 \w \[\033[00m\] ⏰ $(date "+%H:%M:%S")\[\033[00m\]\[\e[33m\]\[\033[00;92m\]\[\e[1m\]$(__git_branch)\[\033[96m\]$(__virtualenv_info)\[\033[93m\]$(__secrets_loaded)\[\033[00;34m\]\[\e[1m\]$(__awsume_active_profile)\[\033[00m\]\n$ '
# Environment variables
export EDITOR=vim

source ~/.bash_completion

if [[ "$OSTYPE" == "darwin"* ]]
then
    source ~/.bashrc > /dev/null || true
fi

if tty -s;
then
    # Run neofetch
    neofetch
fi



# Added by Toolbox App
export PATH="$PATH:/home/timo/.local/share/JetBrains/Toolbox/scripts"

# Added by Toolbox App
export PATH="$PATH:/usr/local/bin"

