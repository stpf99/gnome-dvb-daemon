# -*- coding: utf-8 -*-
# Copyright (C) 2008-2011 Sebastian Pölsterl
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

import gettext
import gnomedvb
import gobject
import os
import os.path
import sys

from gi.repository import Gdk
from gi.repository import Gio
from gi.repository import Gtk
from gi.repository import Peas
from gi.repository import Totem
from cgi import escape
from gobject import GError

from gnomedvb import global_error_handler
from gnomedvb.DVBModel import DVBModel
from gnomedvb.ui.widgets.ChannelsStore import ChannelsTreeStore
from gnomedvb.ui.widgets.ChannelsView import ChannelsView
from gnomedvb.ui.widgets.SchedulePaned import SchedulePaned
from gnomedvb.ui.widgets.ScheduleStore import ScheduleStore
from gnomedvb.ui.widgets.RunningNextStore import RunningNextStore
from gnomedvb.ui.widgets.RunningNextView import RunningNextView
from gnomedvb.ui.preferences.Preferences import Preferences
from gnomedvb.ui.timers.EditTimersDialog import EditTimersDialog
from gnomedvb.ui.timers.MessageDialogs import TimerFailureDialog
from gnomedvb.ui.recordings.DetailsDialog import DetailsDialog

DBUS_DVB_SERVICE = "org.gnome.DVB"

def _(message):
    return gettext.dgettext('gnome-dvb-daemon', message)

def spawn_on_screen(argv, screen, flags=0):

    def set_environment (display):
        os.environ["DISPLAY"] = display

    return gobject.spawn_async(argv,
		      flags=flags,
		      child_setup=set_environment,
		      user_data=screen.make_display_name())

def _get_dbus_proxy():
    return Gio.DBusProxy.new_for_bus_sync(Gio.BusType.SESSION,
            Gio.DBusProxyFlags.NONE, None,
            "org.freedesktop.DBus",
            "/org/freedesktop/DBus",
            "org.freedesktop.DBus", None)

class DvbSetup:

    (MISSING,
	 STARTED_OK,
	 CRASHED,
	 FAILURE,
	 SUCCESS) = range(5)

    def __init__(self):
        self._in_progress = False

    def run(self, parent_window, callback=None, user_data=None):
        if self._dbus_service_available(DBUS_DVB_SERVICE):
            return self._start_setup(parent_window, callback, user_data)
        else:
            return self.MISSING

    def _start_setup(self, parent_window, callback, user_data):
        if self._in_progress:
            return self.FAILURE

        setup_cmd = self._find_program_in_path("gnome-dvb-setup")
        if setup_cmd == None:
            return self.MISSING

        screen = parent_window.get_screen()
        xid = parent_window.window.xid
        argv = [setup_cmd, "--transient-for=%d" % xid]

        pid = spawn_on_screen (argv, screen,
            flags=gobject.SpawnFlags.FILE_AND_ARGV_ZERO | gobject.SpawnFlags.DO_NOT_REAP_CHILD)[0]

        self._in_progress = True

        gobject.child_watch_add (pid, self._child_watch_func,
            (callback, user_data))

        return self.STARTED_OK

    def _child_watch_func(self, pid, status, data):
        func, user_data = data

        if not os.WIFEXITED(status):
            ret = TOTEM_DVB_SETUP_CRASHED
        else:
            ret = os.WEXITSTATUS (status)

        if func:
            if user_data:
	            func (ret, user_data)
            else:
                func (ret)

        self._in_progress = False

    def _find_program_in_path(self, file):
        path = os.environ.get("PATH", os.defpath)
        mode=os.F_OK | os.X_OK

        for dir in path.split(os.pathsep):
            full_path = os.path.join(dir, file)
            if os.path.exists(full_path) and os.access(full_path, mode):
                return full_path
        return None

    def _dbus_service_available(self, name):
	dbusobj = _get_dbus_proxy()

        for iname in dbusobj.ListNames():
            if iname == name:
                return True

        for iname in dbusobj.ListActivatableNames():
            if iname == name:
                return True

        return False


