#!/bin/bash

sudo pacman -Sy --noconfirm usbutils

if lsusb | grep -q "Studio Display"; then
	yay -S --noconfirm --needed asdbctl	
fi