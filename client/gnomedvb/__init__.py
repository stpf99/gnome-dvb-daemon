#!/usr/bin/env python
# -*- coding: utf-8 -*-
from DBusWrapper import *

import gnomedvb.defs
import gettext
import locale
from gettext import gettext as _
from os.path import abspath, join

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
  
