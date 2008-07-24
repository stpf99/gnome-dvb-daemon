#!/usr/bin/env python
# -*- coding: utf-8 -*-
import gtk
import gobject
import gnomedvb
import re

PRIME = 31

class Device:

    def __init__(self, name, adapter, frontend, devtype):
        self.name = name
        self.adapter = adapter
        self.frontend = frontend
        self.type = devtype
        
    def __hash__(self):
        return 2 * PRIME + PRIME * self.adapter + self.frontend
        
    def __eq__(self, other):
        if not isinstance(other, Device):
            return False
        
        return (self.adapter == other.adapter \
            and self.frontend == other.frontend)
            
    def __repr__(self):
        return "/dev/dvb/adapter%d/frontend%d" % (self.adapter, self.frontend)

class UnassignedDevicesStore (gtk.ListStore):

    (COL_DEVICE,) = range(1)
    
    def __init__(self):
        gtk.ListStore.__init__(self, gobject.TYPE_PYOBJECT)


class DeviceGroupsStore (gtk.TreeStore):

    (COL_DEVICE,) = range(1)

    def __init__(self):
        gtk.TreeStore.__init__(self, gobject.TYPE_PYOBJECT)
        
        
class DeviceGroupsView (gtk.TreeView):

    def __init__(self, model):
        gtk.TreeView.__init__(self, model)
        self.set_headers_visible(False)
        self.set_reorderable(True)
        
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

class AlignedLabel (gtk.Alignment):

    def __init__(self, markup):
        gtk.Alignment.__init__(self)
        
        self.label = gtk.Label()
        self.label.set_markup(markup)
        self.label.show()
        self.add(self.label)

class AlignedScrolledWindow (gtk.Alignment):

    def __init__(self, treeview):
        gtk.Alignment.__init__(self, xscale=1.0, yscale=1.0)
        
        self.set_padding(0, 0, 12, 0)
        
        scrolled = gtk.ScrolledWindow()
        scrolled.set_shadow_type(gtk.SHADOW_ETCHED_IN)
        scrolled.set_policy(gtk.POLICY_AUTOMATIC, gtk.POLICY_AUTOMATIC)
        scrolled.add(treeview)
        scrolled.show()
        self.add(scrolled)

class Frame (gtk.VBox):

    def __init__(self, markup, child):
        gtk.VBox.__init__(self, spacing=6)
    
        label = AlignedLabel(markup)
        label.show()
        self.pack_start(label, False, False, 0)
        
        view = AlignedScrolledWindow(child)
        view.show()
        self.pack_start(view)

class DVBPreferences(gtk.Window):

    def __init__(self):
        gtk.Window.__init__(self)
        
        self._model = DVBModel()
        
        self.connect('delete-event', gtk.main_quit)
        self.connect('destroy-event', gtk.main_quit)
        self.set_title("Configure DVB")
        self.set_default_size(600, 450)
        self.set_border_width(6)
        
        self.vbox = gtk.VBox(spacing=12)
        self.add(self.vbox)
        self.vbox.show()
        
        self.devicegroups = DeviceGroupsStore()
        self.devicegroupsview = DeviceGroupsView(self.devicegroups)
        self.devicegroupsview.show()
        
        groups_frame = Frame("<b>Registered groups</b>", self.devicegroupsview)
        groups_frame.show()
        self.vbox.pack_start(groups_frame)

        self.unassigned_devices = UnassignedDevicesStore()
        self.unassigned_view = DeviceGroupsView(self.unassigned_devices)
        self.unassigned_view.show()
        
        unassigned_frame = Frame("<b>Unassigned devices</b>", self.unassigned_view)
        unassigned_frame.show()
        self.vbox.pack_start(unassigned_frame)
        
        buttonbox = gtk.HButtonBox()
        buttonbox.set_layout(gtk.BUTTONBOX_END)
        buttonbox.show()
        self.vbox.pack_end(buttonbox, False, False, 0)
        
        close_button = gtk.Button(stock=gtk.STOCK_CLOSE)
        close_button.connect('clicked', gtk.main_quit)
        buttonbox.pack_start(close_button)
        close_button.show()
        
        separator = gtk.HSeparator()
        separator.show()
        self.vbox.pack_end(separator, False, False, 0)
        
        self._fill()
        
    def _fill(self):
        for device in self._model.get_unregistered_devices():
            self.unassigned_devices.append([device])
        
        for group_id, group in self._model.get_registered_device_groups().items():
            group_iter = self.devicegroups.append(None)
            self.devicegroups.set(group_iter, self.devicegroups.COL_DEVICE, group_id)
            
            for device in group:
                dev_iter = self.devicegroups.append(group_iter)
                self.devicegroups.set(dev_iter, self.devicegroups.COL_DEVICE, device)

class DVBModel:

    def __init__(self):
        self._manager = gnomedvb.DVBManagerClient()
        self._adapter_pattern = re.compile("adapter(\d+?)/frontend(\d+?)")
        
    def get_registered_device_groups(self):
        """
        @returns: dict of list of Device
        """
        groups = {}
        for group_id in self._manager.get_registered_device_groups():
            group = []
            for device_path in self._manager.get_device_group_members(group_id):
                match = self._adapter_pattern.search(device_path)
                if match != None:
                    adapter = int(match.group(1))
                    info = gnomedvb.get_adapter_info(adapter)
                    frontend = int(match.group(2))
                    dev = Device (info["name"], adapter, frontend, info["type"])
                    group.append(dev)
                
            groups[group_id] = group
            
        return groups
        
    def get_all_devices(self):
        """
        @returns: list of Device
        """
        devs = []
        for info in gnomedvb.get_dvb_devices():
            dev = Device (info["name"], info["adapter"], info["frontend"],
                info["type"])
            devs.append(dev)
        return devs
        
    def get_unregistered_devices(self):
        """
        @returns: set of Device
        """
        devgroups = self.get_registered_device_groups()
        registered = set()
        for group in devgroups.values():
            for dev in group:
                registered.add(dev)
                
        alldevs = set()
        for dev in self.get_all_devices():
            alldevs.add(dev)
        
        return alldevs - registered
        

if __name__=='__main__':
    prefs = DVBPreferences()
    prefs.show()
    gtk.main()
