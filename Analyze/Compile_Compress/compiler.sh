#!/bin/bash

# compiler.sh - Multi-purpose File Utility (Compress, Decompress, Compile, Decompile)

# --- Global Variables and Helper Functions ---
SCRIPT_NAME=$(basename "$0")
HELP_MESSAGE="
Usage: $SCRIPT_NAME [OPTIONS] <file(s)>

Options:
  -c, --compress        Compress the specified file(s).
                        Uses gzip, bzip2, zip (if available).
                        Additional options:
                          --gz, --gzip      Force gzip compression.
                          --bz, --bzip2     Force bzip2 compression.
                          --zip             Force zip compression.

  -d, --decompress      Decompress the specified file(s).
                        Uses gunzip, bunzip2, unzip (if available).
                        Additional options:
                          --gz, --gzip      Force gzip decompression.
                          --bz, --bzip2     Force bzip2 decompression.
                          --zip             Force zip decompression.

  -C, --compile         Compile the specified source file(s) (e.g., .c, .cpp).
                        Currently supports C/C++ with gcc/g++.
                        Example: -C myprogram.c -o myexecutable
                        Additional options:
                          -o <output_name>  Specify output executable name.
                          --c-compiler <compiler> Specify C compiler (e.g., clang).
                          --cpp-compiler <compiler> Specify C++ compiler (e.g., clang++).
                          --libs <libs>     Link additional libraries (e.g., '-lm -pthread').

  -D, --decompile       Attempt to decompile (disassemble) the specified binary file.
                        Uses objdump and gdb for disassembly.
                        Output will be assembly code.
                        Example: -D myexecutable
                        Additional options:
                          --intel           Use Intel assembly syntax (default is AT&T).
                          --section <section_name> Disassemble specific section (e.g., .text).

  -h, --help            Display this help message.

Examples:
  $SCRIPT_NAME -c myfile.txt               # Compress myfile.txt with best available
  $SCRIPT_NAME -d myfile.txt.gz            # Decompress myfile.txt.gz
  $SCRIPT_NAME -c --zip myarchive.zip dir/ # Compress a directory into a zip archive
  $SCRIPT_NAME -C mycode.c -o myexe        # Compile mycode.c into myexe
  $SCRIPT_NAME -C main.c func.c -o program --libs '-lm' # Compile multiple files with math lib
  $SCRIPT_NAME -D myexecutable             # Disassemble myexecutable
  $SCRIPT_NAME -D --intel myexecutable     # Disassemble with Intel syntax
"

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

log_info() {
    echo -e "\e[34m[INFO]\e[0m $1"
}

log_success() {
    echo -e "\e[32m[SUCCESS]\e[0m $1"
}

log_warning() {
    echo -e "\e[33m[WARNING]\e[0m $1"
}

log_error() {
    echo -e "\e[31m[ERROR]\e[0m $1" >&2
}

# --- Default Values for Options ---
MODE="" # compress, decompress, compile, decompile
COMPRESSION_TOOL="" # gzip, bzip2, zip
DECOMPRESSION_TOOL="" # gunzip, bunzip2, unzip
COMPILE_OUTPUT_NAME="a.out"
C_COMPILER="gcc"
CPP_COMPILER="g++"
COMPILE_LIBS=""
DECOMPILE_SYNTAX="" # --intel for objdump
DECOMPILE_SECTION="" # .text, .data etc.

# --- Argument Parsing ---
# Using getopts for short options, and manual parsing for long options
# A colon after an option means it requires an argument.
# -o: for output file, -C: for compile, -D: for decompile, etc.
# Short options that take arguments: o:
# Long options that take arguments: output=, c-compiler=, cpp-compiler=, libs=, section=
# Long options that are flags: gz, gzip, bz, bzip2, zip, intel, help, compress, decompress, compile, decompile

ARGS=$(getopt -o hcCdDo: --long help,compress,decompress,compile,decompile,gz,gzip,bz,bzip2,zip,output:,c-compiler:,cpp-compiler:,libs:,intel,section: -- "$@")

if [ $? -ne 0 ]; then
    log_error "Error parsing arguments. Use -h for help."
    exit 1
fi

eval set -- "$ARGS"

