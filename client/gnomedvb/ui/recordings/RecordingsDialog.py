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
from gettext import gettext as _

from gnomedvb import global_error_handler
from gnomedvb.ui.widgets.RecordingsStore import RecordingsStore
from gnomedvb.ui.widgets.RecordingsView import RecordingsView
from gnomedvb.ui.recordings.DetailsDialog import DetailsDialog

class RecordingsDialog(gtk.Dialog):

    def __init__(self, parent=None):
        gtk.Dialog.__init__(self, title=_("Recordings"),
            parent=parent,
            flags=gtk.DIALOG_MODAL | gtk.DIALOG_DESTROY_WITH_PARENT,
            buttons=(gtk.STOCK_CLOSE, gtk.RESPONSE_CLOSE))
            
        self.set_size_request(600, 400)
        self.set_has_separator(False)
        self.vbox.set_spacing(12)
            
        hbox_main = gtk.HBox(spacing=12)
        hbox_main.set_border_width(6)
        hbox_main.show()
        self.vbox.pack_start(hbox_main)
            
        self._model = RecordingsStore()
        self._model.set_sort_column_id(RecordingsStore.COL_START,
            gtk.SORT_ASCENDING)
        self._view = RecordingsView(self._model)
        self._view.connect("button-press-event", self._on_recording_selected)
        self._view.set_property("rules-hint", True)
        self._view.show()
        
        treeselection = self._view.get_selection()
        treeselection.connect("changed", self._on_selection_changed)
        
        scrolledwindow = gtk.ScrolledWindow()
        scrolledwindow.set_policy(gtk.POLICY_AUTOMATIC, gtk.POLICY_AUTOMATIC)
        scrolledwindow.set_shadow_type(gtk.SHADOW_IN)
        scrolledwindow.add(self._view)
        scrolledwindow.show()
        hbox_main.pack_start(scrolledwindow)
        
        buttonbox = gtk.VButtonBox()
        buttonbox.set_spacing(6)
        buttonbox.set_layout(gtk.BUTTONBOX_START)
        buttonbox.show()
        hbox_main.pack_start(buttonbox, False)
        
        self.details_button = gtk.Button(stock=gtk.STOCK_INFO)
        self.details_button.connect("clicked", self._on_details_clicked)
        self.details_button.set_sensitive(False)
        self.details_button.show()
        buttonbox.pack_start(self.details_button)
        
        self.delete_button = gtk.Button(stock=gtk.STOCK_DELETE)
        self.delete_button.connect("clicked", self._on_delete_clicked)
        self.delete_button.set_sensitive(False)
        self.delete_button.show()
        buttonbox.pack_start(self.delete_button)
        
    def _on_selection_changed(self, treeselection):
        model, rows = treeselection.get_selected_rows()
        
        self.delete_button.set_sensitive(len(rows) > 0)
        self.details_button.set_sensitive(len(rows) == 1)
        
    def _on_delete_clicked(self, button):
        model, aiter = self._view.get_selection().get_selected()
        
        if aiter != None:
            dialog = gtk.MessageDialog(parent=self,
                    flags=gtk.DIALOG_MODAL|gtk.DIALOG_DESTROY_WITH_PARENT,
                    type=gtk.MESSAGE_QUESTION, buttons=gtk.BUTTONS_YES_NO)
            dialog.set_markup("<big><span weight=\"bold\">%s</span></big>" % _("Delete selected recordings?"))
            response = dialog.run()
            dialog.destroy()
            if response == gtk.RESPONSE_YES:
                client = self._model.get_recordings_store_client()
                client.delete(model[aiter][RecordingsStore.COL_ID],
                    reply_handler=self._delete_callback,
                    error_handler=global_error_handler)
                        
    def _on_details_clicked(self, button):
        model, aiter = self._view.get_selection().get_selected()
        
        if aiter != None:
            dialog = DetailsDialog(model[aiter][RecordingsStore.COL_ID], self)
            dialog.run ()
            dialog.destroy ()
            
    def _on_recording_selected(self, treeview, event):
        if event.type == gtk.gdk._2BUTTON_PRESS:
            self._on_details_clicked(treeview)
                    
    def _delete_callback(self, success):
        if not success:
            global_error_handler("Could not delete recording")
        