class ScheduleDialog(Gtk.Dialog):

    def __init__(self, group, sid, parent=None):
        Gtk.Dialog.__init__(self, title=_("Program Guide"),
            parent=parent,
            flags=Gtk.DialogFlags.DESTROY_WITH_PARENT,
            buttons=(Gtk.STOCK_CLOSE, Gtk.ResponseType.CLOSE))
            
        self._group = group
        self._sid = sid
            
        self.set_default_size(640, 380)
        content_area = self.get_content_area()
        content_area.set_spacing(6)
            
        self.schedulepaned = SchedulePaned()
        self.schedulepaned.show()
        content_area.pack_start(self.schedulepaned, True, True, 0)
        
        self.scheduleview = self.schedulepaned.get_treeview()
        self.scheduleview.connect("button-press-event", self._on_event_selected)
        
        self.schedulestore = ScheduleStore(group, sid)
        self.scheduleview.set_model(self.schedulestore)
    
    def _on_event_selected(self, treeview, event):
        if event.type == Gdk.EventType._2BUTTON_PRESS:
            model, aiter = treeview.get_selection().get_selected()
            if aiter != None:
                dialog = Gtk.MessageDialog(parent=self,
                    flags=Gtk.DialogFlags.MODAL | Gtk.DialogFlags.DESTROY_WITH_PARENT,
                    type=Gtk.MessageType.QUESTION, buttons=Gtk.ButtonsType.YES_NO)
                dialog.set_markup ("<big><span weight=\"bold\">%s</span></big>" % _("Schedule recording for the selected event?"))
                response = dialog.run()
                if response == Gtk.ResponseType.YES:
                    event_id = model[aiter][model.COL_EVENT_ID]
                    recorder = self._group.get_recorder()
                    rec_id, success = recorder.add_timer_for_epg_event(event_id, self._sid)
                dialog.destroy()
                
                if response == Gtk.ResponseType.YES and not success:
                    dialog = TimerFailureDialog(self)
                    dialog.run()
                    dialog.destroy()

class RunningNextDialog(Gtk.Dialog):

    def __init__(self, group, parent=None):
        Gtk.Dialog.__init__(self, title=_("Program Guide"),
            parent=parent,
            flags=Gtk.DialogFlags.DESTROY_WITH_PARENT,
            buttons=(Gtk.STOCK_CLOSE, Gtk.ResponseType.CLOSE))
            
        self._group = group
        
        self.set_default_size(640, 380)
        content_area = self.get_content_area()
        content_area.set_spacing(6)
        
        self.schedule = RunningNextStore(self._group)
        self.scheduleview = RunningNextView(self.schedule)
        self.scheduleview.show()
        
        self.scrolledschedule = Gtk.ScrolledWindow()
        self.scrolledschedule.add(self.scheduleview)
        self.scrolledschedule.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        self.scrolledschedule.set_shadow_type(Gtk.ShadowType.IN)
        content_area.pack_start(self.scrolledschedule, True, True, 0)
        self.scrolledschedule.show()


