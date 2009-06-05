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

import pygtk
pygtk.require("2.0")
import gtk
import pygst
pygst.require("0.10")

import subprocess
import totem
import gnomedvb

from gnomedvb import global_error_handler
from gnomedvb.DVBModel import DVBModel
from gnomedvb.ui.widgets.ChannelsStore import ChannelsTreeStore
from gnomedvb.ui.widgets.ChannelsView import ChannelsView
from gnomedvb.ui.widgets.ScheduleStore import ScheduleStore
from gnomedvb.ui.widgets.ScheduleView import ScheduleView
from gnomedvb.ui.preferences.Preferences import Preferences
from gnomedvb.ui.timers.EditTimersDialog import EditTimersDialog
from gnomedvb.ui.timers.TimerDialog import NoTimerCreatedDialog

class ScheduleDialog(gtk.Dialog):

    def __init__(self, group, sid, parent=None):
        gtk.Dialog.__init__(self, title=_("Program Guide"),
            parent=parent,
            flags=gtk.DIALOG_DESTROY_WITH_PARENT,
            buttons=(gtk.STOCK_CLOSE, gtk.RESPONSE_CLOSE))
            
        self._group = group
        self._sid = sid
            
        self.set_default_size(640, 380)
        self.vbox.set_spacing(6)
            
        self.scheduleview = ScheduleView()
        self.scheduleview.connect("button-press-event", self._on_event_selected)
        self.scheduleview.show()
        
        self.scrolledschedule = gtk.ScrolledWindow()
        self.scrolledschedule.add(self.scheduleview)
        self.scrolledschedule.set_policy(gtk.POLICY_AUTOMATIC, gtk.POLICY_AUTOMATIC)
        self.scrolledschedule.set_shadow_type(gtk.SHADOW_IN)
        self.vbox.pack_start(self.scrolledschedule)
        self.scrolledschedule.show()
        
        self.schedulestore = ScheduleStore(group, sid)
        self.scheduleview.set_model(self.schedulestore)
    
    def _on_event_selected(self, treeview, event):
        if event.type == gtk.gdk._2BUTTON_PRESS:
            model, aiter = treeview.get_selection().get_selected()
            if aiter != None:
                dialog = gtk.MessageDialog(parent=self,
                    flags=gtk.DIALOG_MODAL | gtk.DIALOG_DESTROY_WITH_PARENT,
                    type=gtk.MESSAGE_QUESTION, buttons=gtk.BUTTONS_YES_NO)
                dialog.set_markup ("<big><span weight=\"bold\">%s</span></big>" % _("Schedule recording for the selected event?"))
                if dialog.run() == gtk.RESPONSE_YES:
                    event_id = model[aiter][model.COL_EVENT_ID]
                    recorder = self._group.get_recorder()
                    rec_id = recorder.add_timer_for_epg_event(event_id, self._sid)
                dialog.destroy()
                
                if rec_id == 0:
                    dialog = NoTimerCreatedDialog(self)
                    dialog.run()
                    dialog.destroy()


class PairBox(gtk.HBox):
    def __init__(self, name, text=None):
        gtk.HBox.__init__(self, spacing=3)
        
        name_label = gtk.Label()
        name_label.set_markup(name)
        name_label.show()
        self.pack_start(name_label, False)
        
        text_ali = gtk.Alignment()
        text_ali.show()
        self.pack_start(text_ali)
        
        self.text_label = gtk.Label(text)
        self.text_label.show()
        text_ali.add(self.text_label)
        
    def get_text_label(self):
        return self.text_label

      
class DetailsDialog(gtk.Dialog):

    def __init__(self, parent=None):
        gtk.Dialog.__init__(self, title=_("Details"),
            parent=parent,
            flags=gtk.DIALOG_DESTROY_WITH_PARENT,
            buttons=(gtk.STOCK_CLOSE, gtk.RESPONSE_CLOSE))
        
        self.set_default_size(440, 350)
        self.vbox.set_spacing(6)
        
        title_hbox = PairBox(_("<b>Title:</b>"))
        self.title_label = title_hbox.get_text_label()
        title_hbox.show_all()
        self.vbox.pack_start(title_hbox, False)
        
        channel_hbox = PairBox(_("<b>Channel:</b>"))
        self.channel = channel_hbox.get_text_label()
        channel_hbox.show_all()
        self.vbox.pack_start(channel_hbox, False)
        
        duration_hbox = PairBox(_("<b>Duration:</b>"))
        self.duration = duration_hbox.get_text_label()
        duration_hbox.show_all()
        self.vbox.pack_start(duration_hbox, False)
        
        label_description = gtk.Label()
        label_description.set_markup(_("<b>Description:</b>"))
        label_description.show()
        
        ali_desc = gtk.Alignment()
        ali_desc.show()
        ali_desc.add(label_description)
        self.vbox.pack_start(ali_desc, False)
            
        self.textview = gtk.TextView()
        self.textview.set_editable(False)
        self.textview.set_wrap_mode(gtk.WRAP_WORD)
        self.textview.show()
        
        self.scrolledwin = gtk.ScrolledWindow()
        self.scrolledwin.set_policy(gtk.POLICY_NEVER, gtk.POLICY_AUTOMATIC)
        self.scrolledwin.set_shadow_type(gtk.SHADOW_IN)
        self.scrolledwin.add(self.textview)
        self.scrolledwin.show()
        self.vbox.pack_start(self.scrolledwin)
        
    def set_text(self, text):
        self.textview.get_buffer().set_text(text)
        
    def set_title(self, title):
        gtk.Dialog.set_title(self, title)
        self.title_label.set_text(title)

    def set_channel(self, channel):
        self.channel.set_text(channel)
        
    def set_duration(self, duration):
        self.duration.set_text(duration)


