# Function to get branch of current directory or empty string if no git folder
git_branch() {
  output="$(git branch 2> /dev/null | grep '^*' | colrm 1 2)"

  if [ ! -z $output ]
    then
    echo " 🌳$output"
  fi
}

# Customize bash colors
export PS1='🦄\[\e[1m\]\[\e[38;5;202m\]\u@\h 📂\[\033[92m\]\w\[\033[00;96m\]\[\e[1m\]$(git_branch)\[\033[00m\]\[\033[00m\]\n$ '

# Alias definition
alias ll="ls -lisa"
alias update="sudo apt update && sudo apt upgrade -y"
alias diff="git diff $(git branch | grep \* | cut -d ' ' -f2)"
alias commit="git stage . && git commit -m"
alias gpush="git push"

# Run neofetch
neofetch
