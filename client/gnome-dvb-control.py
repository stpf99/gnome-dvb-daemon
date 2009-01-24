#!/usr/bin/env python
# -*- coding: utf-8 -*-
import gtk
import gnomedvb
from gettext import gettext as _
from gnomedvb.widgets.ChannelsStore import ChannelsStore
from gnomedvb.widgets.ChannelsView import ChannelsView
from gnomedvb.widgets.ScheduleStore import ScheduleStore
from gnomedvb.widgets.ScheduleView import ScheduleView
from gnomedvb.preferences.ui.Preferences import Preferences
from gnomedvb.widgets.DVBModel import DVBModel
from gnomedvb.widgets.EditTimersDialog import EditTimersDialog

class ScheduleWindow(gtk.Window):

    def __init__(self, model):
        gtk.Window.__init__(self)
        
        self.channellists = {}
        self.manager = model
        
        self.connect('delete-event', gtk.main_quit)
        self.connect('destroy-event', gtk.main_quit)
        self.set_title(_("Program guide"))
        self.set_default_size(800, 500)
        self.set_border_width(3)
        
        self.vbox_outer = gtk.VBox(spacing=6)
        self.vbox_outer.show()
        self.add(self.vbox_outer)
        
        self.__create_toolbar()
        
        self.hbox = gtk.HBox(spacing=6)
        self.vbox_outer.pack_start(self.hbox)
        
        self.hpaned = gtk.HPaned()
        self.hpaned.set_position(175)
        self.hbox.pack_start(self.hpaned)
        
        self.vbox_left = gtk.VBox(spacing=6)
        self.hpaned.pack1(self.vbox_left)
        
        groups_label = gtk.Label(_("Device groups:"))
        self.vbox_left.pack_start(groups_label, False)
        
        self.devgroupslist = gtk.ListStore(str, int)
        
        self.devgroupscombo = gtk.ComboBox(self.devgroupslist)
        self.devgroupscombo.connect("changed", self._on_devgroupscombo_changed)
        
        cell_adapter = gtk.CellRendererText()
        self.devgroupscombo.pack_start(cell_adapter)
        self.devgroupscombo.add_attribute(cell_adapter, "markup", 0)
        
        self.vbox_left.pack_start(self.devgroupscombo, False)
        
        self.channelsstore = None
        
        self.channelsview = ChannelsView()
        self.channelsview.set_headers_visible(False)
        self.channelsview.get_selection().connect("changed", self._on_channel_selected)
        
        scrolledchannels = gtk.ScrolledWindow()
        scrolledchannels.add(self.channelsview)
        scrolledchannels.set_policy(gtk.POLICY_AUTOMATIC, gtk.POLICY_AUTOMATIC)
        scrolledchannels.set_shadow_type(gtk.SHADOW_ETCHED_IN)
        self.vbox_left.pack_start(scrolledchannels)
        
        self.schedulestore = None
        
        self.scheduleview = ScheduleView()
        self.scheduleview.connect("button-press-event", self._on_event_selected)
        
        scrolledschedule = gtk.ScrolledWindow()
        scrolledschedule.add(self.scheduleview)
        scrolledschedule.set_policy(gtk.POLICY_AUTOMATIC, gtk.POLICY_AUTOMATIC)
        scrolledschedule.set_shadow_type(gtk.SHADOW_ETCHED_IN)
        self.hpaned.pack2(scrolledschedule)
        
        self.get_device_groups()
        
        self.devgroupscombo.set_active(0)
        self.channelsview.grab_focus()
        
    def __create_toolbar(self):
        toolbar = gtk.Toolbar()
        toolbar.show()
        self.vbox_outer.pack_start(toolbar, False)
        
        edit_image = gtk.image_new_from_stock(gtk.STOCK_FIND_AND_REPLACE, gtk.ICON_SIZE_SMALL_TOOLBAR)
        edit_image.show()
        self.button_display_timers = gtk.ToolButton(icon_widget=edit_image, label=_("Edit Recordings"))
        self.button_display_timers.set_sensitive(False)
        self.button_display_timers.connect("clicked", self._on_button_display_timers_clicked)
        self.button_display_timers.set_tooltip_markup(_("View scheduled recordings"))
        self.button_display_timers.show()
        toolbar.insert(self.button_display_timers, 0)
        
        sep = gtk.SeparatorToolItem()
        sep.show()
        toolbar.insert(sep, 1)
        
        self.button_prefs = gtk.ToolButton(gtk.STOCK_PREFERENCES)
        self.button_prefs.connect("clicked", self._on_button_prefs_clicked)
        self.button_prefs.set_tooltip_markup(_("Manage devices"))
        self.button_prefs.show()
        toolbar.insert(self.button_prefs, 2)
         
    def get_device_groups(self):
        for group in self.manager.get_registered_device_groups():
            self.devgroupslist.append([group["name"], group["id"]])
            self.channellists[group["id"]] = gnomedvb.DVBChannelListClient(group["id"])
            
    def _get_selected_group_id(self):
        aiter = self.devgroupscombo.get_active_iter()
        if aiter == None:
            return None
        else:
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
        if group_id != None:
            self.button_display_timers.set_sensitive(True)
            
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
                dialog = gtk.MessageDialog(parent=self,
                    flags=gtk.DIALOG_MODAL|gtk.DIALOG_DESTROY_WITH_PARENT,
                    type=gtk.MESSAGE_QUESTION, buttons=gtk.BUTTONS_YES_NO)
                dialog.set_markup (_("<big><span weight=\"bold\">Schedule recording for the selected event?</span></big>"))
                if dialog.run() == gtk.RESPONSE_YES:
                    event_id = model[aiter][model.COL_EVENT_ID]
                    group_id = self._get_selected_group_id()
                    channel_sid = self._get_selected_channel_sid()
                    recorder = gnomedvb.DVBRecorderClient(group_id)
                    recorder.add_timer_for_epg_event(event_id, channel_sid)
                dialog.destroy()
        
    def _on_button_display_timers_clicked(self, button):
        group_id = self._get_selected_group_id()
        if group_id != None:
            edit = EditTimersDialog(group_id, self)
            edit.run()
            edit.destroy()
        
    def _on_button_prefs_clicked(self, button):
        prefs = Preferences(self.manager, self)
        prefs.run()
        prefs.destroy()
                    
if __name__ == '__main__':
    model = DVBModel()
    w = ScheduleWindow(model)
    w.show_all()

    gtk.main()
    
        
        
