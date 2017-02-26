#!/bin/bash

# ======================================
#  Constants
# ======================================
theme='Railway'

theme_dir=~/'.themes'

sass_input='scss/cinnamon.scss'

sass_output='cinnamon.css'

sass_style='expanded'

assets_dir='img'

watch_dirs=(
    $assets_dir
    'scss'
)


zip_name="$theme.zip"

# Relative to the project's root
package_files=(
    "$theme/cinnamon/cinnamon.css"
    "$theme/cinnamon/theme.json"
    "$theme/cinnamon/thumbnail.png"
    "$theme/cinnamon/img/"
)

# Files that need to be moved into the $theme folder
extra_files=(
    'LICENSE'
    'README.md'
	'screenshot.png'
)

# ======================================
#  Operations
# ======================================
compile_sass () {
    sassc -t "$sass_style" "$sass_input" > "$sass_output"
}

restart_theme () {
    gsettings set org.cinnamon.theme name "$theme"
}

symlink_theme () {
    mkdir -p "$theme_dir"
    rm -rf "$theme_dir/$theme"
    ln -rfs "../../$theme" "$theme_dir"
}

install_theme () {
    spices_package &> /dev/null
    mkdir -p "$theme_dir"
    rm -rf "$theme_dir/$theme"
    unzip "$zip_name" -d "$theme_dir"

	restart_theme
}

spices_package () {
	if type sassc ;then compile_sass ;fi

    cd ../../
    rm -f "$zip_name"
    zip -r "$zip_name" "${package_files[@]}"

    for ef in ${extra_files[@]} ;do
        ln -rfs "$ef" "$theme/$ef"
        zip -r "$zip_name" "$theme/$ef"
        rm -rf "$theme/$ef"
    done

    echo "Files compressed into $zip_name"
}

simplify_assets () {
    simplify () {
        scour -i "$1" -o "$2"\
            --remove-metadata \
            --enable-id-stripping \
            --protect-ids-noninkscape
    }

    # Usage: print_progress PROGRESS TOTAL
    print_progress () {
        local n_cols=$(($(tput cols)-5))
        local cols_completed=$(($1*n_cols/$2))
        local percent_completed=$(($1*100/$2))

        echo -n "$percent_completed% "
        for ((i=0; i<$cols_completed; i++)) {
            echo -n '#'
        }
    }

    if type scour &> /dev/null ; then

        # temp dir for the output (can't output to self)
        local tmp_dir=$(mktemp -d)
        local assets_list=$(find $assets_dir/ -name '*.svg')
        local n_assets=$(echo "$assets_list" | wc -l)
        local completed=0

        for res in $assets_list ; do
            echo -e "> Simplifying \e[34m$(basename $res)\e[0m"
            print_progress $completed $n_assets

            output=$(simplify "$res" "$tmp_dir/out.svg")
            mv "$tmp_dir/out.svg" "$res"

            echo -en '\033[2K\r' # clear old progress bar
            echo "  $output"
            ((completed=completed+1))
        done

        echo 'Simplify assets task finished'
    else
        echo 'scour not found'
    fi
}

watch_files () {
    symlink_theme
	echo 'Started watching files (Ctrl+C to exit)'
    while
        compile_sass
        restart_theme
        notify-send "Theme $theme reloaded" \
            --icon='preferences-desktop-theme' \
            --hint=int:transient:1

        # test
        inotifywait --format '%T > %e %w%f' --timefmt '%H:%M:%S' -qre modify "${watch_dirs[@]}"
    do :; done
}

show_help () {
    local bold=$(tput bold)
    local normal=$(tput sgr0)

    echo "\
${bold}USAGE${normal}
    ./$(basename $0) --OPTION

${bold}OPTIONS${normal}
    --install       install the theme into the system

${bold}DEVELOPMENT OPTIONS${normal}
    --compile       convert SASS files into CSS

    --pkg           package files ready to be uploaded to the Cinnamon Spices

    --simplify      optimize SVG assets for a smaller size and a better theme
                    performance stripping metadata and other stuff

    --watch         refresh the theme while making changes to files and images

    --help          show help
"
}

# ======================================
#  Start point
# ======================================

declare -A operations
operations[install]=install_theme
operations[compile]=compile_sass
operations[help]=show_help
operations[pkg]=spices_package
operations[simplify]=simplify_assets
operations[watch]=watch_files

if [[ $1 == --?* ]]
then
    opname=${1:2}
    opfunc="${operations[$opname]}"

    if [[ -n "$opfunc" ]]
    then $opfunc
    else
        echo "$opname: command not found"
        show_help
    fi
else
    show_help
fi
