# Usage: printStatus <function> <message>
function printStatus {
    local TMP_NAME="${1}"
    local TMP_TIME="`date '+%y/%m/%d %H:%M:%S'`"
    shift

    if [ -f "${CUBIESTRAP_LOG_FILE}" ]; then
      printf "[${TMP_TIME} %.15s] %s\n" "${TMP_NAME}" "$@" >> ${CUBIESTRAP_LOG_FILE}
    fi

    printf "[${TMP_TIME} %.15s] %s\n" "${TMP_NAME}" "$@"
}


#Usage : getOrUpdateRepo <destDir> <GitRepoURL -b branch>
function getOrUpdateRepo {
    local DESTDIR="${1}"; shift
    local REPOURL="$@"

    if [ -d "$DESTDIR" ]
        then
            printStatus "getOrUpdateRepo" "Updating $DESTDIR"
            cd $DESTDIR;
            #checks if git pull is up to date
            if [ $(git pull | wc -w) -ne 2 ]; then
                touch $DESTDIR/toBuild
            fi
            cd $BASEDIR

	else
            printStatus "getOrUpdateRepo" "Fetching Sources for $DESTDIR"
            #Kernel sources tend to be huge so I opted to get only the latest revision of code
            #Use : git clone --depth 1
            git clone -q --depth 1 $REPOURL $DESTDIR
            touch $DESTDIR/toBuild
    fi
}


#Usage : needBuild <BuildDir>
function needBuild {
    local BUILDDIR="$@"

    if [ -e $BUILDDIR/toBuild ] || [ $FORCEBUILD ]; then
        #YES !
        return 0
    else
        #No
        return 1
    fi
}


#Usage finishBuild <BuildDir>
function finishBuild {
    local BUILDDIR="$@"

    rm -f $BUILDDIR/toBuild
}
