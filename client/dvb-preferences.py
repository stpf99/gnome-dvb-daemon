#!/usr/bin/env python
# -*- coding: utf-8 -*-
import gettext
import locale
from gettext import gettext as _
from os.path import abspath, join

import gtk
import gnomedvb
import gnomedvb.defs
from gnomedvb.preferences.ui.Preferences import Preferences
from gnomedvb.preferences.model.DVBModel import DVBModel

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
  
model = DVBModel()

prefs = Preferences(model)
prefs.show()
gtk.main()
