#!/usr/bin/env python
# -*- coding: utf-8 -*-
import gtk
import gnomedvb
import datetime

class RecorderWindow(gtk.Window):

    (COL_ID,
    COL_CHANNEL,
    COL_START,
    COL_DURATION) = range(4)
    
    (COL_PATH,) = range(1)

    def __init__(self):
        gtk.Window.__init__(self)
        
        self.recorders = {}
        
        self.set_title("Schedule Recordings")
        self.set_size_request(350, 200)
        self.set_border_width(3)
        self.connect("delete-event", gtk.main_quit)
        self.connect("destroy-event", gtk.main_quit)
        
        self.vbox = gtk.VBox(spacing=6)
        self.add(self.vbox)
        
        recorders_ali = gtk.Alignment(0, 0.5)
        self.vbox.pack_start(recorders_ali, False)
        
        recorders_label = gtk.Label()
        recorders_label.set_markup("<b>Choose device group:</b>")
        recorders_ali.add(recorders_label)
        
        self.recorderslist = gtk.ListStore(int)
        
        self.recorderscombo = gtk.ComboBox(self.recorderslist)
        self.recorderscombo.connect("changed", self._on_recorderscombo_changed)
        
        cell_adapter = gtk.CellRendererText()
        self.recorderscombo.pack_start(cell_adapter)
        self.recorderscombo.add_attribute(cell_adapter, "text", self.COL_PATH)
        self.vbox.pack_start(self.recorderscombo, False)
        
        timers_ali = gtk.Alignment(0, 0.5)
        self.vbox.pack_start(timers_ali, False)
        
        timers_label = gtk.Label()
        timers_label.set_markup("<b>Scheduled recordings:</b>")
        timers_ali.add(timers_label)
        
        self.timerslist = gtk.ListStore(int, str, str, int)
        
        self.timersview = gtk.TreeView(self.timerslist)
        self.timersview.get_selection().connect("changed",
            self._on_timers_selection_changed)
        
        cell_id = gtk.CellRendererText()
        col_id = gtk.TreeViewColumn("ID")
        col_id.pack_start(cell_id)
        col_id.add_attribute(cell_id, "text", self.COL_ID)
        
        self.timersview.append_column(col_id)
        
        cell_channel = gtk.CellRendererText()
        col_channel = gtk.TreeViewColumn("Channel")
        col_channel.pack_start(cell_channel)
        col_channel.add_attribute(cell_channel, "text", self.COL_CHANNEL)
        
        self.timersview.append_column(col_channel)
        
        cell_starttime = gtk.CellRendererText()
        col_starttime = gtk.TreeViewColumn("Start time")
        col_starttime.pack_start(cell_starttime)
        col_starttime.add_attribute(cell_starttime, "text", self.COL_START)
        
        self.timersview.append_column(col_starttime)
        
        cell_duration = gtk.CellRendererText()
        col_duration = gtk.TreeViewColumn("Duration in minutes")
        col_duration.pack_start(cell_duration)
        col_duration.add_attribute(cell_duration, "text", self.COL_DURATION )
        
        self.timersview.append_column(col_duration)
        
        self.scrolledwindow = gtk.ScrolledWindow()
        self.scrolledwindow.set_policy(gtk.POLICY_AUTOMATIC, gtk.POLICY_AUTOMATIC)
        self.scrolledwindow.add(self.timersview)
        self.vbox.pack_start(self.scrolledwindow)
        
        self.buttonbox = gtk.HButtonBox()
        self.button_add = gtk.Button(stock=gtk.STOCK_ADD)
        self.button_add.connect("clicked", self._on_button_add_clicked)
        self.button_add.set_sensitive(False)
        self.buttonbox.pack_start(self.button_add)

        self.button_delete = gtk.Button(stock=gtk.STOCK_DELETE)
        self.button_delete.connect("clicked", self._on_button_delete_clicked)
        self.button_delete.set_sensitive(False)
        self.buttonbox.pack_start(self.button_delete)
        
        self.vbox.pack_start(self.buttonbox, False, False, 0)
        
        self.get_device_groups()
        
    def get_device_groups(self):
        manager = gnomedvb.DVBManagerClient()
        
        for group_id in manager.get_registered_device_groups():
            self.recorderslist.append([group_id])
            path = "/org/gnome/DVB/Recorder/%d" % group_id
            self.recorders[group_id] = gnomedvb.DVBRecorderClient(path)
            
    def get_timers(self, recorder_path):
        rec = self.recorders[recorder_path]
        rec.connect("changed", self._on_recorder_changed)
        
        for timer_id in rec.get_timers():
            self._add_timer(rec, timer_id)
            
    def _add_timer(self, rec, timer_id):
        start_list = rec.get_start_time(timer_id)
        starttime = "%d-%d-%d %d:%d" % (start_list[0], start_list[1],
                start_list[2], start_list[3], start_list[4])
        duration = rec.get_duration(timer_id)
        channel = rec.get_channel_name(timer_id)
        
        self.timerslist.append([timer_id, channel, starttime, duration])

    def _on_button_delete_clicked(self, button):
        model, aiter = self.timersview.get_selection().get_selected()
        if aiter != None:
            rec = self.recorders[self._get_active_device_group()]
            rec.delete_timer(model[aiter][self.COL_ID])
            model.remove(aiter)
        
    def _on_button_add_clicked(self, button):   
        device_group = self._get_active_device_group()
        
        d = TimerDialog(self, device_group)
        if (d.run() == gtk.RESPONSE_ACCEPT):
            
            duration = d.get_duration()
            start = d.get_start_time()
            channel = d.get_channel()
            
            rec = self.recorders[device_group]
            rec.add_timer (channel, start[0], start[1], start[2], start[3],
                start[4], duration)
            
        d.destroy()
        
    def _get_active_device_group(self):
        aiter = self.recorderscombo.get_active_iter()
        return self.recorderslist[aiter][self.COL_PATH]
        
    def _on_recorderscombo_changed(self, combo):
        self.get_timers(self._get_active_device_group())
        self.button_add.set_sensitive(True)
        
    def _on_recorder_changed(self, recorder, timer_id, typeid):
        if (typeid == 0):
            # Timer added
            if recorder.get_path().endswith(str(self._get_active_device_group())):
                self._add_timer(recorder, timer_id)
        elif (typeid == 1):
            # Timer deleted
            pass
        elif (typeid == 2):
            # Timer changed
            pass
            
    def _on_timers_selection_changed(self, treeselection):
        model, aiter = treeselection.get_selected()
        if aiter == None:
            self.button_delete.set_sensitive(False)
        else:
            self.button_delete.set_sensitive(True)