while true; do
    case "$1" in
        -h|--help)
            echo "$HELP_MESSAGE"
            exit 0
            ;;
        -c|--compress)
            MODE="compress"
            shift
            ;;
        -d|--decompress)
            MODE="decompress"
            shift
            ;;
        -C|--compile)
            MODE="compile"
            shift
            ;;
        -D|--decompile)
            MODE="decompile"
            shift
            ;;
        --gz|--gzip)
            if [ "$MODE" == "compress" ]; then
                COMPRESSION_TOOL="gzip"
            elif [ "$MODE" == "decompress" ]; then
                DECOMPRESSION_TOOL="gunzip"
            fi
            shift
            ;;
        --bz|--bzip2)
            if [ "$MODE" == "compress" ]; then
                COMPRESSION_TOOL="bzip2"
            elif [ "$MODE" == "decompress" ]; then
                DECOMPRESSION_TOOL="bunzip2"
            fi
            shift
            ;;
        --zip)
            if [ "$MODE" == "compress" ]; then
                COMPRESSION_TOOL="zip"
            elif [ "$MODE" == "decompress" ]; then
                DECOMPRESSION_TOOL="unzip"
            fi
            shift
            ;;
        -o|--output)
            COMPILE_OUTPUT_NAME="$2"
            shift 2
            ;;
        --c-compiler)
            C_COMPILER="$2"
            shift 2
            ;;
        --cpp-compiler)
            CPP_COMPILER="$2"
            shift 2
            ;;
        --libs)
            COMPILE_LIBS="$2"
            shift 2
            ;;
        --intel)
            DECOMPILE_SYNTAX="-M intel"
            shift
            ;;
        --section)
            DECOMPILE_SECTION="$2"
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            log_error "Internal error: unrecognized option '$1'"
            echo "$HELP_MESSAGE"
            exit 1
            ;;
    esac
done

INPUT_FILES=("$@")

if [ -z "$MODE" ]; then
    log_error "No operation mode specified. Use -c, -d, -C, or -D. Use -h for help."
    exit 1
fi

