#!/usr/bin/env python
# -*- coding: utf-8 -*-
import gtk
import gobject
import gnomedvb
import re

PRIME = 31

class Device:

    def __init__(self, group_id, name, adapter, frontend, devtype):
        self.group = group_id
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
        

class NewGroupDialog (gtk.Dialog):

    def __init__(self, parent):
        gtk.Dialog.__init__(self, title="Create Group",
            parent=parent,
            flags=gtk.DIALOG_MODAL | gtk.DIALOG_DESTROY_WITH_PARENT,
            buttons=(gtk.STOCK_CANCEL, gtk.RESPONSE_REJECT,
                      gtk.STOCK_OK, gtk.RESPONSE_ACCEPT))
        
        self.set_default_size(400, 150)
        
        channels = AlignedLabel("<b>Channels File</b>")
        channels.show()
        self.vbox.pack_start(channels, False, False, 0)
        self.vbox.set_spacing(6)
        
        channels_ali = gtk.Alignment(xscale=1.0, yscale=1.0)
        channels_ali.set_padding(0, 0, 12, 0)
        channels_ali.show()
        self.vbox.pack_start(channels_ali)
        
        channelsbox = gtk.HBox(spacing=3)
        channelsbox.show()
        channels_ali.add(channelsbox)
        self.channels_entry = gtk.Entry()
        self.channels_entry.set_editable(False)
        self.channels_entry.show()
        channelsbox.pack_start(self.channels_entry)
        
        channels_open = gtk.Button(stock=gtk.STOCK_OPEN)
        channels_open.connect("clicked", self._on_channels_open_clicked)
        channels_open.show()
        channelsbox.pack_start(channels_open, False, False, 0)
        
        recordings = AlignedLabel("<b>Recordings' Directory</b>")
        recordings.show()
        self.vbox.pack_start(recordings, False, False, 0)
        
        rec_ali = gtk.Alignment(xscale=1.0, yscale=1.0)
        rec_ali.set_padding(0, 0, 12, 0)
        rec_ali.show()
        self.vbox.pack_start(rec_ali)
        
        recbox = gtk.HBox(spacing=6)
        recbox.show()
        rec_ali.add(recbox)
        
        self.recordings_entry = gtk.Entry()
        self.recordings_entry.set_editable(False)
        self.recordings_entry.show()
        recbox.pack_start(self.recordings_entry)
        
        recordings_open = gtk.Button(stock=gtk.STOCK_OPEN)
        recordings_open.connect("clicked", self._on_recordings_open_clicked)
        recordings_open.show()
        recbox.pack_start(recordings_open, False, False, 0)
        
    def _on_channels_open_clicked(self, button):
        dialog = gtk.FileChooserDialog (title = "Select File",
            parent=self, action=gtk.FILE_CHOOSER_ACTION_OPEN,
            buttons=(gtk.STOCK_CANCEL, gtk.RESPONSE_REJECT,
                      gtk.STOCK_OK, gtk.RESPONSE_ACCEPT))
        if dialog.run() == gtk.RESPONSE_ACCEPT:
            self.channels_entry.set_text(dialog.get_filename())
        dialog.destroy()
    
    def _on_recordings_open_clicked(self, button):
        dialog = gtk.FileChooserDialog (title = "Select Directory",
            parent=self, action=gtk.FILE_CHOOSER_ACTION_SELECT_FOLDER,
            buttons=(gtk.STOCK_CANCEL, gtk.RESPONSE_REJECT,
                      gtk.STOCK_OK, gtk.RESPONSE_ACCEPT))
        if dialog.run() == gtk.RESPONSE_ACCEPT:
            self.recordings_entry.set_text(dialog.get_filename())
        dialog.destroy()
         
         