class TimerDialog(gtk.Dialog):

    def __init__(self, parent, device_group):
        gtk.Dialog.__init__(self, title="Timer", parent=parent,
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
        label_channel.set_markup("<b>Channel:</b>")
        table.attach(label_channel, 0, 1, 0, 1)
        
        channel_ali = gtk.Alignment(0, 0.5)
        table.attach(channel_ali, 1, 2, 0, 1)
        
        self.channels = gtk.ListStore(str, int)
        self._add_channels(device_group)
        
        self.channelscombo = gtk.ComboBox(self.channels)
        
        cell_name = gtk.CellRendererText()
        self.channelscombo.pack_start(cell_name)
        self.channelscombo.add_attribute(cell_name, "text", 0)
        channel_ali.add(self.channelscombo)
                         
        label_start = gtk.Label()
        label_start.set_markup("<b>Start time:</b>")
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
        
        calendar_button = gtk.Button("Pick date")
        calendar_button.connect("clicked", self._on_calendar_button_clicked)
        hbox.pack_start(calendar_button)
        
        label_duration = gtk.Label()
        label_duration.set_markup("<b>Duration:</b>")
        table.attach(label_duration, 0, 1, 2, 3)
        
        ali = gtk.Alignment(0, 0.5)
        table.attach(ali, 1, 2, 2, 3)
        
        self.duration = gtk.SpinButton()
        self.duration.set_range(1, 65535)
        self.duration.set_increments(1, 10)
        ali.add(self.duration)
        
        self._set_default_time_and_date()
        
        table.show_all()
        
    def _add_channels(self, device_group):
        channel_list_path = "/org/gnome/DVB/ChannelList/%s" % device_group
        channellist = gnomedvb.DVBChannelListClient(channel_list_path)
        for channel_id in channellist.get_channels():
            name = channellist.get_channel_name(channel_id)
            self.channels.append([name, channel_id])
        
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
        aiter = self.channelscombo.get_active_iter()
        if aiter != None:
            return self.channels[aiter][1]
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
        
class CalendarDialog(gtk.Dialog):

    def __init__(self, parent):
        gtk.Dialog.__init__(self, title="Pick a date", parent=parent,
            flags=gtk.DIALOG_MODAL | gtk.DIALOG_DESTROY_WITH_PARENT,
            buttons=(gtk.STOCK_CANCEL, gtk.RESPONSE_REJECT,
             gtk.STOCK_OK, gtk.RESPONSE_ACCEPT))     
        
        self.set_position(gtk.WIN_POS_MOUSE)
        
        self.calendar = gtk.Calendar()
        self.calendar.show()
        self.vbox.add(self.calendar)
        
    def get_date(self):
        return self.calendar.get_date()
        
if __name__ == '__main__':
    w = RecorderWindow()
    w.show_all()
    gtk.main()
    
