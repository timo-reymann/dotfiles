# Function to get branch of current directory or empty string if no git folder
git_branch() {
  echo "$(git branch 2> /dev/null | grep '^*' | colrm 1 2)"
}

# Customize bash colors
export PS1="\[\033[94m\]\w\[\033[00;96m\] $(git_branch)\[\033[00m\] \[\033[00;92m\]→\[\033[00m\]  "

# Alias definition
alias ll="ls -lisa"
alias update="sudo apt update && sudo apt upgrade -y"
alias diff="git diff $(git branch | grep \* | cut -d ' ' -f2)"
alias commit="git stage . && git commit -m"

# Run neofetch
neofetch
