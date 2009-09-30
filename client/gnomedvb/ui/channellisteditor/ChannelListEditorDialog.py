# -*- coding: utf-8 -*-
# Copyright (C) 2009 Sebastian Pölsterl
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

import gnomedvb
import gobject
import gtk
from gettext import gettext as _
from gnomedvb.ui.widgets.ChannelsStore import ChannelsStore
from gnomedvb.ui.widgets.ChannelsView import ChannelsView
from gnomedvb.ui.widgets.ChannelsGroupStore import ChannelsGroupStore
from gnomedvb.ui.widgets.ChannelsGroupView import ChannelsGroupView
from gnomedvb.ui.widgets.Frame import Frame, BaseFrame
from gnomedvb.ui.widgets.HelpBox import HelpBox

class ChannelListEditorDialog(gtk.Dialog):

    def __init__(self, model, parent=None):
        gtk.Dialog.__init__(self, title=_("Channel List Editor"),
            parent=parent,
            flags=gtk.DIALOG_MODAL | gtk.DIALOG_DESTROY_WITH_PARENT,
            buttons=(gtk.STOCK_CLOSE, gtk.RESPONSE_CLOSE))

        self.model = model
        self.devgroup = None
        self.channel_list = None

        self.set_size_request(600, 500)
        self.connect("destroy-event", gtk.main_quit)
        self.connect("delete-event", gtk.main_quit)

        self.vbox_main = gtk.VBox(spacing=12)
        self.vbox_main.set_border_width(6)
        self.vbox.pack_start(self.vbox_main)

        # device groups
        self.devgroupslist = gtk.ListStore(str, int, gobject.TYPE_PYOBJECT)
        
        self.devgroupscombo = gtk.ComboBox(self.devgroupslist)
        self.devgroupscombo.connect("changed", self.on_devgroupscombo_changed)
        cell_adapter = gtk.CellRendererText()
        self.devgroupscombo.pack_start(cell_adapter)
        self.devgroupscombo.add_attribute(cell_adapter, "markup", 0)
        
        devgroups_frame = BaseFrame("<b>%s</b>" % _("Device groups"),
            self.devgroupscombo, False, False)
        self.vbox_main.pack_start(devgroups_frame, False)

        # channel groups
        groups_box = gtk.HBox(spacing=6)
        groups_frame = BaseFrame("<b>%s</b>" % _("Channel groups"),
            groups_box)
        self.vbox_main.pack_start(groups_frame, False)

        self.channel_groups = ChannelsGroupStore()
        self.channel_groups_view = ChannelsGroupView(self.channel_groups)
        self.channel_groups_view.set_headers_visible(False)
        self.channel_groups_view.get_selection().connect("changed",
            self.on_group_changed)
        self.channel_groups_view.get_renderer().connect("edited",
            self.on_channel_group_edited)
        
        scrolledgroups = gtk.ScrolledWindow()
        scrolledgroups.add(self.channel_groups_view)
        scrolledgroups.set_policy(gtk.POLICY_NEVER, gtk.POLICY_AUTOMATIC)
        scrolledgroups.set_shadow_type(gtk.SHADOW_ETCHED_IN)
        groups_box.pack_start(scrolledgroups)
        
        groups_buttonbox = gtk.VButtonBox()
        groups_buttonbox.set_spacing(6)
        groups_buttonbox.set_layout(gtk.BUTTONBOX_START)
        groups_box.pack_end(groups_buttonbox, False, False, 0)
        
        new_group_button = gtk.Button(stock=gtk.STOCK_ADD)
        new_group_button.connect("clicked", self.on_new_group_clicked)
        groups_buttonbox.pack_start(new_group_button)
        
        self.del_group_button = gtk.Button(stock=gtk.STOCK_REMOVE)
        self.del_group_button.connect("clicked", self.on_delete_group_clicked)
        groups_buttonbox.pack_start(self.del_group_button)
        
        channels_box = gtk.VBox(spacing=6)
        self.vbox_main.pack_start(channels_box)

        cbox = gtk.HBox(spacing=6)
        channels_box.pack_start(cbox)

        # all channels
        self.channels_store = None
        self.channels_view = ChannelsView(self.channels_store)
        self.channels_view.set_headers_visible(False)
        self.channels_view.connect("row-activated",
            self.on_channels_view_activated)
        treesel = self.channels_view.get_selection()
        treesel.set_mode(gtk.SELECTION_MULTIPLE)
        treesel.connect("changed",
            self.on_channel_store_selected)

        left_frame = Frame("<b>%s</b>" % _("All channels"), self.channels_view)
        cbox.pack_start(left_frame)
        
        # selected channels
        self.selected_channels_store = gtk.ListStore(str, int) # Name, sid
        self.selected_channels_view = gtk.TreeView(self.selected_channels_store)
        self.selected_channels_view.set_reorderable(True)
        self.selected_channels_view.set_headers_visible(False)
        self.selected_channels_view.connect("row-activated",
            self.on_selected_channels_view_activated)
        treesel = self.selected_channels_view.get_selection()
        treesel.connect("changed",
            self.on_selected_channels_changed)
        treesel.set_mode(gtk.SELECTION_MULTIPLE)
        col_name = gtk.TreeViewColumn(_("Channel"))
        cell_name = gtk.CellRendererText()
        col_name.pack_start(cell_name)
        col_name.add_attribute(cell_name, "markup", 0)
        self.selected_channels_view.append_column(col_name)
        self.selected_channels_view.show()
        
        self.scrolled_selected_channels = gtk.ScrolledWindow()
        self.scrolled_selected_channels.set_shadow_type(gtk.SHADOW_ETCHED_IN)
        self.scrolled_selected_channels.set_policy(gtk.POLICY_AUTOMATIC,
            gtk.POLICY_AUTOMATIC)
        self.scrolled_selected_channels.add(self.selected_channels_view)
        
        self.select_group_helpbox = HelpBox()
        self.select_group_helpbox.set_markup(_("Choose a channel group"))
        self.right_frame = BaseFrame("<b>%s</b>" % _("Channels of group"),
            self.select_group_helpbox)
        cbox.pack_start(self.right_frame)
        
        buttonbox = gtk.HButtonBox()
        buttonbox.set_spacing(6)
        buttonbox.set_layout(gtk.BUTTONBOX_SPREAD)
        self.add_channel_button = gtk.Button(stock=gtk.STOCK_ADD)
        self.add_channel_button.connect("clicked", self.on_add_channel_clicked)
        buttonbox.pack_start(self.add_channel_button)
        self.remove_channel_button = gtk.Button(stock=gtk.STOCK_REMOVE)
        self.remove_channel_button.connect("clicked", self.on_remove_channel_clicked)
        buttonbox.pack_start(self.remove_channel_button)
        channels_box.pack_start(buttonbox, False, False, 0)
        
        self.del_group_button.set_sensitive(False)
        self.add_channel_button.set_sensitive(False)
        self.remove_channel_button.set_sensitive(False)
        
        self.fill_device_groups()
        self.fill_channel_groups()
        
        self.show_all()
        
    def fill_channel_groups(self):
        def add_groups(groups):
            for gid, name in groups:
                self.channel_groups.append([gid, name, False]) # not editable
        
        self.model.get_channel_groups(reply_handler=add_groups,
            error_handler=gnomedvb.global_error_handler)
            
    def fill_device_groups(self):
        def append_groups(groups):
            for group in groups:
                self.devgroupslist.append([group["name"], group["id"], group])
            self.devgroupscombo.set_active(0)
                
        self.model.get_registered_device_groups(reply_handler=append_groups,
            error_handler=gnomedvb.global_error_handler)
            
    def refill_channel_groups(self):
        self.channel_groups.clear()
        self.fill_channel_groups()
        
    def fill_group_members(self):
        def add_channels(channels, success):
            if success:
                for channel_id in channels:
                    name, success = self.channel_list.get_channel_name(channel_id)
                    if success:
                        self.selected_channels_store.append([name, channel_id])
    
        self.selected_channels_store.clear()
        data = self.get_selected_channel_group()
        if data:
            group_id, group_name = data
            self.channel_list.get_channels_of_group(group_id,
                reply_handler=add_channels,
                error_handler=gnomedvb.global_error_handler)
            
    def get_selected_channels_all(self):
        sel = self.channels_view.get_selection()
        model, paths = sel.get_selected_rows()
        return [model[path][ChannelsStore.COL_SID] for path in paths]
            
    def get_selected_channels_selected_group(self):
        sel = self.selected_channels_view.get_selection()
        model, paths = sel.get_selected_rows()
        return [model[path][1] for path in paths]
            
    def get_selected_channel_group(self):
        model, aiter = self.channel_groups_view.get_selection().get_selected()
        if aiter == None:
            return None
        else:
            return self.channel_groups[aiter][0], self.channel_groups[aiter][1]
            
    def on_new_group_clicked(self, button):
        aiter = self.channel_groups.append()
        self.channel_groups.set_value(aiter, self.channel_groups.COL_EDITABLE,
            True)
        self.channel_groups_view.grab_focus()
        path = self.channel_groups.get_path(aiter)
        self.channel_groups_view.set_cursor(path,
            self.channel_groups_view.get_column(0), True)
        self.channel_groups_view.scroll_to_cell(path)
        
    def on_add_channel_group_finished(self, success):
        if success:
            self.refill_channel_groups()
        else:
            error_dialog = gtk.MessageDialog(parent=self,
                flags=gtk.DIALOG_MODAL|gtk.DIALOG_DESTROY_WITH_PARENT,
                type=gtk.MESSAGE_ERROR, buttons=gtk.BUTTONS_OK)
            error_dialog.set_markup(
                "<big><span weight=\"bold\">%s</big></span>" % _("An error occured while adding the group"))
            error_dialog.run()
            error_dialog.destroy()
            
    def on_delete_group_clicked(self, button):
        dialog = gtk.MessageDialog(parent=self,
            flags=gtk.DIALOG_MODAL|gtk.DIALOG_DESTROY_WITH_PARENT,
            type=gtk.MESSAGE_QUESTION, buttons=gtk.BUTTONS_YES_NO)
        group_id, group_name = self.get_selected_channel_group()
        msg = _("Are you sure you want to delete the group '%s'?") % group_name
        dialog.set_markup (
            "<big><span weight=\"bold\">%s</span></big>\n\n%s" %
            (msg, _("All assignments to this group will be lost.")))
        if dialog.run() == gtk.RESPONSE_YES:
            self.model.remove_channel_group(group_id,
                reply_handler=self.on_remove_channel_group_finished,
                error_handler=gnomedvb.global_error_handler)
        dialog.destroy()
        
    def on_remove_channel_group_finished(self, success):
        if success:
            self.refill_channel_groups()
        else:
            error_dialog = gtk.MessageDialog(parent=self,
                flags=gtk.DIALOG_MODAL|gtk.DIALOG_DESTROY_WITH_PARENT,
                type=gtk.MESSAGE_ERROR, buttons=gtk.BUTTONS_OK)
            error_dialog.set_markup(
                "<big><span weight=\"bold\">%s</big></span>" % _("An error occured while removing the group"))
            error_dialog.run()
            error_dialog.destroy()
            
    def on_add_channel_clicked(self, button):
        channel_ids = self.get_selected_channels_all()
        group_data = self.get_selected_channel_group()
        if group_data:
            for channel_id in channel_ids:
                self.channel_list.add_channel_to_group(channel_id, group_data[0])
            self.fill_group_members()
        
    def on_remove_channel_clicked(self, button):
        channel_ids = self.get_selected_channels_selected_group()
        group_data = self.get_selected_channel_group()
        if group_data:
            for channel_id in channel_ids:
                self.channel_list.remove_channel_from_group(channel_id, group_data[0])
            self.fill_group_members()
        
    def on_channel_store_selected(self, treeselection):
        model, paths = treeselection.get_selected_rows()
        val = (len(paths) > 0 and self.get_selected_channel_group() != None)
        self.add_channel_button.set_sensitive(val)
        
    def on_selected_channels_changed(self, treeselection):
        model, paths = treeselection.get_selected_rows()
        val = (len(paths) > 0)
        self.remove_channel_button.set_sensitive(val)
        
    def on_group_changed(self, treeselection):
        model, aiter = treeselection.get_selected()
        val = aiter != None
        self.del_group_button.set_sensitive(val)
        if val:
            self.fill_group_members()
            self.right_frame.set_aligned_child(self.scrolled_selected_channels)
        else:
            self.right_frame.set_aligned_child(self.select_group_helpbox)
            self.selected_channels_store.clear()
            
    def on_channel_group_edited(self, renderer, path, new_text):
        aiter = self.channel_groups.get_iter(path)
        if len(new_text) == 0:
            self.channel_groups.remove(aiter)
        else:
            self.model.add_channel_group(new_text,
                reply_handler=self.on_add_channel_group_finished,
                error_handler=gnomedvb.global_error_handler)
                
    def get_selected_group(self):
        aiter = self.devgroupscombo.get_active_iter()
        if aiter == None:
            return None
        else:
            return self.devgroupslist[aiter][2]
    
    def on_devgroupscombo_changed(self, combo):
        group = self.get_selected_group()
        if group != None:
            self.devgroup = group
            self.channel_list = group.get_channel_list()
            self.channels_store = ChannelsStore(self.devgroup)
            self.channels_view.set_model(self.channels_store)
            
    def on_channels_view_activated(self, treeview, aiter, path):
        self.on_add_channel_clicked(None)
        
    def on_selected_channels_view_activated(self, treeview, aiter, path):
        self.on_remove_channel_clicked(None)

