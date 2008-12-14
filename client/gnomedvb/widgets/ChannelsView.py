# -*- coding: utf-8 -*-
import gtk
from gettext import gettext as _

from ChannelsStore import ChannelsStore

class ChannelsView(gtk.TreeView):

    def __init__(self, model=None):
        """
        @type model: ChannelsStore
        """
        if model != None:
            gtk.TreeView.__init__(self, model)
        else:
            gtk.TreeView.__init__(self)
        
        col_name = gtk.TreeViewColumn(_("Channel"))
        cell_name = gtk.CellRendererText()
        col_name.pack_start(cell_name)
        col_name.add_attribute(cell_name, "markup", ChannelsStore.COL_NAME)
        self.append_column(col_name)
        
    def set_model(self, model=None):
        if model != None and not isinstance(model, ChannelsStore):
            raise TypeError("model must be a ChannelsStore instance")
        gtk.TreeView.set_model(self, model)
        
