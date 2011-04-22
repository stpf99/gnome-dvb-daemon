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
from gettext import gettext as _
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
        
        self.table = Gtk.Table(6, 2)
        self.table.set_col_spacings(18)
        self.table.set_row_spacings(6)
        self.table.set_border_width(5)
        self.get_content_area().pack_start(self.table, True, True, 0)
        
        self._title = TextFieldLabel()
        self._channel = TextFieldLabel()
        self._date = TextFieldLabel()
        self._duration = TextFieldLabel()
        
        title_label = TextFieldLabel("<i>%s</i>" % _("Title:"))
        self.table.attach(title_label, 0, 1, 0, 1, Gtk.AttachOptions.FILL, Gtk.AttachOptions.FILL)
        self.table.attach(self._title, 1, 2, 0, 1, yoptions=Gtk.AttachOptions.FILL)
        
        channel_label = TextFieldLabel("<i>%s</i>" % _("Channel:"))
        self.table.attach(channel_label, 0, 1, 1, 2, Gtk.AttachOptions.FILL, Gtk.AttachOptions.FILL)
        self.table.attach(self._channel, 1, 2, 1, 2, yoptions=Gtk.AttachOptions.FILL)
        
        date_label = TextFieldLabel("<i>%s</i>" % _("Date:"))
        self.table.attach(date_label, 0, 1, 2, 3, Gtk.AttachOptions.FILL, Gtk.AttachOptions.FILL)
        self.table.attach(self._date, 1, 2, 2, 3, yoptions=Gtk.AttachOptions.FILL)
        
        duration_label = TextFieldLabel("<i>%s</i>" % _("Duration:"))
        self.table.attach(duration_label, 0, 1, 3, 4, Gtk.AttachOptions.FILL, Gtk.AttachOptions.FILL)
        self.table.attach(self._duration, 1, 2, 3, 4, yoptions=Gtk.AttachOptions.FILL)
        
        description_label = TextFieldLabel("<i>%s</i>" % _("Description:"))
        self.table.attach(description_label, 0, 1, 4, 5, Gtk.AttachOptions.FILL,
            yoptions=Gtk.AttachOptions.FILL)
            
        self.textview = Gtk.TextView()
        self.textview.set_editable(False)
        self.textview.set_wrap_mode(Gtk.WrapMode.WORD)
        self.textview.show()

        scrolledwin = Gtk.ScrolledWindow()
        scrolledwin.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scrolledwin.set_shadow_type(Gtk.ShadowType.IN)
        scrolledwin.set_margin_left(12)
        scrolledwin.add(self.textview)
        scrolledwin.show()
        self.table.attach(scrolledwin, 0, 2, 5, 6)
        
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

