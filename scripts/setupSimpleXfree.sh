######
# CONFIG
USERNAME="cubie"
USERPASS="1234"

useradd -m -U -d /home/$USERNAME -s /bin/bash $USERNAME
# set User password to 1234
(echo $USERPASS;echo $USERPASS;) | passwd $USERNAME
# Do NOT force password change upon first login as it will prevent autologin :(

adduser $USERNAME sudo
adduser $USERNAME audio
#Useless ?
#adduser $USERNAME admin
#adduser $USERNAME sshlogin

sourcesFile="/etc/apt/sources.list"

if ! grep -q "iceweasel" $sourcesFile; then
    echo "deb http://mozilla.debian.net/ wheezy-backports iceweasel-release" >> $sourcesFile
    apt-get -qq update
fi

INSTPKG="xorg lightdm ttf-mscorefonts-installer x11vnc openbox xterm iceweasel"
#INSTPKG+=" "
#xserver-xorg-core xinit xserver-xorg-video-sunximali sunxi-disp-test lxde
echo $INSTPKG
export DEBIAN_FRONTEND=noninteractive; apt-get -qq -y install $INSTPKG
apt-get -qq -y install -t wheezy-backports iceweasel
#Needs to run twice for colord issue on the first run :(
export DEBIAN_FRONTEND=noninteractive; apt-get -qq -y install $INSTPKG
apt-get -qq clean

adduser $USERNAME video

if ! grep -q $USERNAME /etc/lightdm/lightdm.conf; then
    sed -i "s/#autologin-user=/autologin-user=$USERNAME/g" /etc/lightdm/lightdm.conf
    sed -i "s/#autologin-user-timeout=0/autologin-user-timeout=0/g" /etc/lightdm/lightdm.conf
fi
#To enable connexion using crontab on DISPLAY :0.0
sed -i "s/xserver-allow-tcp=false/xserver-allow-tcp=true/g" /etc/lightdm/lightdm.conf

mkdir -p /home/$USERNAME/.config/openbox
echo "xhost +localhost &" > /home/$USERNAME/.config/openbox/autostart
echo "xterm -e '/sbin/ifconfig eth0 && read a' &" >> /home/$USERNAME/.config/openbox/autostart
chown -R $USERNAME:$USERNAME /home/$USERNAME/.config/openbox/autostart
chmod 755 /home/$USERNAME/.config/openbox/autostart

#Prevent xscreensaver from starting at boot
#sudo sed -i '/xscreensaver/d' $ROOTFS/etc/xdg/lxsession/LXDE/autostart
export DISPLAY=":0.0"
xset -dpms
xset s noblank;xset s 0 0;xset s off
#xset + dpms
#A inverser pour les xset s
