#!/bin/bash
# shellcheck disable=SC2034,SC2046,SC2066,SC2068,SC2086,SC2162,SC2317

################################################################################
##
##  GitHub: https://github.com/slyfox1186/script-repo
##
##  Install: GCC 11.4.0 /  12.3.0 / 13.1.0
##
##  Supported OS: Linux Ubuntu - 22.04 (Jammy)
##
##  Updated: 06.18.23
##
##  Script Version: 3.1
##
##  Added: Multiple support libraries using the latest versions available
##  Added: Custom LIBRARY_PATH variables for each version of GCC compiled
##
################################################################################

clear

if [ "$EUID" -eq '0' ]; then
    printf "\n%s\n\n" 'You must run this script WITHOUT root/sudo'
    exit 1
fi

#
# CREATE SCRIPT VARIABLES
#

script_ver='3.1'
cwd="$PWD"/gcc-build-script
packages="$cwd"/packages
workspace="$cwd"/workspace
gcc_install_dir='/usr/local'
libs_install_dir='/usr/local'
CFLAGS=' -Wl,-s -Wl,-Bsymbolic -Wl,--gc-sections'
CPPFLAGS="-I$workspace/include -I/usr/local/include -I/usr/include -I/usr/local/cuda-12.1/nvvm/include -I/usr/local/cuda/include"
CPPFLAGS+=' -I/usr/include/x86_64-linux-gnu -I/usr/lib/gcc/x86_64-linux-gnu/8/include -I/usr/lib/gcc/x86_64-linux-gnu/9/include'
LDFLAGS="-L$workspace/lib64 -L$workspace/lib -L$workspace/lib/x86_64-linux-gnu -L/usr/local/lib64 -L/usr/local/lib -L/usr/local/cuda-12.1/nvvm/lib64"
LDFLAGS+=' -L/usr/lib/x86_64-linux-gnu -L/usr/local/cuda-12.1/targets/x86_64-linux/lib -L/usr/share/ant/lib -L/usr/lib'
LDFLAGS+=' -L/usr/lib/gcc/x86_64-linux-gnu/12/adalib -L/lib/x86_64-linux-gnu -L/lib -L/usr/x86_64-linux-gnux32/lib'
repo='https://github.com/slyfox1186/script-repo'
# CHANGE THE DEBUG VARIABLE BELOW TO "ON" TO HELP TROUBLESHOOT BUGS DURING THE BUILD
debug=OFF

#
# SET THE AVAILABLE CPU THREAD AND CORE COUNT FOR PARALLEL PROCESSING (SPEEDS UP THE BUILD PROCESS)
#

if [ -f '/proc/cpuinfo' ]; then
    cpu_threads="$(grep -c ^processor '/proc/cpuinfo')"
else
    cpu_threads="$(nproc --all)"
fi

#
# CREATE OUTPUT DIRECTORIES
#

mkdir -p "$packages" "$workspace"

#
# SET GLOBAL VARIABLES
#

PATH="\
/usr/lib/ccache:\
$workspace/bin:\
/usr/bin/x86_64-linux-gnu-ld:\
$HOME/.local/bin:\
$HOME/.cargo/bin:\
/usr/local/sbin:\
/usr/local/bin:\
/usr/sbin:\
/usr/bin:\
/sbin:\
/bin:\
/usr/local/cuda/bin:\
/snap/bin\
"
export PATH

#
# EXPORT THE PKG-CONFIG PATHS TO ENABLE SUPPORT DURING THE BUILD
#

PKG_CONFIG_PATH="\
$workspace/lib/pkgconfig:\
$workspace/lib64/pkgconfig:\
$workspace/share/pkgconfig:\
$workspace/lib/x86_64-linux-gnu/pkgconfig:\
$workspace/usr/lib/pkgconfig:\
/lib/pkgconfig:\
/usr/local/lib/x86_64-linux-gnu/pkgconfig:\
/usr/local/lib64/pkgconfig:\
/usr/local/lib/pkgconfig:\
/usr/local/share/pkgconfig:\
/usr/share/pkgconfig:\
/usr/lib/x86_64-linux-gnu/pkgconfig:\
/usr/lib/pkgconfig\
"
export PKG_CONFIG_PATH

