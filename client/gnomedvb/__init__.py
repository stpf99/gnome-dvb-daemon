#!/usr/bin/env python
# -*- coding: utf-8 -*-
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

