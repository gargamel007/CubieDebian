#!/bin/bash

###########################
#Doc & Usage
###########################
#This scripts generate a ready to use IMG on Cubieboard from downloaded files
#Do not forget to change configuration in the next section
:<<'USAGE'
sudo apt-get install -y git
git clone https://github.com/gargamel007/CubieDebian.git Code/CubieDebian
#CD in directory
sudo bash createImg.sh
USAGE

###########################
#Configuration
###########################
BASEDIR=$(dirname $0)
if [ $BASEDIR = '.' ]
then
        BASEDIR=$(pwd)
    fi
    DEST="$BASEDIR/output"


    ###########################
    #Main
    ###########################
    if [[ $EUID -ne 0 ]]; then
          echo "You must be a root user" 2>&1
            exit 1
        fi

        echo "------ Creating SD Image"
        mkdir -p $DEST
        # create 2G image and mount image to next free loop device
        dd if=/dev/zero of=$DEST/cubiedebian.img bs=1M count=2000 status=noxfer
        LOOP=$(losetup -f)
        #just to make sure
        umount -l $DEST/sdcard/
        losetup -d $LOOP

        echo "----- Mounting raw image"
        losetup $LOOP $DEST/cubiedebian.img
        sync
        sleep 3

        echo "------ Partitionning and mounting filesystem"
        # create one partition starting at 2048 which is default
        #New method
        parted -s $LOOP -- mklabel msdos
        sleep 1
        parted -s $LOOP -- mkpart primary ext4  2048s -1s
        sleep 1
        # just to make sure
        sleep 3
        sync
        partprobe $LOOP
        sleep 3
        sync

        echo "----- Make image bootable using $BASEDIR/u-boot.bin"
        dd if=$BASEDIR/u-boot.bin of=$LOOP bs=1024 seek=8 status=noxfer
        sync
        sleep 3
        echo "----- Umount raw partition"
        losetup -d $LOOP
        sleep 3

        echo "----- Mounting primary partition and create ext4 file system"
        # 2048 (start) x 512 (block size) = where to mount partition
        losetup -o 1048576 $LOOP $DEST/cubiedebian.img
        sleep 4
        # create filesystem
        mkfs.ext4 $LOOP

        # tune filesystem and disable journaling
        tune2fs -o journal_data_writeback $LOOP

        # label it
        e2label $LOOP "CubieDebian"

        echo "----- Create mount point and mount image"
        mkdir -p $DEST/sdcard/
        mount -t ext4 $LOOP $DEST/sdcard/
        echo "Un-tar root fs file into img"
        tar xPpfz rootfs.tgz -C $DEST/sdcard/

        echo "---- Cleanup & Done :)"
        sync
        sleep 4
        umount -l $DEST/sdcard/
        losetup -d $LOOP
