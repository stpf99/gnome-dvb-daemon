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
from gnomedvb.ui.widgets.Frame import BaseFrame, TextFieldLabel

__all__ = ["AddToGroupDialog", "NewGroupDialog", "EditGroupDialog"]

class AddToGroupDialog (gtk.Dialog):

    def __init__(self, parent, model, device_type):
        gtk.Dialog.__init__(self, title=_("Add to Group"),
            parent=parent,
            flags=gtk.DIALOG_MODAL | gtk.DIALOG_DESTROY_WITH_PARENT,
            buttons=(gtk.STOCK_CANCEL, gtk.RESPONSE_REJECT,
                      gtk.STOCK_OK, gtk.RESPONSE_ACCEPT))
                
        self.__selected_group = None
        self.set_has_separator(False)
        self.vbox.set_spacing(12)
        
        self.vbox_main = gtk.VBox(spacing=12)
        self.vbox_main.set_border_width(6)
        self.vbox_main.show()
        self.vbox.pack_start(self.vbox_main)
        
        groupbox = gtk.HBox(spacing=18)
        groupbox.show()
        
        group_frame = BaseFrame("<b>%s</b>" % _("Add Device to Group"), groupbox)
        group_frame.show()
        self.vbox_main.pack_start(group_frame)
                
        group_label = TextFieldLabel()
        group_label.show()
        label = group_label.get_label()
        label.set_markup_with_mnemonic(_("_Group:"))
        groupbox.pack_start(group_label, False, False, 0)
        
        self.groups = gtk.ListStore(str, gobject.TYPE_PYOBJECT)
        
        combo = gtk.ComboBox(self.groups)
        combo.connect("changed", self.on_combo_changed)
        cell = gtk.CellRendererText()
        combo.pack_start(cell)
        combo.add_attribute(cell, "text", 0)
        combo.show()
        label.set_mnemonic_widget(combo)
        groupbox.pack_start(combo)
                     
        def append_groups(groups):
            for group in groups:
                if group.get_type() == device_type:
                    name = group["name"]
                    if name == "":
                        name = "Group %d" % group["id"]
                    self.groups.append([name, group])
        model.get_registered_device_groups(reply_handler=append_groups)
            
    def on_combo_changed(self, combo):
        aiter = combo.get_active_iter()
        
        if aiter == None:
            self.__selected_group = None
        else:
            self.__selected_group = self.groups[aiter][1]
      
    def get_selected_group(self):
        return self.__selected_group   


class NewGroupDialog (gtk.Dialog):

    def __init__(self, parent):
        gtk.Dialog.__init__(self, title=_("Create new Group"),
            parent=parent,
            flags=gtk.DIALOG_MODAL | gtk.DIALOG_DESTROY_WITH_PARENT,
            buttons=(gtk.STOCK_CANCEL, gtk.RESPONSE_REJECT,
                      gtk.STOCK_OK, gtk.RESPONSE_ACCEPT))
        
        self.set_default_size(400, 150)
        self.set_has_separator(False)
        self.vbox.set_spacing(12)
        
        self.vbox_main = gtk.VBox(spacing=12)
        self.vbox_main.set_border_width(6)
        self.vbox_main.show()
        self.vbox.pack_start(self.vbox_main)
        
        self.table = gtk.Table(3, 2)
        self.table.set_col_spacings(18)
        self.table.set_row_spacings(6)
        self.table.show()
        
        general_frame = BaseFrame("<b>%s</b>" % _("General"), self.table)
        general_frame.show()
        self.vbox_main.pack_start(general_frame)
        
        name = TextFieldLabel()
        label = name.get_label()
        label.set_markup_with_mnemonic(_("_Name:"))
        name.show()
        
        self.name_entry = gtk.Entry()
        self.name_entry.show()
        label.set_mnemonic_widget(self.name_entry)
        
        self.table.attach(name, 0, 1, 0, 1, gtk.FILL, gtk.FILL)
        self.table.attach(self.name_entry, 1, 2, 0, 1, yoptions=gtk.FILL)
        
        self.channels = TextFieldLabel()
        label = self.channels.get_label()
        label.set_markup_with_mnemonic(_("Channels _file:"))
        self.channels.show()
        
        self.channelsbox = gtk.HBox(spacing=6)
        self.channelsbox.show()

        self.channels_entry = gtk.Entry()
        self.channels_entry.set_editable(False)
        self.channels_entry.show()
        self.channelsbox.pack_start(self.channels_entry)
        label.set_mnemonic_widget(self.channels_entry)
        
        channels_open = gtk.Button(stock=gtk.STOCK_OPEN)
        channels_open.connect("clicked", self._on_channels_open_clicked)
        channels_open.show()
        self.channelsbox.pack_start(channels_open, False, False, 0)
        
        self.table.attach(self.channels, 0, 1, 1, 2, gtk.FILL, gtk.FILL)
        self.table.attach(self.channelsbox, 1, 2, 1, 2, yoptions=gtk.FILL)
        
        recbox = gtk.HBox(spacing=18)
        recbox.show()
        
        recordings_frame = BaseFrame("<b>%s</b>" % _("Recordings"), recbox)
        recordings_frame.show()
        self.vbox_main.pack_start(recordings_frame)
        
        recordings = TextFieldLabel()
        label = recordings.get_label()
        label.set_markup_with_mnemonic(_("_Directory:"))
        recordings.show()
        recbox.pack_start(recordings, False)
        
        recentrybox = gtk.HBox(spacing=6)
        recentrybox.show()
        recbox.pack_start(recentrybox)
        
        self.recordings_entry = gtk.Entry()
        self.recordings_entry.set_editable(False)
        self.recordings_entry.show()
        recentrybox.pack_start(self.recordings_entry)
        label.set_mnemonic_widget(self.recordings_entry)
        
        recordings_open = gtk.Button(stock=gtk.STOCK_OPEN)
        recordings_open.connect("clicked", self._on_recordings_open_clicked)
        recordings_open.show()
        recentrybox.pack_start(recordings_open, False, False, 0)
        
    def show_channels_section(self, val):
        if val:
            self.channels.show()
            self.channelsbox.show()
        else:
            self.channels.hide()
            self.channelsbox.hide()
        
    def _on_channels_open_clicked(self, button):
        dialog = gtk.FileChooserDialog (title = _("Select File"),
            parent=self, action=gtk.FILE_CHOOSER_ACTION_OPEN,
            buttons=(gtk.STOCK_CANCEL, gtk.RESPONSE_REJECT,
                      gtk.STOCK_OK, gtk.RESPONSE_ACCEPT))
        if dialog.run() == gtk.RESPONSE_ACCEPT:
            self.channels_entry.set_text(dialog.get_filename())
        dialog.destroy()
    
    def _on_recordings_open_clicked(self, button):
        dialog = gtk.FileChooserDialog (title = _("Select Directory"),
            parent=self, action=gtk.FILE_CHOOSER_ACTION_SELECT_FOLDER,
            buttons=(gtk.STOCK_CANCEL, gtk.RESPONSE_REJECT,
                      gtk.STOCK_OK, gtk.RESPONSE_ACCEPT))
        if dialog.run() == gtk.RESPONSE_ACCEPT:
            self.recordings_entry.set_text(dialog.get_filename())
        dialog.destroy()
        
class EditGroupDialog(NewGroupDialog):

    def __init__(self, name, recdir, parent=None):
        NewGroupDialog.__init__(self, parent)
        
        self.set_title (_("Edit group"))
        self.show_channels_section(False)

        self.name_entry.set_text(name)
        self.recordings_entry.set_text(recdir)
 
