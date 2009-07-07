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

class ScheduleView(gtk.TreeView):

    def __init__(self, model=None):
        if model != None:
            gtk.TreeView.__init__(self, model)
        else:
            gtk.TreeView.__init__(self)
        
        self.set_property("headers-visible", False)
        
        cell_rec = gtk.CellRendererPixbuf()
        col_rec = gtk.TreeViewColumn("Recording", cell_rec)
        col_rec.set_cell_data_func(cell_rec, self._get_rec_data)
        self.append_column(col_rec)
        
        cell_time = gtk.CellRendererText()
        col_time = gtk.TreeViewColumn("Time", cell_time)
        col_time.set_cell_data_func(cell_time, self._get_time_data)
        self.append_column(col_time)
        
        cell_description = gtk.CellRendererText()
        cell_description.set_property("wrap-width", 500)
        cell_description.set_property("wrap-mode", pango.WRAP_WORD)
        col = gtk.TreeViewColumn("Description", cell_description)
        col.set_cell_data_func(cell_description, self._get_description_data)
        self.append_column(col)
    
    def _get_description_data(self, column, cell, model, aiter):
        event_id = model[aiter][ScheduleStore.COL_EVENT_ID]
        
        if event_id == ScheduleStore.NEW_DAY:
            date = model.get_datetime(aiter)
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
            
            # Check if row is the selected row
            sel_iter = self.get_selection().get_selected()[1]
            if sel_iter != None and model.get_path(aiter) == model.get_path(sel_iter):
                ext_desc = model[aiter][ScheduleStore.COL_EXTENDED_DESC]
                if ext_desc == None:
                    ext_desc = model.get_extended_description(aiter)
                description += "\n<small>%s</small>" % ext_desc
                # Update cell height
                model.emit("row-changed", model.get_path(aiter), aiter)
        
        cell.set_property("markup", description)
        
    def _get_time_data(self, column, cell, model, aiter):
        event_id = model[aiter][ScheduleStore.COL_EVENT_ID]
        
        if event_id == ScheduleStore.NEW_DAY:
            cell.set_property("text", "")
            cell.set_property ("cell-background-gdk", self.style.bg[gtk.STATE_NORMAL])
        else:
            date = model.get_datetime(aiter)
            cell.set_property("text", date.strftime("%X"))
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

