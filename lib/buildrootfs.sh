prepareRootfs() {
	# enable arm binary format so that the cross-architecture chroot environment will work
	test -e /proc/sys/fs/binfmt_misc/qemu-arm || update-binfmts --enable qemu-arm
	# install qemu & resolv.conf (to get network in chroot)
	printStatus "PrepareRootfs" "Installing Qemu and resolv.conf"
	if [ ! -f ${ROOTFSDIR}/usr/bin/qemu-arm-static ];then
    	cp `which qemu-arm-static` ${ROOTFSDIR}/usr/bin
	fi
	if [ ! -f ${ROOTFSDIR}/etc/resolv.conf ];then
	    cp /etc/resolv.conf ${ROOTFSDIR}/etc/
	fi
	#mountPseudoFs
	printStatus "PrepareRootfs" "Mounting virtual file systems"
	mount -t proc chproc ${ROOTFSDIR}/proc
	mount -t sysfs chsys ${ROOTFSDIR}/sys
	mount -t devtmpfs chdev ${ROOTFSDIR}/dev || mount --bind /dev ${ROOTFSDIR}/dev
	mkdir -p $ROOTFSDIR/dev/pts
	mount -t devpts chpts ${ROOTFSDIR}/dev/pts
}

cleanupRootfs() {
	#sync & umountPseudoFs
	printStatus "cleanupRootfs" "Unmounting virtual file systems"
	sync
	sleep 5
	umount -l ${ROOTFSDIR}/dev/pts
	umount -l ${ROOTFSDIR}/dev
	umount -l ${ROOTFSDIR}/proc
	umount -l ${ROOTFSDIR}/sys
	#uninstall qemu & resolv.conf
	printStatus "cleanupRootfs" "Uninstall Qemu and revolv.conf"
	if [ -f ${ROOTFSDIR}/etc/resolv.conf ];then
	    rm ${ROOTFSDIR}/etc/resolv.conf
	fi
	if [ -f ${ROOTFSDIR}/usr/bin/qemu-arm-static ];then
    	rm ${ROOTFSDIR}/usr/bin/qemu-arm-static
	fi
}


bootstrapFS() {
	printStatus "bootstrapFS" "Bootstraping Debian file system be patient"
	
	#Old Method
	debootstrap --no-check-gpg --arch=armhf --foreign wheezy $ROOTFSDIR http://debian.mirrors.ovh.net/debian/
	prepareRootfs
	DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
	LC_ALL=C LANGUAGE=C LANG=C chroot $ROOTFSDIR /debootstrap/debootstrap --second-stage http://debian.mirrors.ovh.net/debian/
	cleanupRootfs
	#Seems useless ?
	prepareRootfs
	DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
	LC_ALL=C LANGUAGE=C LANG=C chroot $ROOTFSDIR dpkg --configure -a
	cleanupRootfs

	#New method is a lot shorter :)
	#qemu-debootstrap --no-check-gpg --arch=armhf wheezy $ROOTFSDIR http://debian.mirrors.ovh.net/debian/
}

