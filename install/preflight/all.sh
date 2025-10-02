source $CHRONOS_INSTALL/preflight/guard.sh
source $CHRONOS_INSTALL/preflight/begin.sh
run_logged $CHRONOS_INSTALL/preflight/show-env.sh
run_logged $CHRONOS_INSTALL/preflight/cachyos.sh
run_logged $CHRONOS_INSTALL/preflight/pacman.sh
run_logged $CHRONOS_INSTALL/preflight/first-run-mode.sh
run_logged $CHRONOS_INSTALL/preflight/disable-mkinitcpio.sh