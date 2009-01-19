# -*- coding: utf-8 -*-
import gtk
from gettext import gettext as _
from ScheduleStore import ScheduleStore

class ScheduleView(gtk.TreeView):

    def __init__(self, model=None):
        if model != None:
            gtk.TreeView.__init__(self, model)
        else:
            gtk.TreeView.__init__(self)
        
        self._create_and_append_text_column(_("Start"), ScheduleStore.COL_START)
        self._create_and_append_text_column(_("Duration"), ScheduleStore.COL_DURATION)
        self._create_and_append_text_column(_("Title"), ScheduleStore.COL_TITLE)
        self._create_and_append_text_column(_("Description"), ScheduleStore.COL_SHORT_DESC)
        
    def _create_and_append_text_column(self, title, text_col):
        cell = gtk.CellRendererText()
        col = gtk.TreeViewColumn(title)
        col.pack_start(cell)
        col.add_attribute(cell, "markup", text_col)
        self.append_column(col)