if [ ${#INPUT_FILES[@]} -eq 0 ]; then
    log_error "No input file(s) provided for '$MODE' operation. Use -h for help."
    exit 1
fi

# --- Main Logic ---

case "$MODE" in
    compress)
        log_info "Compressing file(s): ${INPUT_FILES[@]}"
        COMPRESSED_AT_LEAST_ONE=false
        for file in "${INPUT_FILES[@]}"; do
            if [ ! -e "$file" ]; then
                log_warning "File '$file' not found. Skipping."
                continue
            fi

            # Prioritize specific tool if requested, otherwise try common ones
            chosen_tool=""
            if [ -n "$COMPRESSION_TOOL" ]; then
                chosen_tool="$COMPRESSION_TOOL"
            elif command_exists gzip; then
                chosen_tool="gzip"
            elif command_exists bzip2; then
                chosen_tool="bzip2"
            elif command_exists zip; then
                chosen_tool="zip"
            fi

            if [ -z "$chosen_tool" ]; then
                log_error "No suitable compression tool found (gzip, bzip2, or zip)."
                break
            fi

            case "$chosen_tool" in
                gzip)
                    if command_exists gzip; then
                        log_info "  Compressing '$file' with gzip..."
                        gzip "$file"
                        if [ $? -eq 0 ]; then
                            log_success "  '$file' compressed to '$file.gz'."
                            COMPRESSED_AT_LEAST_ONE=true
                        else
                            log_error "  Failed to compress '$file' with gzip."
                        fi
                    else
                        log_warning "  gzip not found. Skipping '$file'."
                    fi
                    ;;
                bzip2)
                    if command_exists bzip2; then
                        log_info "  Compressing '$file' with bzip2..."
                        bzip2 "$file"
                        if [ $? -eq 0 ]; then
                            log_success "  '$file' compressed to '$file.bz2'."
                            COMPRESSED_AT_LEAST_ONE=true
                        else
                            log_error "  Failed to compress '$file' with bzip2."
                        fi
                    else
                        log_warning "  bzip2 not found. Skipping '$file'."
                    fi
                    ;;
                zip)
                    if command_exists zip; then
                        log_info "  Compressing '$file' with zip..."
                        # Check if it's a directory
                        if [ -d "$file" ]; then
                            zip_archive_name="${file%.*}_archive.zip" # e.g., dir/ -> dir_archive.zip
                            log_info "  Creating zip archive for directory '$file' as '$zip_archive_name'."
                            zip -r "$zip_archive_name" "$file"
                        else
                            zip_archive_name="${file%.*}_archive.zip" # e.g., myfile.txt -> myfile_archive.zip
                            log_info "  Creating zip archive for file '$file' as '$zip_archive_name'."
                            zip "$zip_archive_name" "$file"
                        fi

                        if [ $? -eq 0 ]; then
                            log_success "  '$file' compressed to '$zip_archive_name'."
                            COMPRESSED_AT_LEAST_ONE=true
                        else
                            log_error "  Failed to compress '$file' with zip."
                        fi
                    else
                        log_warning "  zip not found. Skipping '$file'."
                    fi
                    ;;
            esac
        done
        if [ "$COMPRESSED_AT_LEAST_ONE" = false ]; then
            log_error "No files were successfully compressed."
            exit 1
        fi
        ;;

    decompress)
        log_info "Decompressing file(s): ${INPUT_FILES[@]}"
        DECOMPRESSED_AT_LEAST_ONE=false
        for file in "${INPUT_FILES[@]}"; do
            if [ ! -e "$file" ]; then
                log_warning "File '$file' not found. Skipping."
                continue
            fi

            chosen_tool=""
            if [ -n "$DECOMPRESSION_TOOL" ]; then
                chosen_tool="$DECOMPRESSION_TOOL"
            elif [[ "$file" =~ \.gz$ ]]; then
                chosen_tool="gunzip"
            elif [[ "$file" =~ \.bz2$ ]]; then
                chosen_tool="bunzip2"
            elif [[ "$file" =~ \.zip$ ]]; then
                chosen_tool="unzip"
            fi

            if [ -z "$chosen_tool" ]; then
                log_warning "Could not determine decompression tool for '$file' based on extension or explicit option. Trying common ones."
                if command_exists gunzip; then chosen_tool="gunzip";
                elif command_exists bunzip2; then chosen_tool="bunzip2";
                elif command_exists unzip; then chosen_tool="unzip";
                fi
            fi

            if [ -z "$chosen_tool" ]; then
                log_error "No suitable decompression tool found (gunzip, bunzip2, or unzip) for '$file'."
                continue
            fi

            case "$chosen_tool" in
                gunzip)
                    if command_exists gunzip; then
                        log_info "  Decompressing '$file' with gunzip..."
                        gunzip "$file"
                        if [ $? -eq 0 ]; then
                            log_success "  '$file' decompressed."
                            DECOMPRESSED_AT_LEAST_ONE=true
                        else
                            log_error "  Failed to decompress '$file' with gunzip."
                        fi
                    else
                        log_warning "  gunzip not found. Skipping '$file'."
                    fi
                    ;;
                bunzip2)
                    if command_exists bunzip2; then
                        log_info "  Decompressing '$file' with bunzip2..."
                        bunzip2 "$file"
                        if [ $? -eq 0 ]; then
                            log_success "  '$file' decompressed."
                            DECOMPRESSED_AT_LEAST_ONE=true
                        else
                            log_error "  Failed to decompress '$file' with bunzip2."
                        fi
                    else
                        log_warning "  bunzip2 not found. Skipping '$file'."
                    fi
                    ;;
                unzip)
                    if command_exists unzip; then
                        log_info "  Decompressing '$file' with unzip..."
                        unzip "$file"
                        if [ $? -eq 0 ]; then
                            log_success "  '$file' decompressed."
                            DECOMPRESSED_AT_LEAST_ONE=true
                        else
                            log_error "  Failed to decompress '$file' with unzip."
                        fi
                    else
                        log_warning "  unzip not found. Skipping '$file'."
                    fi
                    ;;
            esac
        done
        if [ "$DECOMPRESSED_AT_LEAST_ONE" = false ]; then
            log_error "No files were successfully decompressed."
            exit 1
        fi
        ;;

    compile)
        log_info "Compiling source file(s): ${INPUT_FILES[@]}"
        COMPILE_COMMAND=""
        SOURCE_FILES=()

        for file in "${INPUT_FILES[@]}"; do
            if [ ! -e "$file" ]; then
                log_error "Source file '$file' not found. Aborting compilation."
                exit 1
            fi
            SOURCE_FILES+=("$file")
        done

        if [[ "${SOURCE_FILES[@]}" =~ \.cpp$|\.cxx$|\.cc$ ]]; then
            # Assuming C++ if any .cpp-like file exists
            if command_exists "$CPP_COMPILER"; then
                COMPILE_COMMAND="$CPP_COMPILER"
            else
                log_error "C++ compiler '$CPP_COMPILER' not found. Cannot compile."
                exit 1
            fi
        elif [[ "${SOURCE_FILES[@]}" =~ \.c$ ]]; then
            # Assuming C if any .c file exists
            if command_exists "$C_COMPILER"; then
                COMPILE_COMMAND="$C_COMPILER"
            else
                log_error "C compiler '$C_COMPILER' not found. Cannot compile."
                exit 1
            fi
        else
            log_error "Unsupported source file type(s) for compilation. Expected .c or .cpp."
            exit 1
        fi

        log_info "  Using compiler: $COMPILE_COMMAND"
        log_info "  Output executable: $COMPILE_OUTPUT_NAME"

        # Build the compilation command
        FULL_COMPILE_CMD="$COMPILE_COMMAND ${SOURCE_FILES[@]} -o $COMPILE_OUTPUT_NAME"
        if [ -n "$COMPILE_LIBS" ]; then
            FULL_COMPILE_CMD="$FULL_COMPILE_CMD $COMPILE_LIBS"
            log_info "  Linking with libraries: $COMPILE_LIBS"
        fi

        log_info "  Running: $FULL_COMPILE_CMD"
        eval "$FULL_COMPILE_CMD" # Use eval to correctly handle $COMPILE_LIBS if it contains multiple args like '-lm -pthread'

        if [ $? -eq 0 ]; then
            log_success "Compilation successful. Executable: '$COMPILE_OUTPUT_NAME'."
        else
            log_error "Compilation failed."
            exit 1
        fi
        ;;

    decompile)
        log_info "Attempting to decompile (disassemble) binary: ${INPUT_FILES[@]}"
        DECOMPILED_AT_LEAST_ONE=false
        for binary_file in "${INPUT_FILES[@]}"; do
            if [ ! -e "$binary_file" ]; then
                log_warning "Binary file '$binary_file' not found. Skipping."
                continue
            fi
            if [ ! -x "$binary_file" ]; then
                log_warning "Binary file '$binary_file' is not executable. It might not be a compiled program. Proceeding anyway."
            fi

            DECOMPILE_SUCCESS=false

            # Try objdump first for static disassembly
            if command_exists objdump; then
                log_info "  Disassembling '$binary_file' with objdump..."
                OBJUMP_CMD="objdump -d $DECOMPILE_SYNTAX"
                if [ -n "$DECOMPILE_SECTION" ]; then
                    OBJUMP_CMD="$OBJUMP_CMD --section=$DECOMPILE_SECTION"
                fi
                OBJUMP_CMD="$OBJUMP_CMD \"$binary_file\"" # Quote to handle spaces in filenames

                eval "$OBJUMP_CMD" > "${binary_file}.asm"
                if [ $? -eq 0 ]; then
                    log_success "  Disassembly of '$binary_file' saved to '${binary_file}.asm' using objdump."
                    DECOMPILED_AT_LEAST_ONE=true
                    DECOMPILE_SUCCESS=true
                else
                    log_error "  objdump failed for '$binary_file'."
                fi
            else
                log_warning "  objdump not found. Cannot perform static disassembly."
            fi

            # GDB can also disassemble, useful for runtime analysis but simpler here for static
            if ! $DECOMPILE_SUCCESS && command_exists gdb; then
                log_info "  Trying gdb for disassembly of '$binary_file'..."
                log_info "  (Note: gdb is primarily a debugger. This will produce a basic disassembly.)"
                echo "disass main" | gdb -q "$binary_file" > "${binary_file}.gdb.asm" 2>&1
                if [ $? -eq 0 ]; then
                    log_success "  Basic disassembly of '$binary_file' saved to '${binary_file}.gdb.asm' using gdb (main function)."
                    DECOMPILED_AT_LEAST_ONE=true
                else
                    log_error "  gdb failed for '$binary_file'."
                fi
            else
                if ! $DECOMPILE_SUCCESS; then # Only show warning if objdump also failed
                    log_warning "  gdb not found. Cannot perform dynamic/debugger-based disassembly."
                fi
            fi

            if ! $DECOMPILE_SUCCESS && ! command_exists objdump && ! command_exists gdb; then
                log_error "  No suitable disassembly tools (objdump, gdb) found for '$binary_file'."
            fi
        done
        if [ "$DECOMPILED_AT_LEAST_ONE" = false ]; then
            log_error "No files were successfully disassembled/decompiled."
            exit 1
        fi
        ;;

    *)
        log_error "Invalid operation mode: $MODE. This should not happen."
        echo "$HELP_MESSAGE"
        exit 1
        ;;
esac

exit 0
