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

import gtk
import pango

class HelpBox(gtk.EventBox):

    def __init__(self):
        gtk.EventBox.__init__(self)
        self.modify_bg(gtk.STATE_NORMAL, self.style.base[gtk.STATE_NORMAL])
                
        frame = gtk.Frame()
        frame.set_shadow_type(gtk.SHADOW_IN)
        self.add(frame)
        
        self._helpview = gtk.Label()
        self._helpview.set_ellipsize(pango.ELLIPSIZE_END)
        self._helpview.set_alignment(0.50, 0.50)
        frame.add(self._helpview)
        
    def set_markup(self, helptext):
        self._helpview.set_markup("<span foreground='grey50'>%s</span>" % helptext)
  
