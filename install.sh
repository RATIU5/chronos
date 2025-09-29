#!/bin/bash

export CHRONOS_PATH="$HOME/.local/share/chronos"
export CHRONOS_INSTALL="$CHRONOS_PATH/install"
export CHRONOS_LOG_FILE="/var/log/chronos-install.log"

source "$CHRONOS_INSTALL/helpers/all.sh"
source "$CHRONOS_INSTALL/preflight/all.sh"
source "$CHRONOS_INSTALL/packaging/all.sh"