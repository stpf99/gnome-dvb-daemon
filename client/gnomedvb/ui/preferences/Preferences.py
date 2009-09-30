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
import subprocess
from gnomedvb.ui.preferences.Dialogs import *
from gnomedvb.ui.preferences.DeviceGroupsView import *
from gnomedvb.ui.widgets.Frame import Frame
from gettext import gettext as _
from gnomedvb.Device import Device

class Preferences(gtk.Dialog):

    (BUTTON_EDIT,
     BUTTON_REMOVE,
     SEP1,
     BUTTON_PREFERENCES,) = range(4)

    def __init__(self, model, parent=None):
        gtk.Dialog.__init__(self, title=_('Digital TV Preferences'),
            parent=parent,
            flags=gtk.DIALOG_MODAL | gtk.DIALOG_DESTROY_WITH_PARENT,
            buttons=(gtk.STOCK_CLOSE, gtk.RESPONSE_CLOSE))
        
        self._model = model
        self._model.connect("group-added", self._on_manager_group_added)
        self._model.connect("group-removed", self._on_manager_group_removed)
        
        self.set_default_size(600, 450)
        
        self.__create_toolbar()
        
        self.vbox_main = gtk.VBox(spacing=12)
        self.vbox_main.set_border_width(6)
        self.vbox_main.show()
        self.vbox.pack_start(self.vbox_main)
        
        self.__create_registered_groups()
        self.__create_unassigned_devices()
        
        self._fill()
        
        self.devicegroupsview.grab_focus()
        
    def __create_toolbar(self):
        toolbar = gtk.Toolbar()
        toolbar.show()
        self.vbox.pack_start(toolbar, False)
        
        self.button_prefs = gtk.ToolButton(gtk.STOCK_EDIT)
        self.button_prefs.connect("clicked", self._on_button_prefs_clicked)
        self.button_prefs.set_sensitive(False)
        self.button_prefs.set_tooltip_markup(_("Edit selected group"))
        self.button_prefs.show()
        toolbar.insert(self.button_prefs, self.BUTTON_EDIT)
        
        self.button_remove = gtk.ToolButton(gtk.STOCK_REMOVE)
        self.button_remove.connect("clicked", self._on_button_remove_clicked)
        self.button_remove.set_sensitive(False)
        self.button_remove.set_tooltip_markup(_("Remove selected device"))
        self.button_remove.show()
        toolbar.insert(self.button_remove, self.BUTTON_REMOVE)
        
        sep = gtk.SeparatorToolItem()
        sep.show()
        toolbar.insert(sep, self.SEP1)
        
        prefs_image = gtk.image_new_from_stock(gtk.STOCK_PREFERENCES, gtk.ICON_SIZE_SMALL_TOOLBAR)
        button_setup = gtk.MenuToolButton(icon_widget=prefs_image, label=_("Setup"))
        button_setup.connect("clicked", self._on_button_setup_clicked)
        button_setup.set_tooltip_markup(_("Setup devices"))
        button_setup.show()
        toolbar.insert(button_setup, self.BUTTON_PREFERENCES)
        
        setup_menu = gtk.Menu()        
        new_image = gtk.image_new_from_stock(gtk.STOCK_NEW, gtk.ICON_SIZE_MENU)
        new_image.show()
        self.button_new = gtk.ImageMenuItem(_("Create new group"))
        self.button_new.connect("activate", self._on_button_new_clicked)
        self.button_new.set_image(new_image)
        self.button_new.set_sensitive(False)
        self.button_new.set_tooltip_markup(_("Create new group for selected device"))
        self.button_new.show()
        setup_menu.append(self.button_new)
        
        add_image = gtk.image_new_from_stock(gtk.STOCK_ADD, gtk.ICON_SIZE_MENU)
        add_image.show()
        self.button_add = gtk.ImageMenuItem(_("Add to group"))
        self.button_add.connect("activate", self._on_button_add_clicked)
        self.button_add.set_image(add_image)
        self.button_add.set_sensitive(False)
        self.button_add.set_tooltip_markup(_("Add selected device to existing group"))
        self.button_add.show()
        setup_menu.append(self.button_add)
        
        button_setup.set_menu(setup_menu)
        
    def __create_registered_groups(self):
        self.groups_box = gtk.HBox(spacing=6)
        self.groups_box.show()
        self.vbox_main.pack_start(self.groups_box)
    
        self.devicegroups = DeviceGroupsStore()
        self.devicegroupsview = DeviceGroupsView(self.devicegroups)
        self.devicegroupsview.get_selection().connect("changed", self._on_groups_selection_changed)
        self.devicegroupsview.show()
        
        groups_frame = Frame(_("<b>Configured devices</b>"), self.devicegroupsview)
        groups_frame.show()
        self.groups_box.pack_start(groups_frame)
    
    def __create_unassigned_devices(self):
        self.unassigned_devices = UnassignedDevicesStore()
        self.unassigned_view = DeviceGroupsView(self.unassigned_devices)
        self.unassigned_view.get_selection().connect("changed",
            self._on_unassigned_selection_changed)
        self.unassigned_view.show()
        
        unassigned_frame = Frame(_("<b>Unconfigured devices</b>"), self.unassigned_view)
        unassigned_frame.show()
        self.vbox_main.pack_start(unassigned_frame)
        
    def _fill(self):
        def append_unassigned(devices):
            for device in devices:
                self.unassigned_devices.append([device])
                
        def append_registered(groups):
            for group in groups:
                self._append_group(group)
                
        self._model.get_unregistered_devices(reply_handler=append_unassigned)
        self._model.get_registered_device_groups(reply_handler=append_registered)

    def _append_group(self, group):
        group.connect("device-added", self._on_group_device_added)
        group.connect("device-removed", self._on_group_device_removed)
        
        group_iter = self.devicegroups.append(None)
        self.devicegroups.set(group_iter, self.devicegroups.COL_GROUP, group)
        self.devicegroups.set(group_iter, self.devicegroups.COL_DEVICE, group["name"])
        
        for device in group["devices"]:
            dev_iter = self.devicegroups.append(group_iter)
            self.devicegroups.set(dev_iter, self.devicegroups.COL_GROUP, group)
            self.devicegroups.set(dev_iter, self.devicegroups.COL_DEVICE, device)

    def _on_groups_selection_changed(self, treeselection):
        model, aiter = treeselection.get_selected()
        
        if aiter != None:
            if isinstance(self.devicegroups[aiter][self.devicegroups.COL_DEVICE],
                    Device):
                self.button_remove.set_sensitive(True)
            else:
                self.button_remove.set_sensitive(False)
            
            self.button_prefs.set_sensitive(True)
        else:
            self.button_remove.set_sensitive(False)
            self.button_prefs.set_sensitive(False)

    def _on_unassigned_selection_changed(self, treeselection):
        model, aiter = treeselection.get_selected()
        
        val = (aiter != None)
        self.button_new.set_sensitive(val)
        self.button_add.set_sensitive(val)

    def _on_button_remove_clicked(self, button):
        model, aiter = self.devicegroupsview.get_selection().get_selected()
        
        if aiter != None:
            group = device = model[aiter][model.COL_GROUP]
            device = model[aiter][model.COL_DEVICE]
        
            dialog = gtk.MessageDialog(parent=self,
                flags=gtk.DIALOG_MODAL|gtk.DIALOG_DESTROY_WITH_PARENT,
                type=gtk.MESSAGE_QUESTION, buttons=gtk.BUTTONS_YES_NO)
            dialog.set_markup(
                _("Are you sure you want to remove device <b>%s</b> from <b>%s</b>") % (device.name,
                device.group_name))
            response = dialog.run()
            dialog.destroy()
            if response == gtk.RESPONSE_YES:
                if isinstance(device, Device):
                    if group.remove_device(device):
                        # "Success: remove device"
                        # Add device to unassigned devices
                        self.unassigned_devices.append([device])
                    else:
                        # "Error: remove device"
                        error_dialog = gtk.MessageDialog(parent=self,
                            flags=gtk.DIALOG_MODAL|gtk.DIALOG_DESTROY_WITH_PARENT,
                            type=gtk.MESSAGE_ERROR, buttons=gtk.BUTTONS_OK)
                        error_dialog.set_markup(_("<big><span weight=\"bold\">Device could not be removed from group</big></span>"))
                        error_dialog.run()
                        error_dialog.destroy()
                        
    def _on_button_setup_clicked(self, button):
        subprocess.Popen(["gnome-dvb-setup",
            "--transient-for=%d" % self.window.xid])

    def _on_button_new_clicked(self, button):
        model, aiter = self.unassigned_view.get_selection().get_selected()
        
        if aiter != None:
            device = model[aiter][model.COL_DEVICE]
            dialog = NewGroupDialog(self)
            if dialog.run() == gtk.RESPONSE_ACCEPT:
                channels = dialog.channels_entry.get_text()
                recdir = dialog.recordings_entry.get_text()
                name = dialog.name_entry.get_text()
                if self._model.add_device_to_new_group(device.adapter,
                        device.frontend, channels, recdir, name):
                    # "Success: create group"
                    model.remove(aiter)
                else:
                    # "Error: create group"
                    error_dialog = gtk.MessageDialog(parent=dialog,
                        flags=gtk.DIALOG_MODAL|gtk.DIALOG_DESTROY_WITH_PARENT,
                        type=gtk.MESSAGE_ERROR, buttons=gtk.BUTTONS_OK)
                    error_dialog.set_markup(_("<big><span weight=\"bold\">Group could not be created</big></span>"))
                    error_dialog.format_secondary_text(
                        _("Make sure that you selected the correct channels file and directory where recordings are stored and that both are readable.")
                    )
                    error_dialog.run()
                    error_dialog.destroy()
            dialog.destroy()
            
    def _on_button_add_clicked(self, button):
        model, aiter = self.unassigned_view.get_selection().get_selected()

        if aiter != None:
            device = self.unassigned_devices[aiter][0]
            dialog = AddToGroupDialog(self, self._model, device.type)
            if dialog.run() == gtk.RESPONSE_ACCEPT:
                group = dialog.get_selected_group()
                if group.add_device(device.adapter, device.frontend):
                    # "Success: add to group"
                    model.remove(aiter)
                else:
                    # "Error: add to group"
                    error_dialog = gtk.MessageDialog(parent=dialog,
                        flags=gtk.DIALOG_MODAL|gtk.DIALOG_DESTROY_WITH_PARENT,
                        type=gtk.MESSAGE_ERROR, buttons=gtk.BUTTONS_OK)
                    error_dialog.set_markup(_("<big><span weight=\"bold\">Device could not be added to group</big></span>"))
                    error_dialog.format_secondary_text(
                        _("Make sure that the device isn't already assigned to a different group and that all devices in the group are of the same type.")
                    )
                    error_dialog.run()
                    error_dialog.destroy()
                
            dialog.destroy()

    def _on_button_prefs_clicked(self, button):
        model, aiter = self.devicegroupsview.get_selection().get_selected()
        
        if aiter != None:
            group = model[aiter][model.COL_GROUP]
            group_name = group.get_name()
            recdir = group.get_recordings_directory()
            
            dialog = EditGroupDialog(group_name, recdir, self)
            if dialog.run() == gtk.RESPONSE_ACCEPT:
                name = dialog.name_entry.get_text()
                group.set_name(name)
                recdir = dialog.recordings_entry.get_text()
                group.set_recordings_directory(recdir)
            dialog.destroy()

    def _on_manager_group_added(self, manager, group_id):
        group = manager.get_device_group(group_id)
        if group:
            self._append_group(group)
    
    def _on_manager_group_removed(self, manager, group_id):        
        aiter = self.devicegroups.get_iter_first()
        # Iterate over groups
        while aiter != None:
            group = self.devicegroups[aiter][self.devicegroups.COL_GROUP]
            if group["id"] == group_id:
                self.devicegroups.remove(aiter)
                return
            aiter = self.devicegroups.iter_next(aiter)
        
    def _on_group_device_added(self, group, adapter, frontend):
        # Iterate over groups
        for list_group, aiter in self.devicegroups.get_groups():
            if group["id"] == list_group["id"]:
                # Added
                devtype = group.get_type()
                devname, success = self._model.get_name_of_registered_device(adapter, frontend)
                device = Device (group["id"], devname, adapter, frontend, devtype)
                device.group_name = group["name"]
                dev_iter = self.devicegroups.append(aiter)
                self.devicegroups.set(dev_iter, self.devicegroups.COL_DEVICE, device)
                break
                    
    def _on_group_device_removed(self, group, adapter, frontend):
        # Iterate over groups
        for list_group, aiter in self.devicegroups.get_groups():
            if group["id"] == list_group["id"]:
                # Removed
                child_iter =  self.devicegroups.iter_children(aiter)
                while child_iter != None:
                    device = self.devicegroups[child_iter][self.devicegroups.COL_DEVICE]
                    if device.adapter == adapter and device.frontend == frontend:
                        self.devicegroups.remove(child_iter)
                        return
                    child_iter = self.devicegroups.iter_next(child_iter)

