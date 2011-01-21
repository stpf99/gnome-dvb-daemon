# -*- coding: utf-8 -*-
# Copyright (C) 2009 Sebastian Pölsterl
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

import gobject
from gi.repository import Gtk
from gnomedvb.ui.widgets.ScheduleStore import ScheduleStore
from gnomedvb.ui.widgets.ScheduleView import ScheduleView

class SchedulePaned (Gtk.VPaned):

    def __init__(self):
        gobject.GObject.__init__(self)
        
        self.scheduleview = ScheduleView()
        self.scheduleview.show()
        
        self.scheduleview.get_selection().connect("changed", self._on_selection_changed)
        
        self.scrolledschedule = Gtk.ScrolledWindow()
        self.scrolledschedule.add(self.scheduleview)
        self.scrolledschedule.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        self.scrolledschedule.set_shadow_type(Gtk.ShadowType.IN)
        self.scrolledschedule.show()
        
        self.pack1(self.scrolledschedule, True)
        
        self.textview = Gtk.TextView()
        self.textview.set_wrap_mode(Gtk.WrapMode.WORD)
        self.textview.set_editable(False)
        self.textview.show()
        
        self.scrolledtextview = Gtk.ScrolledWindow()
        self.scrolledtextview.add(self.textview)
        self.scrolledtextview.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        self.scrolledtextview.set_shadow_type(Gtk.ShadowType.IN)
        self.scrolledtextview.show()
        
        self.pack2(self.scrolledtextview, False)
        
        self.scrolledtextview.set_size_request(-1, 100)
        
    def get_treeview(self):
        return self.scheduleview
    
    def get_textview(self):
        return self.textview
        
    def _on_selection_changed(self, selection):
        model, aiter = selection.get_selected()
        
        if aiter != None:
            event_id = model[aiter][ScheduleStore.COL_EVENT_ID]
            if event_id != ScheduleStore.NEW_DAY:
                description = model[aiter][ScheduleStore.COL_SHORT_DESC]
                if description != None and len(description) > 0:
                    description += "\n\n"
                
                # Check if row is the selected row
                ext_desc = model[aiter][ScheduleStore.COL_EXTENDED_DESC]
                if ext_desc == None:
                    ext_desc = model.get_extended_description(aiter)
                    model[aiter][ScheduleStore.COL_EXTENDED_DESC] = ext_desc
                description += ext_desc
                
                textbuffer = self.textview.get_buffer()
                textbuffer.set_text(description)
                self.scrolledtextview.show()
        else:
            self.scrolledtextview.hide()