configureBaseFS() {
	#Add Qemu executable and mounts
	prepareRootfs

	local DEST_LANG="en_US"
	local DEST_LANGUAGE="en"

	#@TODO : Add crytpo module sunxi_ss for better speed
	#@TODO : Bootsplash
	#@TODO : Lirc
	#@TODO : module gpio_sunxi

	printStatus "configureBaseFS" "Generating sources.list"
	local sourcesFile="$ROOTFSDIR/etc/apt/sources.list"
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
	
	printStatus "configureBaseFS" "Running update"
	chroot $ROOTFSDIR /bin/bash -c "apt-get -qq update"

	printStatus "configureBaseFS" "Reconfiguring locales and console"
	chroot $ROOTFSDIR /bin/bash -c "export LANG=C"
	# console
	chroot $ROOTFSDIR /bin/bash -c "export TERM=linux"
	# reconfigure locales
	chroot $ROOTFSDIR /bin/bash -c "apt-get -qq -y install locales"
	echo -e $DEST_LANG'.UTF-8 UTF-8\n' > $ROOTFSDIR/etc/locale.gen
	echo -e 'fr_FR.UTF-8 UTF-8\n' >> $ROOTFSDIR/etc/locale.gen
	echo -e 'LANG="'$DEST_LANG'.UTF-8"\nLANGUAGE="'$DEST_LANG':'$DEST_LANGUAGE'"\n' > $ROOTFSDIR/etc/default/locale
	chroot $ROOTFSDIR /bin/bash -c "export LANG=$DEST_LANG.UTF-8"
	chroot $ROOTFSDIR /bin/bash -c "dpkg-reconfigure -f noninteractive locales"
	chroot $ROOTFSDIR /bin/bash -c "update-locale"
	#Change Timezones
	printStatus "configureBaseFS" "Configure timezone"	
	echo "Europe/Zurich" > $ROOTFSDIR/etc/timezone 
	chroot $ROOTFSDIR /bin/bash -c "dpkg-reconfigure -f noninteractive tzdata"

	printStatus "configureBaseFS" "Upgrade system"
	chroot $ROOTFSDIR /bin/bash -c "apt-get -qq -y upgrade"

	printStatus "configureBaseFS" "Installing other packages this will take a while"
	#Put all packages here :)
	local INSTPKG="dosfstools ntfs-3g hdparm bc lsof hddtemp procps console-setup console-data"
	INSTPKG+=" module-init-tools udev usbutils sysfsutils libfuse2 pciutils uboot-envtools"
	INSTPKG+=" iputils-ping ifupdown iproute ntp ntpdate dhcp3-client telnet rsync libnl-dev"
	INSTPKG+=" netselect-apt openssh-server ca-certificates wget"
	INSTPKG+=" alsa-utils perl bash-completion parted cpufrequtils unzip"
	INSTPKG+=" vim less screen htop sudo locate tree ncdu toilet figlet git mosh"
	echo $INSTPKG
	chroot $ROOTFSDIR /bin/bash -c "export DEBIAN_FRONTEND=noninteractive; apt-get -qq -y install $INSTPKG"
	
	#bluetooth libbluetooth3 libbluetooth-dev lirc console-data hostapd 
 	#wireless-tools wpasupplicant bridge-utils

	printStatus "configureBaseFS" "Reconfiguring Hostname"
	# set hostname
	local DESTHOSTNAME="Cubieboard"
	echo $DESTHOSTNAME > $ROOTFSDIR/etc/hostname
	if ! grep -q $DESTHOSTNAME $ROOTFSDIR/etc/hosts; then
		sed -i "s/localhost/localhost Cubieboard/g" $ROOTFSDIR/etc/hosts
	fi
	# update /etc/motd
	rm $ROOTFSDIR/etc/motd
	touch $ROOTFSDIR/etc/motd

	#Enable Sshd root login
	sed -e "s/PermitRootLogin without-password/PermitRootLogin yes/g" -i $ROOTFSDIR/etc/ssh/sshd_config
	sed -e "s/PermitRootLogin no/PermitRootLogin yes/g" -i $ROOTFSDIR/etc/ssh/sshd_config

	printStatus "configureBaseFS" "Tweaking io/sdcard performance"
	#Add noatime to root fs !
	if ! grep -q noatime $ROOTFSDIR/etc/fstab; then
		echo "/dev/mmcblk0p1  /           ext4    defaults,noatime,nodiratime,data=writeback,commit=600,errors=remount-ro        0       0" >> $ROOTFSDIR/etc/fstab
	fi
	# change default I/O scheduler, noop for flash media and SSD, cfq for mechanical drive
	if ! grep -q noop $ROOTFSDIR/etc/sysfs.conf; then
		echo "block/mmcblk0/queue/scheduler = noop" >> $ROOTFSDIR/etc/sysfs.conf
		echo "block/sda/queue/scheduler = cfq" >> $ROOTFSDIR/etc/sysfs.conf
	fi
	# flash media tuning
	sed -e 's/#RAMTMP=no/RAMTMP=yes/g' -i $ROOTFSDIR/etc/default/tmpfs
	sed -e 's/#RUN_SIZE=10%/RUN_SIZE=128M/g' -i $ROOTFSDIR/etc/default/tmpfs 
	sed -e 's/#LOCK_SIZE=/LOCK_SIZE=/g' -i $ROOTFSDIR/etc/default/tmpfs 
	sed -e 's/#SHM_SIZE=/SHM_SIZE=128M/g' -i $ROOTFSDIR/etc/default/tmpfs 
	sed -e 's/#TMP_SIZE=/TMP_SIZE=800M/g' -i $ROOTFSDIR/etc/default/tmpfs 
	# configure MIN / MAX Speed for cpufrequtils
	sed -e 's/MIN_SPEED="0"/MIN_SPEED="480000"/g' -i $ROOTFSDIR/etc/init.d/cpufrequtils
	sed -e 's/MAX_SPEED="0"/MAX_SPEED="1008000"/g' -i $ROOTFSDIR/etc/init.d/cpufrequtils
	#sudo sed -i "s/echo -n 1200000/echo -n 1008000/g" $ROOTFSDIR/etc/init.d/cpufrequtils
	#@TODO :Ondemand is not compiled in kernel config. Need to fix this
	sed -e 's/ondemand/interactive/g' -i $ROOTFSDIR/etc/init.d/cpufrequtils
	# enable serial console (Debian/sysvinit way)
	echo T0:2345:respawn:/sbin/getty -L ttyS0 115200 vt100 >> $ROOTFSDIR/etc/inittab

	printStatus "configureBaseFS" "Installing init.d scripts"
	#Scripts for autoresize at first boot from cubian
	cp -u $BASEDIR/scripts/cubian-resize2fs $ROOTFSDIR/etc/init.d
	cp -u $BASEDIR/scripts/cubian-firstrun $ROOTFSDIR/etc/init.d
	chroot $ROOTFSDIR /bin/bash -c "chmod +x /etc/init.d/cubian-*"
	chroot $ROOTFSDIR /bin/bash -c "update-rc.d cubian-firstrun defaults"
	#Script to configure leds
	cp -u $BASEDIR/scripts/blink_leds $ROOTFSDIR/etc/init.d
	chroot $ROOTFSDIR /bin/bash -c "chmod +x /etc/init.d/blink_leds"
	chroot $ROOTFSDIR /bin/bash -c "update-rc.d blink_leds defaults"

 	printStatus "configureBaseFS" "Installing Ramlog"
	wget --quiet http://www.tremende.com/ramlog/download/ramlog_2.0.0_all.deb
	mv ramlog_2.0.0_all.deb $ROOTFSDIR/tmp/ramlog_2.0.0_all.deb
	chroot $ROOTFSDIR /bin/bash -c "dpkg -i /tmp/ramlog_2.0.0_all.deb"
	sed -e 's/TMPFS_RAMFS_SIZE=/TMPFS_RAMFS_SIZE=256m/g' -i $ROOTFSDIR/etc/default/ramlog
	sed -e 's/# Required-Start:    $remote_fs $time/# Required-Start:    $remote_fs $time ramlog/g' -i $ROOTFSDIR/etc/init.d/rsyslog 
	sed -e 's/# Required-Stop:     umountnfs $time/# Required-Stop:     umountnfs $time ramlog/g' -i $ROOTFSDIR/etc/init.d/rsyslog   
	rm $ROOTFSDIR/tmp/ramlog_2.0.0_all.deb
	chroot $ROOTFSDIR /bin/bash -c "insserv"


	printStatus "configureBaseFS" "Cleanup apt files"
	chroot $ROOTFSDIR /bin/bash -c "apt-get -y clean"

	printStatus "configureBaseFS" "Configuring Network"
	sed -i "s/#timeout 60/timeout 10/g" $ROOTFSDIR/etc/dhcp/dhclient.conf
	echo "# interfaces(5) file used by ifup(8) and ifdown(8)" > $ROOTFSDIR/etc/network/interfaces
	echo "auto lo" >> $ROOTFSDIR/etc/network/interfaces
	echo "iface lo inet loopback" >> $ROOTFSDIR/etc/network/interfaces
	echo "auto eth0" >> $ROOTFSDIR/etc/network/interfaces
	echo "allow-hotplug eth0" >> $ROOTFSDIR/etc/network/interfaces
	echo "iface eth0 inet dhcp" >> $ROOTFSDIR/etc/network/interfaces
	echo "        hwaddress ether fa:5e:d1:84:e7:08" >> $ROOTFSDIR/etc/network/interfaces
	# set password to 1234
	chroot $ROOTFSDIR /bin/bash -c "(echo $ROOTPWD;echo $ROOTPWD;) | passwd root"

	#Custom and fun MOTD :)
	if ! grep -q toilet $ROOTFSDIR/etc/init.d/motd; then
  		echo "" > $ROOTFSDIR/etc/motd
  		local ADDMOTD="        toilet -f smmono9 -F gay \`hostname -s\` > \/var\/run\/motd.dynamic"
  		sed -i "s/# Update motd/# Update motd\n$ADDMOTD/g" $ROOTFSDIR/etc/init.d/motd
  		sed -i "s/uname -snrvm >/uname -srvm >>/g" $ROOTFSDIR/etc/init.d/motd
	fi

	#####################################
	#BOARD DEPENDANT this for CB2 and CT
	# eth0 should run on a dedicated processor for CB2/CBT only !
	if ! grep -q smp_affinity $ROOTFSDIR/etc/rc.local; then
		sed -e 's/exit 0//g' -i $ROOTFSDIR/etc/rc.local
		echo "echo 2 > /proc/irq/\$(cat /proc/interrupts | grep eth0 | cut -f 1 -d \":\" )/smp_affinity" >> $ROOTFSDIR/etc/rc.local
		echo "exit 0" >> $ROOTFSDIR/etc/rc.local
	fi

	#Cleanup
	cleanupRootfs
}

