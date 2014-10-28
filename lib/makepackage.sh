function copyBinFiles {
    local DEST="${1}"; shift
    local UBOOT="${1}"; shift
    local ROOTFSFOLDER="${1}"; shift
    local BINFOLDER="${1}"; shift
    local UENV="${1}"; shift
    local FSDEST="$@"

    printStatus "installBootFiles" "Copy bin files"
    cp -u $UBOOT $DEST/u-boot.bin
    cp -u $BASEDIR/createImg.sh $DEST/
    printStatus "installBootFiles" "Copy root FS - long"
    cp -ax $ROOTFSFOLDER $DEST
    local OLDFSNAME=`basename $ROOTFSFOLDER`
    mv $DEST/$OLDFSNAME $DEST/`basename $FSDEST`
    cp -u $BINFOLDER/*.bin $FSDEST/boot/
    cp -u $BINFOLDER/*.fex $FSDEST/boot/
    cp -u $UENV $FSDEST/boot/uEnv.cb2
}

function installKernelDeb {
    local DEST="${1}"; shift
    local KERNELFOLDER="${1}"; shift
    local FSDEST="$@"

    cp -u $KERNELFOLDER/uImage $FSDEST/boot/
    cp -u $KERNELFOLDER/*.deb $FSDEST/tmp/
    prepareRootFS $FSDEST
    chroot $FSDEST /bin/bash -c "dpkg -i /tmp/linux-image-*.deb"
    cleanupRootFS $FSDEST
    rm -f $FSDEST/tmp/*.deb
}

function createFsTgz {
    local DEST="${1}"; shift
    local FSDEST="$@"

    printStatus "PackageRootfs" "Creating RootFS tgz archive"
    cd $FSDEST
    tar cpPfz "$DEST/rootfs.tgz" .
    sleep 3
    #@TODO : Create MD5SUMS
}

packageCb2Headless() {
    local DEST="$BUILDOUT/cb2Headless"; rm -rf $DEST; mkdir -p $DEST
    local UBOOT="$BUILDPATH/cb2/u-boot-sunxi/u-boot-sunxi-with-spl.bin"
    local ROOTFSFOLDER="$ROOTFSDIR/base"
    local BINFOLDER="$BUILDPATH/cb2"
    local UENV="$BASEDIR/uEnv/uEnv.cb2.headless.720p"
    local KERNELFOLDER="$BUILDPATH/cb2/kernel/dan-3.4.103"

    printStatus "installBootFiles" "Creating CB2 Headless Package"
    local FSDEST="$DEST/fs"
    copyBinFiles $DEST $UBOOT $ROOTFSFOLDER $BINFOLDER $UENV $FSDEST
    installKernelDeb $DEST $KERNELFOLDER $FSDEST
    createFsTgz $DEST $FSDEST

    cd $BASEDIR
}

packageCb2Xfree() {
    local DEST="$BUILDOUT/cb2Xfree"; rm -rf $DEST; mkdir -p $DEST
    local UBOOT="$BUILDPATH/cb2/u-boot-sunxi/u-boot-sunxi-with-spl.bin"
    local ROOTFSFOLDER="$ROOTFSDIR/simpleXfree"
    local BINFOLDER="$BUILDPATH/cb2"
    local UENV="$BASEDIR/uEnv/uEnv.cb2.headless.720p"
    local KERNELFOLDER="$BUILDPATH/cb2/kernel/dan-3.4.103"

    printStatus "installBootFiles" "Creating CB2 Xfree Package"
    local FSDEST="$DEST/fs"
    copyBinFiles $DEST $UBOOT $ROOTFSFOLDER $BINFOLDER $UENV $FSDEST
    installKernelDeb $DEST $KERNELFOLDER $FSDEST
    createFsTgz $DEST $FSDEST

    cd $BASEDIR
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


installBootFiles (){
        #TODO: # remove false links to the kernel source
        #find $DEST/output/sdcard/lib/modules -type l -exec rm -f {} \;
	#cp -R $BUILDPATH/linux-sunxi/output/lib/modules $ROOTFSDIR/lib/
	#cp -R $BUILDPATH/linux-sunxi/output/lib/firmware/ $ROOTFSDIR/lib/
	#cp -R $BUILDPATH/linux-sunxi/output/include/ $ROOTFSDIR/usr/
	#copy Module.symvers
	#cp $BUILDPATH/linux-sunxi/Module.symvers $ROOTFSDIR/usr/includei
        echo void
}
