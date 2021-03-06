#!/bin/bash

OS_TYPE=$(uname -s)

if [ $OS_TYPE == "Linux" ]; then
    BIN_DIR=/usr/bin
    COMPLETION=/etc/bash_completion.d
elif [ $OS_TYPE == "Darwin" ]; then
    BIN_DIR=/usr/local/bin
    COMPLETION=/usr/local/etc/bash_completion.d
else
    echo "This SO is not supported"
    exit 1
fi

BASH_PROFILE=$HOME/.bashrc
DEFAULT_CONFIG=$HOME/.config/penv
INSTALL_DIR=/usr/local/penv
TEMP_DIR=/tmp/penv-install
URL="https://gitlab.com/fortizc/penv/raw/master"

create_config() {
    echo "Config file path ($DEFAULT_CONFIG):"
    read path
    if [ -z "$path" ]; then
        path=$DEFAULT_CONFIG
    else
        DEFAULT_CONFIG=$path
    fi

    mkdir -p $DEFAULT_CONFIG
    > $DEFAULT_CONFIG/config
}

set_pyenv_path() {
    local default=$HOME/pyenvs
    echo "Choose a path for your environments ($default):"
    read env_path

    if [ -z "$env_path" ]; then
        env_path=$default
    fi
    echo "pyenv_folder=$env_path" >> $DEFAULT_CONFIG/config
}

set_python_interpreter_path() {
    local default=$BIN_DIR
    echo "Choose a path for your Python interpreters ($default):"
    read int_path

    if [ -z "$int_path" ]; then
        int_path=$default
    fi
    echo "python_interpreter=$int_path" >> $DEFAULT_CONFIG/config
}

set_env_var() {
    export PENV_CONFIG_FILE=$DEFAULT_CONFIG/config
    echo "export PENV_CONFIG_FILE=\"$DEFAULT_CONFIG/config\"" >> $BASH_PROFILE
}

download_penv() {
    echo "Download penv scripts"
    curl -O $URL/src/penv
    curl -O $URL/src/config.sh
    curl -O $URL/src/env_wrapper.sh
    curl -O $URL/version
    curl -O $URL/completion/penv-completion.bash
}

create_temp_dir() {
    echo "Creating temp dir"
    if [ -d "$TEMP_DIR" ]; then
        rm -rf $TEMP_DIR
    fi

    mkdir $TEMP_DIR
}

create_install_dir() {
    echo "Install dir ($INSTALL_DIR):"
    read user_dir

    if [ -z "$user_dir" ]; then
        user_dir=$INSTALL_DIR
    else
        INSTALL_DIR=$user_dir
    fi

    if [ ! -d "$INSTALL_DIR" ]; then
        sudo mkdir -p $INSTALL_DIR
    fi
    echo "Install dir created in $INSTALL_DIR"
}

update_bash_profile() {
    echo "Looking for your .bash_profile"
    while [ ! -f "$BASH_PROFILE" ]; do
        echo "Cannot find the .bash_profile, please give me a path:"
        read BASH_PROFILE
    done

    echo "Adding alias to your bash_profile"
    echo "alias penv='. $INSTALL_DIR/penv'" >> $BASH_PROFILE
}

install_scripts() {
    echo "Installing scripts"
    sudo cp penv $INSTALL_DIR/
    sudo cp config.sh $INSTALL_DIR/
    sudo cp env_wrapper.sh $INSTALL_DIR/
    sudo cp version $INSTALL_DIR/
    sudo cp penv-completion.bash $INSTALL_DIR/

    sudo chmod +x $INSTALL_DIR/penv

    if [ $OS_TYPE == "Linux" ]; then
        sudo ln -s $INSTALL_DIR/penv-completion.bash $COMPLETION/penv
    elif [ $OS_TYPE == "Darwin" ]; then
        ln -s $INSTALL_DIR/penv-completion.bash $COMPLETION/penv
    else
        echo "Could not set bash completion"
    fi
}

clean_up() {
    echo "Backing up install information for the uninstalling process"
    > $DEFAULT_CONFIG/install_vars.sh
    echo "CUR_INSTALL_DIR=$INSTALL_DIR" >> $DEFAULT_CONFIG/install_vars.sh
    echo "CUR_BIN_DIR=$BIN_DIR" >> $DEFAULT_CONFIG/install_vars.sh
    echo "CUR_BASH_PROFILE=$BASH_PROFILE" >> $DEFAULT_CONFIG/install_vars.sh
    echo "Cleaning up and finish"
    rm -rf $TEMP_DIR
}

get_install_vars() {
    echo "Reading install vars"
    source $(dirname $PENV_CONFIG_FILE)/install_vars.sh
    echo "Current install paths:"
    echo "Install dir: $CUR_INSTALL_DIR"
    echo "Binary dir: $CUR_BIN_DIR"
    echo "Bash profile: $CUR_BASH_PROFILE"
}

delete_scripts() {
    echo "Deleting scripts"
    if [ -d "$CUR_INSTALL_DIR" ]; then
        sudo rm -rf $CUR_INSTALL_DIR
    else
        echo "ERROR!!! folder $CUR_INSTALL_DIR not found!!!"
        exit 1
    fi

    sudo rm -rf $COMPLETION/penv
    rm -rf $(dirname $PENV_CONFIG_FILE)
}

remove_from_bash_profile() {
    echo "Creating backup for your current bash_profile in $HOME"
    cp $CUR_BASH_PROFILE $HOME/bash_profile.bak
    echo "Removing penv from your bash_profile"
    grep -v "PENV_CONFIG_FILE" $CUR_BASH_PROFILE > temp && \
        mv temp $CUR_BASH_PROFILE
    grep -v "penv" $CUR_BASH_PROFILE > temp && mv temp $CUR_BASH_PROFILE
}

install_penv() {
    echo
    echo "Installing on $OS_TYPE"
    echo "-------------------"
    echo
    create_temp_dir
    cd $TEMP_DIR
    download_penv
    create_install_dir
    update_bash_profile
    create_config
    set_env_var
    set_pyenv_path
    set_python_interpreter_path
    install_scripts
    clean_up
    echo "Install complete!!!"
    echo "Please reload your shell or open a new one to use penv"
}

uninstall_penv() {
    echo "This command remove penv completely, Are you sure? (y/N):"
    opt=0

    until [ $opt -eq 1 ]; do
        read remove

        case "$remove" in
            "" | N | n)
                exit 0
                ;;
            y | Y)
                opt=1
                ;;
            *)
                echo "Invalid option (y/N):"
                ;;
        esac
    done

    get_install_vars
    delete_scripts
    remove_from_bash_profile
}

help() {
    echo -e "Usage $1 {option}:"
    echo -e ""
    echo -e "Arguments:"
    echo -e "--install\tInstall penv"
    echo -e "--uninstall\tUnistall penv"
}

if [ -z "$1" ]; then
    options=$0
else
    options=$1
fi

case "$options" in
    --install)
        install_penv
        ;;
    --uninstall)
        uninstall_penv
        ;;
    *)
        help $0
        ;;
esac