#
# CREATE FUNCTIONS
#

exit_fn()
{
    printf "\n%s\n\n%s\n%s\n\n" \
        'The script has completed' \
        'Make sure to star this repository to show your support!' \
        "$repo"
    exit 0
}

fail_fn()
{
    printf "\n\n%s\n\n%s\n\n%s\n\n" \
        "$1" \
        'Please create a support ticket so I can work on a fix.' \
        "$repo/issues"
    exit 1
}

cleanup_fn()
{
    local answer

    printf "\n%s\n\n%s\n%s\n\n" \
        'Do you want to remove the build files?' \
        '[1] Yes' \
        '[2] No'
    read -p 'Your choices are (1 or 2): ' answer

    case "$answer" in
        1)      sudo rm -fr "$cwd" "$0";;
        2)      return 0;;
        *)
                printf "%s\n\n" 'Bad user input.'
                read -p 'Press enter to try again.'
                clear
                cleanup_fn
                ;;
    esac
}

show_ver_fn()
{
    clear

    if [ ! -f "$gcc_install_dir"/bin/gcc-11 ]; then
        fail_fn "Could not find the file: $gcc_install_dir/bin/gcc-11"
        elif [ ! -f "$gcc_install_dir"/bin/gcc-12 ]; then
            fail_fn "Could not find the file: $gcc_install_dir/bin/gcc-12"
            elif [ ! -f "$gcc_install_dir"/bin/gcc-13 ]; then
                fail_fn "Could not find the file: $gcc_install_dir/bin/gcc-13"
    else
        printf "%s\n\n" 'The installed gcc versions are:'
        sudo "$gcc_install_dir/bin/gcc-11" -v
        echo
        sudo "$gcc_install_dir/bin/gcc-12" -v
        echo
        sudo "$gcc_install_dir/bin/gcc-13" -v
        echo
    fi
}

lib_path_other_fn()
{
    LIBRARY_PATH+="\
/usr/x86_64-linux-gnu/lib/x86_64-linux-gnu:\
/usr/x86_64-linux-gnu/lib64:\
/usr/x86_64-linux-gnu/lib:\
/usr/local/x86_64-pc-linux-gnu/lib64:\
/usr/local/x86_64-pc-linux-gnu/lib:\
/usr/local/lib/x86_64-linux-gnu:\
/usr/local/lib64:\
/usr/local/lib:\
/usr/local/cuda/targets/x86_64-linux/lib:\
/usr/lib/x86_64-linux-gnu/libfakeroot:\
/usr/lib/x86_64-linux-gnu64:\
/usr/lib/x86_64-linux-gnu:\
/usr/libx32:\
/usr/lib64:\
/usr/lib32:\
/usr/lib:\
/lib/x86_64-linux-gnu:\
/lib/i386-linux-gnu:\
/libx32:\
/lib64:\
/lib32:\
/lib\
"
    export LIBRARY_PATH
}

lib_path_gcc11_fn()
{
    LIBRARY_PATH="\
/usr/x86_64-linux-gnu/lib/x86_64-linux-gnu/11:\
/usr/local/x86_64-pc-linux-gnu/lib/x86_64-pc-linux-gnu/11:\
/usr/local/lib/x86_64-pc-linux-gnu/11:\
/usr/local/lib/gcc/x86_64-pc-linux-gnu/11:\
/usr/lib/x86_64-pc-linux-gnu/11:\
/usr/lib/x86_64-linux-gnu/11:\
/usr/lib/gcc/x86_64-linux-gnu/11:\
/lib/x86_64-pc-linux-gnu/11:\
/lib/x86_64-linux-gnu/11:\
"
    lib_path_other_fn
}

lib_path_gcc12_fn()
{
    unset LIBRARY_PATH
    LIBRARY_PATH="\
/usr/x86_64-linux-gnu/lib/x86_64-linux-gnu/12:\
/usr/local/x86_64-pc-linux-gnu/lib/x86_64-pc-linux-gnu/12:\
/usr/local/lib/x86_64-pc-linux-gnu/12:\
/usr/local/lib/gcc/x86_64-pc-linux-gnu/12:\
/usr/lib/x86_64-pc-linux-gnu/12:\
/usr/lib/x86_64-linux-gnu/12:\
/usr/lib/gcc/x86_64-linux-gnu/12:\
/lib/x86_64-pc-linux-gnu/12:\
/lib/x86_64-linux-gnu/12:\
"
    lib_path_other_fn
}

