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

import datetime
import gtk
from gettext import gettext as _

from RecordingsStore import RecordingsStore

class RecordingsView(gtk.TreeView):

    def __init__(self, model=None):
        if model != None:
            gtk.TreeView.__init__(self, model)
        else:
            gtk.TreeView.__init__(self)
        
        col, cell = self._append_text_column(_("Start"), RecordingsStore.COL_START)
        col.set_cell_data_func(cell, self._get_start_data)
        self._append_text_column(_("Channel"), RecordingsStore.COL_CHANNEL)
        self._append_text_column(_("Title"), RecordingsStore.COL_NAME)
        self._append_text_column(_("Length"), RecordingsStore.COL_DURATION)
            
    def _append_text_column(self, title, col_index):
        col = gtk.TreeViewColumn(title)
        cell = gtk.CellRendererText()
        col.pack_start(cell)
        col.add_attribute(cell, "markup", col_index)
        self.append_column(col)
        
        return (col, cell)
        
    def _get_start_data(self, column, cell, model, aiter):
        timestamp = model[aiter][RecordingsStore.COL_START]
        time = datetime.datetime.fromtimestamp(timestamp)
        cell.set_property("text", time.strftime("%c"))
                
