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
from gettext import gettext as _

from gnomedvb import seconds_to_time_duration_string
from gnomedvb.ui.widgets.RecordingsStore import RecordingsStore
from gnomedvb.ui.widgets.CellRendererDatetime import CellRendererDatetime

class RecordingsView(gtk.TreeView):

    def __init__(self, model=None):
        if model != None:
            gtk.TreeView.__init__(self, model)
        else:
            gtk.TreeView.__init__(self)
        
        cell = CellRendererDatetime()
        cell.set_property("format", "%c")
        col = gtk.TreeViewColumn(_("Start"), cell,
            datetime=RecordingsStore.COL_START)
        self.append_column(col)
        self._append_text_column(_("Channel"), RecordingsStore.COL_CHANNEL)
        self._append_text_column(_("Title"), RecordingsStore.COL_NAME)
        
        col_length, cell_length = self._append_text_column(_("Length"),
            RecordingsStore.COL_DURATION)
        col_length.set_cell_data_func(cell_length, self._get_length_data)
            
    def _append_text_column(self, title, col_index):
        cell = gtk.CellRendererText()
        col = gtk.TreeViewColumn(title, cell, markup=col_index)
        self.append_column(col)
        
        return (col, cell)
        
    def _get_length_data(self, column, cell, model, aiter):
        duration = model[aiter][RecordingsStore.COL_DURATION]
        duration_str = seconds_to_time_duration_string(duration)
        cell.set_property("text", duration_str)
                
