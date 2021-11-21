#
#    Copyright (c) 2019-2021 Grant Erickson
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
#      This file is the makefile for a script that synchronizes the
#      music-only portion of a user's iTunes and/or Music library to a
#      locally-mounted, remote file share using rsync.
#
#      The remote file share is typically a NAS volume hosted by
#      a product such as QNAP or Synology, accessible by Sonos.
#

#
# This Package
#
PACKAGE                 := nas-sonos-itunes-sync

#
# Build directories
#
builddir                := .
top_builddir            := .
abs_builddir            := $(CURDIR)
abs_top_builddir        := $(abspath $(top_builddir))

#
# Source directories
#
srcdir                  := .
top_srcdir              := .
abs_srcdir              := $(CURDIR)
abs_top_srcdir          := $(abspath $(top_srcdir))

#
# Installation Directories
#
DESTDIR                 ?=

prefix                   = ${HOME}
exec_prefix              = ${prefix}
bindir                   = ${exec_prefix}/bin

#
# Programs
#
CAT                      = cat
CHMOD                    = chmod
CP                       = cp
MKDIR                    = mkdir
INSTALL                  = install
RM                       = rm
SED                      = sed

#
# Verbosity
#
V                       ?= 

DEFAULT_VERBOSITY       ?= 0

AT                      := @

VERBOSE                  = $(VERBOSE_$(V))
VERBOSE_                 = $(VERBOSE_$(DEFAULT_VERBOSITY))
VERBOSE_0                = $(AT)
VERBOSE_1                = 

_PROGRESS               := printf "  %-13s %s\n"
PROGRESS                := $(AT)$(_PROGRESS)

VERBOSE_PROGRESS         = $(VERBOSE_PROGRESS_$(V))
VERBOSE_PROGRESS_        = $(VERBOSE_PROGRESS_$(DEFAULT_VERBOSITY))
VERBOSE_PROGRESS_0       = $(PROGRESS)
VERBOSE_PROGRESS_1       = $(AT)true

#
# Version
#
PACKAGE_VERSION          = $(shell $(CAT) $(top_builddir)/.default-version)

VERSION                  = $(PACKAGE_VERSION)

define copy-target
$(VERBOSE_PROGRESS) "CP" "$(@)"
$(VERBOSE)$(CP) $(<) $(@)
endef # copy-target

define create-directory-target
$(VERBOSE_PROGRESS) "MKDIR" "$(@)"
$(VERBOSE)$(MKDIR) -p $(@)
endef # create-directory-target

define install-target
$(VERBOSE_PROGRESS) "INSTALL" "$(@)"
$(VERBOSE)$(INSTALL) -c $(<) $(@)
endef # install-target

SCRIPT = nas-sonos-itunes-sync

all: $(SCRIPT)

$(SCRIPT): $(SCRIPT).sh
	$(VERBOSE_PROGRESS) "SED" "$(@)"
	$(VERBOSE)$(SED) -e \
		"s,@PACKAGE_VERSION@,${PACKAGE_VERSION},g" \
		< "$(<)" \
		> "$(@)"
	$(VERBOSE_PROGRESS) "CHMOD" "$(@)"
	$(VERBOSE)$(CHMOD) 775 $(@)

$(DESTDIR):
	$(create-directory-target)

$(DESTDIR)$(bindir): | $(DESTDIR)
	$(create-directory-target)

$(DESTDIR)$(bindir)/$(SCRIPT): $(SCRIPT) | $(DESTDIR)$(bindir)
	$(install-target)

install: $(DESTDIR)$(bindir)/$(SCRIPT)

uninstall:
	$(VERBOSE_PROGRESS) "RM" "$(DESTDIR)$(bindir)/$(SCRIPT)"
	$(VERBOSE)$(RM) -f $(DESTDIR)$(bindir)/$(SCRIPT)

dist: $(DIST_TARGETS)

clean:
	-$(VERBOSE)$(RM) -f $(SCRIPT)
	-$(VERBOSE)$(RM) -f *~ "#"*