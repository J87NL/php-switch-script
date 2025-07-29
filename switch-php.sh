#!/bin/bash

CURRENT_PHP_VERSION=$(php -v | head -n 1 | cut -d " " -f 2 | cut -f1-2 -d".")
AVAILABLE_PHP_VERSIONS=$(ls /usr/bin/php* | grep -oP 'php([0-9]+\.[0-9]+)' | sed 's/php//g' | sort -rV | uniq)

function change_version() {
    local NEW_PHP_VERSION="$1"

    if [[ "$NEW_PHP_VERSION" =~ ^[0-9]+$ ]]; then
        NEW_PHP_VERSION="${NEW_PHP_VERSION:0:1}.${NEW_PHP_VERSION:1}"
    fi

    if ! echo "$AVAILABLE_PHP_VERSIONS" | grep -qw "$NEW_PHP_VERSION"; then
        echo "Error: PHP version $NEW_PHP_VERSION is not installed."
        echo "Available versions: $(echo "$AVAILABLE_PHP_VERSIONS" | tr '\n' ' ')"
        exit 1
    fi

    if [ "$NEW_PHP_VERSION" = "$CURRENT_PHP_VERSION" ]; then
        echo "PHP version $NEW_PHP_VERSION is already active."
        exit 0
    fi

    echo "* Enabling Apache PHP $NEW_PHP_VERSION module"
    sudo a2enconf php${NEW_PHP_VERSION}-fpm > /dev/null
    echo "* Disabling Apache PHP $CURRENT_PHP_VERSION module"
    sudo a2disconf php${CURRENT_PHP_VERSION}-fpm > /dev/null
    echo "* Restarting Apache..."
    sudo service apache2 restart > /dev/null
    echo "* Switching CLI PHP to $NEW_PHP_VERSION"
    sudo update-alternatives --set php /usr/bin/php${NEW_PHP_VERSION} > /dev/null
    echo "* Current PHP version: $(php -v | head -n 1 | cut -d " " -f 2 | cut -f1-2 -d".")"
}

function interactive_menu() {
    local prompt="$1" outvar="$2"
    shift
    shift
    local options=("$@") cur=0 count=${#options[@]} index=0
    local esc=$(echo -en "\e")
    printf "$prompt\n"
    while true
    do
        index=0
        for o in "${options[@]}"
        do
            if [ "$index" == "$cur" ]
            then
                echo -e " >\e[7m$o\e[0m"
            else
                echo "  $o"
            fi
            index=$(( $index + 1 ))
        done
        read -s -n3 key
        if [[ $key == $esc[A ]]
        then cur=$(( $cur - 1 ))
            [ "$cur" -lt 0 ] && cur=0
        elif [[ $key == $esc[B ]]
        then cur=$(( $cur + 1 ))
            [ "$cur" -ge $count ] && cur=$(( $count - 1 ))
        elif [[ $key == "" ]]
        then break
        fi
        echo -en "\e[${count}A"
    done

    printf -v $outvar "${options[$cur]}"

    if [[ $cur -gt 0 ]]; then
        echo ""
        change_version "${options[$cur]}"
    fi
}

for arg in "$@"; do
    if [ "$arg" = "-h" ]; then
        echo "Usage: $0 [php-version]"
        echo "Switch the PHP version for Apache and CLI to the specified version."
        echo ""
        echo "Options:"
        echo "  <php-version>  The desired PHP version (e.g., 8.4). If omitted, shows an interactive menu."
        echo "  -h             Display this help information"
        echo ""
        echo "Examples:"
        echo "  $0 8.4        Switch directly to PHP 8.4"
        echo "  $0 74         Switch directly to PHP 7.4 (the dot is optional)"
        echo "  $0            Show interactive PHP version selection menu"
        echo ""
        echo "Available versions: $(echo "$AVAILABLE_PHP_VERSIONS" | tr '\n' ' ')"
        exit 0
    fi
done

if [ $# -eq 1 ]; then
    change_version "$1"
else
    options=("Cancel, stay on PHP $CURRENT_PHP_VERSION")
    for version in $AVAILABLE_PHP_VERSIONS
    do
        if [ "$version" != "$CURRENT_PHP_VERSION" ]; then
            options+=("$version")
        fi
    done

    interactive_menu "Switch to PHP-version:" selected_choice "${options[@]}"
fi
