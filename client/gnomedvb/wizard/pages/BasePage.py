# -*- coding: utf-8 -*-
import gtk

class BasePage(gtk.VBox):

	def __init__(self):
		gtk.VBox.__init__(self, False, 5)
		self.set_border_width(5)

