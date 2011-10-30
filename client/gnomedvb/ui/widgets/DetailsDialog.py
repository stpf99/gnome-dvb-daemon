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

import datetime
from gi.repository import Gtk
import gnomedvb
from gnomedvb import _
from gnomedvb.ui.widgets.Frame import TextFieldLabel

class DetailsDialog(Gtk.Dialog):

    def __init__(self, parent=None):
        Gtk.Dialog.__init__(self, parent=parent)
    
        self.set_destroy_with_parent(True)
        self.set_default_size(440, 350)
        self.set_border_width(5)

        self.get_action_area().set_layout(Gtk.ButtonBoxStyle.EDGE)

        self.rec_button = Gtk.Button(stock=Gtk.STOCK_MEDIA_RECORD)
        self.rec_button.show()
        self.get_action_area().pack_start(self.rec_button, True, True, 0)
        
        close_button = self.add_button(Gtk.STOCK_CLOSE, Gtk.ResponseType.CLOSE)
        close_button.grab_default()
        
        self.table = Gtk.Grid(orientation=Gtk.Orientation.VERTICAL)
        self.table.set_column_spacing(18)
        self.table.set_row_spacing(6)
        self.table.set_border_width(5)
        self.get_content_area().pack_start(self.table, True, True, 0)
        
        self._title = TextFieldLabel(hexpand=True)
        self._channel = TextFieldLabel(hexpand=True)
        self._date = TextFieldLabel(hexpand=True)
        self._duration = TextFieldLabel(hexpand=True)
        
        title_label = TextFieldLabel("<i>%s</i>" % _("Title:"))
        self.table.add(title_label)
        self.table.attach_next_to(self._title, title_label,
            Gtk.PositionType.RIGHT, 1, 1)
        
        channel_label = TextFieldLabel("<i>%s</i>" % _("Channel:"))
        self.table.add(channel_label)
        self.table.attach_next_to(self._channel, channel_label,
            Gtk.PositionType.RIGHT, 1, 1)
        
        date_label = TextFieldLabel("<i>%s</i>" % _("Date:"))
        self.table.add(date_label)
        self.table.attach_next_to(self._date, date_label,
            Gtk.PositionType.RIGHT, 1, 1)
        
        duration_label = TextFieldLabel("<i>%s</i>" % _("Duration:"))
        self.table.add(duration_label)
        self.table.attach_next_to(self._duration, duration_label,
            Gtk.PositionType.RIGHT, 1, 1)
        
        description_label = TextFieldLabel("<i>%s</i>" % _("Description:"))
        self.table.add(description_label)
            
        self.textview = Gtk.TextView()
        self.textview.set_editable(False)
        self.textview.set_wrap_mode(Gtk.WrapMode.WORD)
        self.textview.show()

        scrolledwin = Gtk.ScrolledWindow(expand=True)
        scrolledwin.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scrolledwin.set_shadow_type(Gtk.ShadowType.IN)
        scrolledwin.set_margin_left(12)
        scrolledwin.add(self.textview)
        scrolledwin.show()
        self.table.attach_next_to(scrolledwin, description_label,
            Gtk.PositionType.BOTTOM, 2, 1)
        
        self.table.show_all()
        
    def set_description(self, text):
        self.textview.get_buffer().set_text(text)
        
    def set_title(self, title):
        Gtk.Dialog.set_title(self, title)
        self._title.set_text(title)

    def set_channel(self, channel):
        self._channel.set_text(channel)
        
    def set_duration(self, duration):
        duration_str = gnomedvb.seconds_to_time_duration_string(duration)
        self._duration.set_text(duration_str)
        
    def set_date(self, timestamp):
        date = datetime.datetime.fromtimestamp(timestamp)
        self._date.set_text(date.strftime("%c"))

    def get_record_button(self):
        return self.rec_button