lib_path_gcc13_fn()
{
    unset LIBRARY_PATH
    LIBRARY_PATH="\
/usr/x86_64-linux-gnu/lib/x86_64-linux-gnu/13:\
/usr/local/x86_64-pc-linux-gnu/lib/x86_64-pc-linux-gnu/13:\
/usr/local/lib/x86_64-pc-linux-gnu/13:\
/usr/local/lib/gcc/x86_64-pc-linux-gnu/13:\
/usr/lib/x86_64-pc-linux-gnu/13:\
/usr/lib/x86_64-linux-gnu/13:\
/usr/lib/gcc/x86_64-linux-gnu/13:\
/lib/x86_64-pc-linux-gnu/13:\
/lib/x86_64-linux-gnu/13:\
"
    lib_path_other_fn
}

link_gcc_13_fn()
{
    list=(x86_64-pc-linux-gnu-c++-13 x86_64-pc-linux-gnu-cpp-13 x86_64-pc-linux-gnu-g++-13
          x86_64-pc-linux-gnu-gcc-13 x86_64-pc-linux-gnu-gcc-ar-13 x86_64-pc-linux-gnu-gccgo-13
          x86_64-pc-linux-gnu-gcc-nm-13 x86_64-pc-linux-gnu-gcc-ranlib-13 x86_64-pc-linux-gnu-gcov-13
          x86_64-pc-linux-gnu-gcov-dump-13 x86_64-pc-linux-gnu-gcov-tool-13 x86_64-pc-linux-gnu-gdc-13
          x86_64-pc-linux-gnu-gfortran-13 x86_64-pc-linux-gnu-go-13 x86_64-pc-linux-gnu-gofmt-13
          x86_64-pc-linux-gnu-lto-dump-13)

    for i in ${list[@]}
    do
        trim_str="$(echo "$i" | sed 's/.*gnu-\(.*\)$/\1/')"
        sudo ln -fs /usr/local/bin/$i /usr/local/bin/$trim_str
    done
}

link_gcc_12_fn()
{
    list=(x86_64-pc-linux-gnu-c++-12 x86_64-pc-linux-gnu-cpp-12 x86_64-pc-linux-gnu-g++-12
          x86_64-pc-linux-gnu-gcc-12 x86_64-pc-linux-gnu-gcc-ar-12 x86_64-pc-linux-gnu-gccgo-12
          x86_64-pc-linux-gnu-gcc-nm-12 x86_64-pc-linux-gnu-gcc-ranlib-12 x86_64-pc-linux-gnu-gcov-12
          x86_64-pc-linux-gnu-gcov-dump-12 x86_64-pc-linux-gnu-gcov-tool-12 x86_64-pc-linux-gnu-gdc-12
          x86_64-pc-linux-gnu-gfortran-12 x86_64-pc-linux-gnu-go-12 x86_64-pc-linux-gnu-gofmt-12
          x86_64-pc-linux-gnu-lto-dump-12)

    for i in ${list[@]}
    do
        trim_str="$(echo "$i" | sed 's/.*gnu-\(.*\)$/\1/')"
        sudo ln -fs /usr/local/bin/$i /usr/local/bin/$trim_str
    done
}

link_gcc_11_fn()
{
    list=(x86_64-pc-linux-gnu-c++-11 x86_64-pc-linux-gnu-cpp-11 x86_64-pc-linux-gnu-g++-11
          x86_64-pc-linux-gnu-gcc-11 x86_64-pc-linux-gnu-gcc-ar-11 x86_64-pc-linux-gnu-gccgo-11
          x86_64-pc-linux-gnu-gcc-nm-11 x86_64-pc-linux-gnu-gcc-ranlib-11 x86_64-pc-linux-gnu-gcov-11
          x86_64-pc-linux-gnu-gcov-dump-11 x86_64-pc-linux-gnu-gcov-tool-11 x86_64-pc-linux-gnu-gdc-11
          x86_64-pc-linux-gnu-gfortran-11 x86_64-pc-linux-gnu-go-11 x86_64-pc-linux-gnu-gofmt-11
          x86_64-pc-linux-gnu-lto-dump-11)

    for i in ${list[@]}
    do
        trim_str="$(echo "$i" | sed 's/.*gnu-\(.*\)$/\1/')"
        sudo ln -fs /usr/local/bin/$i /usr/local/bin/$trim_str
    done
}

