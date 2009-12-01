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
import gtk
import gnomedvb
from gettext import gettext as _
from gnomedvb.ui.widgets.Frame import TextFieldLabel

class DetailsDialog(gtk.Dialog):

    def __init__(self, parent=None):
        gtk.Dialog.__init__(self, title=_("Details"),
            parent=parent,
            flags=gtk.DIALOG_DESTROY_WITH_PARENT)
        
        self.set_default_size(440, 350)
        self.set_border_width(6)
        self.set_has_separator(False)
        self.vbox.set_spacing(12)
        
        close_button = self.add_button(gtk.STOCK_CLOSE, gtk.RESPONSE_CLOSE)
        close_button.grab_default()
        
        self.table = gtk.Table(6, 2)
        self.table.set_col_spacings(18)
        self.table.set_row_spacings(6)
        self.table.set_border_width(6)
        self.vbox.pack_start(self.table)
        
        self._title = TextFieldLabel()
        self._channel = TextFieldLabel()
        self._date = TextFieldLabel()
        self._duration = TextFieldLabel()
        
        title_label = TextFieldLabel("<i>%s</i>" % _("Title:"))
        self.table.attach(title_label, 0, 1, 0, 1, gtk.FILL, gtk.FILL)
        self.table.attach(self._title, 1, 2, 0, 1, yoptions=gtk.FILL)
        
        channel_label = TextFieldLabel("<i>%s</i>" % _("Channel:"))
        self.table.attach(channel_label, 0, 1, 1, 2, gtk.FILL, gtk.FILL)
        self.table.attach(self._channel, 1, 2, 1, 2, yoptions=gtk.FILL)
        
        date_label = TextFieldLabel("<i>%s</i>" % _("Date:"))
        self.table.attach(date_label, 0, 1, 2, 3, gtk.FILL, gtk.FILL)
        self.table.attach(self._date, 1, 2, 2, 3, yoptions=gtk.FILL)
        
        duration_label = TextFieldLabel("<i>%s</i>" % _("Duration:"))
        self.table.attach(duration_label, 0, 1, 3, 4, gtk.FILL, gtk.FILL)
        self.table.attach(self._duration, 1, 2, 3, 4, yoptions=gtk.FILL)
        
        description_label = TextFieldLabel("<i>%s</i>" % _("Description:"))
        self.table.attach(description_label, 0, 1, 4, 5, gtk.FILL,
            yoptions=gtk.FILL)
            
        self.textview = gtk.TextView()
        self.textview.set_editable(False)
        self.textview.set_wrap_mode(gtk.WRAP_WORD)
        self.textview.show()
        
        desc_text_ali = gtk.Alignment(xscale=1.0, yscale=1.0)
        desc_text_ali.set_padding(0, 0, 12, 0)
        desc_text_ali.show()
        self.table.attach(desc_text_ali, 0, 2, 5, 6)
        
        scrolledwin = gtk.ScrolledWindow()
        scrolledwin.set_policy(gtk.POLICY_NEVER, gtk.POLICY_AUTOMATIC)
        scrolledwin.set_shadow_type(gtk.SHADOW_IN)
        scrolledwin.add(self.textview)
        scrolledwin.show()
        desc_text_ali.add(scrolledwin)
        
        self.table.show_all()
        
    def set_description(self, text):
        self.textview.get_buffer().set_text(text)
        
    def set_title(self, title):
        gtk.Dialog.set_title(self, title)
        self._title.label.set_text(title)

    def set_channel(self, channel):
        self._channel.label.set_text(channel)
        
    def set_duration(self, duration):
        duration_str = gnomedvb.seconds_to_time_duration_string(duration)
        self._duration.label.set_text(duration_str)
        
    def set_date(self, timestamp):
        date = datetime.datetime.fromtimestamp(timestamp)
        self._date.label.set_text(date.strftime("%c"))