class AddToGroupDialog (gtk.Dialog):

    def __init__(self, parent, model, device_type):
        gtk.Dialog.__init__(self, title="Add To Group",
            parent=parent,
            flags=gtk.DIALOG_MODAL | gtk.DIALOG_DESTROY_WITH_PARENT,
            buttons=(gtk.STOCK_CANCEL, gtk.RESPONSE_REJECT,
                      gtk.STOCK_OK, gtk.RESPONSE_ACCEPT))
                
        self.__selected_group = None
        self.vbox.set_spacing(6)
                
        label = gtk.Label()
        label.set_markup("<b>Select a group:</b>")
        label.show()
        self.vbox.pack_start(label, False, False, 0)
        
        self.groups = gtk.ListStore(str, int)
        
        combo = gtk.ComboBox(self.groups)
        combo.connect("changed", self.on_combo_changed)
        cell = gtk.CellRendererText()
        combo.pack_start(cell)
        combo.add_attribute(cell, "text", 0)
        combo.show()
        self.vbox.pack_start(combo)
                      
        for group_id in model.get_registered_device_groups():
            if model.get_type_of_device_group(group_id) == device_type:
                group_name = "Group %d" % group_id
                self.groups.append([group_name, group_id])
            
    def on_combo_changed(self, combo):
        aiter = combo.get_active_iter()
        
        if aiter == None:
            self.__selected_group = None
        else:
            self.__selected_group = self.groups[aiter][1]
      
    def get_selected_group(self):
        return self.__selected_group   

         
