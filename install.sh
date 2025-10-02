#!/bin/bash

export CHRONOS_PATH="$HOME/.local/share/chronos"
export CHRONOS_INSTALL="$CHRONOS_PATH/install"
export CHRONOS_INSTALL_LOG_FILE="/var/log/chronos-install.log"
export CHRONOS_ONLINE_INSTALL="true"

source "$CHRONOS_INSTALL/helpers/all.sh"
source "$CHRONOS_INSTALL/preflight/all.sh"
source "$CHRONOS_INSTALL/packaging/all.sh"
source "$CHRONOS_INSTALL/config/all.sh"
source "$CHRONOS_INSTALL/login/all.sh"
source "$CHRONOS_INSTALL/post-install/all.sh"