execute()
{
    echo "$ $*"

    if [ "$debug" = 'ON' ]; then
        if ! output=$("$@"); then
            notify-send "Failed to execute: $*"
            fail_fn "Failed to execute: $*"
        fi
    else
        if ! output=$("$@" 2>&1); then
            notify-send "Failed to execute: $*"
            fail_fn "Failed to execute: $*"
        fi
    fi
}

download()
{
    dl_path="$packages"
    dl_url="$1"
    dl_file="${2:-"${1##*/}"}"

    if [[ "$dl_file" =~ tar. ]]; then
        output_dir="${dl_file%.*}"
        output_dir="${3:-"${output_dir%.*}"}"
    else
        output_dir="${3:-"${dl_file%.*}"}"
    fi

    target_file="$dl_path/$dl_file"
    target_dir="$dl_path/$output_dir"

    if [ -f "$target_file" ]; then
        echo "The file \"$dl_file\" is already downloaded."
    else
        echo "Downloading \"$dl_url\" saving as \"$dl_file\""
        if ! curl -Lso "$target_file" "$dl_url"; then
            printf "\n%s\n\n" "The script failed to download \"$dl_file\" and will try again in 5 seconds..."
            sleep 5
            if ! curl -Lso "$target_file" "$dl_url"; then
                fail_fn "The script failed to download \"$dl_file\" twice and will now exit."
            fi
        fi
        echo 'Download Completed'
    fi

    if [ -d "$target_dir" ]; then
        sudo rm -fr "$target_dir"
    fi

    mkdir -p "$target_dir"

    if [ -n "$3" ]; then
        if ! tar -xf "$target_file" -C "$target_dir" 2>/dev/null >/dev/null; then
            sudo rm "$target_file"
            fail_fn "Failed to extract \"$dl_file\" so it was deleted. Please run the script again."
        fi
    else
        if ! tar -xf "$target_file" -C "$target_dir" --strip-components 1 2>/dev/null >/dev/null; then
            sudo rm "$target_file"
            fail_fn "Failed to extract \"$dl_file\" so it was deleted. Please run the script again."
        fi
    fi

    echo -e "File extracted: $dl_file\\n"

    cd "$target_dir" || fail_fn "Unable to change the working directory to: $target_dir"
}

download_git()
{
    local dl_path dl_url dl_file target_dir

    dl_path="$packages"
    dl_url="$1"
    dl_file="${2:-"${1##*/}"}"
    dl_file="${dl_file//\./-}"
    target_dir="$dl_path/$dl_file"

    if [ -d "$target_dir" ]; then
        sudo rm -fr "$target_dir"
    fi

    echo "Downloading $dl_url as $dl_file"
    if ! git clone -q "$dl_url" "$target_dir"; then
        printf "\n%s\n\n" "The script failed to clone the git repository \"$target_dir\" and will try again in 10 seconds..."
        sleep 10
        if ! git clone -q "$dl_url" "$target_dir"; then
            fail_fn "The script failed to clone \"$target_dir\" twice and will now exit the build."
        fi
    else
        echo -e "Succesfully cloned: $target_dir\\n"
    fi

    cd "$target_dir" || fail_fn "Unable to change the working directory to: $target_dir"
}

build()
{
    echo
    echo "building $1 - version $2"
    echo '===================================='

    if [ -f "$packages/$1.done" ]; then
        if grep -Fx "$2" "$packages/$1.done" >/dev/null; then
            echo "$1 version $2 is already built. Remove $packages/$1.done lockfile to rebuild it."
            return 1
        else
            echo "$1 is outdated, but will not be rebuilt. Pass in --latest to rebuild it or remove $packages/$1.done lockfile."
            return 1
        fi
    fi

    return 0
}

curl_timeout=10

git_1_fn()
{
    local curl_cmd github_repo github_url g_sver

    # SCRAPE GITHUB'S API FOR THE LATEST REPO VERSION
    github_repo="$1"
    github_url="$2"

    if curl_cmd="$(curl -m "$curl_timeout" -sSL "https://api.github.com/repos/$github_repo/$github_url")"; then
        g_sver="$(echo "$curl_cmd" | jq -r '.[0].name' 2>/dev/null)"
        g_tag="$(echo "$curl_cmd" | jq -r '.[0].tag_name' 2>/dev/null)"
        g_ver="${g_tag#v}"
        g_ver="${g_sver#v}"
    fi
}

git_ver_fn()
{
    local t_flag u_flag v_flag v_tag v_url

    v_url="$1"
    v_tag="$2"

    if [ -n "$3" ]; then
        v_flag="$3"
    fi

    case "$v_flag" in
            R)      t_flag='releases';;
            T)      t_flag='tags';;
            *)      fail_fn 'Could not detect the variable $v_flag.'
    esac

    case "$v_tag" in
            1)      u_flag='git_1_fn';;
            *)      fail_fn 'Could not detect the variable $v_tag.'
    esac

    "$u_flag" "$v_url" "$t_flag" 2>/dev/null
}