class DVBPreferences(gtk.Window):

    def __init__(self):
        gtk.Window.__init__(self)
        
        self._model = DVBModel()
        self._model.connect("changed", self._on_manager_changed)
        self._model.connect("group-changed", self._on_group_changed)
        
        self.connect('delete-event', gtk.main_quit)
        self.connect('destroy-event', gtk.main_quit)
        self.set_title("Configure DVB")
        self.set_default_size(600, 450)
        
        self.vbox_outer = gtk.VBox()
        self.vbox_outer.show()
        self.add(self.vbox_outer)
        
        self.__create_toolbar()
        
        self.vbox = gtk.VBox(spacing=12)
        self.vbox.set_border_width(6)
        self.vbox.show()
        self.vbox_outer.pack_start(self.vbox)
        
        self.__create_registered_groups()
        self.__create_unassigned_devices()
        
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
        
        self.devicegroupsview.expand_all()
        
    def __create_toolbar(self):
        toolbar = gtk.Toolbar()
        toolbar.show()
        self.vbox_outer.pack_start(toolbar, False)
        
        self.button_remove = gtk.ToolButton(gtk.STOCK_REMOVE)
        self.button_remove.connect("clicked", self._on_button_remove_clicked)
        self.button_remove.set_sensitive(False)
        self.button_remove.set_tooltip_markup("Remove selected device")
        self.button_remove.show()
        toolbar.insert(self.button_remove, 0)
        
        sep = gtk.SeparatorToolItem()
        sep.show()
        toolbar.insert(sep, 1)
        
        new_image = gtk.image_new_from_stock(gtk.STOCK_NEW, gtk.ICON_SIZE_SMALL_TOOLBAR)
        new_image.show()
        self.button_new = gtk.ToolButton(icon_widget=new_image, label="Create new group")
        self.button_new.connect("clicked", self._on_button_new_clicked)
        self.button_new.set_sensitive(False)
        self.button_new.set_tooltip_markup("Create new group for selected device")
        self.button_new.show()
        toolbar.insert(self.button_new, 2)
        
        add_image = gtk.image_new_from_stock(gtk.STOCK_ADD, gtk.ICON_SIZE_SMALL_TOOLBAR)
        add_image.show()
        self.button_add = gtk.ToolButton(icon_widget=add_image, label="Add to group")
        self.button_add.connect("clicked", self._on_button_add_clicked)
        self.button_add.set_sensitive(False)
        self.button_add.set_tooltip_markup("Add selected device to existing group")
        self.button_add.show()
        toolbar.insert(self.button_add, 3)
        
    def __create_registered_groups(self):
        self.groups_box = gtk.HBox(spacing=6)
        self.groups_box.show()
        self.vbox.pack_start(self.groups_box)
    
        self.devicegroups = DeviceGroupsStore()
        self.devicegroupsview = DeviceGroupsView(self.devicegroups)
        self.devicegroupsview.connect("focus-out-event", self._on_focus_out, [self.button_remove])
        self.devicegroupsview.connect("focus-in-event", self._on_focus_in, [self.button_remove])
        self.devicegroupsview.get_selection().connect("changed", self._on_groups_selection_changed)
        self.devicegroupsview.show()
        
        groups_frame = Frame("<b>Registered groups</b>", self.devicegroupsview)
        groups_frame.show()
        self.groups_box.pack_start(groups_frame)
    
    def __create_unassigned_devices(self):
        self.unassigned_devices = UnassignedDevicesStore()
        self.unassigned_view = DeviceGroupsView(self.unassigned_devices)
        self.unassigned_view.connect("focus-out-event", self._on_focus_out, [self.button_add, self.button_new])
        self.unassigned_view.connect("focus-in-event", self._on_focus_in, [self.button_add, self.button_new])
        self.unassigned_view.get_selection().connect("changed",
            self._on_unassigned_selection_changed)
        self.unassigned_view.show()
        
        unassigned_frame = Frame("<b>Unassigned devices</b>", self.unassigned_view)
        unassigned_frame.show()
        self.vbox.pack_start(unassigned_frame)
        
    def _fill(self):
        for device in self._model.get_unregistered_devices():
            self.unassigned_devices.append([device])
        
        for group_id, group in self._model.get_registered_device_groups().items():
            group_iter = self.devicegroups.append(None)
            self.devicegroups.set(group_iter, self.devicegroups.COL_DEVICE, group_id)
            
            for device in group:
                dev_iter = self.devicegroups.append(group_iter)
                self.devicegroups.set(dev_iter, self.devicegroups.COL_DEVICE, device)

    def _on_groups_selection_changed(self, treeselection):
        model, aiter = treeselection.get_selected()
        
        if aiter != None:
            if isinstance(self.devicegroups[aiter][self.devicegroups.COL_DEVICE],
                    Device):
                self.button_remove.set_sensitive(True)
            else:
                self.button_remove.set_sensitive(False)
        else:
            self.button_remove.set_sensitive(aiter != None)

    def _on_unassigned_selection_changed(self, treeselection):
        model, aiter = treeselection.get_selected()
        
        val = (aiter != None)
        self.button_new.set_sensitive(val)
        self.button_add.set_sensitive(val)

    def _on_button_remove_clicked(self, button):
        model, aiter = self.devicegroupsview.get_selection().get_selected()
        
        if aiter != None:
            device = model[aiter][model.COL_DEVICE]
        
            dialog = gtk.MessageDialog(parent=self,
                flags=gtk.DIALOG_MODAL|gtk.DIALOG_DESTROY_WITH_PARENT,
                type=gtk.MESSAGE_QUESTION, buttons=gtk.BUTTONS_YES_NO)
            dialog.set_markup(
                "Are you sure you want to remove device <b>%s</b> from <b>group %s</b>" % (device.name,
                device.group))
            response = dialog.run()
            dialog.destroy()
            if response == gtk.RESPONSE_YES:
                if isinstance(device, Device):
                    if self._model.remove_device_from_group(device):
                        print "Success: remove device"
                        
                        # Add device to unassigned devices
                        self.unassigned_devices.append([device])
                    else:
                        print "Error: remove device"

    def _on_button_new_clicked(self, button):
        model, aiter = self.unassigned_view.get_selection().get_selected()
        
        if aiter != None:
            device = model[aiter][model.COL_DEVICE]
            dialog = NewGroupDialog(self)
            if dialog.run() == gtk.RESPONSE_ACCEPT:
                channels = dialog.channels_entry.get_text()
                recdir = dialog.recordings_entry.get_text()
                if self._model.add_device_to_new_group(device.adapter,
                        device.frontend, channels, recdir):
                    print "Success: create group"
                    model.remove(aiter)
                else:
                    print "Error: create group"
            dialog.destroy()
            
    def _on_button_add_clicked(self, button):
        model, aiter = self.unassigned_view.get_selection().get_selected()

        if aiter != None:
            device = self.unassigned_devices[aiter][0]
            dialog = AddToGroupDialog(self, self._model, device.type)
            if dialog.run() == gtk.RESPONSE_ACCEPT:
                group_id = dialog.get_selected_group()
                if self._model.add_device_to_existing_group(device.adapter,
                    device.frontend, group_id):
                    print "Success: add to group"
                    model.remove(aiter)
                else:
                    print "Error: add to group"
                
            dialog.destroy()

    def _on_manager_changed(self, manager, group_id, change_type):
        # A group has been added or deleted
        if change_type == 0:
            # Added
            group_iter = self.devicegroups.append(None)
            self.devicegroups.set(group_iter, self.devicegroups.COL_DEVICE, group_id)
            for device in self._model.get_device_group_members(group_id):
                dev_iter = self.devicegroups.append(group_iter)
                self.devicegroups.set(dev_iter, self.devicegroups.COL_DEVICE, device)
        elif change_type == 1:
            # Removed
            aiter = self.devicegroups.get_iter_first()
            # Iterate over groups
            while aiter != None:
                group = self.devicegroups[aiter][self.devicegroups.COL_DEVICE]
                if group == group_id:
                    self.devicegroups.remove(aiter)
                    return
                aiter = self.devicegroups.iter_next(aiter)
        
    def _on_group_changed(self, manager, group_id, adapter, frontend, change_type):
        # Iterate over groups
        for group, aiter in self.devicegroups.get_groups():
            if group == group_id:
                if change_type == 0:
                    # Added
                    info = gnomedvb.get_adapter_info(adapter)
                    device = Device (group_id, info["name"], adapter, frontend, info["type"])
                    dev_iter = self.devicegroups.append(aiter)
                    self.devicegroups.set(dev_iter, self.devicegroups.COL_DEVICE, device)
                    break
                elif change_type == 1:
                    # Removed
                    child_iter =  self.devicegroups.iter_children(aiter)
                    while child_iter != None:
                        device = self.devicegroups[child_iter][self.devicegroups.COL_DEVICE]
                        if device.adapter == adapter and device.frontend == frontend:
                             self.devicegroups.remove(child_iter)
                             return
                        child_iter = self.devicegroups.iter_next(child_iter)
           
    def _on_focus_out(self, treeview, event, widgets):
        for w in widgets:
            w.set_sensitive(False)
            
    def _on_focus_in(self, treeview, event, widgets):
        for w in widgets:
            w.set_sensitive(True)
                        

