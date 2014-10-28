CubieDebian
===========

Debian for wheezy Cubieboards 1 and 2 built from scratch !

Freely inspired by other similar projects

For now the generated images only work on cubieboard2: 
- Simple Headless Server version that I use as a home server
- Simple X server version : lightweight, boots openbox, and display the IP on startup.

The default password is "1234" for both root and cubie accounts

###Included features :
#### Headless Server & X Free Versions
- Expand File system to fill the  SD card on boot
- Regenerate SSH keys on first boot
- Blinking led : Green for CPU and Blue for SD Card access
- DHCP enabled - Manual MAC address change possible in /etc/network/interfaces
- Optimization to reduce wear on SD card : 
    - SWAP is disabled
    - Ramlog daemon stores all /var/log in RAM
    - tmpfs used for serveral mountpoints
    - tweaked fstab and other misc stuff
- Custom but simple MOTD using toilet

#### XFree Version only
- Super light and fast to boot
- Boots Openbox automatically and display current Ip adress
- Firefox (iceweasel) installed


### Planned features
- Using RAM to store Firefox profiles and data
- Launch VNC on boot
- Disable screen blanking on boot (user can enable it again if necessary)


References :
https://wiki.debian.org/EmDebian/CrossDebootstrap
