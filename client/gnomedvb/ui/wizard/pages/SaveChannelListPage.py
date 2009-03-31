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
import gobject
from gettext import gettext as _
from BasePage import BasePage

class SaveChannelListPage(BasePage):

	__gsignals__ = {
        "finished": (gobject.SIGNAL_RUN_LAST, gobject.TYPE_NONE, [bool]),
    }

	def __init__(self):
		BasePage.__init__(self)
		self.__scanner = None
		
		text = _("Choose a location where you want to save the list of channels.")
		label = gtk.Label(text)
		self.pack_start(label)

		button_box = gtk.HButtonBox()
		self.pack_start(button_box)
	
		save_button = gtk.Button(stock=gtk.STOCK_SAVE)
		save_button.connect("clicked", self.__on_save_button_clicked)
		button_box.pack_start(save_button)
			
	def get_page_title(self):
		return _("Save channels")
	
	def set_scanner(self, scanner):
		self.__scanner = scanner
		
	def __on_save_button_clicked(self, button):
		filechooser = gtk.FileChooserDialog(action=gtk.FILE_CHOOSER_ACTION_SAVE,
			buttons=(gtk.STOCK_CANCEL, gtk.RESPONSE_CANCEL,
			gtk.STOCK_SAVE, gtk.RESPONSE_OK))
		filechooser.set_do_overwrite_confirmation(True)
		if (filechooser.run() == gtk.RESPONSE_OK):
			self.__scanner.write_channels_to_file(filechooser.get_filename())
			self.emit("finished", True)
		filechooser.destroy()