installBootFiles (){
	#@TODO : Add Kernel debug mode to enable/disable serial out on boot
	printStatus "installBootFiles" "Installing uImage modules and boot files"
	cp $BUILDOUT/*.bin $ROOTFSDIR/boot/
	#####################################
	#BOARD DEPENDANT this for CB2 and CT
	cp $BASEDIR/uEnv/uEnv.cb2 $ROOTFSDIR/boot/
	cp $BUILDPATH/linux-sunxi/arch/arm/boot/uImage $ROOTFSDIR/boot/
	cp -R $BUILDPATH/linux-sunxi/output/lib/modules $ROOTFSDIR/lib/
	cp -R $BUILDPATH/linux-sunxi/output/lib/firmware/ $ROOTFSDIR/lib/
	cp -R $BUILDPATH/linux-sunxi/output/include/ $ROOTFSDIR/usr/
	# copy Module.symvers
	cp $BUILDPATH/linux-sunxi/Module.symvers $ROOTFSDIR/usr/include
}

packageRootfs (){
	printStatus "PackageRootfs" "Creating RootFS tgz archive"
	cd $ROOTFSDIR/
	tar cpPfz $BUILDOUT"/rootfs.tgz" .
	cd $BASEDIR
	sleep 3
	#@TODO : Create MD5SUMS
	cp -u $BASEDIR/createImg.sh $BUILDOUT/

}


#UnusedTo configure keyboard :
#apt-get install console-data

