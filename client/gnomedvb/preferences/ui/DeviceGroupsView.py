# -*- coding: utf-8 -*-
import gtk
import gobject
from gnomedvb.preferences.model.Device import Device

__all__ = ["UnassignedDevicesStore", "DeviceGroupsStore", "DeviceGroupsView"]

class UnassignedDevicesStore (gtk.ListStore):

    (COL_DEVICE,) = range(1)
    
    def __init__(self):
        gtk.ListStore.__init__(self, gobject.TYPE_PYOBJECT)


class DeviceGroupsStore (gtk.TreeStore):

    (COL_DEVICE,) = range(1)

    def __init__(self):
        gtk.TreeStore.__init__(self, gobject.TYPE_PYOBJECT)
        
    def get_groups(self):
        groups = []
        for row in self:
            if not isinstance(row, Device):
                groups.append((row[self.COL_DEVICE], row.iter))
        return groups
 
    
class DeviceGroupsView (gtk.TreeView):

    def __init__(self, model):
        gtk.TreeView.__init__(self, model)
        self.set_headers_visible(False)
        #self.set_reorderable(True)
        
        cell_description = gtk.CellRendererText ()
        column_description = gtk.TreeViewColumn ("Devices", cell_description)
        column_description.set_cell_data_func(cell_description, self.get_description_data)
        self.append_column(column_description)
        
    def get_description_data(self, column, cell, model, aiter):
        device = model[aiter][model.COL_DEVICE]
        
        if isinstance(device, Device):
            text = "<b>%s (%s)</b>\n" % (device.name, device.type)
            text += "<small>Adapter: %d, Frontend: %d</small>" % (device.adapter,
                device.frontend)
        else:
            text = "Group %d" % device
            
        cell.set_property("markup", text)


