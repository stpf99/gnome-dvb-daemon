# -*- coding: utf-8 -*-
# Copyright (C) 2008,2009 Sebastian Pölsterl
#
# This file is part of GNOME DVB Daemon.
#
# GNOME DVB Daemon is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# GNOME DVB Daemon is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with GNOME DVB Daemon.  If not, see <http://www.gnu.org/licenses/>.

from gnomedvb.DBusWrapper import *

import gnomedvb.defs
import gnomedvb.userdirs
import gettext
from gi.repository import Gtk
import locale
import os
from gettext import gettext as _
from os.path import abspath, join, expanduser

INFOS = {
    "authors": ["Sebastian Pölsterl <sebp@k-d-w.org>"],
    "copyright" : "Copyright © 2008-2009\nSebastian Pölsterl.",
    "name" : _("GNOME DVB Daemon"),
    "version" : gnomedvb.defs.VERSION,
    "website" : "http://live.gnome.org/DVBDaemon",
    "website-label" : _("GNOME DVB Daemon Website"),
}

# From pyxdg
_home = os.environ.get('HOME', '/')
XDG_CONFIG_HOME = os.environ.get('XDG_CONFIG_HOME', join(_home, '.config'))

def setup_i18n():
    # Setup i18n
    gettext.bindtextdomain(gnomedvb.defs.PACKAGE,
        abspath(join(gnomedvb.defs.DATA_DIR, 'locale')))
    if hasattr(gettext, 'bind_textdomain_codeset'):
        gettext.bind_textdomain_codeset(gnomedvb.defs.PACKAGE, 'UTF-8')
    gettext.textdomain(gnomedvb.defs.PACKAGE)

    locale.bindtextdomain(gnomedvb.defs.PACKAGE,
        abspath(join(gnomedvb.defs.DATA_DIR, 'locale')))
    if hasattr(locale, 'bind_textdomain_codeset'):
        locale.bind_textdomain_codeset(gnomedvb.defs.PACKAGE, 'UTF-8')
    locale.textdomain(gnomedvb.defs.PACKAGE)
    
def get_config_dir():
    return join(XDG_CONFIG_HOME, gnomedvb.defs.PACKAGE)

def get_default_recordings_dir():
    videos = None
    gnomedvb.userdirs.get_xdg_user_dir(
        gnomedvb.userdirs.DIRECTORY_VIDEOS)
    if videos == None:
        videos = join(expanduser('~'), 'Videos')
    return join(videos, 'Recordings')
        
def seconds_to_time_duration_string(duration):
    hours = duration / 3600
    minutes = (duration / 60) % 60
    seconds = duration % 60
    text = []
    if hours != 0:
        text.append(gettext.ngettext("%d hour", "%d hours", hours) % hours)
    if minutes != 0:
        text.append(gettext.ngettext("%d minute", "%d minutes", minutes) % minutes)
    if seconds != 0:
        text.append(gettext.ngettext("%d second", "%d seconds", seconds) % seconds)
    return " ".join(text)

