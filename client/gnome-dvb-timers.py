#!/usr/bin/env python
# -*- coding: utf-8 -*-
import gnomedvb
import gtk
from gnomedvb.timers.ui.RecorderWindow import RecorderWindow

gnomedvb.setup_i18n()

w = RecorderWindow()
w.show_all()
gtk.main()
    
