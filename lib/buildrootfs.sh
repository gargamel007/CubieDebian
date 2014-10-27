# Usage : prepareRootFS <DEST DIR>
function prepareRootFS {
    local DEST="$@"

    # enable arm binary format so that the cross-architecture chroot environment will work
    test -e /proc/sys/fs/binfmt_misc/qemu-arm || update-binfmts --enable qemu-arm
    # install qemu & resolv.conf (to get network in chroot)
    printStatus "PrepareRootfs" "Installing Qemu and resolv.conf in $DEST"
    if [ ! -f $DEST/usr/bin/qemu-arm-static ];then
        cp `which qemu-arm-static` $DEST/usr/bin
    fi
    if [ ! -f $DEST/etc/resolv.conf ];then
        cp /etc/resolv.conf $DEST/etc/
    fi
    #mountPseudoFs
    printStatus "PrepareRootfs" "Mounting virtual file systems"
    mount -t proc chproc $DEST/proc
    mount -t sysfs chsys $DEST/sys
    mount -t devtmpfs chdev $DEST/dev || mount --bind /dev $DEST/dev
    mkdir -p $DEST/dev/pts
    mount -t devpts chpts $DEST/dev/pts
}

# Usage : cleanupRootFS <DEST DIR>
function cleanupRootFS {
    local DEST="$@"
	#sync & umountPseudoFs
	printStatus "cleanupRootfs" "Unmounting virtual file systems in $DEST"
	sync
	sleep 2
	umount -l $DEST/dev/pts
	umount -l $DEST/dev
	umount -l $DEST/proc
	umount -l $DEST/sys
        sleep 5
	#uninstall qemu & resolv.conf
	printStatus "cleanupRootfs" "Uninstall Qemu and revolv.conf"
	if [ -f $DEST/etc/resolv.conf ];then
            rm $DEST/etc/resolv.conf
	fi
	if [ -f $DEST/usr/bin/qemu-arm-static ];then
            rm $DEST/usr/bin/qemu-arm-static
	fi
}

# Usage <DEST ROOT> <ScriptFilePath>
function runChrootScript {
    local DEST="${1}"; shift
    local SCRIPTPATH="$@"
    local SCRIPTNAME=`basename $SCRIPTPATH`
    printStatus "runChrootScript" "Running $SCRIPTNAME from $SCRIPTPATH chrooted in  $DEST"
    cp -u $SCRIPTPATH $DEST/root/
    prepareRootFS $DEST
    LC_ALL=C LANGUAGE=C LANG=C chroot $DEST /bin/bash -c "bash /root/$SCRIPTNAME"
    rm -f $DEST/root/$SCRIPTNAME
    cleanupRootFS $DEST
}



createBaseFS() {
    local DEST="$ROOTFSDIR/base"; mkdir -p $DEST
    if [ $FORCEREBUILDBASEROOTFS ]; then
        cleanupRootFS $DEST
        rm -rf $DEST
        printStatus "createBaseFS" "Bootstrapping base FS in $DEST"
        qemu-debootstrap --no-check-gpg --arch=armhf wheezy $DEST http://debian.mirrors.ovh.net/debian/
    fi

    printStatus "createBaseFS" "Installing scripts on file system"
    cp -u $BASEDIR/scripts/cubian-resize2fs $DEST/etc/init.d
    cp -u $BASEDIR/scripts/cubian-firstrun $DEST/etc/init.d
    cp -u $BASEDIR/scripts/blink_leds $DEST/etc/init.d
    cp -u $BUILDPATH/sunxi-tools/fex2bin $DEST/usr/bin/
    cp -u $BUILDPATH/sunxi-tools/bin2fex $DEST/usr/bin/
    cp -u $BUILDPATH/sunxi-tools/nand-part $DEST/usr/bin/
    printStatus "createBaseFS" "Copy lirc configuration"
    cp -u $BUILDPATH/sunxi-lirc/lirc_init_files/hardware.conf $DEST/tmp/lirc_config
    cp -u $BUILDPATH/sunxi-lirc/lirc_init_files/init.d_lirc $DEST/tmp/lirc_initd

    printStatus "createBaseFS" "Installing Ramlog"
    wget --quiet http://www.tremende.com/ramlog/download/ramlog_2.0.0_all.deb
    mv ramlog_2.0.0_all.deb $DEST/tmp/ramlog_2.0.0_all.deb

    printStatus "createBaseFS" "Running base install script - long"
    runChrootScript $DEST $BASEDIR/scripts/setupCubianBase.sh
}


createSimpleXfreeFS() {
    local DEST="$ROOTFSDIR/simpleXfree"; mkdir -p $DEST
    if [ $FORCEREBUILDBASEROOTFS ] || [ $FORCEBUILDXFREEROOTFS ]; then
        cleanupRootFS $DEST
        rm -rf $DEST
        printStatus "createBaseFS" "Copying base system in $DEST"
        cp -ax $ROOTFSDIR/base $DEST
    fi

    printStatus "createSimpleXfreeFS" "Running Xfree install script - long !"
    runChrootScript $DEST $BASEDIR/scripts/setupSimpleXfree.sh
}
