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

from gi.repository import GObject
from gi.repository import Gtk
from gi.repository import Pango

class HelpBox(Gtk.EventBox):

    def __init__(self):
        GObject.GObject.__init__(self)

        frame = Gtk.Frame()
        frame.set_shadow_type(Gtk.ShadowType.IN)
        self.add(frame)

        self._helpview = Gtk.Label()
        self._helpview.set_ellipsize(Pango.EllipsizeMode.END)
        self._helpview.set_alignment(0.50, 0.50)
        frame.add(self._helpview)

        style = self._helpview.get_style_context()
        style.add_class(Gtk.STYLE_CLASS_ENTRY)

        color = style.get_background_color(Gtk.StateFlags.NORMAL)
        self.override_background_color(Gtk.StateFlags.NORMAL, color)

    def set_markup(self, helptext):
        self._helpview.set_markup("<span foreground='grey50'>%s</span>" % helptext)

