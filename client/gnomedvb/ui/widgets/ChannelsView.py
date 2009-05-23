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

from gnomedvb.ui.widgets.ChannelsStore import ChannelsStore

class ChannelsView(gtk.TreeView):

    def __init__(self, model=None, name_col=ChannelsStore.COL_NAME):
        """
        @type model: ChannelsStore
        """
        if model != None:
            gtk.TreeView.__init__(self, model)
        else:
            gtk.TreeView.__init__(self)
        
        col_name = gtk.TreeViewColumn(_("Channel"))
        cell_name = gtk.CellRendererText()
        col_name.pack_start(cell_name)
        col_name.add_attribute(cell_name, "markup", name_col)
        self.append_column(col_name)
        
    def set_model(self, model=None):
        if model != None and not isinstance(model, ChannelsStore):
            raise TypeError("model must be a ChannelsStore instance")
        gtk.TreeView.set_model(self, model)
        
