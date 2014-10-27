
#WARNING: Do not use the 4.8 gcc versions of the linaro toolchain to build legacy kernels (sunxi-3.4 etc.), those seem to have issues building the kernel. Use an earlier version instead.
#@TODO : http://wits-hep.blogspot.fr/2013/11/building-cubieboard-kernel-part-1.html


fetchSourcesAndBuild() {
    local DEST=$BUILDPATH
    local BOARDPATH=$BUILDPATH

    printStatus "fetchSources" "Downloading all sources for build and compiling"
    # Sunxi Tools
    DEST="$BUILDPATH/sunxi-tools";
    getOrUpdateRepo $DEST "https://github.com/linux-sunxi/sunxi-tools.git"
    cd $DEST
    if needBuild $DEST; then
        printStatus "fetchSources" "Compiling $DEST"
        make clean && make fex2bin && make bin2fex
        cp fex2bin bin2fex /usr/local/bin/
        make clean
        make 'fex2bin' CC=arm-linux-gnueabihf-gcc
        make 'bin2fex' CC=arm-linux-gnueabihf-gcc
        make 'nand-part' CC=arm-linux-gnueabihf-gcc
        finishBuild $DEST
    fi

    #Cubieboard Config files
    DEST="$BUILDPATH/cubie-configs";
    getOrUpdateRepo $DEST "https://github.com/cubieboard/cubie_configs"

    # Lirc RX and TX functionality for Allwinner A1X and A20 chips
    DEST="$BUILDPATH/sunxi-lirc";
    getOrUpdateRepo $DEST "https://github.com/matzrh/sunxi-lirc"

    ############
    #CB2 Section - sun7i
    BOARDPATH="$BUILDPATH/cb2"; mkdir -p $BOARDPATH

    #KERNELS
    DEST="$BOARDPATH/kernel/dan-3.4.103/linux-sunxi";
    getOrUpdateRepo $DEST "https://github.com/dan-and/linux-sunxi -b dan-3.4.103"
    if needBuild $DEST; then
        printStatus "fetchSources" "Compiling $DEST - this will take a long time"
        make clean CROSS_COMPILE=arm-linux-gnueabihf-
	# Adding wlan firmware to kernel source
	cd $DEST/firmware;
	wget --quiet https://github.com/igorpecovnik/Cubietruck-Debian/raw/master/bin/ap6210.zip
	unzip -o ap6210.zip
	rm ap6210.zip
	cd $DEST
	# get proven config
	cp -u $BASEDIR/config/kernel.config $DEST/.config
	#Build
	export ARCH=arm
	export DEB_HOST_ARCH=armhf
	export CONCURRENCY_LEVEL=4
	fakeroot make-kpkg --arch arm --cross-compile arm-linux-gnueabihf- --initrd --append-to-version=-aku1 kernel_image kernel_headers
	make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- EXTRAVERSION=-aku1 uImage
        cp arch/arm/boot/uImage ../uImage
        export ARCH=
        export DEB_HOST_ARCH=
        export CONCURRENCY_LEVEL=
        finishBuild $DEST
    fi

    #U-BOOT
    DEST="$BOARDPATH/u-boot-sunxi";
    getOrUpdateRepo $DEST "https://github.com/patrickhwood/u-boot -b pat-cb2-ct"
    if needBuild $DEST; then
        # Applying Patch for CB2 stability
        sed -e 's/.clock = 480/.clock = 432/g' -i $DEST/board/sunxi/dram_cubieboard2.c
        #WARNING : DO NOT use parallel CC as compilation will fail miserably.
        cd $DEST
        make clean CROSS_COMPILE=arm-linux-gnueabihf-
        make 'cubieboard2' CROSS_COMPILE=arm-linux-gnueabihf-
        #cp -u $DEST/u-boot-sunxi/u-boot-sunxi-with-spl.bin $BUILDOUT/
        finishBuild $DEST
    fi

    #FEX Files
    DEST=$BOARDPATH;
    # Applying Patch for "high load". Could cause troubles with USB OTG port
    cp -f $BUILDPATH/cubie-configs/sysconfig/linux/cubieboard2.fex $DEST/cubieboard2.fex
    sed -e 's/usb_detect_type     = 1/usb_detect_type     = 0/g' -i $DEST/cubieboard2.fex
    # Prepare fex files for VGA & HDMI
    sed -e 's/screen0_output_type.*/screen0_output_type     = 3/g' $DEST/cubieboard2.fex > $DEST/cb2-hdmi.fex
    sed -e 's/screen0_output_type.*/screen0_output_type     = 4/g' $DEST/cubieboard2.fex > $DEST/cb2-vga.fex
    # Build bin files
    fex2bin $DEST/cb2-hdmi.fex $DEST/cb2-hdmi.bin
    fex2bin $DEST/cb2-vga.fex $DEST/cb2-vga.bin

    ############
    #CB1 Section - sun4i
    #TODO

    cd $BASEDIR
}

