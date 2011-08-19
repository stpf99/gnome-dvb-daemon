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

from gi.repository import Gtk
from gnomedvb import _
        
class CalendarDialog(Gtk.Dialog):

    def __init__(self, parent):
        Gtk.Dialog.__init__(self, title=_("Pick a date"), parent=parent)

        self.set_modal(True)
        self.set_destroy_with_parent(True)
        
        self.set_position(Gtk.WindowPosition.MOUSE)
        self.add_button(Gtk.STOCK_CANCEL, Gtk.ResponseType.REJECT)
        ok_button = self.add_button(Gtk.STOCK_OK, Gtk.ResponseType.ACCEPT)
        ok_button.grab_default()
        
        self.calendar = Gtk.Calendar()
        self.calendar.show()
        self.get_content_area().add(self.calendar)
        
    def get_date(self):
        return self.calendar.get_date()

