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

import gobject
import glib
import gnomedvb
import gtk
import os.path
from gettext import gettext as _
from gnomedvb.ui.wizard import DVB_TYPE_TO_DESC
from gnomedvb.ui.wizard.pages.BasePage import BasePage

class SetupDevicePage(BasePage):
    
    __gsignals__ = {
        "finished": (gobject.SIGNAL_RUN_LAST, gobject.TYPE_NONE, [bool]),
    }

    def __init__(self, model):
        BasePage.__init__(self)
        self.__model = model
        self.__scanner = None
        self.__adapter_info = None
        self.__summary = None
        self.__channels = None
        self._progressbar = None
        self._progressbar_timer = None
            
    def get_page_title(self):
        return _("Configuring device")
        
    def get_page_type(self):
        return gtk.ASSISTANT_PAGE_PROGRESS
  
    def set_scanner(self, scanner):
        self.__scanner = scanner
        
    def set_adapter(self, adapter):
        self.__adapter_info = adapter

    def set_channels(self, channels):
        self.__channels = channels
   
    def get_summary(self):
        return self.__summary
        
    def can_be_added_to_group(self, adapter_info):
        self.__adapter_info = adapter_info
        ex_group = self.get_existing_group_of_same_type()
        self.__adapter_info = None
        return ex_group != None
        
    def run(self, create_group):
        self.show_progressbar()
        
        def reply_handler(success):
            self.destroy_progressbar()
            self.emit("finished", True)
        
        existing_group = self.get_existing_group_of_same_type()
        if existing_group == None:
            self.create_group_automatically(reply_handler=reply_handler,
                error_handler=gnomedvb.global_error_handler)
        else:
            self.add_to_group(existing_group, reply_handler=reply_handler,
                error_handler=gnomedvb.global_error_handler)
         
    def show_progressbar(self):
        # From parent
        self._label.hide()

        self._progressbar = gtk.ProgressBar()
        self._progressbar.set_text(_("Configuring device"))
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
   
    def get_existing_group_of_same_type(self):
        groups = self.__model.get_registered_device_groups(None)
        # Find group of same type
        existing_group = None
        for group in groups:
            if group['type'] == self.__adapter_info['type']:
                existing_group = group
                break
        return existing_group

    def create_group_automatically(self, reply_handler, error_handler):
        def write_channels_handler(success):
            if success:
                recordings_dir = gnomedvb.get_default_recordings_dir()
                name = "%s %s" % (DVB_TYPE_TO_DESC[self.__adapter_info["type"]], _("TV"))
                self.__model.add_device_to_new_group(self.__adapter_info['adapter'],
                                self.__adapter_info['frontend'], channels_file,
                                recordings_dir, name,
                                reply_handler=reply_handler, error_handler=error_handler)
            else:
                self.show_error()
            
        self.__summary = ''
        channels_file = os.path.join(gnomedvb.get_config_dir(),
            "channels_%s.conf" % self.__adapter_info["type"])
        
        self.__scanner.write_channels_to_file(self.__channels, channels_file,
            reply_handler=write_channels_handler, error_handler=error_handler)
                        
    def add_to_group(self, group, reply_handler, error_handler):
        self.__summary = _('The device has been added to the group %s.') % group['name']
        group.add_device(self.__adapter_info['adapter'],
            self.__adapter_info['frontend'], reply_handler=reply_handler,
            error_handler=error_handler)

    def show_error(self):
        if self._progressbar != None:
            self._progressbar.destroy()

        text = "<big><span weight=\"bold\">%s</span></big>" % _("An error occured while trying to setup the device.")
        self._label.set_selectable(True)
        self._label.set_markup (text)
        self._label.show()

