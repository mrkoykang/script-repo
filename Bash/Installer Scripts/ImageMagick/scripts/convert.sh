#!/usr/bin/env bash
# shellcheck disable=SC2086 source=/dev/null

# Color setup
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'
export CYAN GREEN RED YELLOW NC

# Default values
output_dir="output"
quality=82
additional_args=""
max_file_size=0
log_file="convert.log"
recursive="false"
parallel="false"
verbose="false"
test_run="false"
delete_input="false"
webp_sizes=(1.5 2 3 4)
icon_sizes="256,128,96,64,48,32,20,16"

MAGICK_AREA_LIMIT="1GP"
MAGICK_DISK_LIMIT="128GiB"
MAGICK_FILE_LIMIT="1536"
MAGICK_HEIGHT_LIMIT="512MP"
MAGICK_MAP_LIMIT="32GiB"
MAGICK_MEMORY_LIMIT="32GiB"
MAGICK_THREAD_LIMIT="$(nproc --all)"
MAGICK_WIDTH_LIMIT="512MP"
export MAGICK_AREA_LIMIT MAGICK_DISK_LIMIT MAGICK_FILE_LIMIT MAGICK_HEIGHT_LIMIT MAGICK_MAP_LIMIT MAGICK_MEMORY_LIMIT MAGICK_THREAD_LIMIT MAGICK_WIDTH_LIMIT

# Function to display the help menu
display_help() {
    echo "Purpose:"
    echo "This script converts image files to various formats using ImageMagick."
    echo "It supports conversions between BMP, GIF, ICO, JPG, PNG, TIFF, and WEBP formats."
    echo
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  -h, --help                   Display the help menu"
    echo "  -q, --quality <value>        Set the quality level (default is 82)"
    echo "  -o, --output <dir>           Set the output directory (default is 'output')"
    echo "  -a, --additional <args>      Set additional command-line arguments for ImageMagick"
    echo "  -m, --max-size <size>        Set the maximum output file size (e.g., 500KB or 1.5MB)"
    echo "  -l, --log-file <file>        Set the log file (default is 'convert.log')"
    echo "  -r, --recursive              Search for image files recursively"
    echo "  -p, --parallel               Convert images in parallel"
    echo "  -v, --verbose                Enable verbose mode"
    echo "  -t, --test-run               Perform a test run (show actions without executing)"
    echo "  -d, --delete                 Delete input files after processing"
}

# Function to check for required dependencies
check_dependencies() {
    local -a missing_deps dependencies
    local dep deps_magick deps_other

    dependencies=(convert gifsicle identify optipng parallel)

    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            missing_deps+=("$dep")
        fi
    done

    deps_magick='convert|identify'
    deps_other='gifsicle|optipng|parallel'

    if [[ "${#missing_deps[@]}" -gt 0 ]]; then
        if [[ "${#missing_deps[@]}" =~ $deps_magick ]]; then
            echo "The <convert|identify> commands are commonly found in your package manager in the package \"imagemagick\""
        elif [[ "${#missing_deps[@]}" =~ $deps_other ]]; then
            echo "The <gifsicle|optipng|parallel> commands are commonly found in your package manager in packages with the same names."
        fi
        echo -e "${RED}[ERROR]${NC} Missing dependencies: ${missing_deps[*]}"
        exit 1
    fi
}

# Function to determine file type
get_file_type() {
    identify -format '%m' "$1" | tr '[:upper:]' '[:lower:]'
}

