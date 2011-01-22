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

import gobject
from gi.repository import Gtk
from gi.repository import Pango
from gettext import gettext as _
from gnomedvb import seconds_to_time_duration_string
from gnomedvb.ui.widgets.ScheduleStore import ScheduleStore
from gnomedvb.ui.widgets.CellRendererDatetime import CellRendererDatetime

class ScheduleView(Gtk.TreeView):

    def __init__(self, model=None):
        gobject.GObject.__init__(self)
        if model != None:
            self.set_model(model)
        
        self.prev_selection = None
        self.set_property("headers-visible", False)

        col_time = Gtk.TreeViewColumn("Time")

        cell_rec = Gtk.CellRendererPixbuf()
        col_time.pack_start(cell_rec, True)
        col_time.set_cell_data_func(cell_rec, self._get_rec_data, None)

        cell_time = CellRendererDatetime()
        col_time.pack_start(cell_time, True)
        col_time.set_cell_data_func(cell_time, self._get_time_data, None)
        col_time.add_attribute(cell_time, "datetime", ScheduleStore.COL_DATETIME)
        col_time.add_attribute(cell_time, "format", ScheduleStore.COL_FORMAT)

        self.append_column(col_time)
        
        cell_description = Gtk.CellRendererText()
        cell_description.set_property("wrap-width", 500)
        cell_description.set_property("wrap-mode", Pango.WrapMode.WORD)
        col = Gtk.TreeViewColumn("Description", cell_description)
        col.set_cell_data_func(cell_description, self._get_description_data, None)
        self.append_column(col)

    def set_model(self, model):
        Gtk.TreeView.set_model(self, model)

        if model:
            self.set_enable_search(True)
            self.set_search_column(ScheduleStore.COL_TITLE)
            self.set_search_equal_func(self._search_func, None)

    def _search_func(self, model, col, key, aiter, user_data=None):
        data = model.get_value(aiter, col)
        if data and data.lower().startswith(key.lower()):
            return False
        return True
    
    def _get_description_data(self, column, cell, model, aiter, user_data=None):
        event_id = model[aiter][ScheduleStore.COL_EVENT_ID]

        if event_id == ScheduleStore.NEW_DAY:
            date = model[aiter][ScheduleStore.COL_DATETIME]
            description = "<big><b>%s</b></big>" % date.strftime("%A %x")
            cell.set_property("xalign", 0.5)
            #XXX cell.set_property ("cell-background-gdk", self.style.bg[Gtk.StateType.NORMAL])
        else:
            cell.set_property("xalign", 0)
            #XXX cell.set_property ("cell-background-gdk", self.style.base[Gtk.StateType.NORMAL])
            
            duration = seconds_to_time_duration_string(model[aiter][ScheduleStore.COL_DURATION])
            title = model[aiter][ScheduleStore.COL_TITLE]
            
            short_desc = model[aiter][ScheduleStore.COL_SHORT_DESC]
            if len(short_desc) > 0:
                short_desc += "\n"
            
            description = "<b>%s</b>\n%s<small><i>%s: %s</i></small>" % (title, short_desc, _("Duration"), duration)
        
        cell.set_property("markup", description)
        
    def _get_time_data(self, column, cell, model, aiter, user_data=None):
        event_id = model[aiter][ScheduleStore.COL_EVENT_ID]
        
        # XXX style
        #sc = self.get_style_context()
        #if event_id == ScheduleStore.NEW_DAY:
        #    cell.set_property ("cell-background-rgba", sc.get_background_color(Gtk.StateFlags.NORMAL))
        #else:
        #    cell.set_property ("cell-background-rgba", sc.get_border_color(Gtk.StateFlags.NORMAL))
            
    def _get_rec_data(self, column, cell, model, aiter, user_data=None):
        event_id = model[aiter][ScheduleStore.COL_EVENT_ID]
        # XXX style
        #if event_id == ScheduleStore.NEW_DAY:
        #    cell.set_property ("cell-background-gdk", self.style.bg[Gtk.StateType.NORMAL])
        #else:
        #    cell.set_property ("cell-background-gdk", self.style.base[Gtk.StateType.NORMAL])
    
        if model[aiter][ScheduleStore.COL_RECORDED] > 1:
            cell.set_property("icon-name", "appointment-soon")
        else:
            cell.set_property("icon-name", None)

