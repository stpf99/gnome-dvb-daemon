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

import datetime
import gtk
from gettext import gettext as _
from gnomedvb.ui.timers.CalendarDialog import CalendarDialog
from gnomedvb.ui.widgets.ChannelsStore import ChannelsStore
from gnomedvb.ui.widgets.ChannelsView import ChannelsView
from gnomedvb.ui.widgets.Frame import TextFieldLabel
from gnomedvb.ui.widgets.DateTime import DateTimeBox

class TimerDialog(gtk.Dialog):

    def __init__(self, parent, device_group, channel=None,
            starttime=None, duration=60):
        """
        @param parent: Parent window
        @type parent: gtk.Window
        @param device_group: DeviceGroup instance
        """
        gtk.Dialog.__init__(self, parent=parent,
                flags=gtk.DIALOG_MODAL | gtk.DIALOG_DESTROY_WITH_PARENT)

        self.set_default_size(320, -1)

        self.device_group = device_group
        self.date_valid = False
        self.allowed_delta = datetime.timedelta(hours=1)
        
        self.add_button(gtk.STOCK_CANCEL, gtk.RESPONSE_REJECT)
        self.ok_button = self.add_button(gtk.STOCK_OK, gtk.RESPONSE_ACCEPT)
        
        self.set_has_separator(False)
        self.set_border_width(5)
        
        table = gtk.Table(rows=4, columns=2)
        table.set_col_spacings(18)
        table.set_row_spacings(6)
        table.set_border_width(5)
        self.vbox.pack_start(table)
                         
        label_channel = TextFieldLabel()
        label = label_channel.get_label()
        table.attach(label_channel, 0, 1, 0, 1, gtk.FILL, gtk.FILL)
        
        if channel == None:
            self.channel_selected = False
            self.set_title(_("Add Timer"))
            self.ok_button.set_sensitive(False)

            label.set_markup_with_mnemonic(_("_Channel:"))
            self.channels = ChannelsStore(device_group)
        
            scrolledchannels = gtk.ScrolledWindow()
            scrolledchannels.set_policy(gtk.POLICY_AUTOMATIC, gtk.POLICY_AUTOMATIC)
            scrolledchannels.set_shadow_type(gtk.SHADOW_ETCHED_IN)
            table.attach(scrolledchannels, 0, 2, 1, 2)
            
            self.channelsview = ChannelsView(self.channels)
            self.channelsview.set_headers_visible(False)
            self.channelsview.get_selection().connect("changed",
                self._on_channel_changed)
            scrolledchannels.add(self.channelsview)
            label.set_mnemonic_widget(self.channelsview)
            self.channelsview.grab_focus()
        else:
            self.channel_selected = True
            self.set_title(_("Edit Timer"))
            self.ok_button.set_sensitive(True)

            label.set_text(_("Channel:"))
            self.channels = None
            self.channelsview = None
            channel_label = TextFieldLabel(channel)
            table.attach(channel_label, 1, 2, 0, 1, yoptions=gtk.FILL)
        
        label_start = TextFieldLabel()
        label = label_start.get_label()
        label.set_markup_with_mnemonic(_("_Start time:"))
        table.attach(label_start, 0, 1, 2, 3)
        
        hbox = gtk.HBox(spacing=6)
        table.attach(hbox, 1, 2, 2, 3, yoptions=0)

        if starttime == None:
            starttime = datetime.datetime.now()
        
        self.datetime_box = DateTimeBox(starttime)
        self.datetime_box.connect("changed", self._on_datetime_changed)
        hbox.pack_start(self.datetime_box)
        label.set_mnemonic_widget(self.datetime_box)
        
        label_duration = TextFieldLabel()
        label = label_duration.get_label()
        label.set_markup_with_mnemonic(_("_Duration:"))
        table.attach(label_duration, 0, 1, 3, 4, gtk.FILL, gtk.FILL)
        
        duration_hbox = gtk.HBox(spacing=6)
        table.attach(duration_hbox, 1, 2, 3, 4)
        
        self.duration = gtk.SpinButton()
        self.duration.set_range(1, 65535)
        self.duration.set_increments(1, 10)
        self.duration.set_width_chars(3)
        self.duration.set_value(60)
        duration_hbox.pack_start(self.duration, False)
        label.set_mnemonic_widget(self.duration)
        
        minutes_label = TextFieldLabel(_("minutes"))
        duration_hbox.pack_start(minutes_label)
        
        self.set_start_time(starttime)
        self.set_duration(duration)
        
        table.show_all()

    def get_duration(self):
        return self.duration.get_value_as_int()

    def set_duration(self, minutes):
        self.duration.set_value(minutes)
        
    def get_start_time(self):
        return self.datetime_box.get_date_and_time()

    def set_start_time(self, time):
        self.datetime_box.set_date_and_time(time.year, time.month, time.day,
            time.hour, time.minute)
        
    def get_channel(self):
        if self.channelsview == None:
            return None
        model, aiter = self.channelsview.get_selection().get_selected()
        if aiter != None:
            return model[aiter][1]
        else:
            return None

    def set_time_and_date_editable(self, val):
        self.datetime_box.set_editable(val)
        
    def _on_channel_changed(self, treeselection):
        model, aiter = treeselection.get_selected()
        self.channel_selected = (aiter != None)
        self._update_sensivity()

    def _on_datetime_changed(self, widget, year, mon, day, hour, minute):
        dt_new = datetime.datetime(year, mon, day, hour, minute)
        dt_now = datetime.datetime.now()
        delta = dt_new - dt_now
        # Check if delta is negative
        if delta < datetime.timedelta():
            self.date_valid = abs(delta) <= self.allowed_delta
        else:
            self.date_valid = True
        self._update_sensivity()

    def _update_sensivity(self):
        status = self.date_valid and self.channel_selected
        self.ok_button.set_sensitive(status)
        self.datetime_box.mark_valid(self.date_valid)

