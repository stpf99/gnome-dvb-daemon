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

import gnomedvb
import gtk
import subprocess
from gettext import gettext as _
from gnomedvb.DVBModel import DVBModel
from gnomedvb.ui.wizard import DVB_TYPE_TO_DESC
from gnomedvb.ui.wizard.pages.IntroPage import IntroPage
from gnomedvb.ui.wizard.pages.AdaptersPage import AdaptersPage
from gnomedvb.ui.wizard.pages.InitialTuningDataPage import InitialTuningDataPage
from gnomedvb.ui.wizard.pages.ChannelScanPage import ChannelScanPage
from gnomedvb.ui.wizard.pages.SaveChannelListPage import SaveChannelListPage
from gnomedvb.ui.wizard.pages.SummaryPage import SummaryPage
from gnomedvb.ui.wizard.pages.SetupDevicePage import SetupDevicePage

class SetupWizard(gtk.Assistant):

    (INTRO_PAGE,
     ADAPTERS_PAGE,
     INITIAL_TUNING_DATA_PAGE,
     CHANNEL_SCAN_PAGE,
     SAVE_CHANNELS_PAGE,
     SETUP_DEVICE_PAGE,
     SUMMARY_PAGE) = range(7)

    def __init__(self):
        gtk.Assistant.__init__(self)
        self.__ask_on_exit = False
        self.__adapter_info = None
        self.__model = DVBModel()
        self.__expert_mode = False
        self.__create_group = False
        
        self.connect ('delete-event', self.confirm_quit)
        self.connect ('cancel', self.confirm_quit)
        self.connect ('close', self.confirm_quit)
        self.connect ('prepare', self.on_prepare)
        self.set_forward_page_func(self.page_func)
        self.set_default_size(500, 400)
        self.set_border_width(4)
        self.set_title(_("Setup digital TV"))
        
        self.intro_page = IntroPage()
        self.append_page(self.intro_page)
        self.set_page_complete(self.intro_page, True)
        
        self.adapters_page = AdaptersPage(self.__model)
        self.adapters_page.connect("finished", self.on_adapter_page_finished)
        self.adapters_page.connect("next-page", self.on_next_page)
        self.append_page(self.adapters_page)
        
        self.tuning_data_page = InitialTuningDataPage()
        self.tuning_data_page.connect("finished", self.on_page_finished)
        self.append_page(self.tuning_data_page)
        
        self.scan_page = ChannelScanPage(self.__model)
        self.scan_page.connect("finished", self.on_page_finished)
        self.append_page(self.scan_page)
        
        save_channels_page = SaveChannelListPage()
        save_channels_page.connect("finished", self.on_page_finished)
        self.append_page(save_channels_page)
        
        self.setup_page = SetupDevicePage(self.__model)
        self.setup_page.connect("finished", self.on_setup_device_page_finished)
        self.append_page(self.setup_page)
        
        self.summary_page = SummaryPage()
        self.summary_page.configure_button.connect("clicked",
            lambda button: self.set_current_page(self.INTRO_PAGE))
        self.append_page(self.summary_page)
        
    def append_page(self, page):
        gtk.Assistant.append_page(self, page)
        self.set_page_type(page, page.get_page_type())
        
    def on_prepare(self, assistant, page):
        if isinstance(page, InitialTuningDataPage):
            page.set_adapter_info(self.__adapter_info)
        elif isinstance(page, AdaptersPage):
            self.__expert_mode = self.intro_page.has_expert_mode()
            page.display_configured(self.__expert_mode)
            page.run()
        elif isinstance(page, ChannelScanPage):
            self.__ask_on_exit = True
            if self.__adapter_info["name"] != None:
                page.set_name(self.__adapter_info["name"])
                page.start_scanning(self.__adapter_info["adapter"],
                    self.__adapter_info["frontend"], self.tuning_data_page.get_tuning_data ())
        elif isinstance(page, SetupDevicePage):
            page.set_adapter(self.__adapter_info)
            page.set_scanner(self.scan_page.get_scanner())
            page.set_channels(self.scan_page.get_selected_channel_sids())
            page.run(self.__create_group)
        elif isinstance(page, SaveChannelListPage):
            page.set_scanner(self.scan_page.get_scanner())
            page.set_channels(self.scan_page.get_selected_channel_sids())
        elif isinstance(page, SummaryPage):
            self.__ask_on_exit = False
            if self.__expert_mode:
                summary = _('The generated channels file can be used to configure your devices in the control center.')
            else:
                summary = self.setup_page.get_summary()
            page.set_device_name_and_details(self.__adapter_info["name"],
                summary)

        self.set_page_title(page, page.get_page_title())
        
    def on_page_finished(self, page, state):
        self.set_page_complete(page, state)
            
    def on_adapter_page_finished(self, page, state):
        if state:
            self.__adapter_info = page.get_adapter_info()
        self.on_page_finished(page, state)
        
    def on_setup_device_page_finished(self, page, state):
        if state:
            self.set_current_page(self.SUMMARY_PAGE)
        
    def page_func(self, current_page, user_data=None):
        if current_page == self.ADAPTERS_PAGE and not self.__expert_mode:
            # Check if the selected adapter is not registered
            if self.__adapter_info != None and not self.__adapter_info['registered']:
                # Check if we can add it to an existing group
                if self.setup_page.can_be_added_to_group(self.__adapter_info):
                    self.__create_group = False
                    return self.SETUP_DEVICE_PAGE
        elif current_page == self.CHANNEL_SCAN_PAGE:
            if self.__expert_mode:
                return self.SAVE_CHANNELS_PAGE
            else:
                return self.SETUP_DEVICE_PAGE
        elif current_page == self.SAVE_CHANNELS_PAGE:
            return self.SUMMARY_PAGE

        return current_page + 1
            
    def confirm_quit(self, *args):
        scanner = self.scan_page.get_scanner()
        if self.__ask_on_exit:
            dialog = gtk.MessageDialog(parent=self,
                flags=gtk.DIALOG_MODAL | gtk.DIALOG_DESTROY_WITH_PARENT,
                type=gtk.MESSAGE_QUESTION,
                buttons=gtk.BUTTONS_YES_NO,
                message_format=_("Are you sure you want to abort?\nAll process will be lost."))
            
            response = dialog.run()
            if response == gtk.RESPONSE_YES:
                if scanner != None:
                    scanner.destroy()
                gtk.main_quit()
            elif response == gtk.RESPONSE_NO:
                dialog.destroy()
        
            return True
        else:
            if scanner != None:
                scanner.destroy()
            if self.summary_page.start_control_center():
                subprocess.Popen('gnome-dvb-control')
            gtk.main_quit()
            
    def on_next_page(self, adapters_page):
        if not self.__expert_mode:
            # There's only one device no need to select one
            self.__adapter_info = adapters_page.get_adapter_info()
            # Check if we can add it to an existing group
            if self.setup_page.can_be_added_to_group(self.__adapter_info):
                self.__create_group = False
                index = self.SETUP_DEVICE_PAGE
            else:
                index = self.INITIAL_TUNING_DATA_PAGE
            self.set_current_page(index)

