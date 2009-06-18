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
from gnomedvb.ui.wizard.pages.BasePage import BasePage

class SummaryPage(BasePage):

    def __init__(self):
        BasePage.__init__(self)
        
        self.checkbutton = gtk.CheckButton(label=_("Start control center now"))
        self.pack_end(self.checkbutton, False, False, 0)
    
    def get_page_title(self):
        return _("Configuration finished")
        
    def get_page_type(self):
        return gtk.ASSISTANT_PAGE_SUMMARY
        
    def set_device_name_and_details(self, name, details):
        text = "<span weight=\"bold\">%s</span>" % (_("The device %s has been configured sucessfully.") % name)
        text += "\n%s\n" % details
        text += _("You can configure additional devices by re-running this application.")
        label = gtk.Label()
        label.set_markup(text)
        label.set_line_wrap(True)
        label.show()
        self.pack_start(label)
        
    def start_control_center(self):
        return self.checkbutton.get_active()
    