class DVBModel (gnomedvb.DVBManagerClient):

    def __init__(self):
        gnomedvb.DVBManagerClient.__init__(self)
        self._adapter_pattern = re.compile("adapter(\d+?)/frontend(\d+?)")
        
    def get_registered_device_groups(self):
        """
        @returns: dict of list of Device
        """
        groups = {}
        for group_id in gnomedvb.DVBManagerClient.get_registered_device_groups(self):
            groups[group_id] = self.get_device_group_members(group_id)
            
        return groups
        
    def get_all_devices(self):
        """
        @returns: list of Device
        """
        devs = []
        for info in gnomedvb.get_dvb_devices():
            dev = Device (0, info["name"], info["adapter"], info["frontend"],
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
        
    def remove_device_from_group(self, device):
        return gnomedvb.DVBManagerClient.remove_device_from_group(self, device.adapter,
            device.frontend, device.group)
            
    def get_device_group_members(self, group_id):
        devices = []
        for device_path in gnomedvb.DVBManagerClient.get_device_group_members(self, group_id):
            match = self._adapter_pattern.search(device_path)
            if match != None:
                adapter = int(match.group(1))
                info = gnomedvb.get_adapter_info(adapter)
                frontend = int(match.group(2))
                dev = Device (group_id, info["name"], adapter, frontend, info["type"])
                devices.append(dev)
        return devices


if __name__=='__main__':
    prefs = DVBPreferences()
    prefs.show()
    gtk.main()
