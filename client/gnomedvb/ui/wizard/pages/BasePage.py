# -*- coding: utf-8 -*-
import gtk

class BasePage(gtk.VBox):

	def __init__(self):
		gtk.VBox.__init__(self, False, 5)
		self.set_border_width(5)
		
	def get_page_title(self):
		raise NotImplementedError
		
	def get_page_type(self):
		return gtk.ASSISTANT_PAGE_CONTENT

