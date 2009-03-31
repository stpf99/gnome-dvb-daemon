# -*- coding: utf-8 -*-
# Copyright (C) 2008,2009 Sebastian Pölsterl
#
# This file is part of GNOME DVB Daemon.
#
# GNOME DVB Daemon is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# GNOME DVB Daemon is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with GNOME DVB Daemon.  If not, see <http://www.gnu.org/licenses/>.

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
	
