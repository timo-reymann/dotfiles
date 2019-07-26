# Function to get branch of current directory or empty string if no git folder
git_branch() {
  output="$(git branch 2> /dev/null | grep '^*' | colrm 1 2)"
  if [ ! -z $output ]
    then
    echo "  🌳 $output"
  fi
}

# Alias definition
alias ll="ls -lisa"
alias update="sudo apt update && sudo apt upgrade -y"
alias diff="git diff \$(git branch | grep \* | cut -d ' ' -f2)"
alias commit="git stage . && git commit -m"
alias gpush="git push"

# Export helper to fix m$ bullshit and utf8 probs
to-utf8() {
    if [ -z "$1" ] || [ ! -e "$1" ]
        then
        echo "❌ Please specify a valid file to fix!"
        return
    fi

    iconv -t UTF-8 "$1" -o "$1" &> /dev/null && \
    dos2unix "$1" &> /dev/null &&
    echo "✔️  Fixed charset and m$ bullshit!"

    if [ $? != 0 ]
    then
        echo "❌ Error processing file ..."
    fi
}
export -f to-utf8

# Export helper for commiting current directory
commit-pwd() {
    if [ -z "$1" ]
    then
        echo "❌ Please specifiy a commit message!"
        return
    fi

    commit "$(basename $PWD) : $1"
}
export -f commit-pwd

# Customize bash colors
export PS1='🦄 \[\e[1m\]\[\e[38;5;202m\]\u@\h  📂 \[\033[92m\]\w\[\033[00;96m\]\[\e[1m\]$(git_branch)\[\033[00m\]\[\033[00m\]\n$ '

# Run neofetch
neofetch
