if status is-interactive
    # Commands to run in interactive sessions can go here
    atuin init fish | source
end

# setup go path
if command -q go
    set -x GOPATH (go env GOPATH)
    set -x PATH $PATH (go env GOPATH)/bin
end

# Show "directory — command" in the terminal window/tab title.
function fish_title
    set -l title (prompt_pwd)
    if test -n "$argv"
        set title "$title — $argv"
    end
    echo $title
end

# Starship prompt with Fish transient prompt support.
if status is-interactive; and command -q starship
    function starship_transient_prompt_func
        starship module character
    end

    starship init fish | source

    # Starship's generated transient handler requires Fish 3.4+ APIs
    # (`commandline --is-valid` and `--paging-mode`). Ubuntu 22.04 ships
    # Fish 3.3, so enable it only on compatible versions.
    if test (string split . $version)[1] -gt 3; or test (string split . $version)[1] -eq 3 -a (string split . $version)[2] -ge 4
        enable_transience
    end
end

# NPM global path configuration
if command -q npm
    # Get the npm prefix directory
    set -l NPM_PREFIX (npm config get prefix)

    # Check if the path exists and isn't already in the PATH
    if test -d "$NPM_PREFIX/bin"
        and not contains "$NPM_PREFIX/bin" $fish_user_paths
        # Add npm global bin directory to fish_user_paths
        set -U fish_user_paths "$NPM_PREFIX/bin" $fish_user_paths
    end

    # Also make npm binaries available through the NODE_PATH environment variable
    if test -d "$NPM_PREFIX/lib/node_modules"
        set -gx NODE_PATH "$NPM_PREFIX/lib/node_modules"
    end
end

# zoxide
# =============================================================================
#
# Utility functions for zoxide.
#

# pwd based on the value of _ZO_RESOLVE_SYMLINKS.
function __zoxide_pwd
    builtin pwd -L
end

# A copy of fish's internal cd function. This makes it possible to use
# `alias cd=z` without causing an infinite loop.
if ! builtin functions --query __zoxide_cd_internal
    if builtin functions --query cd
        builtin functions --copy cd __zoxide_cd_internal
    else
        alias __zoxide_cd_internal='builtin cd'
    end
end

# cd + custom logic based on the value of _ZO_ECHO.
function __zoxide_cd
    __zoxide_cd_internal $argv
end

# =============================================================================
#
# Hook configuration for zoxide.
#

# Initialize hook to add new entries to the database.
function __zoxide_hook --on-variable PWD
    test -z "$fish_private_mode"
    and command zoxide add -- (__zoxide_pwd)
end

# =============================================================================
#
# When using zoxide with --no-cmd, alias these internal functions as desired.
#

if test -z $__zoxide_z_prefix
    set __zoxide_z_prefix 'z!'
end
set __zoxide_z_prefix_regex ^(string escape --style=regex $__zoxide_z_prefix)

# Jump to a directory using only keywords.
function __zoxide_z
    set -l argc (count $argv)
    if test $argc -eq 0
        __zoxide_cd $HOME
    else if test "$argv" = -
        __zoxide_cd -
    else if test $argc -eq 1 -a -d $argv[1]
        __zoxide_cd $argv[1]
    else if set -l result (string replace --regex $__zoxide_z_prefix_regex '' $argv[-1]); and test -n $result
        __zoxide_cd $result
    else
        set -l result (command zoxide query --exclude (__zoxide_pwd) -- $argv)
        and __zoxide_cd $result
    end
end

# Completions.
function __zoxide_z_complete
    set -l tokens (commandline --current-process --tokenize)
    set -l curr_tokens (commandline --cut-at-cursor --current-process --tokenize)

    if test (count $tokens) -le 2 -a (count $curr_tokens) -eq 1
        # If there are < 2 arguments, use `cd` completions.
        complete --do-complete "'' "(commandline --cut-at-cursor --current-token) | string match --regex '.*/$'
    else if test (count $tokens) -eq (count $curr_tokens); and ! string match --quiet --regex $__zoxide_z_prefix_regex. $tokens[-1]
        # If the last argument is empty and the one before doesn't start with
        # $__zoxide_z_prefix, use interactive selection.
        set -l query $tokens[2..-1]
        set -l result (zoxide query --exclude (__zoxide_pwd) --interactive -- $query)
        and echo $__zoxide_z_prefix$result
        commandline --function repaint
    end
end
complete --command __zoxide_z --no-files --arguments '(__zoxide_z_complete)'

# Jump to a directory using interactive search.
function __zoxide_zi
    set -l result (command zoxide query --interactive -- $argv)
    and __zoxide_cd $result
end

# =============================================================================
#
# Commands for zoxide. Disable these using --no-cmd.
#

abbr --erase z &>/dev/null
alias z=__zoxide_z

abbr --erase zi &>/dev/null
alias zi=__zoxide_zi

# =============================================================================
#
# To initialize zoxide, add this to your configuration (usually
# ~/.config/fish/config.fish):
#
#   zoxide init fish | source
if command -q zoxide
    zoxide init fish | source
end

# alias
## EzA
# general use
if command -q eza
    alias ls='eza' # ls
    alias l='eza -lbF --git' # list, size, type, git
    alias ll='eza -lbGF --git' # long list
    alias llm='eza -lbGF --git --sort=modified' # long list, modified date sort
    alias la='eza -lbhHigUmuSa --time-style=long-iso --git --color-scale' # all list
    alias lx='eza -lbhHigUmuSa@ --time-style=long-iso --git --color-scale' # all + extended list

    # speciality views
    alias lS='eza -1' # one column, just names
    alias lt='eza --tree --level=2' # tree
