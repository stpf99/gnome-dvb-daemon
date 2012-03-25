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
from gnomedvb import _

from gnomedvb import seconds_to_time_duration_string
from gnomedvb.ui.widgets.RecordingsStore import RecordingsStore
from gnomedvb.ui.widgets.CellRendererDatetime import CellRendererDatetime

class RecordingsView(Gtk.TreeView):

    def __init__(self, model=None):
        GObject.GObject.__init__(self)
        if model != None:
            self.set_model(model)

        self._append_text_column(_("Title"), RecordingsStore.COL_NAME)
        self._append_text_column(_("Channel"), RecordingsStore.COL_CHANNEL)

        col_length, cell_length = self._append_text_column(_("Length"),
            RecordingsStore.COL_DURATION)
        col_length.set_cell_data_func(cell_length, self._get_length_data, None)

        cell = CellRendererDatetime()
        col = Gtk.TreeViewColumn(_("Start"), cell,
            datetime=RecordingsStore.COL_START)
        self.append_column(col)

    def _append_text_column(self, title, col_index):
        cell = Gtk.CellRendererText()
        col = Gtk.TreeViewColumn(title, cell, markup=col_index)
        self.append_column(col)

        return (col, cell)

    def _get_length_data(self, column, cell, model, aiter, user_data=None):
        duration = model[aiter][RecordingsStore.COL_DURATION]
        duration_str = seconds_to_time_duration_string(duration)
        cell.set_property("text", duration_str)
