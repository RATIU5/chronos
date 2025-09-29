# Disable shutting system down on power button press to bind it to power menu afterwards
sudo sed -i 's/.*HandlePowerKey=.*HandlePowerKey=ignore/' /etc/systemd/logind.conf