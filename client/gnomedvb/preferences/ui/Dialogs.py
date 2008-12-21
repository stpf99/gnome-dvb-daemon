# -*- coding: utf-8 -*-
import gtk
from gettext import gettext as _
from Frame import AlignedLabel

__all__ = ["AddToGroupDialog", "NewGroupDialog"]

class AddToGroupDialog (gtk.Dialog):

    def __init__(self, parent, model, device_type):
        gtk.Dialog.__init__(self, title=_("Add To Group"),
            parent=parent,
            flags=gtk.DIALOG_MODAL | gtk.DIALOG_DESTROY_WITH_PARENT,
            buttons=(gtk.STOCK_CANCEL, gtk.RESPONSE_REJECT,
                      gtk.STOCK_OK, gtk.RESPONSE_ACCEPT))
                
        self.__selected_group = None
        self.vbox.set_spacing(6)
                
        label = gtk.Label()
        label.set_markup(_("<b>Select a group:</b>"))
        label.show()
        self.vbox.pack_start(label, False, False, 0)
        
        self.groups = gtk.ListStore(str, int)
        
        combo = gtk.ComboBox(self.groups)
        combo.connect("changed", self.on_combo_changed)
        cell = gtk.CellRendererText()
        combo.pack_start(cell)
        combo.add_attribute(cell, "text", 0)
        combo.show()
        self.vbox.pack_start(combo)
                      
        for group in model.get_registered_device_groups():
            if model.get_type_of_device_group(group["id"]) == device_type:
                self.groups.append([group["name"], group["id"]])
            
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
        gtk.Dialog.__init__(self, title=_("Create Group"),
            parent=parent,
            flags=gtk.DIALOG_MODAL | gtk.DIALOG_DESTROY_WITH_PARENT,
            buttons=(gtk.STOCK_CANCEL, gtk.RESPONSE_REJECT,
                      gtk.STOCK_OK, gtk.RESPONSE_ACCEPT))
        
        self.set_default_size(400, 150)
        
        name = AlignedLabel(_("<b>Name</b>"))
        name.show()
        self.vbox.pack_start(name, False, False, 0)
        
        name_ali = gtk.Alignment(xscale=1.0, yscale=1.0)
        name_ali.set_padding(0, 0, 12, 0)
        name_ali.show()
        self.vbox.pack_start(name_ali)
        
        self.name_entry = gtk.Entry()
        self.name_entry.show()
        name_ali.add(self.name_entry)
        
        channels = AlignedLabel(_("<b>Channels File</b>"))
        channels.show()
        self.vbox.pack_start(channels, False, False, 0)
        self.vbox.set_spacing(6)
        
        channels_ali = gtk.Alignment(xscale=1.0, yscale=1.0)
        channels_ali.set_padding(0, 0, 12, 0)
        channels_ali.show()
        self.vbox.pack_start(channels_ali)
        
        channelsbox = gtk.HBox(spacing=3)
        channelsbox.show()
        channels_ali.add(channelsbox)
        self.channels_entry = gtk.Entry()
        self.channels_entry.set_editable(False)
        self.channels_entry.show()
        channelsbox.pack_start(self.channels_entry)
        
        channels_open = gtk.Button(stock=gtk.STOCK_OPEN)
        channels_open.connect("clicked", self._on_channels_open_clicked)
        channels_open.show()
        channelsbox.pack_start(channels_open, False, False, 0)
        
        recordings = AlignedLabel(_("<b>Recordings' Directory</b>"))
        recordings.show()
        self.vbox.pack_start(recordings, False, False, 0)
        
        rec_ali = gtk.Alignment(xscale=1.0, yscale=1.0)
        rec_ali.set_padding(0, 0, 12, 0)
        rec_ali.show()
        self.vbox.pack_start(rec_ali)
        
        recbox = gtk.HBox(spacing=6)
        recbox.show()
        rec_ali.add(recbox)
        
        self.recordings_entry = gtk.Entry()
        self.recordings_entry.set_editable(False)
        self.recordings_entry.show()
        recbox.pack_start(self.recordings_entry)
        
        recordings_open = gtk.Button(stock=gtk.STOCK_OPEN)
        recordings_open.connect("clicked", self._on_recordings_open_clicked)
        recordings_open.show()
        recbox.pack_start(recordings_open, False, False, 0)
        
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
         
 
