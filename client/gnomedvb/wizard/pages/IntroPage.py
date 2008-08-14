# -*- coding: utf-8 -*-
import gtk
from gettext import gettext as _
from BasePage import BasePage

class IntroPage(BasePage):
	
	def __init__(self):
		BasePage.__init__(self)
		self.set_border_width(5)
		
		text = _("This wizard will guide you through the process of setting up your DVB cards.")
		label = gtk.Label(text)
		label.set_line_wrap(True)
		self.pack_start(label)
    	
	def get_page_title(self):
		return _("Welcome")
		
	def get_page_type(self):
		return gtk.ASSISTANT_PAGE_INTRO
	