end
alias search="fzf --preview 'bat --color=always --style=numbers --line-range=:500 {}' | xargs nvim"

alias g='git'
#compdef g=git
alias gst='git status'
#compdef _git gst=git-status
alias gd='git diff'
#compdef _git gd=git-diff
alias gdc='git diff --cached'
#compdef _git gdc=git-diff
alias gl='git pull'
#compdef _git gl=git-pull
alias gup='git pull --rebase'
#compdef _git gup=git-fetch
alias gp='git push'
#compdef _git gp=git-push
alias gd='git diff'

function gdv
    git diff -w $argv | view -
end

#compdef _git gdv=git-diff
alias gc='git commit -v'
#compdef _git gc=git-commit
alias gc!='git commit -v --amend'
#compdef _git gc!=git-commit
alias gca='git commit -v -a'
#compdef _git gc=git-commit
alias gca!='git commit -v -a --amend'
#compdef _git gca!=git-commit
alias gcmsg='git commit -m'
#compdef _git gcmsg=git-commit
alias gco='git checkout'
#compdef _git gco=git-checkout
alias gcm='git checkout master'
alias gr='git remote'
#compdef _git gr=git-remote
alias grv='git remote -v'
#compdef _git grv=git-remote
alias grmv='git remote rename'
#compdef _git grmv=git-remote
alias grrm='git remote remove'
#compdef _git grrm=git-remote
alias grset='git remote set-url'
#compdef _git grset=git-remote
alias grup='git remote update'
#compdef _git grset=git-remote
alias grbi='git rebase -i'
#compdef _git grbi=git-rebase
alias grbc='git rebase --continue'
#compdef _git grbc=git-rebase
alias grba='git rebase --abort'
#compdef _git grba=git-rebase
alias gb='git branch'
#compdef _git gb=git-branch
alias gba='git branch -a'
#compdef _git gba=git-branch
alias gcount='git shortlog -sn'
#compdef gcount=git
alias gcl='git config --list'
alias gcp='git cherry-pick'
#compdef _git gcp=git-cherry-pick
alias glg='git log --stat --max-count=10'
#compdef _git glg=git-log
alias glgg='git log --graph --max-count=10'
#compdef _git glgg=git-log
alias glgga='git log --graph --decorate --all'
#compdef _git glgga=git-log
alias glo='git log --oneline'
#compdef _git glo=git-log
alias gss='git status -s'
#compdef _git gss=git-status
alias ga='git add'
#compdef _git ga=git-add
alias gm='git merge'
#compdef _git gm=git-merge
alias grh='git reset HEAD'
alias grhh='git reset HEAD --hard'
alias gclean='git reset --hard; and git clean -dfx'
alias gwc='git whatchanged -p --abbrev-commit --pretty=medium'

#remove the gf alias
#alias gf='git ls-files | grep'

alias gpoat='git push origin --all; and git push origin --tags'
alias gmt='git mergetool --no-prompt'
#compdef _git gm=git-mergetool

alias gg='git gui citool'
alias gga='git gui citool --amend'
alias gk='gitk --all --branches'

alias gsts='git stash show --text'
alias gsta='git stash'
alias gstp='git stash pop'
alias gstd='git stash drop'

# Will cd into the top of the current repository
# or submodule.
alias grt='cd (git rev-parse --show-toplevel or echo ".")'

# Git and svn mix
alias git-svn-dcommit-push='git svn dcommit; and git push github master:svntrunk'
#compdef git-svn-dcommit-push=git

alias gsr='git svn rebase'
alias gsd='git svn dcommit'
#
# Will return the current branch name
# Usage ezample: git pull origin $(current_branch)
#
function current_branch
    git symbolic-ref --short HEAD
end

function current_repository
    set ref (git symbolic-ref HEAD 2> /dev/null); or set ref (git rev-parse --short HEAD 2> /dev/null); or return
    echo (git remote -v | cut -d':' -f 2)
end

# these aliases take advantage of the previous function
alias ggpull='git pull origin (current_branch)'
#compdef ggpull=git
alias ggpur='git pull --rebase origin (current_branch)'
#compdef ggpur=git
alias ggpush='git push origin (current_branch)'
#compdef ggpush=git
alias ggpnp='git pull origin (current_branch); and git push origin (current_branch)'
#compdef ggpnp=git

# Pretty log messages
function _git_log_prettily
    if ! [ -z $1 ]
        then
        git log --pretty=$1
    end
end

alias glp="_git_log_prettily"
#compdef _git glp=git-log

# Work In Progress (wip)
# These features allow to pause a branch development and switch to another one (wip)
# When you want to go back to work, just unwip it
#
# This function return a warning if the current branch is a wip
function work_in_progress
    if git log -n 1 | grep -q -c wip
        then
        echo "WIP!!"
    end
end

# these alias commit and uncomit wip branches
alias gwip='git add -A; git ls-files --deleted -z | xargs -0 git rm; git commit -m "wip"'
alias python=python3

# AWS Profile switching utility
function awsp --description "Switch between AWS profiles"
    if test -f ~/.config/fish/functions/_awsp.fish
        source ~/.config/fish/functions/_awsp.fish
    else if test -f ~/bin/_awsp
        source ~/bin/_awsp
    else if test -f /usr/local/bin/_awsp
        source /usr/local/bin/_awsp
    else
        echo "Could not find _awsp script. Please install it first."
        echo "You can download it with: curl -o ~/.config/fish/functions/_awsp.fish https://raw.githubusercontent.com/antonbabenko/awsp/master/_awsp.fish"
        return 1
    end
end

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
if test -f ~/.orbstack/shell/init2.fish
    source ~/.orbstack/shell/init2.fish 2>/dev/null || :
end
