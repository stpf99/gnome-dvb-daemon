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

import gobject
from gi.repository import Gdk
from gi.repository import Gtk
from gettext import gettext as _

from gnomedvb import global_error_handler
from gnomedvb.ui.widgets.RecordingsStore import RecordingsStore
from gnomedvb.ui.widgets.RecordingsView import RecordingsView
from gnomedvb.ui.recordings.DetailsDialog import DetailsDialog

class RecordingsDialog(Gtk.Dialog):

    def __init__(self, parent=None):
        Gtk.Dialog.__init__(self, title=_("Recordings"),
            parent=parent)

        self.set_modal(True)
        self.set_destroy_with_parent(True)
        self.set_default_size(600, 400)
        self.set_border_width(5)
        
        close_button = self.add_button(Gtk.STOCK_CLOSE, Gtk.ResponseType.CLOSE)
        close_button.grab_default()
            
        hbox_main = Gtk.HBox(spacing=12)
        hbox_main.set_border_width(5)
        hbox_main.show()
        self.get_content_area().pack_start(hbox_main, True, True, 0)
            
        self._model = RecordingsStore()
        self._model.set_sort_func(RecordingsStore.COL_START,
            self._datetime_sort_func)
        self._view = RecordingsView(self._model)
        self._view.connect("button-press-event", self._on_recording_selected)
        self._view.set_property("rules-hint", True)
        self._view.show()
        
        treeselection = self._view.get_selection()
        treeselection.connect("changed", self._on_selection_changed)
        
        scrolledwindow = Gtk.ScrolledWindow()
        scrolledwindow.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        scrolledwindow.set_shadow_type(Gtk.ShadowType.IN)
        scrolledwindow.add(self._view)
        scrolledwindow.show()
        hbox_main.pack_start(scrolledwindow, True, True, 0)
        
        buttonbox = Gtk.VButtonBox()
        buttonbox.set_spacing(6)
        buttonbox.set_layout(Gtk.ButtonBoxStyle.START)
        buttonbox.show()
        hbox_main.pack_start(buttonbox, False, True, 0)
        
        self.details_button = Gtk.Button(stock=Gtk.STOCK_INFO)
        self.details_button.connect("clicked", self._on_details_clicked)
        self.details_button.set_sensitive(False)
        self.details_button.show()
        buttonbox.pack_start(self.details_button, True, True, 0)
        
        self.delete_button = Gtk.Button(stock=Gtk.STOCK_DELETE)
        self.delete_button.connect("clicked", self._on_delete_clicked)
        self.delete_button.set_sensitive(False)
        self.delete_button.show()
        buttonbox.pack_start(self.delete_button, True, True, 0)
        
    def _on_selection_changed(self, treeselection):
        model, rows = treeselection.get_selected_rows()
        
        self.delete_button.set_sensitive(len(rows) > 0)
        self.details_button.set_sensitive(len(rows) == 1)
        
    def _on_delete_clicked(self, button):
        model, aiter = self._view.get_selection().get_selected()
        
        if aiter != None:
            dialog = Gtk.MessageDialog(parent=self,
                    flags=Gtk.DialogFlags.MODAL|Gtk.DialogFlags.DESTROY_WITH_PARENT,
                    type=Gtk.MessageType.QUESTION, buttons=Gtk.ButtonsType.YES_NO)
            dialog.set_markup("<big><span weight=\"bold\">%s</span></big>" % _("Delete selected recordings?"))
            response = dialog.run()
            dialog.destroy()
            if response == Gtk.ResponseType.YES:
                client = self._model.get_recordings_store_client()
                client.delete(model[aiter][RecordingsStore.COL_ID],
                    result_handler=self._delete_callback,
                    error_handler=global_error_handler)
                        
    def _on_details_clicked(self, button):
        model, aiter = self._view.get_selection().get_selected()
        
        if aiter != None:
            dialog = DetailsDialog(model[aiter][RecordingsStore.COL_ID], self)
            dialog.run ()
            dialog.destroy ()
            
    def _on_recording_selected(self, treeview, event):
        if event.type == getattr(Gdk.EventType, "2BUTTON_PRESS"):
            self._on_details_clicked(treeview)
                    
    def _delete_callback(self, proxy, success, user_data):
        if not success:
            global_error_handler("Could not delete recording")

    def _datetime_sort_func(treemodel, iter1, iter2):
        d1 = treemodel[iter1][RecordingsStore.COL_START]
        d2 = treemodel[iter2][RecordingsStore.COL_START]
        return cmp(d1, d2)

        
