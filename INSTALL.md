# Installation 

## Install minimal dependencies
```
sudo apt install vim git curl wget htop stress-ng re-tests python3-pip
pip install scipy numpy pandas --break-system-packages
```

## Install realtime kernel
```
sudo rm -f /boot/firmware/.firmware_revision /boot/firmware/.bootloader_revision
sudo SKIP_SDK=1 SKIP_VCLIBS=1 WANT_32BIT=0 WANT_64BIT=1 WANT_64BIT_RT=1 WANT_PI4=1 WANT_PI5=1 SKIP_WARNING=1 rpi-update next
```