class DVBDaemonPlugin(gobject.GObject, Peas.Activatable):

    __gtype_name__ = 'DVBDaemonPlugin'

    object = gobject.property(type = gobject.GObject)

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
    
    (ORDER_BY_NAME_ID,
     ORDER_BY_GROUP_ID,) = range(2)

    def __init__ (self):
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
        self.setup = None
        self.sidebar = None
        self._size = 0
        self._loaded_groups = 0

    def do_activate (self):
        gettext.bindtextdomain('gnome-dvb-daemon')

        self.monitor_bus()

        try:
            self.construct()
        except Exception, e:
            print >> sys.stderr, "Failed activating DVB DBus service", str(e)
            return

    def monitor_bus(self):
        dbusobj = _get_dbus_proxy()
        dbusobj.connect("g-signal", self.on_dbus_signal)

    def on_dbus_signal(self, proxy, sender_name, signal_name, params):
        if signal_name == "NameOwnerChanged":
            name, old_owner, new_owner = params.unpack()
            if name == DBUS_DVB_SERVICE:
                if old_owner == "":
                    self.construct()
                elif new_owner == "":
                    self.deactivate()

    def construct(self):
        self.totem_object = self.object
        self.manager = DVBModel()

        self.setup = DvbSetup()
        
        self.manager.get_all_devices(lambda devs: self.enable_dvb_support(len(devs) > 0))

    def enable_dvb_support(self, val):
        if val:
            self._size = self.manager.get_device_group_size()

            self._setup_sidebar()
            self._setup_menu()

            self._get_and_add_recordings()
            
            self.totem_object.add_sidebar_page ("dvb-daemon", _("Digital TV"), self.sidebar)
            self.sidebar.show_all()

    def _get_and_add_recordings(self):
        # Add recordings
        self.rec_iter = self.channels.append(None)
        self.channels[self.rec_iter][ChannelsTreeStore.COL_GROUP_ID] = self.REC_GROUP_ID
        self.channels[self.rec_iter][ChannelsTreeStore.COL_NAME] = _("Recordings")

        self.recstore = gnomedvb.DVBRecordingsStoreClient()
        self.recstore.connect("changed", self._on_recstore_changed)
        add_rec = lambda p,recs,u: [self._add_recording(rid) for rid in recs]
        self.recstore.get_recordings(result_handler=add_rec, error_handler=global_error_handler)

    def _setup_sidebar(self):
        self.sidebar = Gtk.VBox(spacing=6)
        
        self.channels = ChannelsTreeStore()
        self.channels.connect("loading-finished", self._on_group_loaded)
        
        self.channels_view = ChannelsView(self.channels, ChannelsTreeStore.COL_NAME)
        self.channels_view.connect("button-press-event", self._on_channel_selected)
        self.channels_view.get_selection().connect("changed", self._on_selection_changed)
        
        self.scrolledchannels = Gtk.ScrolledWindow()
        self.scrolledchannels.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        self.scrolledchannels.set_shadow_type(Gtk.ShadowType.ETCHED_IN)
        self.scrolledchannels.add(self.channels_view)
        self.sidebar.pack_start(self.scrolledchannels, True, True, 0)
        
        buttonbox = Gtk.HButtonBox()
        buttonbox.set_spacing(6)
        self.sidebar.pack_start(buttonbox, False, True, 0)
        
        self.whatson_button = Gtk.Button(label=_("What's on now"))
        self.whatson_button.set_image(Gtk.Image.new_from_stock(Gtk.STOCK_INDEX, Gtk.IconSize.BUTTON))
        self.whatson_button.connect('clicked', self._on_action_whats_on_now)
        buttonbox.pack_start(self.whatson_button, True, True, 0)
        self.whatson_button.set_sensitive(False)
        
        self.epg_button = Gtk.Button(label=_('Program Guide'))
        self.epg_button.connect('clicked', self._on_action_epg)
        self.epg_button.set_sensitive(False)
        buttonbox.pack_start(self.epg_button, True, True, 0)
        
    def _setup_menu(self):
        uimanager = self.totem_object.get_ui_manager()
        
        # Create actions
        actiongroup = Gtk.ActionGroup('dvb')
        actiongroup.add_actions([
            ('dvbdevice', None, _('Watch TV'), None, None, self._on_play_dvb_activated),
            ('dvb-menu', None, _('Digital _TV')),
            ('dvb-timers', None, _('_Recording schedule'), None, None, self._on_action_timers),
            ('dvb-epg', None, _('_Program Guide'), None, None, self._on_action_epg),
            ('dvb-whatson', Gtk.STOCK_INDEX, _("What's on now"), None, None, self._on_action_whats_on_now),
            ('dvb-preferences', Gtk.STOCK_PREFERENCES, _('Digital TV Preferences'), None, None, self._on_action_preferences),
            ('dvb-delete-recording', None, _('_Delete'), None, None, self._on_action_delete),
            ('dvb-detail-recording', None, _('D_etails'), None, None, self._on_action_details),
            ('dvb-order-channels', None, _('_Order channels')),
        ])
        actiongroup.add_radio_actions([
            ('dvb-order-by-name', None, _('By _name'), None, None, self.ORDER_BY_NAME_ID),
            ('dvb-order-by-group', None, _('By _group'), None, None, self.ORDER_BY_GROUP_ID),
        ], 0, self._on_order_by_changed)
        actiongroup.add_toggle_actions([
            ('dvb-order-reverse', None, _('_Reverse order'), None, None,
             self._on_order_reverse_toggled)
        ])
        uimanager.insert_action_group(actiongroup)
        
        uimanager.add_ui_from_string(self.MENU)
        uimanager.ensure_update()

        # Movie menu
        merge_id = uimanager.new_merge_id()
        uimanager.add_ui(merge_id, '/tmw-menubar/movie/devices-placeholder',
            'dvbdevice', 'dvbdevice', Gtk.UIManagerItemType.MENUITEM, False)

        # Edit menu
        merge_id = uimanager.new_merge_id()
        uimanager.add_ui(merge_id, '/tmw-menubar/edit/plugins', 'dvb-timers', 'dvb-timers',
            Gtk.UIManagerItemType.AUTO, True)
        
        merge_id = uimanager.new_merge_id()
        uimanager.add_ui(merge_id, '/tmw-menubar/edit/plugins', 'dvb-preferences', 'dvb-preferences',
            Gtk.UIManagerItemType.AUTO, True)
            
        merge_id = uimanager.new_merge_id()
        uimanager.add_ui(merge_id, '/tmw-menubar/edit/plugins', 'dvb-sep-1', None,
            Gtk.UIManagerItemType.AUTO, True)
        
        # View menu
        merge_id = uimanager.new_merge_id()
        uimanager.add_ui(merge_id, '/tmw-menubar/view/sidebar', 'dvb-whatson', 'dvb-whatson',
            Gtk.UIManagerItemType.AUTO, True)
        
        merge_id = uimanager.new_merge_id()
        uimanager.add_ui(merge_id, '/tmw-menubar/view/sidebar', 'dvb-epg', 'dvb-epg',
            Gtk.UIManagerItemType.AUTO, True)
        
        merge_id = uimanager.new_merge_id()
        uimanager.add_ui(merge_id, '/tmw-menubar/view/sidebar', 'dvb-sep-2', None,
            Gtk.UIManagerItemType.AUTO, True)

        # Order by menu
        merge_id = uimanager.new_merge_id()
        uimanager.add_ui(merge_id, '/tmw-menubar/view/show-controls', 'dvb-order-channels',
            'dvb-order-channels', Gtk.UIManagerItemType.MENU, False)
            
        merge_id = uimanager.new_merge_id()
        uimanager.add_ui(merge_id, '/tmw-menubar/view/dvb-order-channels',
            'dvb-order-by-name', 'dvb-order-by-name', Gtk.UIManagerItemType.AUTO, False)
            
        merge_id = uimanager.new_merge_id()
        uimanager.add_ui(merge_id, '/tmw-menubar/view/dvb-order-channels',
            'dvb-order-by-group', 'dvb-order-by-group', Gtk.UIManagerItemType.AUTO, False)
        
        merge_id = uimanager.new_merge_id()
        uimanager.add_ui(merge_id, '/tmw-menubar/view/dvb-order-channels', 'dvb-sep-3', None,
            Gtk.UIManagerItemType.AUTO, False)
            
        merge_id = uimanager.new_merge_id()
        uimanager.add_ui(merge_id, '/tmw-menubar/view/dvb-order-channels',
            'dvb-order-reverse', 'dvb-order-reverse', Gtk.UIManagerItemType.AUTO, False)
        
        merge_id = uimanager.new_merge_id()
        uimanager.add_ui(merge_id, '/tmw-menubar/view/show-controls', 'dvb-sep-4', None,
            Gtk.UIManagerItemType.AUTO, False)
        
        self.popup_menu = uimanager.get_widget('/dvb-popup')
        self.popup_recordings = uimanager.get_widget('/dvb-recording-popup')

        totemtv_image = Gtk.Image.new_from_icon_name("totem-tv", Gtk.IconSize.MENU)
        totemtv_image.show()

        watch_item = uimanager.get_widget('/tmw-menubar/movie/devices-placeholder/dvbdevice')
        watch_item.set_image(totemtv_image)
        
        timers_image = Gtk.Image.new_from_icon_name("stock_timer", Gtk.IconSize.MENU)
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
            root_iter = self.channels.get_iter_first()
            group_iter = self.channels.iter_next(root_iter)
            self.single_group = self.channels[group_iter][self.channels.COL_GROUP]
            self._enable_single_group_mode(True)
        
        # Monitor if channels are added (don't monitor it when channels are added when loading)
        self.channels.connect('row-deleted', self._on_channels_row_inserted_deleted)
        self.channels.connect('row-inserted', self._on_channels_row_inserted_deleted)
            
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

    def _on_action_timers(self, action, user_date=None):
        group = self._get_selected_group_and_channel()[0]
        if group == None:
            group = self.single_group
        if group != None:
            edit = EditTimersDialog(group, self.totem_object.get_main_window())
            edit.run()
            edit.destroy()

    def _on_action_epg(self, action, user_date=None):
        group, sid = self._get_selected_group_and_channel()
        if group == None:
            group = self.single_group
        if group != None:
            if sid != 0:
                dialog = ScheduleDialog(group, sid, self.totem_object.get_main_window())
            else:
                dialog = RunningNextDialog(group, self.totem_object.get_main_window())
            dialog.connect("response", lambda d, resp: d.destroy())
            dialog.show()
            
    def _on_action_whats_on_now(self, action, user_date=None):
        group, sid = self._get_selected_group_and_channel()
        if group == None:
            group = self.single_group
        if group != None:
            dialog = RunningNextDialog(group, self.totem_object.get_main_window())
            dialog.connect("response", lambda d, resp: d.destroy())
            dialog.show()
    
    def _on_action_preferences(self, action, user_date=None):
        prefs = Preferences(self.manager, self.totem_object.get_main_window())
        prefs.show()
        
    def _on_action_delete(self, action, user_date=None):
        model, aiter = self.channels_view.get_selection().get_selected()
        if aiter != None:
            dialog = Gtk.MessageDialog(parent=self.totem_object.get_main_window(),
                    flags=Gtk.DialogFlags.MODAL|Gtk.DialogFlags.DESTROY_WITH_PARENT,
                    type=Gtk.MessageType.QUESTION, buttons=Gtk.ButtonsType.YES_NO)
            dialog.set_markup("<big><span weight=\"bold\">%s</span></big>" % _("Delete selected recording?"))
            response = dialog.run()
            dialog.destroy()
            if response == Gtk.ResponseType.YES:
                self.recstore.delete(model[aiter][model.COL_SID],
                    result_handler=self._delete_callback,
                    error_handler=global_error_handler)
        
    def _on_action_details(self, action, user_date=None):
        model, aiter = self.channels_view.get_selection().get_selected()
        if aiter != None:
            rec_id = model[aiter][model.COL_SID]
            dialog = DetailsDialog(rec_id, self.totem_object.get_main_window())
            dialog.run()
            dialog.destroy()
    
    def do_deactivate (self):
        if self.totem_object != None:
            self.totem_object.remove_sidebar_page ("dvb-daemon")
        
    def _on_channel_selected(self, treeview, event):
        if event.type == Gdk.EventType._2BUTTON_PRESS:
            # double click
            model, aiter = treeview.get_selection().get_selected()
            if aiter != None:
                group_id = model[aiter][model.COL_GROUP_ID]
                sid = model[aiter][model.COL_SID]
                # Skip section headers
                if sid == 0L:
                    return

                if group_id == self.REC_GROUP_ID:
                    url, success = self.recstore.get_location(sid)
                else:
                    group = gnomedvb.DVBManagerClient().get_device_group(group_id)
                    channellist = group.get_channel_list()
                    url, success = channellist.get_channel_url(sid)
                self.totem_object.action_remote(Totem.RemoteCommand.REPLACE, url)
                self.totem_object.action_remote(Totem.RemoteCommand.PLAY, url)
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
                        self.popup_recordings.popup(None, None, None, None, event.button, time)
                else:
                    self.popup_menu.popup(None, None, None, None, event.button, time)
        
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
        aiter = self.channels.append(self.rec_iter)
        self.channels[aiter][ChannelsTreeStore.COL_GROUP_ID] = self.REC_GROUP_ID
        self.channels[aiter][ChannelsTreeStore.COL_NAME] = name
        self.channels[aiter][ChannelsTreeStore.COL_SID] = rid

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
        if path.get_depth() == 1:
            # One entry is for recordings
            val = len(treestore) == 2
            self._enable_single_group_mode(val)

    def _on_group_loaded(self, treestore, group_id):
        self._loaded_groups += 1
        if self._loaded_groups == self._size:
            self._configure_mode()
                        
    def _delete_callback(self, proxy, success, user_data):
        if not success:
            global_error_handler("Could not delete recording")
            
    def _on_order_by_changed(self, action, current, user_date=None):
        val = current.get_current_value()
        sort_order = self.channels.get_sort_column_id()[1]
        if val == self.ORDER_BY_NAME_ID:
            self.channels = ChannelsTreeStore(False)
        elif val == self.ORDER_BY_GROUP_ID:
            self.channels = ChannelsTreeStore(True)
        self.channels.set_sort_order(sort_order)
        self._get_and_add_recordings()
        self.channels_view.set_model(self.channels)
        
    def _on_order_reverse_toggled(self, action, user_date=None):
        if action.get_active():
            self.channels.set_sort_order(Gtk.SortType.DESCENDING)
        else:
            self.channels.set_sort_order(Gtk.SortType.ASCENDING)

    def _on_play_dvb_activated(self, action, user_date=None):
        main_window = self.totem_object.get_main_window()
        # Only run setup if no devices are configured, yet
        if self._size == 0:
            status = self.setup.run (main_window, self._on_setup_dvb_finished)
            if status == DvbSetup.MISSING:
                self.totem_object.action_error(_("Setup Failed"),
                    _("GNOME DVB Daemon is not installed"))

            print "DVB SETUP STARTED", status

        # TODO select dvb-daemon page from totem sidebar

    def _on_setup_dvb_finished(self, status):
        print "DVB SETUP FINISHED", status

