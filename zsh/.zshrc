# common {{{1
if [[ $(uname) = 'Darwin' ]]; then
    IS_MAC=1
elif [[ $(uname) = "Linux" ]];then
    IS_LINUX=1
fi

# Zinit {{{1
export ZINIT_HOME=$HOME/.zinit
## Install zinit
[ -d $ZINIT_HOME ] || git clone https://github.com/zdharma-continuum/zinit $ZINIT_HOME/bin
source $ZINIT_HOME/bin/zinit.zsh
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

## Setting
zinit ice lucid wait'0';zinit light "mollifier/cd-gitroot"
zinit ice lucid wait'0';zinit light "zsh-users/zsh-completions"
# zinit ice lucid wait'0';zinit light "Aloxaf/fzf-tab"
# zstyle ':fzf-tab:*' no-group-color $'\033[1;37m'
zinit light "zsh-users/zsh-autosuggestions"
unset ZSH_AUTOSUGGEST_USE_ASYNC
zinit ice lucid wait'0';zinit light "soimort/translate-shell"
zinit ice as"command" from"gh-r" mv"fd* -> fd" pick"fd/fd"; zinit light sharkdp/fd
zinit ice as"command" from"gh-r" mv"bat* -> bat" pick"bat/bat"; zinit light sharkdp/bat
zinit ice as"command" from"gh-r" mv"ripgrep*/rg -> rg" pick"ripgrep/ripgrep"; zinit light BurntSushi/ripgrep
zinit ice as"command" from"gh-r" mv"gh*/bin/gh -> gh" pick"gh/gh"; zinit light cli/cli
zinit ice as"command" from"gh-r" mv"terraform-lsp* -> terraform-lsp" pick"terraform-lsp/terraform-lsp"; zinit light juliosueiras/terraform-lsp
zinit ice as"command" from"gh-r" mv"jq* -> jq" pick"stedolan/jq"; zinit light stedolan/jq
zinit ice from"gh-r" as"program";zinit light junegunn/fzf-bin
export FZF_DEFAULT_COMMAND='rg --files --hidden --glob "!.git"'
export FZF_DEFAULT_OPTS='--height 40% --reverse --border'
zinit ice from"gh-r" as"program" mv"direnv* -> direnv"; zinit light direnv/direnv
zinit ice as"command"; zinit light simonwhitaker/gibo
### zsh-notify
zinit ice lucid wait'0';zinit light "deresmos/zsh-notify"
zstyle ':notify:*' command-success-timeout 7
zstyle ':notify:*' command-error-timeout 2
zstyle ':notify:*' ignore-success-command "nvim"
zstyle ':notify:*' error-title "_(*/□＼*) (#{time_elapsed} seconds)"
zstyle ':notify:*' success-title "o(≧▽≦)o (#{time_elapsed} seconds)"

# zsh setting {{{1
bindkey -e

setopt auto_cd
setopt auto_menu
setopt auto_list
setopt auto_param_slash
setopt auto_pushd
setopt pushd_ignore_dups
DIRSTACKSIZE=10

setopt nolistbeep
setopt nobeep

autoload -Uz colors; colors

