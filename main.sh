#!/bin/bash

###########################
#Doc & Usage
###########################
#This scripts generates a kernel and tar archive of a debian system for Cubieboard
#Do not forget to change configuration in the next section
:<<'USAGE'
git clone https://github.com/gargamel007/CubieDebian.git Code/CubieDebian
bash main.sh ### AS ROOT
USAGE

###########################
#Configuration
###########################
BASEDIR=$(dirname $0)
if [ $BASEDIR = '.' ]
then
	BASEDIR=$(pwd)
fi

WORKDIR="/var/CubieBuild"
ROOTFSDIR="$WORKDIR/rootfs"
BUILDPATH="$WORKDIR/buildPath"
BUILDOUT="$WORKDIR/buildOut"

VERSION="CubieDebian 0.3-alpha"

###########################
#Main
###########################
if [[ $EUID -ne 0 ]]; then
  echo "You must be a root user" 2>&1
  exit 1
fi

# To display build time at the end
start=`date +%s`

for i in ./lib/*.sh; do
  source ${i}
done

# optimize build time
CPUS=$(grep -c 'processor' /proc/cpuinfo)
#CTHREADS="-j$(($CPUS + $CPUS/2))" # Might be too high for WM even : "-j${CPUS}"
CTHREADS="-j4"
OLD_PATH=$PATH
#Use compiler cache !
export PATH="/usr/lib/ccache:$PATH"
printStatus "SetupBuild" "Compilation will be optimized for $CPUS CPUS"


printStatus "Main" "Creating Work Directories"
cd $BASEDIR
mkdir -p $WORKDIR $ROOTFSDIR $BUILDPATH $BUILDOUT


#Use to force recompiling all and init base file system
#FORCEBUILD=0 #unset to save time !
#FORCEREBUILDBASEROOTFS=0 #unset to save time !
#FORCEBUILDXFREEROOTFS=0 #Unset to save time !
fetchSourcesAndBuild
createBaseFS
#createSimpleXfreeFS
packageCb2Headless
#packageCb2Xfree

#Cleaning up
export PATH=$OLD_PATH

#Ending script
end=`date +%s`
runtime=$((end-start))
printStatus "Main" " ***** Script completed in $runtime seconds :) *****"
