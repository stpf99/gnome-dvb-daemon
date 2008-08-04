# -*- coding: utf-8 -*-
import gtk
from gettext import gettext as _
from BasePage import BasePage

class SummaryPage(BasePage):

	def __init__(self):
		BasePage.__init__(self)
		
		text = _("Your DVB cards are now setup.")
		label = gtk.Label(text)
		label.set_line_wrap(True)
		self.pack_start(label)

