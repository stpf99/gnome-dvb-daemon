# -*- coding: utf-8 -*-
import gtk
from gettext import gettext as _
        
class CalendarDialog(gtk.Dialog):

    def __init__(self, parent):
        gtk.Dialog.__init__(self, title=_("Pick a date"), parent=parent,
            flags=gtk.DIALOG_MODAL | gtk.DIALOG_DESTROY_WITH_PARENT,
            buttons=(gtk.STOCK_CANCEL, gtk.RESPONSE_REJECT,
             gtk.STOCK_OK, gtk.RESPONSE_ACCEPT))     
        
        self.set_position(gtk.WIN_POS_MOUSE)
        
        self.calendar = gtk.Calendar()
        self.calendar.show()
        self.vbox.add(self.calendar)
        
    def get_date(self):
        return self.calendar.get_date()

