# -*- coding: utf-8 -*-
import gtk
from gettext import gettext as _

from gnomedvb import global_error_handler
from gnomedvb.ui.widgets.RecordingsStore import RecordingsStore
from gnomedvb.ui.widgets.RecordingsView import RecordingsView

class RecordingsDialog(gtk.Dialog):

    def __init__(self, parent=None):
        gtk.Dialog.__init__(self, title=_("Recordings"),
            parent=parent,
            flags=gtk.DIALOG_MODAL | gtk.DIALOG_DESTROY_WITH_PARENT,
            buttons=(gtk.STOCK_CLOSE, gtk.RESPONSE_CLOSE))
            
        self.set_size_request(600, 400)
        self.vbox.set_spacing(6)
            
        hbox_main = gtk.HBox(spacing=6)
        hbox_main.show()
        self.vbox.pack_start(hbox_main)
            
        self._model = RecordingsStore()
        self._model.set_sort_column_id(RecordingsStore.COL_START,
            gtk.SORT_ASCENDING)
        self._view = RecordingsView(self._model)
        self._view.set_property("rules-hint", True)
        self._view.show()
        
        treeselection = self._view.get_selection()
        treeselection.set_mode(gtk.SELECTION_MULTIPLE)
        treeselection.connect("changed", self._on_selection_changed)
        
        scrolledwindow = gtk.ScrolledWindow()
        scrolledwindow.set_policy(gtk.POLICY_AUTOMATIC, gtk.POLICY_AUTOMATIC)
        scrolledwindow.set_shadow_type(gtk.SHADOW_IN)
        scrolledwindow.add(self._view)
        scrolledwindow.show()
        hbox_main.pack_start(scrolledwindow)
        
        buttonbox = gtk.VButtonBox()
        buttonbox.set_layout(gtk.BUTTONBOX_START)
        buttonbox.show()
        hbox_main.pack_start(buttonbox, False)
        
        self.delete_button = gtk.Button(stock=gtk.STOCK_DELETE)
        self.delete_button.connect("clicked", self._on_delete_clicked)
        self.delete_button.set_sensitive(False)
        self.delete_button.show()
        buttonbox.pack_start(self.delete_button)
        
    def _on_selection_changed(self, treeselection):
        model, rows = treeselection.get_selected_rows()
        
        self.delete_button.set_sensitive(len(rows) > 0)
        
    def _on_delete_clicked(self, button):
        model, rows = self._view.get_selection().get_selected_rows()
        
        if len(rows) > 0:
            dialog = gtk.MessageDialog(parent=self,
                    flags=gtk.DIALOG_MODAL|gtk.DIALOG_DESTROY_WITH_PARENT,
                    type=gtk.MESSAGE_QUESTION, buttons=gtk.BUTTONS_YES_NO)
            dialog.set_markup(_("<big><span weight=\"bold\">Delete selected recordings?</span></big>"))
            response = dialog.run()
            dialog.destroy()
            if response == gtk.RESPONSE_YES:
                client = self._model.get_recordings_store_client()
                for row_path in rows:
                    aiter = model.get_iter(row_path)
                    client.delete(model[aiter][RecordingsStore.COL_ID],
                        reply_handler=self._delete_callback,
                        error_handler=global_error_handler)
                    
    def _delete_callback(self, success):
        if not success:
            global_error_handler("Could not delete recording")
        
