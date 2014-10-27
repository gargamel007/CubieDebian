#TODO : Add crytpo module sunxi_ss for better speed
#@TODO : Bootsplash
#@TODO : Lirc
#@TODO : module gpio_sunxi

######
# CONFIG
ROOTPWD="1234"

# Setup apt-sources
sourcesFile="/etc/apt/sources.list"
rm $sourcesFile
touch $sourcesFile
#Get all info running : sudo netselect-apt -a armhf -n -s -c fr wheezy
#Edit output file to add wheezy updates and uncomment security
echo "# Debian packages for wheezy" >> $sourcesFile
echo "deb http://debian.mirrors.ovh.net/debian/ wheezy main contrib non-free" >> $sourcesFile
echo "deb http://debian.mirrors.ovh.net/debian/ wheezy-updates main contrib non-free" >> $sourcesFile
echo "#Security updates for stable" >> $sourcesFile
echo "deb http://security.debian.org/ stable/updates main contrib non-free" >> $sourcesFile
echo "# Uncomment the deb-src line if you want 'apt-get source'" >> $sourcesFile
echo "# to work with most packages." >> $sourcesFile
echo "#deb-src http://debian.mirrors.ovh.net/debian/ wheezy main contrib non-free" >> $sourcesFile
apt-get -qq update

# Fix LOCALES and TimeZone
export LANG=C
DEST_LANG="en_US"
DEST_LANGUAGE="en"
# console
export TERM=linux
# reconfigure locales
apt-get -qq -y install locales
echo -e $DEST_LANG'.UTF-8 UTF-8\n' > /etc/locale.gen
echo -e 'fr_FR.UTF-8 UTF-8\n' >> /etc/locale.gen
echo -e 'LANG="'$DEST_LANG'.UTF-8"\nLANGUAGE="'$DEST_LANG':'$DEST_LANGUAGE'"\n' > /etc/default/locale
export LANG=$DEST_LANG.UTF-8
dpkg-reconfigure -f noninteractive locales
update-locale
#Change Timezones
echo "Europe/Zurich" > /etc/timezone
dpkg-reconfigure -f noninteractive tzdata

# Install packages
#Put all packages here :)
INSTPKG="dosfstools ntfs-3g hdparm bc lsof hddtemp procps console-setup console-data"
INSTPKG+=" module-init-tools udev usbutils sysfsutils libfuse2 pciutils uboot-envtools"
INSTPKG+=" iputils-ping ifupdown iproute ntp ntpdate dhcp3-client telnet rsync libnl-dev"
INSTPKG+=" netselect-apt openssh-server ca-certificates wget lirc"
INSTPKG+=" alsa-utils perl bash-completion parted cpufrequtils unzip"
INSTPKG+=" vim less screen htop sudo locate tree ncdu toilet figlet git mosh tmux"

# bluetooth libbluetooth3 libbluetooth-dev lirc console-data hostapd
# wireless-tools wpasupplicant bridge-utils
echo $INSTPKG
apt-get -qq -y upgrade
export DEBIAN_FRONTEND=noninteractive; apt-get -qq -y install $INSTPKG
# set hostname
DESTHOSTNAME="Cubieboard"
echo $DESTHOSTNAME > /etc/hostname
if ! grep -q $DESTHOSTNAME /etc/hosts; then
    sed -i "s/localhost/localhost Cubieboard/g" /etc/hosts
fi

#Enable Sshd root login
sed -e "s/PermitRootLogin without-password/PermitRootLogin yes/g" -i /etc/ssh/sshd_config
sed -e "s/PermitRootLogin no/PermitRootLogin yes/g" -i /etc/ssh/sshd_config

#Add noatime to root fs and tell that journaling is disabled (data=writeback)
if ! grep -q noatime /etc/fstab; then
    FSTABLINE="/dev/mmcblk0p1  /           ext4    defaults,noatime,nodiratime,data=writeback,commit=600,errors=remount-ro        0       0"
    echo $FSTABLINE >> /etc/fstab
fi
# change default I/O scheduler, noop for flash media and SSD, cfq for mechanical drive
if ! grep -q noop /etc/sysfs.conf; then
    echo "block/mmcblk0/queue/scheduler = noop" >> /etc/sysfs.conf
    echo "block/sda/queue/scheduler = cfq" >> /etc/sysfs.conf
fi
# flash media tuning
sed -e 's/#RAMTMP=no/RAMTMP=yes/g' -i /etc/default/tmpfs
sed -e 's/#RUN_SIZE=10%/RUN_SIZE=128M/g' -i /etc/default/tmpfs
sed -e 's/#LOCK_SIZE=/LOCK_SIZE=/g' -i /etc/default/tmpfs
sed -e 's/#SHM_SIZE=/SHM_SIZE=128M/g' -i /etc/default/tmpfs
sed -e 's/#TMP_SIZE=/TMP_SIZE=800M/g' -i /etc/default/tmpfs
# configure MIN / MAX Speed for cpufrequtils