# Style
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([%0-9]#)*=0=01;31'

# Completion
setopt list_packed
setopt extended_glob
unsetopt correct
autoload -Uz compinit && compinit
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*:default' menu select=1
bindkey "^[[Z" reverse-menu-complete

autoload -Uz select-word-style
select-word-style default
zstyle ':zle:*' word-chars " /=;@:,|"
zstyle ':zle:*' word-style unspecified

# exports {{{1
export EDITOR=nvim
export PATH=$HOME/usr/local/bin:$PATH
export PATH="$HOME/.cargo/bin:$PATH"

if [ $IS_LINUX ]; then
	export TERM=xterm-256color
fi

## XDG Base Directory Specification
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"

# Go
export GOPATH=$HOME/go
export PATH=$GOPATH/bin:$PATH

# PHP
export PATH=$HOME/.phpenv/bin:$PATH
export PATH=$HOME/.config/composer/vendor/bin:$PATH

# Neovim
export NVIM_LISTEN_ADDRESS=/tmp/nvimsocket

# ETC
export LD_LIBRARY_PATH=/opt/cuda/lib64:$LD_LIBRARY_PATH:
export CUDA_HOME=/opt/cuda

# Deno
export DENO_INSTALL=$HOME/.deno
export PATH=$DENO_INSTALL/bin:$PATH

# Prompt {{{1
autoload -Uz vcs_info
setopt prompt_subst
# zstyle ':vcs_info:git:*' check-for-changes true
# zstyle ':vcs_info:git:*' stagedstr "!"
# zstyle ':vcs_info:git:*' unstagedstr "+"
zstyle ':vcs_info:*' formats "%F{red}[%b]%f"
zstyle ':vcs_info:*' actionformats '[%b|%a]'
precmd () { 
	print 
	vcs_info 
}

local upper_prompt="%B%F{cyan}[%~]%f%b "
local left_prompt="%B%F{green}[%n%f%F{blue}@%f%F{green}%m%f%F{green}]%(?,,%f%F{red})$%f%b "
local tmp_prompt2="%F{green}%_> %f"
local rprompt="%B%F{cyan}%*%f%b"
local tmp_sprompt="%F{red}%r is correct? [Yes, No, Abort, Edit]:%f"

if [ ${UID} -eq 0 ]; then
	local left_prompt="%B%F{magenta}[%n@%%m%f%(?,,%F{red} x%f)%F{magenta}]$%f%b "
	local tmp_prompt2="%F{magenta}%_> %f"
fi

PROMPT=${upper_prompt}"%B"'${vcs_info_msg_0_}'"%b""
${left_prompt}"
PROMPT2="%B${tmp_prompt2}%b"
RPROMPT=${rprompt}

# History {{{1
HISTFILE=$HOME/.zshistory
HISTSIZE=100000
SAVEHIST=1000000
HISTTIMEFORMAT='%F %T '
HISTCONTROL=ignoreboth
HISTORY_IGNORE="(exit|pwd)"

setopt bang_hist
setopt extended_history
setopt hist_reduce_blanks
setopt hist_save_no_dups
setopt hist_no_store
setopt share_history
setopt inc_append_history
setopt hist_find_no_dups
setopt hist_ignore_space
setopt hist_ignore_all_dups

alias history='history -t $HISTTIMEFORMAT'

autoload -Uz history-search-end
zle -N history-beginning-search-backward-end history-search-end
zle -N history-beginning-search-forward-end history-search-end
bindkey "^p" history-beginning-search-backward-end
bindkey "^n" history-beginning-search-forward-end

# history back
setopt no_flow_control
bindkey '^r' history-incremental-pattern-search-backward
bindkey '^s' history-incremental-pattern-search-forward

# Alias {{{1
alias ls='ls -hp --color'
if [ $IS_MAC ]; then
	alias ls='ls -hpG'
fi

alias l='ls -l'
alias ll='ls -Al'
alias cp='cp -i'
alias mv='mv -i'
alias df='df -h'

if [[ $IS_LINUX ]]; then
	alias pacinst='sudo pacman --needed -S'
	# alias pacinsT='sudo pacman --needed --noconfirm -S'
	alias pacupdate='sudo pacman -Syu'
	alias pacsearch='sudo pacman -Ss'
	alias pacinfo='sudo pacman -Si'
	alias pacpackage='sudo pacman -Ql'
	alias pacrpackage='sudo pacman -Qo'
	alias pacmirrors='sudo pacman-mirrors -g'

	pacrefreshkeys() {
		sudo pacman -Sy archlinux-keyring manjaro-keyring
		sudo pacman-key --populate archlinux manjaro
		sudo pacman-key --refresh-keys 
	}
fi

alias pipall='pip list --outdated --format=freeze | awk "{print $1}" | xargs pip install -U'

if [ $IS_LINUX ]; then
	alias pbcopy='xsel --clipboard --input'
	alias pbpaste='xsel --clipboard --output'
	alias open='xdg-open'
fi

alias vimt='vim -u NONE --noplugin'
alias rc-reload='source ~/.zshrc'
alias rc-open='$EDITOR ~/.zshrc'

alias gitc='git checkout'
alias gitC='git checkout -b'
alias gits='git stash save'
alias gitsp='git stash pop'
alias gitR='git reset --hard'
alias gitr='git reset --mixed'
alias gitp='git push origin HEAD'
alias gitpl='git pull origin'
alias gitall='git add . && git commit && git push'
alias gitpullreq='(){ git fetch origin pull/$1/head:pull/$1/head && git checkout pull/$1/head; }'

alias hl='fc -W'

alias -g L='| less'
alias -g V='| $EDITOR -R -'
alias -g G='| grep'
alias -g W='| wc'
alias -g S='| sed'
alias -g A='| awk'
alias -g F='| fzf'
alias -g FF='$(fzf)'

alias cam-disable='sudo modprobe -r uvcvideo'
alias cam-enable='sudo modprobe -a uvcvideo'

image_viewer='sxiv'
if [ $IS_MAC ]; then
	image_viewer='open -a Preview'
fi

# suffix alias
alias -s {png,jpg,jpeg,bmp,PNG,JPG,BMP}='$image_viewer'
alias -s {gz,tgz,xz,zip,bz2,tar}='aunpack -x --subdir $1'
alias -s {c, cpp}='(){ g++ $1 && shift && ./a.out $@ }'
alias -s {py}='python'
alias -s txt='cat'
alias -s go='go run $1'

autoload -Uz zmv
alias zmv='noglob zmv -W'

alias nvimt='nvr -cc tabnew'
alias nvims='nvr -cc "wincmd p | split"'
alias nvimv='nvr -cc "wincmd p | vsplit"'
alias nvimT='nvr -cc close && nvr -cc tabnew'
alias nvimS='nvr -cc close && nvr -cc split'
alias nvimV='nvr -cc close && nvr -cc vsplit'

# pyenv {{{1
export PYENV_ROOT="${HOME}/.pyenv"
export PATH="${PYENV_ROOT}/bin:${PYENV_ROOT}/shims:${PATH}"

# Lazy load pyenv
if type pyenv > /dev/null; then
    function pyenv() {
        unset -f pyenv
        eval "$(command pyenv init -)"
				eval "$(pyenv virtualenv-init -)"
        pyenv $@
    }
fi

# rbenv {{{1
export RBENV_ROOT="${HOME}/.rbenv"
export PATH="${RBENV_ROOT}/bin:${RBENV_ROOT}/shims:${PATH}"
# Lazy load
if type rbenv > /dev/null; then
    function rbenv() {
        unset -f rbenv
        eval "$(~/.rbenv/bin/rbenv init - zsh)"
        rbenv $@
    }
fi

# nodenv {{{1
export NODENV_ROOT="${HOME}/.nodenv"
export PATH="${NODENV_ROOT}/bin:${NODENV_ROOT}/shims:${PATH}"
# Lazy load
if type nodenv > /dev/null; then
    function nodenv() {
        unset -f nodenv
        eval "$(nodenv init -)"
        nodenv $@
    }
fi

# go environment {{{1
[ -f $HOME/.gvm/scripts/gvm ] && source "$HOME/.gvm/scripts/gvm"

export GOENV_ROOT="$HOME/.goenv"
export PATH="$GOENV_ROOT/bin:$GOENV_ROOT/shims:$PATH"
if type goenv > /dev/null; then
    function goenv() {
        unset -f goenv
        eval "$(goenv init -)"
				export PATH="$GOROOT/bin:$PATH"
				export PATH="$PATH:$GOPATH/bin"
        goenv $@
    }
fi

function save_wheels() {
	[ -d $1 ] || mkdir -p $1
	tmp_dir=$(pwd)
	cd $1

	pip freeze > requirements.txt

	w_dir='wheels'
	[ -d $w_dir ] || mkdir -p $w_dir 
	pip wheel --wheel-dir=$w_dir -r requirements.txt

	cd $tmp_dir
}

function load_wheels() {
	tmp_dir=$(pwd)

	cd $1
	pip install -r requirements.txt --no-index --find-links='wheels'

	cd $tmp_dir
}

# ETC {{{1
export ZSH_RECORDER_PATH=$XDG_CACHE_HOME/zsh-log
function start_recorder() {
	[ -d $ZSH_RECORDER_PATH ] || mkdir -p $ZSH_RECORDER_PATH
	local log_path=$ZSH_RECORDER_PATH/$(date '+%Y%m%d')

	echo "Start script, output file if $log_path"
	if [ $IS_LINUX ]; then
		script -aqf $ZSH_RECORDER_PATH/$(date '+%Y%m%d')
	elif [ $IS_MAC ]; then
		script -aqF $ZSH_RECORDER_PATH/$(date '+%Y%m%d')
	fi
	exit
}

if type direnv > /dev/null; then
 eval "$(direnv hook zsh)"
fi

function rename2serialN() {
  files=$(\ls -v)
  [ -d backup ] || mkdir backup

  i=1
	for file in $(echo $files | xargs -n1 echo) ; do
		echo $file
    if [[ ! -f "$file" ]]; then
      continue
    fi
    ext=${file##*.}

    \cp -f "$file" "backup/$file"
    rename_file=$(printf %03d.${ext} $i)
		echo "Rename ${file} -> ${rename_file}"
		mv $file $rename_file

    i=$(expr $i + 1) 
  done
}

# fzf
[ -d $HOME/.fzf ] || $(git clone --depth 1 https://github.com/junegunn/fzf.git $HOME/.fzf && ~/.fzf/install)
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

if [ -f "$HOME/.zshrc_custom" ]; then source "$HOME/.zshrc_custom"; fi

[ -f ~/.cargo/env ] && source ~/.cargo/env

# The next line updates PATH for the Google Cloud SDK.
if [ -f '$HOME/google-cloud-sdk/path.zsh.inc' ]; then . '$HOME/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '$HOME/google-cloud-sdk/completion.zsh.inc' ]; then . '$HOME/google-cloud-sdk/completion.zsh.inc'; fi

[ -f ~/.cargo/env ] && source ~/.cargo/env
