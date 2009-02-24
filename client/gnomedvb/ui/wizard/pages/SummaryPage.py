# -*- coding: utf-8 -*-
import gtk
from gettext import gettext as _
from BasePage import BasePage

class SummaryPage(BasePage):

	def __init__(self):
		BasePage.__init__(self)
		
		text = _("The channel search has completed.")
		text += _("You can search for channels again for this or different devices by re-running this application.")
		label = gtk.Label(text)
		label.set_line_wrap(True)
		self.pack_start(label)
	
	def get_page_title(self):
		return _("Channel search finished")
		
	def get_page_type(self):
		return gtk.ASSISTANT_PAGE_SUMMARY
	
