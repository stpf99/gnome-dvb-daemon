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
from cgi import escape

from gnomedvb import global_error_handler
from gnomedvb.DVBModel import DVBModel
from gnomedvb.ui.widgets.ChannelsStore import ChannelsTreeStore
from gnomedvb.ui.widgets.ChannelsView import ChannelsView
from gnomedvb.ui.widgets.ScheduleStore import ScheduleStore
from gnomedvb.ui.widgets.ScheduleView import ScheduleView
from gnomedvb.ui.widgets.RunningNextStore import RunningNextStore
from gnomedvb.ui.widgets.RunningNextView import RunningNextView
from gnomedvb.ui.preferences.Preferences import Preferences
from gnomedvb.ui.timers.EditTimersDialog import EditTimersDialog
from gnomedvb.ui.timers.TimerDialog import NoTimerCreatedDialog
from gnomedvb.ui.recordings.DetailsDialog import DetailsDialog

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
                response = dialog.run()
                if response == gtk.RESPONSE_YES:
                    event_id = model[aiter][model.COL_EVENT_ID]
                    recorder = self._group.get_recorder()
                    rec_id, success = recorder.add_timer_for_epg_event(event_id, self._sid)
                dialog.destroy()
                
                if response == gtk.RESPONSE_YES and not success:
                    dialog = NoTimerCreatedDialog(self)
                    dialog.run()
                    dialog.destroy()

class RunningNextDialog(gtk.Dialog):

    def __init__(self, group, parent=None):
        gtk.Dialog.__init__(self, title=_("Program Guide"),
            parent=parent,
            flags=gtk.DIALOG_DESTROY_WITH_PARENT,
            buttons=(gtk.STOCK_CLOSE, gtk.RESPONSE_CLOSE))
            
        self._group = group
        
        self.set_default_size(640, 380)
        self.vbox.set_spacing(6)
        
        self.schedule = RunningNextStore(self._group)
        self.scheduleview = RunningNextView(self.schedule)
        self.scheduleview.show()
        
        self.scrolledschedule = gtk.ScrolledWindow()
        self.scrolledschedule.add(self.scheduleview)
        self.scrolledschedule.set_policy(gtk.POLICY_AUTOMATIC, gtk.POLICY_AUTOMATIC)
        self.scrolledschedule.set_shadow_type(gtk.SHADOW_IN)
        self.vbox.pack_start(self.scrolledschedule)
        self.scrolledschedule.show()


