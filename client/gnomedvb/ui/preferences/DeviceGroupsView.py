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
import gobject
from gettext import gettext as _
from gnomedvb.Device import Device

__all__ = ["UnassignedDevicesStore", "DeviceGroupsStore", "DeviceGroupsView"]

class UnassignedDevicesStore (gtk.ListStore):

    (COL_DEVICE,) = range(1)
    
    def __init__(self):
        gtk.ListStore.__init__(self, gobject.TYPE_PYOBJECT)


class DeviceGroupsStore (gtk.TreeStore):

    (COL_GROUP, COL_DEVICE,) = range(2)

    def __init__(self):
        gtk.TreeStore.__init__(self, gobject.TYPE_PYOBJECT, gobject.TYPE_PYOBJECT)
        
    def get_groups(self):
        groups = []
        for row in self:
            if not isinstance(row, Device):
                groups.append((row[self.COL_GROUP], row.iter))
        return groups
 
    
class DeviceGroupsView (gtk.TreeView):

    def __init__(self, model):
        gtk.TreeView.__init__(self, model)
        self.set_headers_visible(False)
        #self.set_reorderable(True)
        
        cell_description = gtk.CellRendererText ()
        column_description = gtk.TreeViewColumn (_("Devices"), cell_description)
        column_description.set_cell_data_func(cell_description, self.get_description_data)
        self.append_column(column_description)
        
    def get_description_data(self, column, cell, model, aiter):
        device = model[aiter][model.COL_DEVICE]
        
        if isinstance(device, Device):
            # translators: first is device's name, second its type
            text = _("<b>%s (%s)</b>\n") % (device.name, device.type)
            text += _("<small>Adapter: %d, Frontend: %d</small>") % (device.adapter,
                device.frontend)
        else:
            if device == "":
                group = model[aiter][model.COL_GROUP]
                text = _("Group %d") % group["id"]
            else:
                text = device
            
        cell.set_property("markup", text)