oldFetch () {
	#@TODO : ADD SUPPORT FOR CB1 !
	printStatus "fetchSources" "Getting Required Source Files from GitHub"
	#########################
	#BOARD INDEPENDANT
	if [ -d "$DEST/sunxi-tools" ]
	then
		cd $DEST/sunxi-tools; git pull; cd $SRC
	else
		printStatus "fetchSources" "Getting sunxi-tools"
		git clone -q https://github.com/linux-sunxi/sunxi-tools.git $DEST/sunxi-tools # Allwinner tools
	fi
	#Kernel sources tend to be huge so I opted to get only the latest revision of code
	#Use : git clone --depth 1
	if [ -d "$DEST/linux-sunxi" ]
	then
		cd $DEST/linux-sunxi; git pull -f; cd $SRC
	else
		printStatus "fetchSources" "Getting sunxi linux kernel"
                git clone -q --depth 1 https://github.com/patrickhwood/u-boot -b pat-cb2-ct  $DEST/u-boot-sunxi
	fi


	#####################################
	#BOARD DEPENDANT
	if [ -d "$DEST/u-boot-sunxi" ]
	then
		cd $DEST/u-boot-sunxi ; git pull; cd $SRC
	else
		printStatus "fetchSources" "Getting u-boot-sunxi"
		#git clone https://github.com/linux-sunxi/u-boot-sunxi $DEST/u-boot-sunxi     # Experimental boot loader
		#cd $DEST/u-boot-sunxi; patch -p1 < $SRC/patch/uboot-dualboot.patch           # Patching for dual boot
		git clone -q --depth 1 https://github.com/patrickhwood/u-boot -b pat-cb2-ct  $DEST/u-boot-sunxi # CB2 / CT Dual boot loader
	fi

	#OK For CB2 and CBT but wrong for CB1 !!
	#@TODO : Suggest FIX !
	printStatus "fetchSources" "Getting cubie-config files"
	if [ -d "$DEST/cubie_configs" ]
	then
		cd $DEST/cubie_configs; git pull; cd $SRC
	else
		git clone -q https://github.com/cubieboard/cubie_configs $DEST/cubie_configs # Hardware configurations
	fi

	cd $BASEDIR
}

patchSource () {
	# Applying patch for crypt and some performance tweak
        printStatus "patchSource" "Pathcing Source Files"
	local DEST=$BUILDPATH
	# Applying Patch for CB2 stability
	sed -e 's/.clock = 480/.clock = 432/g' -i $DEST/u-boot-sunxi/board/sunxi/dram_cubieboard2.c
	# Applying Patch for "high load". Could cause troubles with USB OTG port
	sed -e 's/usb_detect_type     = 1/usb_detect_type     = 0/g' -i $DEST/cubie_configs/sysconfig/linux/cubietruck.fex
	sed -e 's/usb_detect_type     = 1/usb_detect_type     = 0/g' -i $DEST/cubie_configs/sysconfig/linux/cubieboard2.fex

	# Prepare fex files for VGA & HDMI
	sed -e 's/screen0_output_type.*/screen0_output_type     = 3/g' $DEST/cubie_configs/sysconfig/linux/cubieboard2.fex > $DEST/cubie_configs/sysconfig/linux/cb2-hdmi.fex
	sed -e 's/screen0_output_type.*/screen0_output_type     = 4/g' $DEST/cubie_configs/sysconfig/linux/cubieboard2.fex > $DEST/cubie_configs/sysconfig/linux/cb2-vga.fex

}

compileTools () {
	printStatus "compileTools" "Compiling boot loader and tools"
	local DEST=$BUILDPATH
	mkdir -p $BUILDOUT

	# sunxi-tools
	cd $DEST/sunxi-tools
	make clean && make fex2bin && make bin2fex
	cp fex2bin bin2fex /usr/local/bin/

	#####################################
	#BOARD DEPENDANT
	# boot loader - DO NOT use parallel CC as compilation will fail miserably.
	cd $DEST/u-boot-sunxi
	make clean CROSS_COMPILE=arm-linux-gnueabihf-
	make 'cubieboard2' CROSS_COMPILE=arm-linux-gnueabihf-
	cp -u $DEST/u-boot-sunxi/u-boot-sunxi-with-spl.bin $BUILDOUT/

	# hardware configuration for BC2
	fex2bin $DEST/cubie_configs/sysconfig/linux/cb2-hdmi.fex $BUILDOUT/cb2-hdmi.bin
	fex2bin $DEST/cubie_configs/sysconfig/linux/cb2-vga.fex $BUILDOUT/cb2-vga.bin

	# hardware configuration for CT or CB1
        # TODO

        cd $BASEDIR
}


buildKernel () {
	printStatus "compileTools" "Compiling Kernel - This will take a while"
	local DEST=$BUILDPATH
	cd $DEST/linux-sunxi

        #####################################
	#BOARD DEPENDANT this is for CB2 and CT => sun7i
	make clean CROSS_COMPILE=arm-linux-gnueabihf-

	# Adding wlan firmware to kernel source
	cd $DEST/linux-sunxi/firmware;
	wget https://github.com/igorpecovnik/Cubietruck-Debian/raw/master/bin/ap6210.zip
	unzip -o ap6210.zip
	rm ap6210.zip
	cd $DEST/linux-sunxi

	#useless ? make $CTHREADS ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- sun7i_defconfig
	# get proven config
	cp -u $BASEDIR/config/kernel.config $DEST/linux-sunxi/.config
	#Build
	export ARCH=arm
	export DEB_HOST_ARCH=armhf
	export CONCURRENCY_LEVEL=`grep -m1 cpu\ cores /proc/cpuinfo | cut -d : -f 2`
	fakeroot make-kpkg --arch arm --cross-compile arm-linux-gnueabihf- --initrd --append-to-version=-aku1 kernel_image kernel_headers
	make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- EXTRAVERSION=-aku1 uImage

	#make $CTHREADS ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- uImage modules
	#make $CTHREADS ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- INSTALL_MOD_PATH=output modules_install
	#make $CTHREADS ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- INSTALL_HDR_PATH=output headers_install

	#####################################
	#BOARD DEPENDANT this is for CB1 sun4i

	cd $BASEDIR
}