class DVBDaemonPlugin(totem.Plugin):

    REC_GROUP_ID = -1
    
    MENU = '''<ui>
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
        self.whatson_item = None
        self.manager = None
        self.single_group = None
        self.sidebar = None

    def activate (self, totem_object):
        self.totem_object = totem_object
        
        self.manager = DVBModel()
        self._size = self.manager.get_device_group_size()
        self._loaded_groups = 0
        
        self._setup_sidebar()
        self._setup_menu()
        
        # Add recordings
        self.rec_iter = self.channels.append(None, [self.REC_GROUP_ID, _("Recordings"), 0, None])
        self.recstore = gnomedvb.DVBRecordingsStoreClient()
        self.recstore.connect("changed", self._on_recstore_changed)
        add_rec = lambda recs: [self._add_recording(rid) for rid in recs]
        self.recstore.get_recordings(reply_handler=add_rec, error_handler=global_error_handler)
        
        totem_object.add_sidebar_page ("dvb-daemon", _("Digital TV"), self.sidebar)
        self.sidebar.show_all()

        if self._size == 0:
            self._show_configure_dialog()  
        
    def _setup_sidebar(self):
        self.sidebar = gtk.VBox(spacing=6)
        
        self.channels = ChannelsTreeStore()
        self.channels.connect("loading-finished", self._on_group_loaded)
        
        self.channels_view = ChannelsView(self.channels, ChannelsTreeStore.COL_NAME)
        self.channels_view.connect("button-press-event", self._on_channel_selected)
        self.channels_view.get_selection().connect("changed", self._on_selection_changed)
        
        self.scrolledchannels = gtk.ScrolledWindow()
        self.scrolledchannels.set_policy(gtk.POLICY_AUTOMATIC, gtk.POLICY_AUTOMATIC)
        self.scrolledchannels.set_shadow_type(gtk.SHADOW_ETCHED_IN)
        self.scrolledchannels.add(self.channels_view)
        self.sidebar.pack_start(self.scrolledchannels)
        
        buttonbox = gtk.HButtonBox()
        buttonbox.set_spacing(6)
        self.sidebar.pack_start(buttonbox, False)
        
        self.whatson_button = gtk.Button(label=_("What's on now"))
        self.whatson_button.set_image(gtk.image_new_from_stock(gtk.STOCK_INDEX, gtk.ICON_SIZE_BUTTON))
        self.whatson_button.connect('clicked', self._on_action_whats_on_now)
        buttonbox.pack_start(self.whatson_button)
        self.whatson_button.set_sensitive(False)
        
        self.epg_button = gtk.Button(label=_('Program Guide'))
        self.epg_button.connect('clicked', self._on_action_epg)
        self.epg_button.set_sensitive(False)
        buttonbox.pack_start(self.epg_button)
        
    def _setup_menu(self):
        uimanager = self.totem_object.get_ui_manager()
        
        # Create actions
        actiongroup = gtk.ActionGroup('dvb')
        actiongroup.add_actions([
            ('dvb-menu', None, _('Digital _TV')),
            ('dvb-timers', None, _('_Recording schedule'), None, None, self._on_action_timers),
            ('dvb-epg', None, _('_Program Guide'), None, None, self._on_action_epg),
            ('dvb-whatson', gtk.STOCK_INDEX, _("What's on now"), None, None, self._on_action_whats_on_now),
            ('dvb-preferences', gtk.STOCK_PREFERENCES, _('Digital TV Preferences'), None, None, self._on_action_preferences),
            ('dvb-delete-recording', None, _('_Delete'), None, None, self._on_action_delete),
            ('dvb-detail-recording', None, _('D_etails'), None, None, self._on_action_details),
        ])
        uimanager.insert_action_group(actiongroup)
        
        uimanager.add_ui_from_string(self.MENU)
        uimanager.ensure_update()
        
        # Edit menu
        merge_id = uimanager.new_merge_id()
        uimanager.add_ui(merge_id, '/tmw-menubar/edit/plugins', 'dvb-timers', 'dvb-timers',
            gtk.UI_MANAGER_AUTO, True)
        
        merge_id = uimanager.new_merge_id()
        uimanager.add_ui(merge_id, '/tmw-menubar/edit/plugins', 'dvb-preferences', 'dvb-preferences',
            gtk.UI_MANAGER_AUTO, True)
            
        merge_id = uimanager.new_merge_id()
        uimanager.add_ui(merge_id, '/tmw-menubar/edit/plugins', 'dvb-sep-1', None,
            gtk.UI_MANAGER_AUTO, True)
        
        # View menu
        merge_id = uimanager.new_merge_id()
        uimanager.add_ui(merge_id, '/tmw-menubar/view/sidebar', 'dvb-whatson', 'dvb-whatson',
            gtk.UI_MANAGER_AUTO, True)
        
        merge_id = uimanager.new_merge_id()
        uimanager.add_ui(merge_id, '/tmw-menubar/view/sidebar', 'dvb-epg', 'dvb-epg',
            gtk.UI_MANAGER_AUTO, True)
        
        merge_id = uimanager.new_merge_id()
        uimanager.add_ui(merge_id, '/tmw-menubar/view/sidebar', 'dvb-sep-2', None,
            gtk.UI_MANAGER_AUTO, True)
        
        self.popup_menu = uimanager.get_widget('/dvb-popup')
        self.popup_recordings = uimanager.get_widget('/dvb-recording-popup')
        
        icon_theme = gtk.icon_theme_get_default()
        
        pixbuf = icon_theme.load_icon("stock_timer", gtk.ICON_SIZE_MENU, gtk.ICON_LOOKUP_USE_BUILTIN)
        timers_image = gtk.image_new_from_pixbuf(pixbuf)
        timers_image.show()
        
        self.timers_item = uimanager.get_widget('/tmw-menubar/edit/dvb-timers')
        self.timers_item.set_image(timers_image)
        
        self.epg_item = uimanager.get_widget('/tmw-menubar/view/dvb-epg')
        self.timers_item.set_sensitive(False)
        self.epg_item.set_sensitive(False)
        
        self.whatson_item = uimanager.get_widget('/tmw-menubar/view/dvb-whatson')
        self.whatson_item.set_sensitive(False)

    def _configure_mode(self):
        if self._size == 1:
            # Activate single group mode
            root_iter = self.channels.get_iter_root()
            group_iter = self.channels.iter_next(root_iter)
            self.single_group = self.channels[group_iter][self.channels.COL_GROUP]
            self._enable_single_group_mode(True)
        
        # Monitor if channels are added (don't monitor it when channels are added when loading)
        self.channels.connect('row-deleted', self._on_channels_row_inserted_deleted)
        self.channels.connect('row-inserted', self._on_channels_row_inserted_deleted)

    def _show_configure_dialog(self):
        dialog = gtk.MessageDialog(parent=self.totem_object.get_main_window(),
            flags=gtk.DIALOG_MODAL|gtk.DIALOG_DESTROY_WITH_PARENT,
            type=gtk.MESSAGE_QUESTION, buttons=gtk.BUTTONS_YES_NO)
        dialog.set_markup (
            "<big><span weight=\"bold\">%s</span></big>" % _("DVB card is not configured"))
        dialog.format_secondary_text(_("Do you want to search for channels now?"))
        response = dialog.run()
        if response == gtk.RESPONSE_YES:
            self._on_action_setup(None)
        dialog.destroy()
            
    def _enable_single_group_mode(self, val):
        self.timers_item.set_sensitive(val)
        self.whatson_item.set_sensitive(val)
        self.whatson_button.set_sensitive(val)
        if not val:
            self.single_group = None

    def _get_selected_group_and_channel(self):
        model, aiter = self.channels_view.get_selection().get_selected()
        if aiter == None:
            return (None, 0)
        else:
            return (model[aiter][model.COL_GROUP], model[aiter][model.COL_SID],)
        
    def _on_action_setup(self, action):
        main_window = self.totem_object.get_main_window()
        xid = main_window.window.xid
        subprocess.Popen(["gnome-dvb-setup", "--transient-for=%d" % xid])

    def _on_action_timers(self, action):
        group = self._get_selected_group_and_channel()[0]
        if group == None:
            group = self.single_group
        if group != None:
            edit = EditTimersDialog(group, self.totem_object.get_main_window())
            edit.run()
            edit.destroy()

    def _on_action_epg(self, action):
        group, sid = self._get_selected_group_and_channel()
        if group == None:
            group = self.single_group
        if group != None:
            if sid != 0:
                dialog = ScheduleDialog(group, sid, self.totem_object.get_main_window())
            else:
                dialog = RunningNextDialog(group, self.totem_object.get_main_window())
            dialog.run()
            dialog.destroy()
            
    def _on_action_whats_on_now(self, action):
        group, sid = self._get_selected_group_and_channel()
        if group == None:
            group = self.single_group
        if group != None:
            dialog = RunningNextDialog(group, self.totem_object.get_main_window())
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
            rec_id = model[aiter][model.COL_SID]
            dialog = DetailsDialog(rec_id, self.totem_object.get_main_window())
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
                    url, success = self.recstore.get_location(sid)
                else:
                    group = gnomedvb.DVBManagerClient().get_device_group(group_id)
                    channellist = group.get_channel_list()
                    url, success = channellist.get_channel_url(sid)
                self.totem_object.action_remote(totem.REMOTE_COMMAND_REPLACE, url)
                self.totem_object.action_remote(totem.REMOTE_COMMAND_PLAY, url)
                # Totem adds the URL to recent manager, remove it again
                recentmanager = gtk.recent_manager_get_default()
                recentmanager.remove_item (url)
                recentmanager.add_full (url,
                    {"display_name": model[aiter][model.COL_NAME],
                     "app_name": _("Totem Movie Player"),
                     "app_exec": "totem %u",
                     "mime_type": "video",
                     "groups": ("Totem", "gnome-dvb-daemon",)})
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
            if self.single_group == None:
                self._enable_single_group_mode(False)
            self.epg_item.set_sensitive(False)
            self.epg_button.set_sensitive(False)
        else:
            if self.single_group == None:
                self._enable_single_group_mode(True)
            # Check if a channel is selected
            epg_status = model[aiter][model.COL_SID] != 0
            self.epg_item.set_sensitive(epg_status)
            self.epg_button.set_sensitive(epg_status)
                
    def _add_recording(self, rid):
        name, success = self.recstore.get_name(rid)
        if name == "":
            name = _("Recording %d") % rid
        else:
            name = escape(name)
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
                
    def _on_channels_row_inserted_deleted(self, treestore, path, aiter=None):
        if len(path) == 1:
            # One entry is for recordings
            val = len(treestore) == 2
            self._enable_single_group_mode(val)

    def _on_group_loaded(self, treestore, group_id):
        self._loaded_groups += 1
        if self._loaded_groups == self._size:
            self._configure_mode()
                        
    def _delete_callback(self, success):
        if not success:
            global_error_handler("Could not delete recording")
       