class DVBDaemonPlugin(totem.Plugin):

    REC_GROUP_ID = -1
    
    MENU = '''<ui>
    <menubar name="tmw-menubar">
    <menu name="dvb" action="dvb-menu">
      <menuitem name="setup" action="dvb-setup" />
      <menuitem name="timers" action="dvb-timers" />
      <menuitem name="program-guide" action="dvb-epg" />
      <separator />
      <menuitem name="dvb-prefs" action="dvb-preferences" />
    </menu></menubar>
    <popup name="dvb-popup">
        <menuitem name="dvb-program-guide" action="dvb-epg" />
    </popup>
    <popup name="dvb-recording-popup">
        <menuitem name="delete-recording" action="dvb-delete-recording" />
        <menuitem name="detail-recording" action="dvb-detail-recording" />
    </popup>
    </ui>
    '''

    def __init__ (self):
        totem.Plugin.__init__(self)
        
        self.totem_object = None
        self.channels = None
        self.channels_view = None
        self.scrolledchannels = None
        self.rec_iter = None
        self.recstore = None
        self.popup_menu = None
        self.popup_recordings = None
        self.timers_item = None
        self.epg_item = None
        self.manager = None

    def activate (self, totem_object):
        self.totem_object = totem_object
        
        self.channels = ChannelsTreeStore()
        
        self.channels_view = ChannelsView(self.channels, ChannelsTreeStore.COL_NAME)
        self.channels_view.connect("button-press-event", self._on_channel_selected)
        self.channels_view.get_selection().connect("changed", self._on_selection_changed)
        
        self.scrolledchannels = gtk.ScrolledWindow()
        self.scrolledchannels.set_policy(gtk.POLICY_AUTOMATIC, gtk.POLICY_AUTOMATIC)
        self.scrolledchannels.set_shadow_type(gtk.SHADOW_ETCHED_IN)
        self.scrolledchannels.add(self.channels_view)
        
        # Add recordings
        self.rec_iter = self.channels.append(None, [self.REC_GROUP_ID, _("Recordings"), 0, None])
        self.recstore = gnomedvb.DVBRecordingsStoreClient()
        self.recstore.connect("changed", self._on_recstore_changed)
        add_rec = lambda recs: [self._add_recording(rid) for rid in recs]
        self.recstore.get_recordings(reply_handler=add_rec, error_handler=global_error_handler)
        
        self.manager = DVBModel()
        
        uimanager = self.totem_object.get_ui_manager()
        
        # Create actions
        actiongroup = gtk.ActionGroup('dvb')
        actiongroup.add_actions([
            ('dvb-menu', None, _('_DVB')),
            ('dvb-setup', None, _('_Setup'), None, None, self._on_action_setup),
            ('dvb-timers', None, _('_Timers'), None, None, self._on_action_timers),
            ('dvb-epg', None, _('_Program Guide'), None, None, self._on_action_epg),
            ('dvb-preferences', gtk.STOCK_PREFERENCES, _('Preferences'), None, None, self._on_action_preferences),
            ('dvb-delete-recording', None, _('_Delete'), None, None, self._on_action_delete),
            ('dvb-detail-recording', None, _('D_etails'), None, None, self._on_action_details),
        ])
        uimanager.insert_action_group(actiongroup)
        
        uimanager.add_ui_from_string(self.MENU)
        uimanager.ensure_update()
 
        self.popup_menu = uimanager.get_widget('/dvb-popup')
        self.popup_recordings = uimanager.get_widget('/dvb-recording-popup')
        
        self.timers_item = uimanager.get_widget('/tmw-menubar/dvb/timers')
        self.epg_item = uimanager.get_widget('/tmw-menubar/dvb/program-guide')
        self.timers_item.set_sensitive(False)
        self.epg_item.set_sensitive(False)
        
        totem_object.add_sidebar_page ("dvb-daemon", _("DVB"), self.scrolledchannels)
        self.scrolledchannels.show_all()

    def _get_selected_group_and_channel(self):
        model, aiter = self.channels_view.get_selection().get_selected()
        if aiter == None:
            return None
        else:
            return (model[aiter][model.COL_GROUP], model[aiter][model.COL_SID],)
        
    def _on_action_setup(self, action):
        subprocess.Popen('gnome-dvb-setup')

    def _on_action_timers(self, action):
        group = self._get_selected_group_and_channel()[0]
        if group != None:
            edit = EditTimersDialog(group, self.totem_object.get_main_window())
            edit.run()
            edit.destroy()

    def _on_action_epg(self, action):
        group, sid = self._get_selected_group_and_channel()
        if group != None:
            dialog = ScheduleDialog(group, sid, self.totem_object.get_main_window())
            dialog.run()
            dialog.destroy()
    
    def _on_action_preferences(self, action):
        prefs = Preferences(self.manager, self.totem_object.get_main_window())
        prefs.run()
        prefs.destroy()
        
    def _on_action_delete(self, action):
        model, aiter = self.channels_view.get_selection().get_selected()
        if aiter != None:
            dialog = gtk.MessageDialog(parent=self.totem_object.get_main_window(),
                    flags=gtk.DIALOG_MODAL|gtk.DIALOG_DESTROY_WITH_PARENT,
                    type=gtk.MESSAGE_QUESTION, buttons=gtk.BUTTONS_YES_NO)
            dialog.set_markup("<big><span weight=\"bold\">%s</span></big>" % _("Delete selected recording?"))
            response = dialog.run()
            dialog.destroy()
            if response == gtk.RESPONSE_YES:
                self.recstore.delete(model[aiter][model.COL_SID],
                    reply_handler=self._delete_callback,
                    error_handler=global_error_handler)
        
    def _on_action_details(self, action):
        model, aiter = self.channels_view.get_selection().get_selected()
        if aiter != None:
            dialog = DetailsDialog(self.totem_object.get_main_window())
            sid = model[aiter][model.COL_SID]
            dialog.set_text(self.recstore.get_description(sid))
            dialog.set_channel(self.recstore.get_channel_name(sid))
            dialog.set_duration(str(self.recstore.get_length(sid) / 60))
            dialog.set_title(model[aiter][model.COL_NAME])
            dialog.run()
            dialog.destroy()
    
    def deactivate (self, totem_object):
        totem_object.remove_sidebar_page ("dvb-daemon")
        self.totem_object = None
        
    def _on_channel_selected(self, treeview, event):
        if event.type == gtk.gdk._2BUTTON_PRESS:
            # double click
            model, aiter = treeview.get_selection().get_selected()
            if aiter != None:
                group_id = model[aiter][model.COL_GROUP_ID]
                sid = model[aiter][model.COL_SID]
                if group_id == self.REC_GROUP_ID:
                    url = self.recstore.get_location(sid)
                else:
                    group = gnomedvb.DVBManagerClient().get_device_group(group_id)
                    channellist = group.get_channel_list()
                    url = channellist.get_channel_url(sid)
                self.totem_object.action_remote(totem.REMOTE_COMMAND_REPLACE, url)
                self.totem_object.action_remote(totem.REMOTE_COMMAND_PLAY, url)
        elif event.button == 3:
            # right click button
            x = int(event.x)
            y = int(event.y)
            time = event.time
            pthinfo = treeview.get_path_at_pos(x, y)
            if pthinfo != None:
                path, col, cellx, celly = pthinfo
                treeview.grab_focus()
                treeview.set_cursor(path, col, 0)
                model = treeview.get_model()
                aiter = model.get_iter(path)
                if model[aiter][model.COL_GROUP] == None:
                    # We are in the recordings section
                    if model.iter_parent(aiter) != None:
                        # A child is selected
                        self.popup_recordings.popup(None, None, None, event.button, time)
                else:
                    self.popup_menu.popup(None, None, None, event.button, time)
        
    def _on_selection_changed(self, treeselection):
        model, aiter = treeselection.get_selected()
        if aiter == None or model[aiter][model.COL_GROUP] == None:
            # Nothing selected or in recordings group
            self.timers_item.set_sensitive(False)
            self.epg_item.set_sensitive(False)
        else:
            self.timers_item.set_sensitive(True)
            self.epg_item.set_sensitive(True)
                
    def _add_recording(self, rid):
        name = self.recstore.get_name(rid)
        if name == "":
            name = _("Recording %d") % rid
        self.channels.append(self.rec_iter, [self.REC_GROUP_ID, name, rid, None])
                
    def _on_recstore_changed(self, recstore, rec_id, change_type):
        if change_type == 0:
            # Added
            self._add_recording(rec_id)
        elif change_type == 1:
            # Deleted
            child_iter = self.channels.iter_children(self.rec_iter)
            while child_iter != None:
                sid = self.channels[child_iter][self.channels.COL_SID]
                if sid == rec_id:
                    self.channels.remove(child_iter)
                    break
                child_iter = self.channels.iter_next(child_iter) 
                        
    def _delete_callback(self, success):
        if not success:
            global_error_handler("Could not delete recording")
       
