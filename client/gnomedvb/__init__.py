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

from DBusWrapper import *

import gnomedvb.defs
import gettext
import gio
import gtk
import locale
from gettext import gettext as _
from os.path import abspath, join

INFOS = {
    "authors": ["Sebastian Pölsterl <sebp@k-d-w.org>"],
    "copyright" : "Copyright © 2008-2009\nSebastian Pölsterl.",
    "name" : _("GNOME DVB Daemon"),
    "version" : gnomedvb.defs.VERSION,
    "website" : "http://live.gnome.org/DVBDaemon",
    "website-label" : _("GNOME DVB Daemon Website"),
}

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

