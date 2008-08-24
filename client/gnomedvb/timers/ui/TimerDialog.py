# -*- coding: utf-8 -*-
import datetime
import gnomedvb
import gtk
from gettext import gettext as _
from CalendarDialog import CalendarDialog
from gnomedvb.widgets.ChannelsStore import ChannelsStore
from gnomedvb.widgets.ChannelsView import ChannelsView

class TimerDialog(gtk.Dialog):

    def __init__(self, parent, device_group):
        gtk.Dialog.__init__(self, title=_("Timer"), parent=parent,
                flags=gtk.DIALOG_MODAL | gtk.DIALOG_DESTROY_WITH_PARENT,
                buttons=(gtk.STOCK_CANCEL, gtk.RESPONSE_REJECT,
                 gtk.STOCK_OK, gtk.RESPONSE_ACCEPT))
        
        self._start_date = None
        
        table = gtk.Table(rows=3, columns=2)
        table.set_row_spacings(6)
        table.set_col_spacings(6)
        table.set_border_width(3)
        self.vbox.add(table)
                         
        label_channel = gtk.Label()
        label_channel.set_markup(_("<b>Channel:</b>"))
        table.attach(label_channel, 0, 1, 0, 1)
        
        self.channels = ChannelsStore(device_group)
        
        scrolledchannels = gtk.ScrolledWindow()
        scrolledchannels.set_policy(gtk.POLICY_AUTOMATIC, gtk.POLICY_AUTOMATIC)
        scrolledchannels.set_shadow_type(gtk.SHADOW_ETCHED_IN)
        table.attach(scrolledchannels, 1, 2, 0, 1)
        
        self.channelsview = ChannelsView(self.channels)
        self.channelsview.set_headers_visible(False)
        scrolledchannels.add(self.channelsview)
        
        label_start = gtk.Label()
        label_start.set_markup(_("<b>Start time:</b>"))
        table.attach(label_start, 0, 1, 1, 2)
        
        hbox = gtk.HBox(spacing=3)
        table.attach(hbox, 1, 2, 1, 2)
        
        self.entry = gtk.Entry()
        self.entry.set_editable(False)
        self.entry.set_width_chars(10)
        hbox.pack_start(self.entry)
        
        self.hour = gtk.SpinButton()
        self.hour.set_range(0, 23)
        self.hour.set_increments(1, 3)
        self.hour.set_wrap(True)
        hbox.pack_start(self.hour)
        
        hour_minute_seperator = gtk.Label(":")
        hbox.pack_start(hour_minute_seperator)
        
        self.minute = gtk.SpinButton()
        self.minute.set_range(0, 59)
        self.minute.set_increments(1, 15)
        self.minute.set_wrap(True)
        hbox.pack_start(self.minute)
        
        calendar_button = gtk.Button(_("Pick date"))
        calendar_button.connect("clicked", self._on_calendar_button_clicked)
        hbox.pack_start(calendar_button)
        
        label_duration = gtk.Label()
        label_duration.set_markup(_("<b>Duration:</b>"))
        table.attach(label_duration, 0, 1, 2, 3)
        
        ali = gtk.Alignment(0, 0.5)
        table.attach(ali, 1, 2, 2, 3)
        
        self.duration = gtk.SpinButton()
        self.duration.set_range(1, 65535)
        self.duration.set_increments(1, 10)
        ali.add(self.duration)
        
        self._set_default_time_and_date()
        
        table.show_all()
      
    def get_duration(self):
        return self.duration.get_value_as_int()
        
    def get_start_time(self):
        start = []
        
        for i in range(3):
            start.append(self._start_date[i])
        
        start.append(self.hour.get_value_as_int())
        start.append(self.minute.get_value_as_int())
        
        return start
        
    def get_channel(self):
        model, aiter = self.channelsview.get_selection().get_selected()
        if aiter != None:
            return model[aiter][1]
        else:
            return None
        
    def _set_default_time_and_date(self):
        current = datetime.datetime.now()
        self._set_date(current.year, current.month, current.day)
        
        self.hour.set_value(current.hour)
        self.minute.set_value(current.minute)
        
    def _set_date(self, year, month, day):
        self._start_date = (year, month, day)
        self.entry.set_text("%04d-%02d-%02d" % (year, month, day))
        
    def _on_calendar_button_clicked(self, button):
        d = CalendarDialog(self)
        if (d.run() == gtk.RESPONSE_ACCEPT):
            date = d.get_date()
            self._set_date(date[0], date[1]+1, date[2])
        
        d.destroy()

