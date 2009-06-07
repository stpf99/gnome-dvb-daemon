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

import datetime
import gtk
from gettext import gettext as _
from gnomedvb.ui.widgets.RunningNextStore import RunningNextStore
       
class RunningNextView(gtk.TreeView):

    def __init__(self, model):
        gtk.TreeView.__init__(self, model)
        
        cell_channel = gtk.CellRendererText()
        col_channel = gtk.TreeViewColumn(_("Channel"), cell_channel)
        col_channel.add_attribute(cell_channel, "markup",
            RunningNextStore.COL_CHANNEL)
        self.append_column(col_channel)
        
        cell_now_start = gtk.CellRendererText()
        cell_now = gtk.CellRendererText()
        col_now = gtk.TreeViewColumn(_("Now"))
        col_now.pack_start(cell_now_start, expand=False)
        col_now.pack_start(cell_now)
        col_now.set_cell_data_func(cell_now_start, self._format_time,
            RunningNextStore.COL_RUNNING_START)
        col_now.add_attribute(cell_now, "markup", RunningNextStore.COL_RUNNING)
        col_now.set_property("resizable", True)
        self.append_column(col_now)
        
        cell_next_start = gtk.CellRendererText()
        cell_next = gtk.CellRendererText()
        col_next = gtk.TreeViewColumn(_("Next"))
        col_next.pack_start(cell_next_start, expand=False)
        col_next.pack_start(cell_next)
        col_next.set_property("resizable", True)
        col_next.set_cell_data_func(cell_next_start, self._format_time,
            RunningNextStore.COL_NEXT_START)
        col_next.add_attribute(cell_next, "markup", RunningNextStore.COL_NEXT)
        self.append_column(col_next)
    
    def _format_time(self, column, cell, model, aiter, col_id):
        timestamp = model[aiter][col_id]
        if timestamp == 0:
            time_str = ""
        else:
            dt = datetime.datetime.fromtimestamp(timestamp)
            time_str = dt.strftime("%X")
        
        cell.set_property("text", time_str)
        
        