# Function to log messages
log_message() {
    local message
    message=$1
    echo "$message" >> "$log_file"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Function to resize images exceeding the limits
resize_if_needed() {
    local file height height_limit width width_limit
    file=$1
    width_limit=$2
    height_limit=$3

    width=$(identify -ping -format '%w' "$file")
    height=$(identify -ping -format '%h' "$file")

    if (( width > width_limit || height > height_limit )); then
        echo -e "${GREEN}[INFO]${NC} Resizing $file to fit within limits."
        log_message "Resizing $file to fit within limits."
        convert "$file" -resize "${width_limit}x${height_limit}" "$file"
    fi
}

# Function to convert image files
process_image() {
    local base_name file img_height max_quality mid_quality min_quality mpc_file output_file
    local output_type size_kb sized_file sizes_dir small_height temp_dir temp_file
    local -a convert_base_opts=() png_opts=()

    file=$1
    output_type=$2
    base_name="${file##*/}"
    output_file="$output_dir/${base_name%.*}.$output_type"
    temp_dir=$(mktemp -d)

    resize_if_needed "$file" 512000 512000

    if [[ "$output_type" =~ bmp ]]; then
        warn "This script does not support the processing of a GIF to BMP."
        return 1
    fi

    if [[ "$test_run" == "true" ]]; then
        echo -e "${GREEN}[INFO] ${CYAN}[TEST RUN]${NC} $file to $output_file with quality $quality and additional args $additional_args"
        log_message "[TEST RUN] $file to $output_file with quality $quality and additional args $additional_args"
        return 0
    fi

    echo -e "${GREEN}[INFO]${NC} Converting $file to $output_file with quality $quality and additional args $additional_args"
    log_message "Converting $file to $output_file with quality $quality and additional args $additional_args"

    convert_base_opts=(
        -thumbnail "$(identify -ping -format '%wx%h' "$file")"
        -strip -unsharp '0.25x0.08+8.3+0.045' -dither None -posterize 136 -quality "$quality"
        -define jpeg:fancy-upsampling=off -auto-level -enhance -interlace none -colorspace sRGB
    )

    png_opts=(
        -define png:compression-filter=5 -define png:compression-level=9
        -define png:compression-strategy=1 -define png:exclude-chunk=all
    )

    convert_image() {
        local qual
        qual=$1
        convert "$file" "${convert_base_opts[@]}" -quality "$qual" "${png_opts[@]}" "$temp_file"
        optipng -o7 "$temp_file"
        size_kb=$(du -k "$temp_file" | cut -f1)
    }

    case "$output_type" in
        jpg)
            mpc_file="$temp_dir/${base_name%.*}.mpc"
            if ! convert "$file" "${convert_base_opts[@]}" -sampling-factor 2x2 -limit area 0 "$mpc_file"; then
                [[ "$verbose" == "true" ]] && log_message "First attempt failed, retrying without '-sampling-factor 2x2 -limit area 0'..."
                if ! convert "$file" "${convert_base_opts[@]}" "$mpc_file"; then
                    [[ "$verbose" == "true" ]] && log_message "Error: Second attempt failed as well."
                    rm -fr "$temp_dir"
                    return 1
                fi
            fi
            convert "$mpc_file" "$output_file"
            ;;
        png)
            if [[ "$max_file_size" -gt 0 ]]; then
                temp_file="$temp_dir/temp.png"
                size_kb=0
                min_quality=10
                max_quality="$quality"
                mid_quality=0

                convert_image "$quality"
                while [[ "$size_kb" -gt "$max_file_size" ]] && [[ "$min_quality" -lt "$max_quality" ]]; do
                    mid_quality=$(( (min_quality + max_quality) / 2 ))
                    max_quality=$(( mid_quality - 1 ))
                    min_quality=$(( mid_quality + 1 ))
                    convert_image "$mid_quality"
                done
                mv "$temp_file" "$output_file"
            else
                convert "$file" "${convert_base_opts[@]}" "${png_opts[@]}" "$output_file"
            fi
            ;;
        bmp)
            convert "$file" -strip -compress none -quality "$quality" "$output_file"
            ;;
        gif)
            if [[ "$output_type" == "gif" ]] && [[ "$(get_file_type "$file")" == "gif" ]]; then
                cp "$file" "$output_file"
                echo -e "${GREEN}[INFO]${NC} Copying $file to $output_file (no conversion needed)"
                log_message "Copying $file to $output_file (no conversion needed)"
                return 0
            fi

            temp_file="$(mktemp).gif"
            convert "$file" -strip -quality "$quality" "$temp_file"
            gifsicle --colors 256 -O3 "$temp_file" -o "$output_file"
            rm "$temp_file"
            ;;
        tiff)
            if [[ "$output_type" =~ jpg ]]; then
                convert "$file" -format tif -compress jpeg "$output_file"
            else
                convert "$file" -format tif "$output_file"
            fi
            ;;
        webp)
            small_height="$(identify -ping -format '%h' "$file")"
            sizes_dir="$output_dir/sizes"
            mkdir -p "$sizes_dir"
            convert -quality "$quality" -define webp:method=6 -resize "x${small_height}" "$file" "$output_file"
            for webp_size in "${webp_sizes[@]}"; do
                img_height=$(awk "BEGIN {print $webp_size*$small_height}")
                sized_file="${output_file%.webp}@${webp_size}x.webp"
                convert -quality "$quality" -define webp:method=6 -resize "x${img_height}" "$file" "$sized_file"
            done
            [[ -d "$sizes_dir" ]] && [[ -z "$(ls -A "$sizes_dir")" ]] && rm -fr "$sizes_dir"
            ;;
        ico)
            convert -background none "$file" -define icon:auto-resize="$icon_sizes" "$output_file"
            ;;
        *)
            convert "$file" "${convert_base_opts[@]}" "$additional_args" "$output_file"
            ;;
    esac

    echo -e "${GREEN}[INFO]${NC} Convert success: $file to $output_file"
    log_message "Convert success: $file to $output_file"

    if [[ "$delete_input" == "true" ]]; then
        rm -f "$file"
        echo -e "${GREEN}[INFO]${NC} Deleted input file: $file"
        log_message "Deleted input file: $file"
    fi

    rm -fr "$temp_dir"
}

