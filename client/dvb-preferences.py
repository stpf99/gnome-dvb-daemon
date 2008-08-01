#!/usr/bin/env python
# -*- coding: utf-8 -*-
import gtk
import gnomedvb
from gnomedvb.preferences.ui.Preferences import Preferences
from gnomedvb.preferences.model.DVBModel import DVBModel
         
model = DVBModel()

prefs = Preferences(model)
prefs.show()
gtk.main()
