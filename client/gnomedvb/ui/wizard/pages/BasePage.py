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
from gnomedvb.ui.widgets.Frame import AlignedLabel

class BasePage(gtk.VBox):

    def __init__(self):
        gtk.VBox.__init__(self, spacing=6)
        self.set_border_width(24)

        ali = AlignedLabel()
        ali.show()
        self.pack_start(ali, False, False)

        self._label = ali.get_label()
        self._label.set_line_wrap(True)
        
    def get_page_title(self):
        raise NotImplementedError
        
    def get_page_type(self):
        return gtk.ASSISTANT_PAGE_CONTENT

