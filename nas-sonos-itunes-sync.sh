#!/bin/sh

#
#    Copyright (c) 2019-2021 Grant Erickson
#    All rights reserved.
#
#    This document is the property of Grant Erickson. It is
#    considered confidential and proprietary information.
#
#    This document may not be reproduced or transmitted in any form,
#    in whole or in part, without the express written permission of
#    Grant Erickson.
#
#    Description:
#      This file synchronizes the music-only portion of a user's
#      iTunes and/or Music library to a locally-mounted, remote file
#      share using rsync.
#
#      The remote file share is typically a NAS volume hosted by
#      Synology accessible by Sonos.
#

usage() {
    name=`basename $0`

    echo "Usage: `basename $0` [ -hqsvV ] <home directory> <remote volume URL> <local mount point>"

    if [ $1 -ne 0 ]; then
        echo "Try '${name} -h' for more information."
    fi

    if [ $1 -ne 1 ]; then
        echo "  -h         Print this help, then exit."
        echo "  -n         Dry run; show what would be done without doing it."
        echo "  -q         Work quietly, without diagnostic output."
        echo "  -s         Log to standard error as well as to "\""${HOME}/Library/Logs/${name}.log"\""."
        echo "  -v         Work verbosely, with diagnostic output."
        echo "  -V         Print version and copyright information, then exit."
    fi

    exit $1
}

version() {
    echo "`basename ${0}` @PACKAGE_VERSION@"
    echo "Copyright (c) 2019-2021 Grant Erickson. All rights reserved."
    
    exit 0
}

log_message() {
    program="`basename ${0}`"
    flags="${1}"
    level="${2}"
    logfile="${HOME}/Library/Logs/${program}.log"

    shift 2

    touch "${logfile}"

    logger -i "${STDERR}" ${flags} -t "${program}" -p "user.${level}" -f "${logfile}" ${*}
}

log_info() {
    log_message "" "info" ${*}
}

log_error() {
    log_message "-s" "error" ${*}
}

do_rsync() {
    local source="${1}"
    local destination="${2}"
    local exclude=""

    shift 2

    exclude="${*}"

    if [ -e "${source}" ]; then
        log_info "Attempting to synchronize "\""${source}"\"" to "\""${destination}"\""..."

        if [ -n "${exclude}" ]; then 
            ${DRYRUN} rsync ${VERBOSE} -a --delete --exclude='.DS_Store' "${exclude}" "${source}" "${destination}"
        else
            ${DRYRUN} rsync ${VERBOSE} -a --delete --exclude='.DS_Store' "${source}" "${destination}"
        fi

        if [ ${?} -ne 0 ]; then
            log_error "failed to synchronize "\""${source}"\"" to "\""${destination}"\"" with status ${?}."

            exit 1
        else
            log_info "successfully synchronized "\""${source}"\"" to "\""${destination}"\""."
        fi
    fi
}

DRYRUN=""
OPTIONS="hnqsvV"
STDERR=""
VERBOSE="--quiet"

#
# Main program body
#

# Parse the command line arguments

while getopts "${OPTIONS}" opt; do

    case "${opt}" in

    'h')
        usage 0
        ;;

    'n')
        DRYRUN="echo"
        ;;

    'q')
        VERBOSE="--quiet"
        ;;

    's')
        STDERR="-s"
        ;;

    'v')
        VERBOSE="--verbose --progress"
        ;;

    'V')
        version
        ;;

    *)
        usage 1
        ;;

    esac

done

# Shift away arguments already parsed.

shift `expr "${OPTIND}" - 1`

# Check to ensure we have the required number of remaining positional
# parameters.

if [ ${#} -ne 3 ]; then
    usage 1
fi

STEM="${1}"
REMOTE="${2}"
REMOTEMOUNT="${3}"
ITUNESDIR="iTunes"
LOCALITUNESPATH="${STEM}/Music/${ITUNESDIR}"
MUSICDIR="Music"
LOCALMUSICPATH="${STEM}/Music/${MUSICDIR}"

shift 3

log_info "Attempting to mount remote volume  "\""${REMOTE}"\""..."

# Attempt to mount the remote volume via an AppleScript message to the
# Finder such that any extant keychains for the remote may be
# transparently leveraged.

${DRYRUN} osascript -e "tell application "\""Finder"\""" -e "mount volume "\""${REMOTE}"\""" -e "end tell"

if [ ${?} -ne 0 ]; then
    log_error "failed to mount remote volume "\""${REMOTE}"\""."

    exit 1
fi

# Double-check that the remote mount point is actually there locally.

if [ ! -d "${REMOTEMOUNT}" ]; then
    log_error "cannot find the remote mount point, "\""${REMOTEMOUNT}"\""."

    exit 1
fi

# As appropriate, run an rsync archive operation of: 1) "iTunes
# Music", "iTunes Library.itl", and "iTunes Music Library.xml" from
# the local source, excluding "TV Shows" and any ".DS_Store" files and
# deleting items in the destination not present in the source, to the
# remote on the local mount point. 2) "Music Library.musiclibrary" and
# "Media" (including a potentially localized version thereof) from the
# local source, excluding any ".DS_Store" files and deleting items in
# the destination not present in the source, to the remote on the local
# mount point.

if [ ! -d "${LOCALITUNESPATH}" ] && [ ! -d "${LOCALMUSICPATH}" ]; then
    log_error "cannot find the local iTunes path, "\""${LOCALITUNESPATH}"\"" or local Music path, "\""${LOCALMUSICPATH}"\""."

    exit 1
fi

# 1) Synchronize iTunes.app content, if present

if [ "${LOCALITUNESPATH}" ]; then
    log_info "Attempting to synchronize "\""${LOCALITUNESPATH}"\""..."

    do_rsync "${LOCALITUNESPATH}/iTunes Library.itl"        "${REMOTEMOUNT}/${ITUNESDIR}/" --exclude='TV Shows'
    do_rsync "${LOCALITUNESPATH}/iTunes Library.xml"        "${REMOTEMOUNT}/${ITUNESDIR}/" --exclude='TV Shows'
    do_rsync "${LOCALITUNESPATH}/iTunes Music"              "${REMOTEMOUNT}/${ITUNESDIR}/" --exclude='TV Shows'

    log_info "successfully synchronized "\""${LOCALITUNESPATH}"\""."
fi

# 2) Synchronize Music.app content, if present
#
# Depending on whether Music.app was a first-time initialization or a
# migration from a prior iTunes.app initialization, some directories
# or files may or may not be present.

if [ -d "${LOCALMUSICPATH}" ]; then
    log_info "Attempting to synchronize "\""${LOCALMUSICPATH}"\""..."

    do_rsync "${LOCALMUSICPATH}/Media"                      "${REMOTEMOUNT}/${MUSICDIR}/"
    do_rsync "${LOCALMUSICPATH}/Media.localized"            "${REMOTEMOUNT}/${MUSICDIR}/"
    do_rsync "${LOCALMUSICPATH}/Music Library.musiclibrary" "${REMOTEMOUNT}/${MUSICDIR}/"

    log_info "successfully synchronized "\""${LOCALMUSICPATH}"\""."
fi
