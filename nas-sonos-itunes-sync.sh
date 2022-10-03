#!/bin/sh

#
#    Copyright (c) 2019-2022 Grant Erickson
#    All rights reserved.
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
#

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
    echo "Copyright (c) 2019-2022 Grant Erickson. All rights reserved."
    
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
MUSICDIR="Music"
ITUNESAPPDIR="iTunes"
LOCALITUNESAPPPATH="${STEM}/${MUSICDIR}/${ITUNESAPPDIR}"
MUSICAPPDIR="Music"
LOCALMUSICAPPPATH="${STEM}/${MUSICDIR}/${MUSICAPPDIR}"
XMLLIBRARYFILE="iTunes Library.xml"

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

# As appropriate, run a: 1) rsync archive operation of "iTunes Music" and
# "iTunes Library.itl" from the local source, excluding "TV Shows" and any
# ".DS_Store" files and deleting items in the destination not present in the
# source, to the remote on the local mount point. 2) rsync archive operation
# of "Music Library.musiclibrary" and "Media" (including a potentially
# localized version thereof) from the local source, excluding any ".DS_Store"
# files and deleting items in the destination not present in the source, to
# the remote on the local mount point. 3) rsync archive operation of or
# AppleScript generation of "iTunes Library.xml" to the remote on the local
# mount point.

if [ ! -d "${LOCALITUNESAPPPATH}" ] && [ ! -d "${LOCALMUSICAPPPATH}" ]; then
    log_error "cannot find the local iTunes path, "\""${LOCALITUNESAPPPATH}"\"" or local Music path, "\""${LOCALMUSICAPPPATH}"\""."

    exit 1
fi

# 1) Synchronize iTunes.app content, if present

if [ -d "${LOCALITUNESAPPPATH}" ]; then
    log_info "Attempting to synchronize "\""${LOCALITUNESAPPPATH}"\""..."

    do_rsync "${LOCALITUNESAPPPATH}/iTunes Library.itl"        "${REMOTEMOUNT}/${ITUNESAPPDIR}/" --exclude='TV Shows'
    do_rsync "${LOCALITUNESAPPPATH}/iTunes Music"              "${REMOTEMOUNT}/${ITUNESAPPDIR}/" --exclude='TV Shows'

    log_info "successfully synchronized "\""${LOCALITUNESAPPPATH}"\""."
fi

# 2) Synchronize Music.app content, if present
#
# Depending on whether Music.app was a first-time initialization or a
# migration from a prior iTunes.app initialization, some directories
# or files may or may not be present.

if [ -d "${LOCALMUSICAPPPATH}" ]; then
    log_info "Attempting to synchronize "\""${LOCALMUSICAPPPATH}"\""..."

    do_rsync "${LOCALMUSICAPPPATH}/Media"                      "${REMOTEMOUNT}/${MUSICAPPDIR}/"
    do_rsync "${LOCALMUSICAPPPATH}/Media.localized"            "${REMOTEMOUNT}/${MUSICAPPDIR}/"
    do_rsync "${LOCALMUSICAPPPATH}/Music Library.musiclibrary" "${REMOTEMOUNT}/${MUSICAPPDIR}/"

    log_info "successfully synchronized "\""${LOCALMUSICAPPPATH}"\""."
fi

# 3) One of the most important things to the Sonos experience, particularly for
# large, playlist-heavy libraries, is the "iTunes Library.xml" XML version of
# the music library, which contains all of those potential playlists and the
# tracks that populate them. When this file exists, either locally or on a
# remote NAS volume, Sonos can process it and auto-populate those playlists
# without the effort of manually exporting each and every playlist as a .m3u
# or .m3u8 export.
#
# The iTunes app used to automatically export "iTunes Library.xml" on every
# run of the iTunes app. However, with the transition from the iTunes app to
# the Music app, this is no longer the case. Consequently, the "iTunes
# Library.xml" (which is the exact name expected by Sonos) must be
# manually-generated. This can either be done from the Music app user
# interface (UI) via File > Library > Export Library... or, as here, via an
# undocumented AppleScript event.
#
# If there is a local iTunes app path and an "iTunes Library.xml" BUT NOT a
# Music app path, then we prefer to rsync that file to the NAS volume since
# this would tend to indicate a legacy iTunes app installation. However, if
# there is a Music app path, then presumably the user has upgraded and we then
# generate the "iTunes Library.xml" file from AppleScript on the fly.

if [ -d "${LOCALMUSICAPPPATH}" ]; then
    log_info "Attempting to generate "\""${REMOTEMOUNT}/${MUSICAPPDIR}/${XMLLIBRARYFILE}"\""..."

    if [ -n "${DRYRUN}" ]; then
        ${DRYRUN} osascript -e 'tell application "Music" to «event hookExpt» source 1' ">|" "${REMOTEMOUNT}/${MUSICAPPDIR}/${XMLLIBRARYFILE}"
    else
        music_was_running=$(osascript -e 'if application "Music" is running then'  \
                -e 'return true'                                                   \
            -e 'else'                                                              \
                -e 'return false'                                                  \
            -e 'end if')

		osascript -e 'tell application "Music" to «event hookExpt» source 1'       \
			>| "${REMOTEMOUNT}/${MUSICAPPDIR}/${XMLLIBRARYFILE}"

        music_is_running=$(osascript -e 'if application "Music" is running then'   \
                -e 'return true'                                                   \
            -e 'else'                                                              \
                -e 'return false'                                                  \
            -e 'end if')

		if [ "${music_was_running}" = "false" ] && [ "${music_is_running}" = "true" ]; then
		    osascript -e 'tell application "Music" to quit'
		fi
    fi

    log_info "successfully generated "\""${REMOTEMOUNT}/${MUSICAPPDIR}/${XMLLIBRARYFILE}"\""."
elif [ -d "${LOCALITUNESAPPPATH}" ]; then
    log_info "Attempting to synchronize "\""${LOCALITUNESAPPPATH}/${XMLLIBRARYFILE}"\""..."

    do_rsync "${LOCALITUNESAPPPATH}/${XMLLIBRARYFILE}"         "${REMOTEMOUNT}/${ITUNESAPPDIR}/" --exclude='TV Shows'
fi