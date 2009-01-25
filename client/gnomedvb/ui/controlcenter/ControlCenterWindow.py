# -*- coding: utf-8 -*-
import gtk
import pango
from gettext import gettext as _
import gnomedvb
from gnomedvb.ui.widgets.ChannelsStore import ChannelsStore
from gnomedvb.ui.widgets.ChannelsView import ChannelsView
from gnomedvb.ui.widgets.ScheduleStore import ScheduleStore
from gnomedvb.ui.widgets.ScheduleView import ScheduleView
from gnomedvb.ui.timers.EditTimersDialog import EditTimersDialog
from gnomedvb.ui.preferences.Preferences import Preferences

class ControlCenterWindow(gtk.Window):

    def __init__(self, model):
        gtk.Window.__init__(self)
        
        self.channellists = {}
        self.manager = model
        
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
        scrolledchannels.set_shadow_type(gtk.SHADOW_IN)
        self.vbox_left.pack_start(scrolledchannels)
        
        self.schedulestore = None
                
        self.help_eventbox = gtk.EventBox()
        self.help_eventbox.modify_bg(gtk.STATE_NORMAL, self.help_eventbox.style.base[gtk.STATE_NORMAL])
                
        frame = gtk.Frame()
        frame.set_shadow_type(gtk.SHADOW_IN)
        self.help_eventbox.add(frame)
        
        self.helpview = gtk.Label()
        helptext = _("Choose a device group and channel on the left to view the program guide")
        self.helpview.set_markup("<span foreground='grey50'>%s</span>" % helptext)
        self.helpview.set_ellipsize(pango.ELLIPSIZE_END)
        self.helpview.set_alignment(0.50, 0.50)
        frame.add(self.helpview)
        self.hpaned.pack2(self.help_eventbox)
        
        self.scheduleview = ScheduleView()
        self.scheduleview.connect("button-press-event", self._on_event_selected)
        self.scheduleview.show()
        
        self.scrolledschedule = gtk.ScrolledWindow()
        self.scrolledschedule.add(self.scheduleview)
        self.scrolledschedule.set_policy(gtk.POLICY_AUTOMATIC, gtk.POLICY_AUTOMATIC)
        self.scrolledschedule.set_shadow_type(gtk.SHADOW_IN)
        self.scrolledschedule.show()
        
        self.get_device_groups()
        
        self.devgroupscombo.set_active(0)
        self.channelsview.grab_focus()
        
    def __create_menu(self):
        ui = '''
        <menubar name="MenuBar">
          <menu action="Timers">
            <menuitem action="EditTimers"/>
            <separator/>
            <menuitem action="Quit"/>
          </menu>
          <menu action="Edit">
            <menuitem action="Preferences"/>
          </menu>
          <menu action="View">
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
            ('Timers', None, _('_Timers')),
            ('Edit', None, _('_Edit')),
            ('View', None, _('_View')),
            ('Help', None, _('Help')),
        ])
        # Add the actiongroup to the uimanager
        uimanager.insert_action_group(actiongroup, 0)
        
        actiongroup = gtk.ActionGroup('Timers')
        actiongroup.add_actions([
            ('EditTimers', gtk.STOCK_SAVE, _('_Manage'), None,
             _('Create and edit timers'), self._on_button_display_timers_clicked),
            ('Quit', gtk.STOCK_QUIT, _('_Quit'), None,
             _('Quit the Program'), gtk.main_quit)])
        uimanager.insert_action_group(actiongroup, 1)
        
        actiongroup = gtk.ActionGroup('Edit')
        actiongroup.add_actions([
            ('Preferences', gtk.STOCK_PREFERENCES, _('_Preferences'), None,
             _('Display preferences'), self._on_button_prefs_clicked),
        ])
        uimanager.insert_action_group(actiongroup, 2)
        
        actiongroup = gtk.ActionGroup('View')
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
        
        actiongroup = gtk.ActionGroup('Edit')
        actiongroup.add_actions([
            ('About', gtk.STOCK_ABOUT, _('_About'), None,
             _('Display informations about the program'),
             self._on_about_clicked),
        ])
        uimanager.insert_action_group(actiongroup, 4)

        # Add a UI description
        uimanager.add_ui_from_string(ui)
        
        # Create a MenuBar
        menubar = uimanager.get_widget('/MenuBar')
        menubar.show()
        self.vbox_outer.pack_start(menubar, False)
        
    def __create_toolbar(self):
        self.toolbar = gtk.Toolbar()
        self.toolbar.show()
        self.vbox_outer.pack_start(self.toolbar, False)
        
        edit_image = gtk.image_new_from_stock(gtk.STOCK_SAVE, gtk.ICON_SIZE_SMALL_TOOLBAR)
        edit_image.show()
        self.button_display_timers = gtk.ToolButton(icon_widget=edit_image, label=_("Timers"))
        self.button_display_timers.set_sensitive(False)
        self.button_display_timers.connect("clicked", self._on_button_display_timers_clicked)
        self.button_display_timers.set_tooltip_markup(_("View and add scheduled recordings"))
        self.button_display_timers.show()
        self.toolbar.insert(self.button_display_timers, 0)
        
        sep = gtk.SeparatorToolItem()
        sep.show()
        self.toolbar.insert(sep, 1)
        
        self.button_prefs = gtk.ToolButton(gtk.STOCK_PREFERENCES)
        self.button_prefs.connect("clicked", self._on_button_prefs_clicked)
        self.button_prefs.set_tooltip_markup(_("Manage devices"))
        self.button_prefs.show()
        self.toolbar.insert(self.button_prefs, 2)
         
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
        child = self.hpaned.get_child2()
        if aiter != None:
            sid = model[aiter][model.COL_SID]
            group_id = self._get_selected_group_id()
            self.schedulestore = ScheduleStore(self.manager.get_schedule(group_id, sid))
            self.scheduleview.set_model(self.schedulestore)
            
            # Display schedule if it isn't already displayed
            if child != self.scrolledschedule:
                self.hpaned.remove(child)
                self.hpaned.pack2(self.scrolledschedule)
        else:
            # Display help message if it isn't already displayed
            if child != self.help_eventbox:
                self.hpaned.remove(child)
                self.hpaned.pack2(self.help_eventbox)
            
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
        pass
    
