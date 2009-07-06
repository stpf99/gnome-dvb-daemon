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
import gio
import gtk
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

def launch_default_for_uri(uri_string):
    """
    Open uri_string with the default application
    
    @type uri_string: str 
    """
    gfile = gio.File(uri=uri_string)
    appinfo = gfile.query_default_handler()
    
    if appinfo != None:
        appinfo.launch_uris([uri_string], None)
        
def get_config_dir():
    return join(XDG_CONFIG_HOME, gnomedvb.defs.PACKAGE)

def get_default_recordings_dir():
    videos = gnomedvb.userdirs.get_xdg_user_dir(
        gnomedvb.userdirs.DIRECTORY_VIDEOS)
    if videos == None:
        videos = join(expanduser('~'), 'Videos')
    return join(videos, 'Recordings')
        
def seconds_to_time_duration_string(duration):
    hours = duration / 3600
    minutes = (duration / 60) % 60
    seconds = duration % 60
    if hours == 0:
        if minutes == 0:
            return gettext.ngettext("%d second", "%d seconds", seconds) % seconds
        else:
            return gettext.ngettext("%d minute", "%d minutes", minutes) % minutes
    else:
        h_txt = gettext.ngettext("%d hour", "%d hours", hours) % hours
        m_txt = gettext.ngettext("%d minute", "%d minutes", minutes) % minutes
        return "%s %s" % (h_txt, m_txt)

