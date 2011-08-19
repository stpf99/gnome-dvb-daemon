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

from gi.repository import GObject
from gi.repository import Gtk
from gnomedvb import _
from gnomedvb.ui.widgets.ChannelGroupsStore import ChannelGroupsStore

class ChannelGroupsView(Gtk.TreeView):

    def __init__(self, model=None):
        GObject.GObject.__init__(self)
        if model != None:
            self.set_model(model)

        col_name = Gtk.TreeViewColumn(_("Channel group"))
        self.cell_name = Gtk.CellRendererText()
        col_name.pack_start(self.cell_name, True)
        col_name.add_attribute(self.cell_name, "markup", ChannelGroupsStore.COL_NAME)
        col_name.add_attribute(self.cell_name, "editable", ChannelGroupsStore.COL_EDITABLE)
        self.append_column(col_name)
        
    def get_renderer(self):
        return self.cell_name

