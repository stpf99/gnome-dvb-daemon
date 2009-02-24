# -*- coding: utf-8 -*-
import gtk
from gettext import gettext as _
from BasePage import BasePage

class IntroPage(BasePage):
	
	def __init__(self):
		BasePage.__init__(self)
		self.set_border_width(5)
		
		text = _("Welcome to the channel search Assistant. It will automatically search for channels.")
		text += "\n\n"
		text += _("Click \"Forward\" to begin.")
		label = gtk.Label(text)
		label.set_line_wrap(True)
		self.pack_start(label)
    	
	def get_page_title(self):
		return _("Channel search")
		
	def get_page_type(self):
		return gtk.ASSISTANT_PAGE_INTRO
	