sed -e 's/MIN_SPEED="0"/MIN_SPEED="480000"/g' -i /etc/init.d/cpufrequtils
sed -e 's/MAX_SPEED="0"/MAX_SPEED="1008000"/g' -i /etc/init.d/cpufrequtils
#sudo sed -i "s/echo -n 1200000/echo -n 1008000/g" /etc/init.d/cpufrequtils
#@TODO :Ondemand is not compiled in kernel config. Need to fix this
sed -e 's/ondemand/interactive/g' -i /etc/init.d/cpufrequtils
# enable serial console (Debian/sysvinit way)
if ! grep -q 115200 /etc/inittab; then
    echo T0:2345:respawn:/sbin/getty -L ttyS0 115200 vt100 >> /etc/inittab
fi

#Scripts for autoresize at first boot from cubian
chmod +x /etc/init.d/cubian-*
update-rc.d cubian-firstrun defaults
#Script to configure leds
chmod +x /etc/init.d/blink_leds
update-rc.d blink_leds defaults

# Install RAMLOG
dpkg -i /tmp/ramlog_2.0.0_all.deb
if ! grep -q "TMPFS_RAMFS_SIZE=256m" /etc/default/ramlog; then
    sed -e 's/TMPFS_RAMFS_SIZE=/TMPFS_RAMFS_SIZE=256m/g' -i /etc/default/ramlog
    sed -e 's/# Required-Start:    $remote_fs $time/# Required-Start:    $remote_fs $time ramlog/g' -i /etc/init.d/rsyslog
    sed -e 's/# Required-Stop:     umountnfs $time/# Required-Stop:     umountnfs $time ramlog/g' -i /etc/init.d/rsyslog
fi
rm /tmp/ramlog_2.0.0_all.deb
insserv

# Cleanup APT
apt-get -y clean

# Configure Network
sed -i "s/#timeout 60/timeout 10/g" /etc/dhcp/dhclient.conf
echo "# interfaces(5) file used by ifup(8) and ifdown(8)" > /etc/network/interfaces
echo "auto lo" >> /etc/network/interfaces
echo "iface lo inet loopback" >> /etc/network/interfaces
echo "auto eth0" >> /etc/network/interfaces
echo "allow-hotplug eth0" >> /etc/network/interfaces
echo "iface eth0 inet dhcp" >> /etc/network/interfaces
echo "        hwaddress ether fa:5e:d1:84:e7:08" >> /etc/network/interfaces

# set root password to 1234
(echo $ROOTPWD;echo $ROOTPWD;) | passwd root
# force password change upon first login
chage -d 0 root

#Copy lirc configuration"
cp -u /tmp/lirc_config /etc/lirc
cp -u /tmp/lirc_initd /etc/init.d/lirc
rm -f /tmp/lirc*

# Modules to load
if ! grep -q "sunxi" /etc/modules; then
    echo "" >> /etc/modules
    echo "gpio_sunxi" >> /etc/modules
    echo "lirc_gpio" >> /etc/modules
    echo "sunxi_lirc" >> /etc/modules
    echo "sunxi_ss" >> /etc/modules
fi

#Custom and fun MOTD :)
# update /etc/motd
rm /etc/motd
touch /etc/motd
if ! grep -q toilet /etc/init.d/motd; then
    echo "" > /etc/motd
    ADDMOTD="        toilet -f smmono9 -F gay \`hostname -s\` > \/var\/run\/motd.dynamic"
    sed -i "s/# Update motd/# Update motd\n$ADDMOTD/g" /etc/init.d/motd
    sed -i "s/uname -snrvm >/uname -srvm >>/g" /etc/init.d/motd
fi

#####################################
#BOARD DEPENDANT this for CB2 and CT
#Removed as this caused CPU issues (high CPU usage)
# eth0 should run on a dedicated processor for CB2/CBT only !
#if ! grep -q smp_affinity $ROOTFSDIR/etc/rc.local; then
#	sed -e 's/exit 0//g' -i $ROOTFSDIR/etc/rc.local
#	echo "echo 2 > /proc/irq/$(cat /proc/interrupts | grep eth0 | cut -f 1 -d ":" | tr -d " ")/smp_affinity" >> $ROOTFSDIR/etc/rc.local
#	echo "exit 0" >> $ROOTFSDIR/etc/rc.local
#fi

#UnusedTo configure keyboard :
#apt-get install console-data

