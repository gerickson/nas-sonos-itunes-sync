NAS Sonos iTunes Sync
=====================

# Introduction

_NAS Sonos iTunes Sync_ is a command line program that synchronizes to a
remote network-attached storage (NAS) volume one or both of a user's legacy
iTunes app library and media or Music app library and media for access by a
Sonos media player. In addition, it either synchronizes or generates the
"iTunes Library.xml" file that allows Sonos to seamlessly ingest playlists
from those libraries and media.

# Getting Started with NAS Sonos iTunes Sync

## Building NAS Sonos iTunes Sync

If you are not using a prebuilt distribution of _NAS Sonos iTunes Sync_,
building _NAS Sonos iTunes Sync_ should be a straightforward, one-step
process. If you are building from the main branch, start with:

    % make

### Dependencies

_NAS Sonos iTunes Sync_ only depends on the default Korn-compatible shell
installed on a given macOS system.

## Installing NAS Sonos iTunes Sync

To install _NAS Sonos iTunes Sync_ for your use simply invoke:

    % make install

to install _NAS Sonos iTunes Sync_ in the location indicated by the prefix
`make` variable (default "${HOME}").

If you want, instead, to install it for all users of the system, for example,
then you might invoke `make install` as follows:

    % make prefix="/usr/local" install

# Interact

There are numerous avenues for _NAS Sonos iTunes Sync_ support:

  * Bugs and feature requests - [submit to the Issue Tracker](https://github.com/gerickson/nas-sonos-itunes-sync/issues)

# Versioning

_NAS Sonos iTunes Sync_ follows the [Semantic Versioning guidelines](http://semver.org/)
for release cycle transparency and to maintain backwards compatibility.

# License

_NAS Sonos iTunes Sync_ is released under the [Apache License, Version 2.0 license](https://opensource.org/licenses/Apache-2.0).
See the `LICENSE` file for more information.