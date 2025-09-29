# Disable USB autosuspend to prevent peripherals disconnection issues
if [[ ! -f /etc/modprobe.d/disable-usb-autosuspend.conf ]]; then
	echo "options usbcore autosuspend=-1" | sudo tee /etc/modprobe.d/disable-usb-autosuspend.conf
fi