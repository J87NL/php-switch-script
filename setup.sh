#!/bin/bash

php_versions=(
    "8.4" "PHP 8.4" ON
    "8.3" "PHP 8.3" ON
    "8.2" "PHP 8.2" OFF
    "8.1" "PHP 8.1" OFF
    "8.0" "PHP 8.0" OFF
    "7.4" "PHP 7.4" ON
    "7.3" "PHP 7.3" OFF
    "7.2" "PHP 7.2" OFF
    "7.1" "PHP 7.1" OFF
    "7.0" "PHP 7.0" OFF
    "5.6" "PHP 5.6" OFF
)

if ! command -v whiptail &> /dev/null; then
    if (whiptail --title "Install whiptail" --yesno "whiptail is not installed. Do you want to install it?" 8 50); then
        echo "* Installing whiptail..."
        sudo apt-get install -y whiptail
    else
        echo "whiptail is required to continue. Exiting installation."
        exit 1
    fi
fi

selected_versions=$(whiptail --title "PHP Version Selection" --checklist \
    "Select PHP versions to install" 20 50 10 \
    "${php_versions[@]}" 3>&1 1>&2 2>&3)

if [[ $? -ne 0 || -z "$selected_versions" ]]; then
    echo "Installation cancelled or no version selected."
    exit 1
fi

echo "Selected PHP versions: $selected_versions"

php_extensions=(
    "bz2" "Enable BZ2 extension" ON
    "curl" "Enable cURL extension" ON
    "gd" "Enable GD (graphics) extension" ON
    "intl" "Enable Internationalization extension" ON
    "mbstring" "Enable Multibyte String extension" ON
    "mysql" "Enable MySQL extension" ON
    "opcache" "Enable OPCACHE extension" ON
    "pdo" "Enable PDO (database abstraction) extension" ON
    "readline" "Enable READLINE extension" ON
    "redis" "Enable REDIS extension" ON
    "soap" "Enable SOAP extension" ON
    "sqlite3" "Enable SQLITE3 extension" ON
    "tidy" "Enable TIDY extension" ON
    "xml" "Enable XML extension" ON
    "xsl" "Enable XSL extension" ON
    "zip" "Enable ZIP extension" ON
)

selected_extensions=$(whiptail --title "PHP Extensions Selection" --checklist \
    "Select PHP extensions to install" 20 100 10 \
    "${php_extensions[@]}" 3>&1 1>&2 2>&3)

if [[ $? -ne 0 ]]; then
    echo "Installation cancelled."
    exit 1
fi

echo "Selected extensions: $selected_extensions"

echo "* Setting up third-party repository to allow installation of multiple PHP versions..."
sudo add-apt-repository -y ppa:ondrej/php

echo "* Refreshing software repositories..."
sudo apt-get update

echo "* Installing prerequisite software packages..."
sudo apt-get install -y software-properties-common

echo "* Installing Apache FastCGI module..."
sudo apt-get install -y libapache2-mod-fcgid
sudo a2enmod actions alias proxy_fcgi fcgid

echo "* Installing selected PHP versions..."

IFS=', ' read -r -a selected_versions_array <<< "$selected_versions"
IFS=', ' read -r -a selected_extensions_array <<< "$selected_extensions"

for version in "${selected_versions_array[@]}"; do
    version=${version//\"/}
    if [[ -n "$version" ]]; then
        echo "* Installing PHP version $version..."
        sudo apt-get install -y "php$version php$version-common php$version-cli"

        for ext in "${selected_extensions_array[@]}"; do
            ext=${ext//\"/}
            if [[ -n "$ext" ]]; then
                echo "* Installing PHP extension $ext for PHP $version..."
                sudo apt-get install -y "php$version-$ext"
            fi
        done
    fi
done

echo "* Enabeling mod_rewrite, mod_headers and vhost_alias..."
sudo a2enmod rewrite
sudo a2enmod headers
sudo a2enmod vhost_alias

if (whiptail --title "Add php.ini for PHP Versions" --yesno "Do you want to add a custom php.ini file to your home directory and create symlinks for the selected PHP versions?" 8 50); then
    echo "* Add an php.ini to your home folder for easy adding of settings to all PHP-versions..."
    ini_file=~/php.ini
    if ! grep -q "^memory_limit" "$ini_file"; then
        echo "memory_limit = 2G" >> "$ini_file"
    fi

    for version in "${selected_versions_array[@]}"; do
        version=${version//\"/}
        if [[ $version != " " ]]; then
            echo "* Create a symlink php.ini for PHP version $version..."

            if [ ! -L "/etc/php/$version/mods-available/php.ini" ]; then
                sudo ln -s ~/php.ini "/etc/php/$version/mods-available/php.ini"
            fi
        fi
    done
fi

echo "* Installation complete."