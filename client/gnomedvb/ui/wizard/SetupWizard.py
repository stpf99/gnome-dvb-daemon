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
from gnomedvb.ui.wizard.pages.IntroPage import IntroPage
from gnomedvb.ui.wizard.pages.AdaptersPage import AdaptersPage
from gnomedvb.ui.wizard.pages.InitialTuningDataPage import InitialTuningDataPage
from gnomedvb.ui.wizard.pages.ChannelScanPage import ChannelScanPage
from gnomedvb.ui.wizard.pages.SaveChannelListPage import SaveChannelListPage
from gnomedvb.ui.wizard.pages.SummaryPage import SummaryPage

class SetupWizard(gtk.Assistant):

    def __init__(self):
        gtk.Assistant.__init__(self)
        self.__ask_on_exit = False
        self.__adapter_info = None
        self.__scanner = None
        
        self.connect ('delete-event', self.confirm_quit)
        self.connect ('cancel', self.confirm_quit)
        self.connect ('close', self.confirm_quit)
        self.connect ('prepare', self.on_prepare)
        self.set_default_size(500, 400)
        self.set_border_width(4)
        self.set_title(_("Setup DVB"))
        
        intro_page = IntroPage()
        self.append_page(intro_page)
        self.set_page_complete(intro_page, True)
        
        self.adapters_page = AdaptersPage()
        self.adapters_page.connect("finished", self.on_adapter_page_finished)
        self.append_page(self.adapters_page)
        
        self.tuning_data_page = InitialTuningDataPage()
        self.tuning_data_page.connect("finished", self.on_scan_finished)
        self.append_page(self.tuning_data_page)
        
        self.scan_page = ChannelScanPage()
        self.scan_page.connect("finished", self.on_scan_finished)
        self.append_page(self.scan_page)
        
        save_channels_page = SaveChannelListPage()
        save_channels_page.connect("finished", self.on_scan_finished)
        self.append_page(save_channels_page)
        
        summary_page = SummaryPage()
        self.append_page(summary_page)
        
    def append_page(self, page):
        gtk.Assistant.append_page(self, page)
        self.set_page_type(page, page.get_page_type())
        
    def on_prepare(self, assistant, page):
        if isinstance(page, InitialTuningDataPage):
            page.set_adapter_info(self.__adapter_info)
        elif isinstance(page, ChannelScanPage):
            self.__ask_on_exit = True
            if self.__adapter_info["name"] != None:
                page.set_name(self.__adapter_info["name"])
                page.start_scanning(self.__adapter_info["adapter"],
                    self.__adapter_info["frontend"], self.tuning_data_page.get_tuning_data ())
        elif isinstance(page, SaveChannelListPage):
            page.set_scanner(self.scan_page.get_scanner())
            page.set_channels(self.scan_page.get_selected_channel_sids())
        elif isinstance(page, SummaryPage):
            self.__ask_on_exit = False
    
        self.set_page_title(page, page.get_page_title())
        
    def on_scan_finished(self, page, state):
        self.set_page_complete(page, state)
            
    def on_adapter_page_finished(self, page, state):
        if state:
            self.__adapter_info = page.get_adapter_info()
        self.on_scan_finished(page, state)
            
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
            gtk.main_quit()