export -f process_image warn
export output_dir quality additional_args max_file_size log_file test_run verbose delete_input

# Function to find files
find_files() {
    local files find_files
    find_files='( -name *.bmp -o -name *.gif -o -name *.ico -o -name *.jfif -o -name *.jpg -o -name *.png -o -name *.tiff -o -name *.webp )'
    if [[ "$recursive" == "true" ]]; then
        files=$(find ./ -type f $find_files ! -path "./$output_dir/*")
    else
        files=$(find ./ -maxdepth 1 -type f $find_files ! -path "./$output_dir/*")
    fi
    echo "$files"
}

# Main script
main() {
    local img_files output_choices output_types gif_to_bmp

    # Parse arguments
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -h|--help)
                display_help
                exit 0
                ;;
            -q|--quality)
                quality=$2
                shift
                ;;
            -o|--output)
                output_dir=$2
                shift
                ;;
            -a|--additional)
                additional_args=$2
                shift
                ;;
            -m|--max-size)
                size=$(echo "$2" | tr '[:upper:]' '[:lower:]')
                if [[ "$size" =~ mb$ ]]; then
                    max_file_size=$(echo "$size" | sed 's/mb$//;s/[[:space:]]//g')
                    max_file_size=$(echo "$max_file_size * 1024" | bc)
                else
                    max_file_size=$(echo "$size" | sed 's/kb$//;s/[[:space:]]//g')
                fi
                shift
                ;;
            -l|--log-file)
                log_file=$2
                shift
                ;;
            -r|--recursive)
                recursive="true"
                ;;
            -p|--parallel)
                parallel="true"
                ;;
            -v|--verbose)
                verbose="true"
                ;;
            -t|--test-run)
                test_run="true"
                ;;
            -d|--delete)
                delete_input="true"
                ;;
            *)
                echo -e "${RED}[ERROR]${NC} Invalid option: $1"
                display_help
                exit 1
                ;;
        esac
        shift
    done

    # Check for dependencies
    check_dependencies

    # Create output directory if it doesn't exist
    mkdir -p "$output_dir"

    # Determine input files
    img_files=$(find_files)

    if [[ -z "$img_files" ]]; then
        echo -e "${RED}[ERROR]${NC} No supported input files found."
        exit 1
    fi

    # Prompt user for output file types
    echo "Select output file types (comma-separated, e.g., bmp,gif,ico,jpg,png,tiff,webp, or all):"
    read -r -p "Enter your choices: " output_choices
    IFS=',' read -ra output_types <<< "$output_choices"

    if [[ " ${output_types[*]} " == *" all "* ]]; then
        output_types=(bmp gif ico jpg png tiff webp)
    fi

    # Validate output types
    for output_type in "${output_types[@]}"; do
        if [[ ! " bmp gif ico jfif jpg png tiff webp " =~ $output_type ]]; then
            echo -e "${RED}[ERROR]${NC} Invalid output type: $output_type"
            exit 1
        fi
    done

    # Check for GIF to BMP conversion
    gif_to_bmp="false"
    for img in $img_files; do
        if [[ "$(get_file_type "$img")" == "gif" ]] && [[ " ${output_types[*]} " == *" bmp "* ]]; then
            echo -e "${RED}[ERROR]${NC} Conversion from GIF to BMP is not possible with this script."
            gif_to_bmp="true"
            break
        fi
    done

    if [[ "$gif_to_bmp" == "true" ]]; then
        if [[ "${#output_types[@]}" -eq 1 ]]; then
            exit 1
        else
            read -r -p "Do you want to continue processing the other file types? [y/N]: " continue_choice
            if [[ "${continue_choice,,}" != "y" ]]; then
                exit 0
            fi
        fi
    fi

    # Convert files
    if [[ "$parallel" == "true" ]]; then
        export -f get_file_type log_message process_image resize_if_needed
        for output_type in "${output_types[@]}"; do
            echo "$img_files" | tr ' ' '\n' | parallel --lb -j 16 process_image {} "$output_type"
        done
    else
        for img in $img_files; do
            for output_type in "${output_types[@]}"; do
                process_image "$img" "$output_type"
            done
        done
    fi
}

main "$@"

# Unset exported variables
unset CYAN GREEN MAGICK_AREA_LIMIT MAGICK_DISK_LIMIT MAGICK_FILE_LIMIT MAGICK_HEIGHT_LIMIT
unset MAGICK_MAP_LIMIT MAGICK_MEMORY_LIMIT MAGICK_THREAD_LIMIT MAGICK_WIDTH_LIMIT NC RED
