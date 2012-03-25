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

from gi.repository import Gtk
from gi.repository import GObject
from gnomedvb import _
from gnomedvb.ui.widgets.Frame import BaseFrame, TextFieldLabel

__all__ = ["AddToGroupDialog", "NewGroupDialog", "EditGroupDialog"]

class AddToGroupDialog (Gtk.Dialog):

    def __init__(self, parent, model, device_type):
        Gtk.Dialog.__init__(self, title=_("Add to Group"), parent=parent,
            buttons=(Gtk.STOCK_CANCEL, Gtk.ResponseType.REJECT,
                      Gtk.STOCK_OK, Gtk.ResponseType.ACCEPT))
        self.set_modal(True)
        self.set_destroy_with_parent(True)
        self.__selected_group = None
        self.set_border_width(5)

        self.vbox_main = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        self.vbox_main.set_border_width(5)
        self.vbox_main.show()
        self.get_content_area().pack_start(self.vbox_main, True, True, 0)

        groupbox = Gtk.Box(spacing=18)
        groupbox.show()

        group_frame = BaseFrame("<b>%s</b>" % _("Add Device to Group"), groupbox)
        group_frame.show()
        self.vbox_main.pack_start(group_frame, True, True, 0)

        group_label = TextFieldLabel()
        group_label.show()
        group_label.set_markup_with_mnemonic(_("_Group:"))
        groupbox.pack_start(group_label, False, False, 0)

        self.groups = Gtk.ListStore(str, GObject.TYPE_PYOBJECT)

        combo = Gtk.ComboBox.new_with_model(self.groups)
        combo.connect("changed", self.on_combo_changed)
        cell = Gtk.CellRendererText()
        combo.pack_start(cell, True)
        combo.add_attribute(cell, "text", 0)
        combo.show()
        group_label.set_mnemonic_widget(combo)
        groupbox.pack_start(combo, True, True, 0)

        def append_groups(groups):
            for group in groups:
                if group.get_type() == device_type:
                    name = group["name"]
                    if name == "":
                        name = "Group %d" % group["id"]
                    self.groups.append([name, group])
        model.get_registered_device_groups(result_handler=append_groups)

    def on_combo_changed(self, combo):
        aiter = combo.get_active_iter()

        if aiter == None:
            self.__selected_group = None
        else:
            self.__selected_group = self.groups[aiter][1]

    def get_selected_group(self):
        return self.__selected_group


class NewGroupDialog (Gtk.Dialog):

    def __init__(self, parent):
        Gtk.Dialog.__init__(self, title=_("Create new Group"),
            parent=parent,
            flags=Gtk.DialogFlags.MODAL | Gtk.DialogFlags.DESTROY_WITH_PARENT,
            buttons=(Gtk.STOCK_CANCEL, Gtk.ResponseType.REJECT,
                      Gtk.STOCK_OK, Gtk.ResponseType.ACCEPT))
        self.set_modal(True)
        self.set_destroy_with_parent(True)
        self.set_default_size(400, 150)
        self.set_border_width(5)

        self.vbox_main = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        self.vbox_main.set_border_width(5)
        self.vbox_main.show()
        self.get_content_area().pack_start(self.vbox_main, True, True, 0)

        self.table = Gtk.Grid(orientation=Gtk.Orientation.VERTICAL)
        self.table.set_column_spacing(18)
        self.table.set_row_spacing(6)
        self.table.show()

        general_frame = BaseFrame("<b>%s</b>" % _("General"), self.table)
        general_frame.show()
        self.vbox_main.pack_start(general_frame, True, True, 0)

        name = TextFieldLabel()
        name.set_markup_with_mnemonic(_("_Name:"))
        name.show()

        self.name_entry = Gtk.Entry(hexpand=True)
        self.name_entry.show()
        name.set_mnemonic_widget(self.name_entry)

        self.table.add(name)
        self.table.attach_next_to(self.name_entry, name, Gtk.PositionType.RIGHT, 1, 1)

        self.channels = TextFieldLabel()
        self.channels.set_markup_with_mnemonic(_("Channels _file:"))
        self.channels.show()

        self.channelsbox = Gtk.Box(spacing=6, hexpand=True)
        self.channelsbox.show()

        self.channels_entry = Gtk.Entry()
        self.channels_entry.set_editable(False)
        self.channels_entry.show()
        self.channelsbox.pack_start(self.channels_entry, True, True, 0)
        self.channels.set_mnemonic_widget(self.channels_entry)

        channels_open = Gtk.Button(stock=Gtk.STOCK_OPEN)
        channels_open.connect("clicked", self._on_channels_open_clicked)
        channels_open.show()
        self.channelsbox.pack_start(channels_open, False, False, 0)

        self.table.add(self.channels)
        self.table.attach_next_to(self.channelsbox, self.channels, Gtk.PositionType.RIGHT, 1, 1)

        recbox = Gtk.Box(spacing=18)
        recbox.show()

        recordings_frame = BaseFrame("<b>%s</b>" % _("Recordings"), recbox)
        recordings_frame.show()
        self.vbox_main.pack_start(recordings_frame, True, True, 0)

        recordings = TextFieldLabel()
        recordings.set_markup_with_mnemonic(_("_Directory:"))
        recordings.show()
        recbox.pack_start(recordings, False, True, 0)

        recentrybox = Gtk.Box(spacing=6)
        recentrybox.show()
        recbox.pack_start(recentrybox, True, True, 0)

        self.recordings_entry = Gtk.Entry()
        self.recordings_entry.set_editable(False)
        self.recordings_entry.show()
        recentrybox.pack_start(self.recordings_entry, True, True, 0)
        recordings.set_mnemonic_widget(self.recordings_entry)

        recordings_open = Gtk.Button(stock=Gtk.STOCK_OPEN)
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
        dialog = Gtk.FileChooserDialog (title = _("Select File"),
            parent=self, action=Gtk.FileChooserAction.OPEN,
            buttons=(Gtk.STOCK_CANCEL, Gtk.ResponseType.REJECT,
                      Gtk.STOCK_OK, Gtk.ResponseType.ACCEPT))
        if dialog.run() == Gtk.ResponseType.ACCEPT:
            self.channels_entry.set_text(dialog.get_filename())
        dialog.destroy()

    def _on_recordings_open_clicked(self, button):
        dialog = Gtk.FileChooserDialog (title = _("Select Directory"),
            parent=self, action=Gtk.FileChooserAction.SELECT_FOLDER,
            buttons=(Gtk.STOCK_CANCEL, Gtk.ResponseType.REJECT,
                      Gtk.STOCK_OK, Gtk.ResponseType.ACCEPT))
        if dialog.run() == Gtk.ResponseType.ACCEPT:
            self.recordings_entry.set_text(dialog.get_filename())
        dialog.destroy()

class EditGroupDialog(NewGroupDialog):

    def __init__(self, name, recdir, parent=None):
        NewGroupDialog.__init__(self, parent)

        self.set_title (_("Edit group"))
        self.show_channels_section(False)

        self.name_entry.set_text(name)
        self.recordings_entry.set_text(recdir)
