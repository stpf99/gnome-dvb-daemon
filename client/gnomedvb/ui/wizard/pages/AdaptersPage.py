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

import gobject
import glib
import gnomedvb
import gtk
from gettext import gettext as _
from gnomedvb.ui.wizard import DVB_TYPE_TO_DESC
from gnomedvb.ui.wizard.pages.BasePage import BasePage
from gnomedvb.ui.widgets.Frame import BaseFrame

class AdaptersPage(BasePage):
    
    __gsignals__ = {
        "finished": (gobject.SIGNAL_RUN_LAST, gobject.TYPE_NONE, [bool]),
        "next-page": (gobject.SIGNAL_RUN_LAST, gobject.TYPE_NONE, []),
    }

    def __init__(self, model):
        BasePage.__init__(self)
        
        self.__adapter_info = None
        self.__use_configured = True
        self.__model = model
        self._progressbar = None
        self.devicesview = None
        self.frame = None
        
        # Name, Type Name, Type, adapter, frontend, registered
        self.deviceslist = gtk.ListStore(str, str, str, int, int, bool)
        
    def show_no_devices(self):
        if self.frame:
            self.frame.hide()
    
        text = "<big><span weight=\"bold\">%s</span></big>" % _('No devices have been found.')
        text += "\n\n"
        text += _('Either no DVB cards are installed or all cards are busy. In the latter case make sure you close all programs such as video players that access your DVB card.')
        self._label.set_markup (text)
        self._label.show()
    
    def show_devices(self):
        self._label.hide()

        if self.devicesview == None:
            self.devicesview = gtk.TreeView(self.deviceslist)
            self.devicesview.get_selection().connect("changed",
                self.on_device_selection_changed)
        
            cell_name = gtk.CellRendererText()
            col_name = gtk.TreeViewColumn(_("Name"))
            col_name.pack_start(cell_name)
            col_name.set_cell_data_func(cell_name, self.name_data_func)
            self.devicesview.append_column(col_name)
        
            cell_type = gtk.CellRendererText()
            col_type = gtk.TreeViewColumn(_("Type"))
            col_type.pack_start(cell_type)
            col_type.add_attribute(cell_type, "text", 1)
            self.devicesview.append_column(col_type)
        
            scrolledview = gtk.ScrolledWindow()
            scrolledview.set_shadow_type(gtk.SHADOW_ETCHED_IN)
            scrolledview.set_policy(gtk.POLICY_AUTOMATIC, gtk.POLICY_AUTOMATIC)
            scrolledview.add(self.devicesview)
            scrolledview.show_all()
        
            text = "<b>%s</b>" % _("Select the device you want to configure.")
            self.frame = BaseFrame(text, scrolledview)
            self.frame.show()
            self.pack_start(self.frame)

        self.devicesview.grab_focus()
        
        if len(self.deviceslist) == 1:
            self.emit("next-page")
        
    def show_all_configured(self):
        if self.frame:
            self.frame.hide()

        text = "<big><span weight=\"bold\">%s</span></big>" % _('All devices are already configured.')
        text += "\n\n"
        text += _('Go to the control center if you want to alter the settings of already configured devices.')
        self._label.set_markup (text)
        self._label.show()
        
    def show_error(self, error):
        if self.frame:
            self.frame.hide()
            
        text = "<big><span weight=\"bold\">%s</span></big>" % _('An error occured while retrieving devices.')
        text += "\n\n"
        text += _("Make sure other applications don't access DVB devices and you have permissions to access them.")
        text += "\n\n"
        text += _('The detailed error message is:')
        text += "\n<i>%s</i>" % error
        self._label.set_selectable(True)
        self._label.set_markup (text)
        self._label.show()
        
    def show_progressbar(self):
        self._label.hide()
        self._progressbar = gtk.ProgressBar()
        self._progressbar.set_text(_("Searching for devices"))
        self._progressbar.set_fraction(0.1)
        self._progressbar.show()
        self.pack_start(self._progressbar, False)
        self._progressbar_timer = glib.timeout_add(100, self.progressbar_pulse)
        
    def destroy_progressbar(self):
        glib.source_remove(self._progressbar_timer)
        self._progressbar_timer = None
        self._progressbar.destroy()

    def progressbar_pulse(self):
        self._progressbar.pulse()
        return True

    def get_page_title(self):
        return _("Device selection")
        
    def display_configured(self, val):
        self.__use_configured = val
    
    def get_selected_device(self):
        model, aiter = self.devicesview.get_selection().get_selected()
        if aiter != None:
            return None
        else:
            return model[aiter]
        
    def get_adapter_info(self):
        if self.__adapter_info == None and len(self.deviceslist) == 1:
            aiter = self.deviceslist.get_iter_first()
            self.__adapter_info = {"name": self.deviceslist[aiter][0],
                                   "type": self.deviceslist[aiter][2],
                                   "adapter": self.deviceslist[aiter][3],
                                   "frontend": self.deviceslist[aiter][4],
                                   "registered": self.deviceslist[aiter][5],}
        return self.__adapter_info

    def run(self):
        """
        Retrieves registered and unregistered devices
        and sets the contents of the page
        """
        def registered_handler(devgroups):
            for group in devgroups:
                for dev in group["devices"]:
                    dev.type_name = DVB_TYPE_TO_DESC[dev.type]
                    dev.registered = True
                    registered.add(dev)       
            self.__model.get_all_devices(reply_handler=devices_handler)
        
        def devices_handler(devices):
            error = None
            for dev in devices:
                if dev not in registered:
                    success, info = gnomedvb.get_adapter_info(dev.adapter,
                        dev.frontend)
                    if success:
                        dev.name = info["name"]
                        dev.type = info["type"]
                        if info["type"] in DVB_TYPE_TO_DESC:
                            dev.type_name = DVB_TYPE_TO_DESC[info["type"]]
                        else:
                            dev.type_name = info["type"]
                        dev.registered = False
                        unregistered.add(dev)
                    else:
                        error = info

            all_devs = registered | unregistered
            has_device = len(all_devs) > 0
            if self.__use_configured:
                devs = all_devs
            else:
                devs = unregistered

            self.deviceslist.clear()
            for dev in devs:
                self.deviceslist.append([dev.name, dev.type_name,
                    dev.type, dev.adapter, dev.frontend, dev.registered])

            self.destroy_progressbar()
            
            if error != None:
                self.show_error(error)
            elif len(devs) == 0:
                if not has_device:
                    self.show_no_devices()
                else:
                    self.show_all_configured()
            else:
                self.show_devices()
    
        registered = set()
        unregistered = set()
        self.__adapter_info = None
        self.show_progressbar()
        
        self.__model.get_registered_device_groups(reply_handler=registered_handler)
    
    def on_device_selection_changed(self, treeselection):
        model, aiter = treeselection.get_selected()
        if aiter != None:
            self.__adapter_info = {"name": model[aiter][0],
                                   "type": model[aiter][2],
                                   "adapter": model[aiter][3],
                                   "frontend": model[aiter][4],
                                   "registered": model[aiter][5],}
            self.emit("finished", True)
        else:
            self.emit("finished", False)

    def name_data_func(self, column, cell, model, aiter):
        name = model[aiter][0]
        adapter = model[aiter][3]
        frontend = model[aiter][4]

        text = _("<b>%s</b>\n") % name
        text += "<small>%s</small>" % (_("Adapter: %d, Frontend: %d") % (adapter, frontend))

        cell.set_property("markup", text)
        
