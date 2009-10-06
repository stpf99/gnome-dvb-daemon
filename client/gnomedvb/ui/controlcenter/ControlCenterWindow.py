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

import gtk
import gobject
from gettext import gettext as _
import gnomedvb
from gnomedvb.ui.widgets.ChannelsStore import ChannelsStore
from gnomedvb.ui.widgets.ChannelsView import ChannelsView
from gnomedvb.ui.widgets.DetailsDialog import DetailsDialog
from gnomedvb.ui.widgets.RunningNextStore import RunningNextStore
from gnomedvb.ui.widgets.RunningNextView import RunningNextView
from gnomedvb.ui.widgets.SchedulePaned import SchedulePaned
from gnomedvb.ui.widgets.ScheduleStore import ScheduleStore
from gnomedvb.ui.widgets.HelpBox import HelpBox
from gnomedvb.ui.channellisteditor.ChannelListEditorDialog import ChannelListEditorDialog
from gnomedvb.ui.timers.EditTimersDialog import EditTimersDialog
from gnomedvb.ui.timers.TimerDialog import NoTimerCreatedDialog
from gnomedvb.ui.preferences.Preferences import Preferences
from gnomedvb.ui.recordings.RecordingsDialog import RecordingsDialog
   
class ControlCenterWindow(gtk.Window):

    def __init__(self, model):
        gtk.Window.__init__(self)
        
        self.runningnextstore = None
        self.scrolledrunningnext = None
        self.runningnextview = None
        
        self.channellists = {}
        self.manager = model
        self.manager.connect('group-added', self._on_manager_group_added)
        self.manager.connect('group-removed', self._on_manager_group_removed)
        
        self.connect('delete-event', gtk.main_quit)
        self.connect('destroy-event', gtk.main_quit)
        self.set_title(_("DVB Control Center"))
        self.set_default_size(800, 500)
        
        self.vbox_outer = gtk.VBox()
        self.vbox_outer.show()
        self.add(self.vbox_outer)
        
        self.toolbar = None
        self.vbox_left  = None
        self.__create_menu()
        self.__create_toolbar()
        
        self.hbox = gtk.HBox(spacing=6)
        self.vbox_outer.pack_start(self.hbox)
        
        self.hpaned = gtk.HPaned()
        self.hpaned.set_border_width(3)
        self.hpaned.set_position(175)
        self.hbox.pack_start(self.hpaned)
        
        self.vbox_left = gtk.VBox(spacing=6)
        self.hpaned.pack1(self.vbox_left)
        
        groups_label = gtk.Label(_("Device groups:"))
        self.vbox_left.pack_start(groups_label, False)
        
        self.devgroupslist = gtk.ListStore(str, int, gobject.TYPE_PYOBJECT)
        self.devgroupslist.connect("row-inserted", self._on_devgroupslist_inserted)
        
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
        scrolledchannels.set_shadow_type(gtk.SHADOW_IN)
        self.vbox_left.pack_start(scrolledchannels)
        
        self.schedulestore = None
                
        self.help_eventbox = HelpBox()
        self.choose_group_text = _("Choose a device group and channel on the left to view the program guide")
        self.create_group_text = _("No devices are configured. Please go to preferences to configure them.")
        self.no_events_text = _("There is currently no schedule available for this channel")
        self.hpaned.pack2(self.help_eventbox)
        
        self.schedulepaned = SchedulePaned()
        self.schedulepaned.show()
        self.scheduleview = self.schedulepaned.get_treeview()
        self.scheduleview.connect("button-press-event", self._on_event_selected)
        
        self.get_device_groups()
        if len(self.devgroupslist) == 0:
            self.help_eventbox.set_markup(self.create_group_text)
        else:
            self._select_first_group()
      
    def __create_menu(self):
        ui = '''
        <menubar name="MenuBar">
          <menu action="Timers">
            <menuitem action="EditTimers"/>
            <menuitem action="Recordings"/>
            <separator/>
            <menuitem action="Quit"/>
          </menu>
          <menu action="Edit">
            <menuitem action="EditChannelLists"/>
            <separator/>
            <menuitem action="Preferences"/>
          </menu>
          <menu action="View">
            <menuitem action="WhatsOnNow"/>
            <menuitem action="Refresh"/>
            <menuitem action="PrevDay"/>
            <menuitem action="NextDay"/>
            <separator/>
            <menuitem action="Channels"/>
            <menuitem action="Toolbar"/>
          </menu>
          <menu action="Help">
            <menuitem action="About"/>
          </menu>
        </menubar>'''

        uimanager = gtk.UIManager()
        
        # Add the accelerator group to the toplevel window
        accelgroup = uimanager.get_accel_group()
        self.add_accel_group(accelgroup)
        
        # Create actions
        actiongroup = gtk.ActionGroup('Root')
        actiongroup.add_actions([
            ('Timers', None, _('_Recording schedule')),
            ('Edit', None, _('_Edit')),
            ('View', None, _('_View')),
            ('Help', None, _('Help')),
        ])
        # Add the actiongroup to the uimanager
        uimanager.insert_action_group(actiongroup, 0)
        
        actiongroup = gtk.ActionGroup('Timers')
        actiongroup.add_actions([
            ('EditTimers', None, _('_Manage'), None,
             _('Manage recording schedule'), self._on_button_display_timers_clicked),
            ('Recordings', None, _('_Recordings'), None,
             _('Manage recordings'), self._on_button_recordings_clicked),
            ('Quit', gtk.STOCK_QUIT, _('_Quit'), None,
             _('Quit the Program'), gtk.main_quit)])
        uimanager.insert_action_group(actiongroup, 1)
        
        actiongroup = gtk.ActionGroup('Edit')
        actiongroup.add_actions([
            ('EditChannelLists', None, _('Channel lists'), None,
             _('Edit channel lists'), self._on_edit_channellists_clicked),
            ('Preferences', gtk.STOCK_PREFERENCES, _('_Preferences'), None,
             _('Display preferences'), self._on_button_prefs_clicked),
        ])
        uimanager.insert_action_group(actiongroup, 2)
        
        actiongroup = gtk.ActionGroup('View')
        actiongroup.add_actions([
            ('WhatsOnNow', None, _("What's on now"), None,
             _("See what's currently on and is coming next"), self._on_whats_on_now_clicked),
            ('Refresh', gtk.STOCK_REFRESH, _('Refresh'), None,
             _('Refresh program guide'), self._on_refresh_clicked),
            ('PrevDay', None, _('Previous Day'), '<Control>B',
             _('Go to previous day'), self._on_button_prev_day_clicked),
            ('NextDay', None, _('Next Day'), '<Control>N',
             _('Go to next day'), self._on_button_next_day_clicked),
        ])
        actiongroup.add_toggle_actions([
            ('Channels', None, _('Channels'), None,
             _('View/Hide channels'), self._on_view_channels_clicked),
            ('Toolbar', None, _('Toolbar'), None,
             _('View/Hide toolbar'), self._on_view_toolbar_clicked),
        ])
        action = actiongroup.get_action('Toolbar')
        action.set_active(True)
        action = actiongroup.get_action('Channels')
        action.set_active(True)
        uimanager.insert_action_group(actiongroup, 3)
        
        actiongroup = gtk.ActionGroup('Help')
        actiongroup.add_actions([
            ('About', gtk.STOCK_ABOUT, _('_About'), None,
             _('Display informations about the program'),
             self._on_about_clicked),
        ])
        uimanager.insert_action_group(actiongroup, 4)

        # Add a UI description
        uimanager.add_ui_from_string(ui)
        
        icon_theme = gtk.icon_theme_get_default()
        
        pixbuf = icon_theme.load_icon("stock_timer", gtk.ICON_SIZE_MENU, gtk.ICON_LOOKUP_USE_BUILTIN)
        timers_image = gtk.image_new_from_pixbuf(pixbuf)
        timers_image.show()
        
        self.timersitem = uimanager.get_widget('/MenuBar/Timers/EditTimers')
        self.timersitem.set_image(timers_image)
        self.timersitem.set_sensitive(False)
        
        pixbuf = icon_theme.load_icon("video", gtk.ICON_SIZE_MENU, gtk.ICON_LOOKUP_USE_BUILTIN)
        recordings_image = gtk.image_new_from_pixbuf(pixbuf)
        recordings_image.show()
        
        recordings = uimanager.get_widget('/MenuBar/Timers/Recordings')
        recordings.set_image(recordings_image)
        
        whatson_image = gtk.image_new_from_stock(gtk.STOCK_INDEX, gtk.ICON_SIZE_MENU)
        whatson_image.show()
        
        whatons_item = uimanager.get_widget('/MenuBar/View/WhatsOnNow')
        whatons_item.set_image(whatson_image)
        
        self.refresh_menuitem = uimanager.get_widget('/MenuBar/View/Refresh')
        self.refresh_menuitem.set_sensitive(False)
        
        self.prev_day_menuitem = uimanager.get_widget('/MenuBar/View/PrevDay')
        prev_image = gtk.image_new_from_stock(gtk.STOCK_GO_BACK, gtk.ICON_SIZE_MENU)
        prev_image.show()
        self.prev_day_menuitem.set_image(prev_image)
        self.prev_day_menuitem.set_sensitive(False)
        
        self.next_day_menuitem = uimanager.get_widget('/MenuBar/View/NextDay')
        next_image = gtk.image_new_from_stock(gtk.STOCK_GO_FORWARD, gtk.ICON_SIZE_MENU)
        next_image.show()
        self.next_day_menuitem.set_image(next_image)
        self.next_day_menuitem.set_sensitive(False)
        
        # Create a MenuBar
        menubar = uimanager.get_widget('/MenuBar')
        menubar.show()
        self.vbox_outer.pack_start(menubar, False)
        
    def __create_toolbar(self):
        self.toolbar = gtk.Toolbar()
        self.toolbar.show()
        self.vbox_outer.pack_start(self.toolbar, False)
        
        icon_theme = gtk.icon_theme_get_default()
        
        pixbuf = icon_theme.load_icon("stock_timer", gtk.ICON_SIZE_LARGE_TOOLBAR, gtk.ICON_LOOKUP_USE_BUILTIN)
        timers_image = gtk.image_new_from_pixbuf(pixbuf)
        timers_image.show()
        
        self.button_display_timers = gtk.ToolButton(icon_widget=timers_image, label=_("Recording schedule"))
        self.button_display_timers.set_is_important(True)
        self.button_display_timers.set_sensitive(False)
        self.button_display_timers.connect("clicked", self._on_button_display_timers_clicked)
        self.button_display_timers.set_tooltip_markup(_("Manage recording schedule"))
        self.button_display_timers.show()
        self.toolbar.insert(self.button_display_timers, 0)
        
        pixbuf = icon_theme.load_icon("video", gtk.ICON_SIZE_MENU, gtk.ICON_LOOKUP_USE_BUILTIN)
        recordings_image = gtk.image_new_from_pixbuf(pixbuf)
        recordings_image.show()
        
        button_recordings = gtk.ToolButton(icon_widget=recordings_image, label=_("Recordings"))
        button_recordings.set_is_important(True)
        button_recordings.connect("clicked", self._on_button_recordings_clicked)
        button_recordings.show()
        self.toolbar.insert(button_recordings, 1)
        
        whatson_image = gtk.image_new_from_stock(gtk.STOCK_INDEX, gtk.ICON_SIZE_LARGE_TOOLBAR)
        whatson_image.show()
        
        button_whatson = gtk.ToolButton(icon_widget=whatson_image, label=_("What's on now"))
        button_whatson.set_is_important(True)
        button_whatson.connect("clicked", self._on_whats_on_now_clicked)
        button_whatson.show()
        self.toolbar.insert(button_whatson, 2)
         
        sep = gtk.SeparatorToolItem()
        sep.show()
        self.toolbar.insert(sep, 3)
        
        self.refresh_button = gtk.ToolButton(gtk.STOCK_REFRESH)
        self.refresh_button.connect("clicked", self._on_refresh_clicked)
        self.refresh_button.set_tooltip_markup(_("Refresh program guide"))        
        self.refresh_button.show()
        self.toolbar.insert(self.refresh_button, 4)
        
        prev_image = gtk.image_new_from_stock(gtk.STOCK_GO_BACK, gtk.ICON_SIZE_LARGE_TOOLBAR)
        prev_image.show()
        self.button_prev_day = gtk.ToolButton(icon_widget=prev_image, label=_("Previous Day"))
        self.button_prev_day.connect("clicked", self._on_button_prev_day_clicked)
        self.button_prev_day.set_tooltip_markup(_("Go to previous day"))
        self.button_prev_day.set_sensitive(False)
        self.button_prev_day.show()
        self.toolbar.insert(self.button_prev_day, 5)
        
        next_image = gtk.image_new_from_stock(gtk.STOCK_GO_FORWARD, gtk.ICON_SIZE_LARGE_TOOLBAR)
        next_image.show()
        self.button_next_day = gtk.ToolButton(icon_widget=next_image, label=_("Next Day"))
        self.button_next_day.connect("clicked", self._on_button_next_day_clicked)
        self.button_next_day.set_tooltip_markup(_("Go to next day"))
        self.button_next_day.set_sensitive(False)
        self.button_next_day.show()
        self.toolbar.insert(self.button_next_day, 6)
        
    def get_device_groups(self):
        def append_groups(groups):
            for group in groups:
                self._append_group(group)
        self.manager.get_registered_device_groups(reply_handler=append_groups)
    
    def _select_first_group(self):
        self.devgroupscombo.set_active(0)
        self.channelsview.grab_focus()
           
    def _append_group(self, group):
        self.devgroupslist.append([group["name"], group["id"], group])
        self.channellists[group["id"]] = group.get_channel_list()
        
    def _remove_group(self, group_id):
        aiter = None
        for row in self.devgroupslist:
            if row[1] == group_id:
                aiter = row.iter
                
        if aiter != None:
            if self._get_selected_group()["id"] == group_id:
                # Select no group
                self.devgroupscombo.set_active(-1)
                
            self.devgroupslist.remove(aiter)
            del self.channellists[group_id]
            
    def _reset_ui(self):
        self.channelsstore = None
        self.channelsview.set_model(None)
        if len(self.devgroupslist) == 0:
            text = self.create_group_text
        else:
            text = self.choose_group_text
        self._display_help_message(text)
        self._set_timers_sensitive(False)
        
    def _reset_schedule_view(self):
        self.schedulestore = None
        self.scheduleview.set_model(None)
        self._display_running_next()

    def _on_manager_group_added(self, manager, group_id):
        group = self.manager.get_device_group(group_id)
        if group:
            self._append_group(group)
        
    def _on_manager_group_removed(self, manager, group_id):
        self._remove_group(group_id)
            
    def _get_selected_group(self):
        aiter = self.devgroupscombo.get_active_iter()
        if aiter == None:
            return None
        else:
            return self.devgroupslist[aiter][2]
        
    def _get_selected_channel_sid(self):
        model, aiter = self.channelsview.get_selection().get_selected()
        if aiter != None:
            sid = model[aiter][model.COL_SID]
            return sid
        else:
            return None
    
    def _on_devgroupscombo_changed(self, combo):
        group = self._get_selected_group()
        if group != None:
            self._set_timers_sensitive(True)
            
            self.channelsstore = ChannelsStore(group)
            self.channelsview.set_model(self.channelsstore)
            
            self._reset_schedule_view()
        else:
            self._reset_ui()
            
    def _on_devgroupslist_inserted(self, model, path, aiter):
        if len(model) == 1:
            # Delay the call otherwise we get DBus errors
            gobject.timeout_add(100, self._select_first_group)
    
    def _on_channel_selected(self, treeselection):
        model, aiter = treeselection.get_selected()
        child = self.hpaned.get_child2()
        if aiter != None:
            sid = model[aiter][model.COL_SID]
            group = self._get_selected_group()
            self.schedulestore = ScheduleStore(group, sid)
            self.schedulestore.connect("loading-finished",
                self._on_schedule_loading_finished)
                
            self.scheduleview.set_model(self.schedulestore)
            # Display schedule if it isn't already displayed
            if child != self.schedulepaned:
                self.hpaned.remove(child)
                self.hpaned.pack2(self.schedulepaned)
                self._set_previous_day_sensitive(True)
                self._set_next_day_sensitive(True)
                self._set_refresh_sensitive(True)
        else:
            # Display running/next if it isn't already displayed
            if child != self.scrolledrunningnext:
                self._display_running_next()
    
    def _on_schedule_loading_finished(self, schedulestore):
        if len(self.schedulestore) == 0:
            self._display_help_message(self.no_events_text)
            
    def _display_help_message(self, text):
        child = self.hpaned.get_child2()
        self.hpaned.remove(child)
        self.hpaned.pack2(self.help_eventbox)
        self._set_previous_day_sensitive(False)
        self._set_next_day_sensitive(False)
        self._set_refresh_sensitive(False)
        
        self.help_eventbox.set_markup(text)
     
    def _display_running_next(self):
        group = self._get_selected_group()
        
        self.runningnextstore = RunningNextStore(group)
        
        self.scrolledrunningnext = gtk.ScrolledWindow()
        self.scrolledrunningnext.set_policy(gtk.POLICY_AUTOMATIC, gtk.POLICY_AUTOMATIC)
        self.scrolledrunningnext.set_shadow_type(gtk.SHADOW_IN)
        self.scrolledrunningnext.show()
        
        self.runningnextview = RunningNextView(self.runningnextstore)
        self.runningnextview.connect("button-press-event", self._on_running_next_clicked)
        self.runningnextview.show()
        self.scrolledrunningnext.add(self.runningnextview)
    
        child = self.hpaned.get_child2()
        self.hpaned.remove(child)
        self.hpaned.pack2(self.scrolledrunningnext)
        self._set_previous_day_sensitive(False)
        self._set_next_day_sensitive(False)
        self._set_refresh_sensitive(False)
                
    def _set_next_day_sensitive(self, val):
        self.button_next_day.set_sensitive(val)
        self.next_day_menuitem.set_sensitive(val)
        
    def _set_previous_day_sensitive(self, val):
        self.button_prev_day.set_sensitive(val)
        self.prev_day_menuitem.set_sensitive(val)
             
    def _set_timers_sensitive(self, val):
        self.button_display_timers.set_sensitive(val)
        self.timersitem.set_sensitive(val)
        
    def _set_refresh_sensitive(self, val):
        self.refresh_button.set_sensitive(val) 
        self.refresh_menuitem.set_sensitive(val)
       
    def _on_event_selected(self, treeview, event):
        if event.type == gtk.gdk._2BUTTON_PRESS:
            model, aiter = treeview.get_selection().get_selected()
            if aiter != None:
                dialog = gtk.MessageDialog(parent=self,
                    flags=gtk.DIALOG_MODAL|gtk.DIALOG_DESTROY_WITH_PARENT,
                    type=gtk.MESSAGE_QUESTION, buttons=gtk.BUTTONS_YES_NO)
                dialog.set_markup (
                    "<big><span weight=\"bold\">%s</span></big>" % _("Schedule recording for the selected event?"))
                rec_id = -1
                success = True
                if dialog.run() == gtk.RESPONSE_YES:
                    event_id = model[aiter][model.COL_EVENT_ID]
                    group = self._get_selected_group()
                    channel_sid = self._get_selected_channel_sid()
                    recorder = group.get_recorder()
                    rec_id, success = recorder.add_timer_for_epg_event(event_id, channel_sid)
                dialog.destroy()
                
                if not success:
                    dialog = NoTimerCreatedDialog(self)
                    dialog.run()
                    dialog.destroy()
        
    def _on_button_display_timers_clicked(self, button):
        group = self._get_selected_group()
        if group != None:
            edit = EditTimersDialog(group, self)
            edit.run()
            edit.destroy()
            
    def _on_whats_on_now_clicked(self, button):
        self._reset_schedule_view()
            
    def _on_refresh_clicked(self, button):
        self.schedulestore.reload_all()
   
    def _on_button_prev_day_clicked(self, button):
        if self.schedulestore != None:
            model, aiter = self.scheduleview.get_selection().get_selected()
            if aiter == None:
                path, col, x, y = self.scheduleview.get_path_at_pos(1, 1)
                aiter = model.get_iter(path)
                
            day_iter = self.schedulestore.get_previous_day_iter(aiter)
            if day_iter == None:
                self._set_previous_day_sensitive(False)
            else:
                self._set_next_day_sensitive(True)
                day_path = model.get_path(day_iter)
                self.scheduleview.scroll_to_cell(day_path, use_align=True)
                self.scheduleview.set_cursor(day_path)
            
    def _on_button_next_day_clicked(self, button):
        if self.schedulestore != None:
            model, aiter = self.scheduleview.get_selection().get_selected()
            if aiter == None:
                path, col, x, y = self.scheduleview.get_path_at_pos(1, 1)
                aiter = model.get_iter(path)
            
            day_iter = self.schedulestore.get_next_day_iter(aiter)
            if day_iter == None:
                self._set_next_day_sensitive(False)
            else:
                self._set_previous_day_sensitive(True)
                day_path = model.get_path(day_iter)
                self.scheduleview.scroll_to_cell(day_path, use_align=True)
                self.scheduleview.set_cursor(day_path)
    
    def _on_button_prefs_clicked(self, button):
        prefs = Preferences(self.manager, self)
        prefs.run()
        prefs.destroy()
        
    def _on_button_recordings_clicked(self, button):
        dialog = RecordingsDialog(self)
        dialog.run()
        dialog.destroy()
        
    def _on_view_channels_clicked(self, action):
        if self.vbox_left:
            if action.get_active():
                self.vbox_left.show()
            else:
                self.vbox_left.hide()
        
    def _on_view_toolbar_clicked(self, action):
        if self.toolbar:
            if action.get_active():
                self.toolbar.show()
            else:
                self.toolbar.hide()

    def _on_about_clicked(self, action):
        about = gtk.AboutDialog()
        about.set_transient_for(self)
        #translators: These appear in the About dialog, usual format applies.
        about.set_translator_credits( _("translator-credits") )
        
        for prop, val in gnomedvb.INFOS.items():
            about.set_property(prop, val)

        about.set_screen(self.get_screen())
        about.run()
        about.destroy()
        
    def _on_edit_channellists_clicked(self, action):
        dialog = ChannelListEditorDialog(self.manager, parent=self)
        dialog.run()
        dialog.destroy()
    
    def _on_running_next_clicked(self, treeview, event):
            
        def show_details(data, success):
            if not success:
                return
            event_id, next, name, duration, desc = data
            
            ext_desc, success = schedule.get_extended_description(event_id)
            if success:
                desc += "\n%s" % ext_desc
            
            dialog = DetailsDialog(self)
            dialog.set_description(desc)
            dialog.set_title(name)
            dialog.set_duration(duration)
            dialog.set_channel(model[aiter][RunningNextStore.COL_CHANNEL])
            start, success = schedule.get_local_start_timestamp(event_id)
            if success:
                dialog.set_date(start)
            dialog.run()
            dialog.destroy()
        
        if event.type == gtk.gdk._2BUTTON_PRESS:
            model, aiter = treeview.get_selection().get_selected()
            if aiter != None:
                pos = treeview.get_path_at_pos(int(event.x), int(event.y))
                if pos != None:
                    col = pos[1]
                    if col.index == RunningNextStore.COL_RUNNING:
                        event_id = model[aiter][RunningNextStore.COL_RUNNING_EVENT]
                    elif col.index == RunningNextStore.COL_NEXT:
                        event_id = model[aiter][RunningNextStore.COL_NEXT_EVENT]
                    else:
                        return
                    
                    devgroup = self._get_selected_group()
                    sid = model[aiter][RunningNextStore.COL_SID]
                    schedule = devgroup.get_schedule(sid)
                    schedule.get_informations(event_id, reply_handler=show_details, error_handler=gnomedvb.global_error_handler)

