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

from gi.repository import Gtk
from gi.repository import GObject
from gnomedvb import _
from gnomedvb.ui.wizard.pages.BasePage import BasePage

class SaveChannelListPage(BasePage):

    __gsignals__ = {
        "finished": (GObject.SIGNAL_RUN_LAST, GObject.TYPE_NONE, [bool]),
    }

    def __init__(self):
        BasePage.__init__(self)
        self.__scanner = None
        self.__channels = None

        text = _("Choose a location where you want to save the list of channels.")
        self._label.set_text(text)

        button_box = Gtk.ButtonBox()
        self.pack_start(button_box, True, True, 0)

        save_button = Gtk.Button(stock=Gtk.STOCK_SAVE)
        save_button.connect("clicked", self.__on_save_button_clicked)
        button_box.pack_start(save_button, True, True, 0)

    def get_page_title(self):
        return _("Save channels")

    def set_scanner(self, scanner):
        self.__scanner = scanner

    def set_channels(self, channels):
        self.__channels = channels

    def __on_save_button_clicked(self, button):
        filechooser = Gtk.FileChooserDialog(action=Gtk.FileChooserAction.SAVE,
            buttons=(Gtk.STOCK_CANCEL, Gtk.ResponseType.CANCEL,
            Gtk.STOCK_SAVE, Gtk.ResponseType.OK))
        filechooser.set_do_overwrite_confirmation(True)
        if (filechooser.run() == Gtk.ResponseType.OK):
            self.__scanner.write_channels_to_file(self.__channels, filechooser.get_filename())
            self.emit("finished", True)
        filechooser.destroy()

