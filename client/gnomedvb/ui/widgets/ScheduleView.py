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
from gettext import gettext as _
from gnomedvb import seconds_to_time_duration_string
from gnomedvb.ui.widgets.ScheduleStore import ScheduleStore
from gnomedvb.ui.widgets.CellRendererDatetime import CellRendererDatetime

class ScheduleView(gtk.TreeView):

    def __init__(self, model=None):
        if model != None:
            gtk.TreeView.__init__(self, model)
        else:
            gtk.TreeView.__init__(self)
        
        self.prev_selection = None
        self.set_property("headers-visible", False)

        col_time = gtk.TreeViewColumn("Time")

        cell_rec = gtk.CellRendererPixbuf()
        col_time.pack_start(cell_rec, expand=False)
        col_time.set_cell_data_func(cell_rec, self._get_rec_data)

        cell_time = CellRendererDatetime()
        col_time.pack_start(cell_time)
        col_time.set_cell_data_func(cell_time, self._get_time_data)
        col_time.set_attributes(cell_time, datetime=ScheduleStore.COL_DATETIME,
            format=ScheduleStore.COL_FORMAT)

        self.append_column(col_time)
        
        cell_description = gtk.CellRendererText()
        cell_description.set_property("wrap-width", 500)
        cell_description.set_property("wrap-mode", pango.WRAP_WORD)
        col = gtk.TreeViewColumn("Description", cell_description)
        col.set_cell_data_func(cell_description, self._get_description_data)
        self.append_column(col)

    def set_model(self, model):
        gtk.TreeView.set_model(self, model)

        if model:
            self.set_enable_search(True)
            self.set_search_column(ScheduleStore.COL_TITLE)
            self.set_search_equal_func(self._search_func)

    def _search_func(self, model, col, key, aiter):
        data = model.get_value(aiter, col)
        if data and data.lower().startswith(key.lower()):
            return False
        return True
    
    def _get_description_data(self, column, cell, model, aiter):
        event_id = model[aiter][ScheduleStore.COL_EVENT_ID]

        if event_id == ScheduleStore.NEW_DAY:
            date = model[aiter][ScheduleStore.COL_DATETIME]
            description = "<big><b>%s</b></big>" % date.strftime("%A %x")
            cell.set_property("xalign", 0.5)
            cell.set_property ("cell-background-gdk", self.style.bg[gtk.STATE_NORMAL])
        else:
            cell.set_property("xalign", 0)
            cell.set_property ("cell-background-gdk", self.style.base[gtk.STATE_NORMAL])
            
            duration = seconds_to_time_duration_string(model[aiter][ScheduleStore.COL_DURATION])
            title = model[aiter][ScheduleStore.COL_TITLE]
            
            short_desc = model[aiter][ScheduleStore.COL_SHORT_DESC]
            if len(short_desc) > 0:
                short_desc += "\n"
            
            description = "<b>%s</b>\n%s<small><i>%s: %s</i></small>" % (title, short_desc, _("Duration"), duration)
        
        cell.set_property("markup", description)
        
    def _get_time_data(self, column, cell, model, aiter):
        event_id = model[aiter][ScheduleStore.COL_EVENT_ID]
        
        if event_id == ScheduleStore.NEW_DAY:
            cell.set_property ("cell-background-gdk", self.style.bg[gtk.STATE_NORMAL])
        else:
            cell.set_property ("cell-background-gdk", self.style.base[gtk.STATE_NORMAL])
            
    def _get_rec_data(self, column, cell, model, aiter):
        event_id = model[aiter][ScheduleStore.COL_EVENT_ID]
        
        if event_id == ScheduleStore.NEW_DAY:
            cell.set_property ("cell-background-gdk", self.style.bg[gtk.STATE_NORMAL])
        else:
            cell.set_property ("cell-background-gdk", self.style.base[gtk.STATE_NORMAL])
    
        if model[aiter][ScheduleStore.COL_RECORDED] > 1:
            cell.set_property("icon-name", "stock_timer")
        else:
            cell.set_property("icon-name", None)

