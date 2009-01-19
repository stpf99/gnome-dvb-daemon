# -*- coding: utf-8 -*-
import gtk
import pango
from gettext import gettext as _
from ScheduleStore import ScheduleStore

class ScheduleView(gtk.TreeView):

    def __init__(self, model=None):
        if model != None:
            gtk.TreeView.__init__(self, model)
        else:
            gtk.TreeView.__init__(self)
        
        self.set_property("headers-visible", False)
        self.set_property("rules-hint", True)
        
        cell_time = gtk.CellRendererText()
        col_time = gtk.TreeViewColumn("Time", cell_time)
        col_time.set_cell_data_func(cell_time, self._get_time_data)
        self.append_column(col_time)
        
        cell_description = gtk.CellRendererText()
        cell_description.set_property("wrap-width", 500)
        cell_description.set_property("wrap-mode", pango.WRAP_WORD)
        col = gtk.TreeViewColumn("Description", cell_description)
        col.set_cell_data_func(cell_description, self._get_description_data)
        self.append_column(col)
    
    def _get_description_data(self, column, cell, model, aiter):
        event_id = model[aiter][ScheduleStore.COL_EVENT_ID]
        
        if event_id == ScheduleStore.NEW_DAY:
            date = model.get_datetime(aiter)
            description = "<big><b>%s</b></big>" % date.strftime("%A %x")
            cell.set_property("xalign", 0.5)
            cell.set_property ("cell-background-gdk", self.style.bg[gtk.STATE_NORMAL])
        else:
            cell.set_property("xalign", 0)
            cell.set_property ("cell-background-gdk", self.style.base[gtk.STATE_NORMAL])
            
            duration = model[aiter][ScheduleStore.COL_DURATION]
            title = model[aiter][ScheduleStore.COL_TITLE]
            short_desc = model[aiter][ScheduleStore.COL_SHORT_DESC]
            if len(short_desc) > 0:
                short_desc += "\n"
            
            description = "<b>%s</b>\n%s<small><i>%s: %s %s</i></small>" % (title, short_desc, _("Duration"), duration, _("minutes"))
            
            # Check if row is the selected row
            sel_iter = self.get_selection().get_selected()[1]
            if sel_iter != None and model.get_path(aiter) == model.get_path(sel_iter):
                ext_desc = model[aiter][ScheduleStore.COL_EXTENDED_DESC]
                description += "\n<small>%s</small>" % ext_desc
                # Update cell height
                model.emit("row-changed", model.get_path(aiter), aiter)
        
        cell.set_property("markup", description)
        
    def _get_time_data(self, column, cell, model, aiter):
        event_id = model[aiter][ScheduleStore.COL_EVENT_ID]
        
        if event_id == ScheduleStore.NEW_DAY:
            cell.set_property("text", "")
            cell.set_property ("cell-background-gdk", self.style.bg[gtk.STATE_NORMAL])
        else:
            date = model.get_datetime(aiter)
            cell.set_property("text", date.strftime("%X"))
            cell.set_property ("cell-background-gdk", self.style.base[gtk.STATE_NORMAL])

