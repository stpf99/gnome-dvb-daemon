#!/usr/bin/env python
# -*- coding: utf-8 -*-
import gtk
import gnomedvb
from gettext import gettext as _
from gnomedvb.widgets.ChannelsStore import ChannelsStore
from gnomedvb.widgets.ChannelsView import ChannelsView
from cgi import escape

class ScheduleStore(gtk.ListStore):

    (COL_START,
     COL_DURATION,
     COL_TITLE,
     COL_SHORT_DESC,
     COL_EVENT_ID,) = range(5)

    def __init__(self, schedule_client):
        gtk.ListStore.__init__(self, str, int, str, str, int)
        self._client = schedule_client
        self._fill()
        
    def _fill(self):
        current = self._client.now_playing()
        
        while current != 0:
            name = escape(self._client.get_name(current))
            desc = escape(self._client.get_short_description(current))
            start_arr = self._client.get_local_start_time(current)
            
            start_str = "Unknown"
            if len(start_arr) != 0:
                start_str = "%04d-%02d-%02d %02d:%02d" % (start_arr[0], start_arr[1],
                    start_arr[2], start_arr[3], start_arr[4])
            # We want minutes
            duration = self._client.get_duration(current) / 60
            
            self.append([start_str, duration, name, desc, current])
            
            current = self._client.next(current)
        
        
class ScheduleView(gtk.TreeView):

    def __init__(self, model=None):
        if model != None:
            gtk.TreeView.__init__(self, model)
        else:
            gtk.TreeView.__init__(self)
        
        self._create_and_append_text_column(_("Start"), ScheduleStore.COL_START)
        self._create_and_append_text_column(_("Duration"), ScheduleStore.COL_DURATION)
        self._create_and_append_text_column(_("Title"), ScheduleStore.COL_TITLE)
        self._create_and_append_text_column(_("Description"), ScheduleStore.COL_SHORT_DESC)
        
    def _create_and_append_text_column(self, title, text_col):
        cell = gtk.CellRendererText()
        col = gtk.TreeViewColumn(title)
        col.pack_start(cell)
        col.add_attribute(cell, "markup", text_col)
        self.append_column(col)

class ScheduleWindow(gtk.Window):

    def __init__(self):
        gtk.Window.__init__(self)
        
        self.channellists = {}
        self.manager = gnomedvb.DVBManagerClient()
        
        self.connect('delete-event', gtk.main_quit)
        self.connect('destroy-event', gtk.main_quit)
        self.set_title(_("Program guide"))
        self.set_default_size(500, 400)
        self.set_border_width(3)
        
        self.hbox = gtk.HBox(spacing=6)
        self.add(self.hbox)
        
        self.hpaned = gtk.HPaned()
        self.hbox.pack_start(self.hpaned)
        
        self.vbox = gtk.VBox(spacing=6)
        self.hpaned.pack1(self.vbox)
        
        self.devgroupslist = gtk.ListStore(str, int)
        
        self.devgroupscombo = gtk.ComboBox(self.devgroupslist)
        self.devgroupscombo.connect("changed", self._on_devgroupscombo_changed)
        
        cell_adapter = gtk.CellRendererText()
        self.devgroupscombo.pack_start(cell_adapter)
        self.devgroupscombo.add_attribute(cell_adapter, "text", 0)
        
        self.vbox.pack_start(self.devgroupscombo, False)
        
        self.channelsstore = None
        
        self.channelsview = ChannelsView()
        self.channelsview.get_selection().connect("changed", self._on_channel_selected)
        
        scrolledchannels = gtk.ScrolledWindow()
        scrolledchannels.add(self.channelsview)
        scrolledchannels.set_policy(gtk.POLICY_AUTOMATIC, gtk.POLICY_AUTOMATIC)
        scrolledchannels.set_shadow_type(gtk.SHADOW_ETCHED_IN)
        self.vbox.pack_start(scrolledchannels)
        
        self.schedulestore = None
        
        self.scheduleview = ScheduleView()
        self.scheduleview.connect("button-press-event", self._on_event_selected)
        
        scrolledschedule = gtk.ScrolledWindow()
        scrolledschedule.add(self.scheduleview)
        scrolledschedule.set_policy(gtk.POLICY_AUTOMATIC, gtk.POLICY_AUTOMATIC)
        scrolledschedule.set_shadow_type(gtk.SHADOW_ETCHED_IN)
        self.hpaned.pack2(scrolledschedule)
        
        self.get_device_groups()
        
    def get_device_groups(self):
        for group_id in self.manager.get_registered_device_groups():
            group_name = _("Group %d") % group_id
            self.devgroupslist.append([group_name, group_id])
            self.channellists[group_id] = gnomedvb.DVBChannelListClient(group_id)
            
    def _get_selected_group_id(self):
        aiter = self.devgroupscombo.get_active_iter()
        return self.devgroupslist[aiter][1]
        
    def _get_selected_channel_sid(self):
        model, aiter = self.channelsview.get_selection().get_selected()
        if aiter != None:
            sid = model[aiter][model.COL_SID]
            return sid
        else:
            return None

    def _on_devgroupscombo_changed(self, combo):
        group_id = self._get_selected_group_id()
        self.channelsstore = ChannelsStore(group_id)
        self.channelsview.set_model(self.channelsstore)
        
    def _on_channel_selected(self, treeselection):
        model, aiter = treeselection.get_selected()
        if aiter != None:
            sid = model[aiter][model.COL_SID]
            group_id = self._get_selected_group_id()
            self.schedulestore = ScheduleStore(self.manager.get_schedule(group_id, sid))
            self.scheduleview.set_model(self.schedulestore)
            
    def _on_event_selected(self, treeview, event):
        if event.type == gtk.gdk._2BUTTON_PRESS:
            model, aiter = treeview.get_selection().get_selected()
            if aiter != None:
                event_id = model[aiter][model.COL_EVENT_ID]
                group_id = self._get_selected_group_id()
                channel_sid = self._get_selected_channel_sid()
                recorder = gnomedvb.DVBRecorderClient(group_id)
                recorder.add_timer_for_epg_event(event_id, channel_sid)
            
            
if __name__ == '__main__':
    w = ScheduleWindow()
    w.show_all()

    gtk.main()
    
        
        
