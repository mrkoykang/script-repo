#!/usr/bin/env bash

# Github Script: https://github.com/slyfox1186/script-repo/blob/main/Bash/Installer%20Scripts/GNU%20Software/build-findutils.sh
# Purpose: build gnu findutils
# Updated: 06.06.24
# Script version: 1.0

CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Set the variables
script_ver=1.0
prog_name="findutils"
default_version=$(curl -fsS "https://ftp.gnu.org/gnu/$prog_name/" | grep -oP '\d\.[\d.]+(?=\.tar\.[a-z]+)' | sort -ruV | head -n1)
install_dir="/usr/local"
cwd="$PWD/$prog_name-build-script"
compiler="gcc"

# Enhanced logging and error handling
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "\\n${YELLOW}[WARNING]${NC} $1"
}

fail() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo -e "To report a bug, create an issue at: https://github.com/slyfox1186/script-repo/issues"
    exit 1
}

print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "  -v, --version VERSION       Set the version of $prog_name to install (default: $default_version)"
    echo "  -l, --list                  List available versions of $prog_name"
    echo "  -u, --uninstall             Uninstall $prog_name"
    echo "  -c, --compiler COMPILER     Set the compiler to use (clang) instead of the default: $compiler"
    echo "  -h, --help                  Display this help and exit"
}

exit_function() {
    echo
    log "The script has completed"
    log "${GREEN}Make sure to ${YELLOW}star ${GREEN}this repository to show your support!${NC}"
    log "${CYAN}https://github.com/slyfox1186/script-repo${NC}"
    exit 0
}

cleanup() {
    sudo rm -fr "$cwd"
}

required_packages() {
    local -a missing_pkgs pkgs
    local pkg
    pkgs=(
        autoconf automake autopoint autotools-dev build-essential
        bzip2 ccache curl libaudit-dev libintl-perl libticonv-dev
        libtool pkg-config valgrind zlib1g-dev librust-polling-dev
    )

    missing_pkgs=()
    for pkg in "${pkgs[@]}"; do
        if ! dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "ok installed"; then
            missing_pkgs+=("$pkg")
        fi
    done

    if [[ "${#missing_pkgs[@]}" -gt 0 ]]; then
        sudo apt update
        sudo apt install "${missing_pkgs[@]}"
    fi
}

set_compiler_flags() {
    CC="$compiler"
    CXX="$compiler++"
    CFLAGS="-O2 -pipe -march=native"
    CXXFLAGS="$CFLAGS"
    LDFLAGS="-Wl,-rpath,$install_dir/lib"
    PATH="/usr/lib/ccache:$PATH"
    PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/local/lib64/pkgconfig:/usr/local/share/pkgconfig:/usr/lib/pkgconfig:/usr/lib64/pkgconfig:/usr/share/pkgconfig"
    PKG_CONFIG_PATH+=":/usr/local/cuda/lib64/pkgconfig:/usr/local/cuda/lib/pkgconfig:/opt/cuda/lib64/pkgconfig:/opt/cuda/lib/pkgconfig"
    PKG_CONFIG_PATH+=":/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/lib/i386-linux-gnu/pkgconfig:/usr/lib/arm-linux-gnueabihf/pkgconfig:/usr/lib/aarch64-linux-gnu/pkgconfig"
    export CC CXX CFLAGS CXXFLAGS LDFLAGS PATH PKG_CONFIG_PATH
}

download_archive() {
    wget --show-progress -cqO "$cwd/$tar_file" "$archive_url" || fail "Failed to download archive with WGET. Line: $LINENO"
}

extract_archive() {
    tar -Jxf "$cwd/$tar_file" -C "$cwd/$archive_name" --strip-components 1 || fail "Failed to extract: $cwd/$tar_file"
}

configure_build() {
    cd "$cwd/$archive_name" || fail "Failed to cd into $cwd/$archive_name. Line: $LINENO"

    autoreconf -fi
    cd build || exit 1
    ../configure --prefix="$install_dir/$archive_name" --enable-threads=posix --disable-nls \
                 --with-libiconv-prefix=/usr --with-libintl-prefix=/usr || fail "Failed to execute: configure. Line: $LINENO"
}

compile_build() {
    make "-j$(nproc --all)" || fail "Failed to execute: make build. Line: $LINENO"
}

install_build() {
    sudo make install || fail "Failed execute: make install. Line: $LINENO"
}

ld_linker_path() {
    echo "$install_dir/$archive_name/lib" | sudo tee "/etc/ld.so.conf.d/custom_$prog_name.conf" >/dev/null
    sudo ldconfig
}

create_soft_links() {
    [[ -d "$install_dir/$archive_name/bin" ]] && sudo ln -sf "$install_dir/$archive_name/bin/"* "/usr/local/bin/"
    [[ -d "$install_dir/$archive_name/lib/pkgconfig" ]] && sudo ln -sf "$install_dir/$archive_name/lib/pkgconfig/"*.pc "/usr/local/lib/pkgconfig/"
    [[ -d "$install_dir/$archive_name/include" ]] && sudo ln -sf "$install_dir/$archive_name/include/"* "/usr/local/include/"
}

uninstall_findutils() {
    local findutils_dir
    findutils_dir="$install_dir/$archive_name"
    if [[ -d "$findutils_dir" ]]; then
        log "Uninstalling $prog_name from $findutils_dir"
        sudo rm -rf "$findutils_dir"
        sudo rm "/etc/ld.so.conf.d/custom_$prog_name.conf"
        sudo ldconfig
        log "$prog_name has been uninstalled"
    else
        log "$prog_name is not installed"
    fi
}

list_versions() {
    log "Available versions of $prog_name:"
    echo
    curl -fsS "https://ftp.gnu.org/gnu/$prog_name/" | grep -oP '\d\.[\d.]+(?=\.tar\.[a-z]+)' | sort -ruV
}

main_menu() {
    # Parse command-line arguments
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -v|--version)
                version="$2"
                shift 2
                ;;
            -l|--list)
                list_versions
                exit 0
                ;;
            -u|--uninstall)
                uninstall_findutils
                exit 0
                ;;
            -c|--compiler)
                compiler="$2"
                shift 2
                ;;
            -h|--help)
                print_usage
                exit 0
                ;;
            *)
                fail "Invalid option: $1"
                ;;
        esac
    done

    if [[ -z "$version" ]]; then
        version="$default_version"
        log "No version specified, using default version: $version"
    fi

    archive_name="$prog_name-$version"
    archive_url="https://ftp.gnu.org/gnu/$prog_name/$prog_name-$version.tar.xz"
    archive_ext="${archive_url//*.}"
    tar_file="$archive_name.tar.$archive_ext"

    # Create output directory
    [[ -d "$cwd/$archive_name" ]] && sudo rm -fr "$cwd/$archive_name"
    mkdir -p "$cwd/$archive_name/build"

    required_packages
    set_compiler_flags
    download_archive
    extract_archive
    configure_build
    compile_build
    install_build
    if [[ ! -f "$install_dir/$archive_name/lib/"*.so ]]; then
        warn "Failed to locate any \".so\" files so no custom ld linking will occur."
    else
        ld_linker_path
    fi
    create_soft_links
    cleanup
    exit_function
}

if [[ "$EUID" -eq 0 ]]; then
    echo "You must run this script without root or sudo."
    exit 1
fi

main_menu "$@"
