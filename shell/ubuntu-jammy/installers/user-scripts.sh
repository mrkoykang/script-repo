#!/bin/bash

clear

# Download the user scripts from github
wget -qN - -i 'https://raw.githubusercontent.com/slyfox1186/script-repo/main/shell/ubuntu-jammy/urls/user-scripts.txt'

# Delete any useless files that get downloaded.
if [ -f 'index.html' ]; then sudo rm 'index.html'; fi
if [ -f 'urls.txt' ]; then sudo rm 'urls.txt'; fi

# define variables
scripts='.bash_aliases .bash_functions .bashrc'

# If the shell scripts exist, move them to the users home directory
for i in ${scripts[@]}
do
    if [ -f "${i}" ]; then
        mv -f "${i}" "${HOME}"
        if [ -f "${HOME}/${i}" ]; then
            sudo chown "${USER}":"${USER}" "${HOME}/${i}"
        fi
    else
        clear
        echo 'Script error: The scripts were not found.'
        echo
        echo 'Please create a support ticket.'
        echo
        echo 'https://github.com/slyfox1186/script-repo/issues'
        echo
        exit 1
    fi
done

# execute all scripts in the pihole-regex folder
for files in ${scripts[@]}
do
    if [ -f "${HOME}/${files}" ]; then
        if which gedit &>/dev/null; then
            gedit "${HOME}/${files}"
        elif which nano &>/dev/null; then
            nano "${HOME}/${files}"
        elif which vim &>/dev/null; then
            vim "${HOME}/${files}"
        else
            vi "${files}"
        fi
    fi
done
