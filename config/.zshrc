# ------------------------------------------------------------
# Base PATH + Oh-My-Zsh
# ------------------------------------------------------------
export ZSH="$HOME/.oh-my-zsh"
export PATH="$HOME/bin:$PATH"

# Plugins harus sebelum load oh-my-zsh
plugins=(
  git
  zsh-autosuggestions
  zsh-autocomplete
  zsh-syntax-highlighting
)

# Load oh-my-zsh dulu
source "$ZSH/oh-my-zsh.sh"


# ------------------------------------------------------------
# Alias dan PATH tambahan baru ditaruh setelah ini
# ------------------------------------------------------------

# Starship
eval "$(starship init zsh)"

# NVM
export NVM_DIR="$HOME/.config/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"

# Tools tambahan
export PATH="$PATH:/opt/flutter/bin"

export JAVA_HOME="/usr/lib/jvm/java-21-openjdk-amd64"
export PATH="$JAVA_HOME/bin:$PATH"

export ANDROID_AVD_HOME="$HOME/.config/.android/avd"

# Aliases
alias ls='eza --icons --group-directories-first --all'
alias setproxy='sudo ~/Documents/scripts/set-proxy.sh'
alias resetproxy='sudo ~/Documents/scripts/set-proxy.sh reset'