build_done()
{
    echo "$2" >"$packages/$1.done"
}

installed()
{
    return $(dpkg-query -W -f '${Status}\n' "$1" 2>&1 | awk '/ok installed/{print 0;exit}{print 1}')
}

#
# PRINT SCRIPT BANNER
#

function box_out_banner()
{
    input_char=$(echo "$@" | wc -c)
    line=$(for i in `seq 0 $input_char`; do printf "-"; done)
    tput bold
    line="$(tput setaf 3)${line}"
    space=${line//-/ }
    echo " ${line}"
    printf '|' ; echo -n "$space" ; printf "%s\n" '|';
    printf '| ' ;tput setaf 4; echo -n "$@"; tput setaf 3 ; printf "%s\n" ' |';
    printf '|' ; echo -n "$space" ; printf "%s\n" '|';
    echo " ${line}"
    tput sgr 0
}

box_out_banner "GCC Build Script: v$script_ver"

#
# INSTALL REQUIRED APT PACKAGES
#

pkgs=(autoconf autogen automake bison build-essential ccache curl dejagnu flex gcc-11-base gcc-multilib
      gdc gdc-multilib gfortran gfortran-multilib git gnat-10 gnulib gperf guile-3.0-dev help2man jq libadacgi4-dev
      libdebuginfod-dev libdmalloc-dev libeigen3-dev libffi-dev libfontconfig1-dev libfreetype6 libgcc-11-dev
      libgd-dev libgm2-11-dev libgm2-12-dev libgm2-15 libgmp-dev libgnat-util10-dev libicu-dev libisl-dev
      libjpeg-dev libmpc-dev libmpfr-dev libphobos2-ldc-shared-dev libpng-dev libquadmath0 libsqlite3-dev libssl-dev
      libunwind-dev libx11-dev libx32gfortran-12-dev libxext-dev linux-libc-dev linux-libc-dev:i386 meson ninja-build
      openjdk-11-jdk-headless perl python3 ruby sphinx-common tcl-expect-dev tex-common texinfo)

for pkg in ${pkgs[@]}; do
    if ! installed "$pkg"; then
        missing_pkgs+=" $pkg"
    fi
done

if [ -n "$missing_pkgs" ]; then
    printf "%s\n%s\n\n" \
        'Installing required apt packages' \
        '================================================'
    for i in "$missing_pkgs"
    do
        echo "\$ sudo apt -y install $i"
        sudo apt -y install $i
        echo
    done
fi

#
# INSTALL PYTHON MODULES
#

py_pkgs=(types-gdb os.path2 mbs-sys tempfile2 PrettyGcov json2json pytest csv23 time-tools argparse3 pathlib shutil-extra latex Pygments)

for py_pkg in ${py_pkgs[@]}; do
    if ! pip show "$py_pkg" &>/dev/null; then
        missing_py_pkgs+=" $py_pkg"
    fi
done

if [ -n "$missing_py_pkgs" ]; then
    printf "%s\n%s\n\n" \
        'Installing required python packages' \
        '================================================'
    for py in "${missing_py_pkgs[@]}"
    do
        pip install -q $py
        echo
    done
fi

#
# SET THE C & C++ COMPILERS
#

export CC=gcc CXX=g++
export CFLAGS='-g -O3 -march=native'
export CXXFLAGS='-g -O3 -march=native'

#
# CREATE SOFT LINKS
#

if [ -f /usr/include/asm-generic ]; then
    if [ ! -f /usr/include/asm ]; then
        sudo ln -fs /usr/include/asm-generic /usr/include/asm 2>&1
    fi
fi

#
# CHECK IF THE CUDA SDK TOOLKIT IS INSTALLED
#

iscuda="$(sudo find /usr/local/ -type f -name nvcc)"
if [ -n "$iscuda" ]; then
    cuda_check='--with-cuda-driver'
else
    cuda_check='--without-cuda-driver'
fi

#
# INSTALL FROM SOURCE CODE
#

if build 'm4' 'latest'; then
    download 'https://ftp.gnu.org/gnu/m4/m4-latest.tar.xz'
    execute ./configure --prefix="$libs_install_dir" --enable-c++ --with-dmalloc
    execute make "-j$cpu_threads"
    execute sudo make install
    execute make distclean
    build_done 'm4' 'latest'
fi

if build 'autoconf' '2.69'; then
    download 'https://ftp.gnu.org/gnu/autoconf/autoconf-2.69.tar.xz'
    execute ./configure --prefix="$workspace" M4="$libs_install_dir"/bin/m4
    execute make "-j$cpu_threads"
    execute sudo make install
    execute make distclean
    build_done 'autoconf' '2.69'
fi

if build 'automake' '1.16.5'; then
    download 'https://ftp.gnu.org/gnu/automake/automake-1.16.5.tar.xz'
    execute ./bootstrap
    execute autoreconf -fi
    execute ./configure --prefix="$libs_install_dir"
    execute make "-j$cpu_threads"
    execute sudo make install
    execute make distclean
    build_done 'automake' '1.16.5'
fi

if build 'libtool' '2.4.6'; then
    download 'https://ftp.gnu.org/gnu/libtool/libtool-2.4.6.tar.xz'
    execute ./configure --prefix="$libs_install_dir" --disable-shared
    execute make "-j$cpu_threads"
    execute sudo make install
    execute make distclean
    build_done 'libtool' '2.4.6'
fi

if build 'libiconv' '1.17'; then
    download 'https://ftp.gnu.org/gnu/libiconv/libiconv-1.17.tar.gz'
    execute ./configure --prefix="$libs_install_dir" --disable-shared
    execute make "-j$cpu_threads"
    execute sudo make install
    execute make distclean
    execute sudo libtool --finish "$libs_install_dir"/lib
    build_done 'libiconv' '1.17'
fi

if build 'diffutils' '3.9'; then
    download 'https://ftp.gnu.org/gnu/diffutils/diffutils-3.9.tar.xz'
    execute autoreconf -fi
    execute ./configure --prefix="$libs_install_dir" --enable-{threads=posix,year2038} --disable-nls --with-libiconv-prefix="$libs_install_dir"
    execute make "-j$cpu_threads"
    execute sudo make install
    execute make distclean
    build_done 'diffutils' '3.9'
fi

if build 'attr' '2.5.1'; then
    download 'http://download.savannah.nongnu.org/releases/attr/attr-2.5.1.tar.xz'
    execute autoreconf -fi
    execute ./configure --prefix="$libs_install_dir" --disable-shared --with-libiconv-prefix="$libs_install_dir"
    execute make "-j$cpu_threads"
    execute sudo make install
    execute make distclean
    build_done 'attr' '2.5.1'
fi

if build 'patch' '2.7.6'; then
    download 'https://ftp.gnu.org/gnu/patch/patch-2.7.6.tar.xz'
    execute autoreconf -fi
    execute ./configure --prefix="$libs_install_dir"
    execute make "-j$cpu_threads"
    execute sudo make install
    execute make distclean
    build_done 'patch' '2.7.6'
fi

if build 'isl' '0.24'; then
    download 'https://gcc.gnu.org/pub/gcc/infrastructure/isl-0.24.tar.bz2'
    execute ./configure --prefix="$libs_install_dir"
    execute make "-j$cpu_threads"
    execute sudo make install
    execute make distclean
    build_done 'isl' '0.24'
fi

git_ver_fn 'gperftools/gperftools' '1' 'R'
g_ver="${g_ver//gperftools-/}"
if build 'gperftools' "$g_ver"; then
    download "https://github.com/gperftools/gperftools/releases/download/gperftools-$g_ver/gperftools-$g_ver.tar.gz"
    execute ./configure --prefix="$libs_install_dir"
    execute make "-j$cpu_threads"
    execute sudo make install
    execute make distclean
    build_done 'gperftools' "$g_ver"
fi

git_ver_fn 'facebook/zstd' '1' 'R'
if build 'zstd' "$g_ver"; then
    download "https://github.com/facebook/zstd/releases/download/v$g_ver/zstd-$g_ver.tar.gz"
    cd build/meson || exit 1
    execute meson setup build --prefix="$libs_install_dir" --libdir="$libs_install_dir"/lib \
        --buildtype=release --default-library=static --strip
    execute ninja "-j$cpu_threads" -C build
    execute sudo ninja "-j$cpu_threads" -C build install
    build_done 'zstd' "$g_ver"
fi

git_ver_fn 'madler/zlib' '1' 'R'
if build 'zlib' "$g_ver"; then
    download "https://github.com/madler/zlib/releases/download/v$g_ver/zlib-$g_ver.tar.gz" "zlib-$g_ver.tar.gz"
    execute ./configure --prefix="$libs_install_dir"
    execute make "-j$cpu_threads"
    execute sudo make install
    execute make distclean
    build_done 'zlib' "$g_ver"
fi

if build 'bison' 'git'; then
    download_git 'https://github.com/akimd/bison.git'
    execute git submodule update --init
    execute ./bootstrap --bootstrap-sync
    execute ./configure --prefix="$libs_install_dir"
    execute make "-j$cpu_threads"
    execute sudo make install
    execute make distclean
    build_done 'bison' 'git'
fi

if build 'binutils' '2.40'; then
    download 'https://ftp.gnu.org/gnu/binutils/binutils-2.40.tar.xz'
    execute ./configure --prefix="$libs_install_dir" --{build,host,target}=x86_64-pc-linux-gnu \
        --with-{jdk=/usr/lib/jvm/java-11-openjdk-amd64,static-standard-libraries} \
        --with-{isl="$libs_install_dir",gmp="$libs_install_dir",mpc="$libs_install_dir"} \
        --with-{mpfr="$libs_install_dir",zstd="$libs_install_dir"} \
        --enable-{lto,year2038} LD=/usr/bin/ld LD_FOR_TARGET=/usr/bin/ld \
        CPPFLAGS='-I/usr/lib/jvm/java-11-openjdk-amd64/include'
    execute make "-j$cpu_threads"
    execute sudo make install
    execute sudo sudo libtool --finish "$libs_install_dir"/lib
    execute make clean
    build_done 'binutils' '2.40'
fi

if build 'gcc-11' '11.4.0'; then
    lib_path_gcc11_fn
    download 'https://ftp.gnu.org/gnu/gcc/gcc-11.4.0/gcc-11.4.0.tar.xz'
    execute autoreconf -fi
    execute sudo ./contrib/download_prerequisites
    if [ -d "$packages"/gcc-11.4.0-build ]; then
        sudo rm -fr "$packages"/gcc-11.4.0-build
    fi
    mkdir "$packages"/gcc-11.4.0-build
    cd "$packages"/gcc-11.4.0-build || exit 1
    execute ../gcc-11.4.0/configure \
        --prefix="$gcc_install_dir" \
        --{build,host,target}=x86_64-pc-linux-gnu \
        --disable-{assembly,nls,werror} \
        --enable-{bootstrap,plugin,threads=posix,languages=all} \
        --with-{link-serialization=2,gcc-major-version-only,libiconv-prefix="$libs_install_dir"} \
        --with-{system-zlib,target-system-zlib=auto,tune=generic} \
        "$cuda_check" \
        --without-included-gettext \
        --program-{prefix=x86_64-pc-linux-gnu-,suffix=-11}
    echo '$ This is going to take a while...'
    execute make "-j$cpu_threads"
    execute sudo make install-strip
    execute sudo libtool --finish "$gcc_install_dir"/libexec/gcc/x86_64-pc-linux-gnu/11
    execute sudo libtool --finish "$gcc_install_dir"/lib
    execute make distclean
    link_gcc_11_fn
    build_done 'gcc-11' '11.4.0'
fi

if build 'gcc-12' '12.3.0'; then
    lib_path_gcc12_fn
    download 'https://ftp.gnu.org/gnu/gcc/gcc-12.3.0/gcc-12.3.0.tar.xz'
    execute autoreconf -fi
    execute sudo ./contrib/download_prerequisites
    if [ -d "$packages"/gcc-12.3.0-build ]; then
        sudo rm -fr "$packages"/gcc-12.3.0-build
    fi
    mkdir "$packages"/gcc-12.3.0-build
    cd "$packages"/gcc-12.3.0-build || exit 1
    execute ../gcc-12.3.0/configure \
        --prefix="$gcc_install_dir" \
        --{build,host,target}=x86_64-pc-linux-gnu \
        --disable-{assembly,nls,werror} \
        --enable-{bootstrap,plugin,threads=posix,languages=all} \
        --with-{link-serialization=2,gcc-major-version-only,libiconv-prefix="$libs_install_dir"} \
        --with-{system-zlib,target-system-zlib=auto,tune=generic} \
        "$cuda_check" \
        --without-included-gettext \
        --program-{prefix=x86_64-pc-linux-gnu-,suffix=-12}
    echo '$ This is going to take a while...'
    execute make "-j$cpu_threads"
    execute sudo make install-strip
    execute sudo libtool --finish "$gcc_install_dir"/libexec/gcc/x86_64-pc-linux-gnu/12
    execute sudo libtool --finish "$gcc_install_dir"/lib
    execute make distclean
    link_gcc_12_fn
    build_done 'gcc-12' '12.3.0'
fi

if build 'gcc-13' '13.1.0'; then
    lib_path_gcc13_fn
    download 'https://ftp.gnu.org/gnu/gcc/gcc-13.1.0/gcc-13.1.0.tar.xz'
    execute autoreconf -fi
    execute sudo ./contrib/download_prerequisites
    if [ -d "$packages"/gcc-13.1.0-build ]; then
        sudo rm -fr "$packages"/gcc-13.1.0-build
    fi
    mkdir "$packages"/gcc-13.1.0-build
    cd "$packages"/gcc-13.1.0-build || exit 1
    execute ../gcc-13.1.0/configure \
        --prefix="$gcc_install_dir" \
        --{build,host,target}=x86_64-pc-linux-gnu \
        --disable-{assembly,nls,werror} \
        --enable-{bootstrap,plugin,threads=posix,languages=all} \
        --with-{link-serialization=2,gcc-major-version-only,libiconv-prefix="$libs_install_dir"} \
        --with-{system-zlib,target-system-zlib=auto,tune=generic} \
        "$cuda_check" \
        --without-included-gettext \
        --program-{prefix=x86_64-pc-linux-gnu-,suffix=-13}
    echo '$ This is going to take a while...'
    execute make "-j$cpu_threads"
    execute sudo make install-strip
    execute sudo libtool --finish "$gcc_install_dir"/libexec/gcc/x86_64-pc-linux-gnu/13
    execute sudo libtool --finish "$gcc_install_dir"/lib
    execute make distclean
    link_gcc_13_fn
    build_done 'gcc-13' '13.1.0'
fi

# LDCONFIG MUST BE RUN NEXT IN ORDER TO UPDATE FILE CHANGES
sudo ldconfig 2>/dev/null

# SHOW THE NEWLY INSTALLED VERSION OF EACH PACKAGE
show_ver_fn

# PROMPT THE USER TO CLEANUP THE BUILD FILES
cleanup_fn

# SHOW THE EXIT MESSAGE
exit_fn
