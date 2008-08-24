# -*- coding: utf-8 -*-
import gtk
from gettext import gettext as _

from ChannelsStore import ChannelsStore

class ChannelsView(gtk.TreeView):

    def __init__(self, model):
        """
        @type model: ChannelsStore
        """
        gtk.TreeView.__init__(self, model)
        
        col_name = gtk.TreeViewColumn(_("Channel"))
        cell_name = gtk.CellRendererText()
        col_name.pack_start(cell_name)
        col_name.add_attribute(cell_name, "text", model.COL_NAME)
        self.append_column(col_name)
        
    def set_model(self, model):
        if isinstance(model, ChannelsStore):
            raise TypeError("model must be a ChannelsStore instance")
        gtk.TreeView.set_model(self, model)
        
