#!/usr/bin/env python
# -*- coding: utf-8 -*-
import gnomedvb
import gtk
from gnomedvb.preferences.ui.Preferences import Preferences
from gnomedvb.preferences.model.DVBModel import DVBModel

gnomedvb.setup_i18n()

model = DVBModel()
prefs = Preferences(model)
prefs.show()
gtk.main()
