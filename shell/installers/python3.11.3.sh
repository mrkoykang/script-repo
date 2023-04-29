#!/bin/bash
# shellcheck disable=SC2016,SC2034,SC2046,SC2066,SC2068,SC2086,SC2162,SC2317

#####################################
##
## Install python v3.11.3
##
## Supported OS: Linux Debian based
##
#####################################

clear

if [ "$EUID" -eq '0' ]; then
    echo 'You must run this script WITHOUT root/sudo'
    echo
    exit 1
fi

##
## define global variables
##

parent_dir="$PWD"/python3.11.3-build
tar_url='https://github.com/python/cpython/archive/refs/tags/v3.11.3.tar.gz'

##
## define functions
##

fail_fn()
{
    printf "\n%s\n\n%s\n\n" \
        "$1" \
        'Please submit a support ticket in GitHub.'
    exit 1
}

exit_fn()
{
    clear
    printf "%s\n\n%s\n\n" \
        'Make sure to star this repository to show your support!' \
        'https://github.com/slyfox1186/script-repo/'
    exit 0
}

cleanup_fn()
{
    printf "\n%s\n\n%s\n%s\n\n" \
        'Do you want to cleanup the build files?' \
        '[1] Yes' \
        '[2] No'
        read -p 'Your choices are (1 or 2): ' pychoice
        case "$pychoice" in
            1)
                    cd "$parent_dir" || exit 1
                    cd ../ || exit 1
                    sudo rm -r 'python3.11.3-build'
                    exit_fn
                    ;;
            2)
                    exit_fn
                    ;;
            *)
                    read -p 'Bad user input. Press enter to try again'
                    clear
                    cleanup_fn
                    ;;
        esac         
}

success_fn()
{
    echo
    printf "\n%s\n\n" \
        'The installed python version is shown below.'
    python3 --version
    cleanup_fn
}

installed() { return $(dpkg-query -W -f '${Status}\n' "$1" 2>&1 | awk '/ok installed/{print 0;exit}{print 1}'); }

##
## create build folders
##

mkdir -p "$parent_dir"
cd "$parent_dir" || exit 1

##
## install required apt packages
##

pkgs=(build-essential gdb lcov libbz2-dev libffi-dev libgdbm-compat-dev libgdbm-dev \
      liblzma-dev libncurses5-dev libreadline6-dev libsqlite3-dev libssl-dev lzma \
      lzma-dev make pkg-config tk-dev uuid-dev zlib1g-dev)

for pkg in ${pkgs[@]}
do
    if ! installed "$pkg"; then
        missing_pkgs+=" $pkg"
    fi
done

if [ -n "${missing_pkgs-}" ]; then
    printf "%s\n%s\n%s\n\n" \
        'Installing required apt packages' \
        '========================================' \
        '$ sudo apt-get -q -y install'
        for i in "$missing_pkgs"
    do
        sudo apt-get -qq -y install $i
    done
fi

##
## download the python3.11.3 tar file and extract the files into the src directory
##

if ! curl -Lso "$parent_dir"/python3.11.3.tar.gz "$tar_url"; then
    fail_fn 'The tar file failed to download.'
else
    if [ -d "$parent_dir"/python3.11.3 ]; then
        rm -r "$parent_dir"/python3.11.3
    else
        mkdir -p "$parent_dir"/python3.11.3
        if ! tar -zxf "$parent_dir"/python3.11.3.tar.gz -C "$parent_dir"/python3.11.3 --strip-components 1; then
            fail_fn 'The tar command failed to extract any files.'
        fi
    fi
fi

##
## change into the source directory
##

cd "$parent_dir"/python3.11.3 || exit 1

##
## run the bootstrap file to generate any required install files
##

printf "%s\n%s\n%s\n\n" \
    'Configuring system settings' \
    '========================================' \
    '$ ./configure --prefix=/usr/local --enable-optimizations --with-pkg-config=yes'
./configure -q --prefix=/usr/local --enable-optimizations --with-pkg-config=yes

##
## run the ninja commands to install python3.11.3 system-wide
##

printf "%s\n%s\n%s\n\n" \
    'Make generating install files' \
    '========================================' \
    "\$ make -j$(nproc --all)"
if make "-j$(nproc --all)" &>/dev/null; then
    printf "%s\n%s\n%s" \
        'Make installing the system binaries' \
        '========================================' \
        '$ sudo make install'
    if ! sudo make install &>/dev/null; then
        fail_fn 'Make failed to install python3.11.3.'
    else
        success_fn
    fi
else
    fail_fn 'Make failed to generate the install files.'
fi
