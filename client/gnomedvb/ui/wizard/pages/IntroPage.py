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
from gnomedvb.ui.wizard.pages.BasePage import BasePage

class IntroPage(BasePage):
    
    def __init__(self):
        BasePage.__init__(self)
        self.set_border_width(5)
        
        text = _('Welcome to the digital television Assistant.')
        text += "\n"
        text += _('It will automatically configure your devices and search for channels, if necessary.')
        text += "\n\n"
        text += _("Click \"Forward\" to begin.")
        self._label.set_text(text)
        self.set_child_packing(self._label, True, True, 0, gtk.PACK_START)
        
        self.expert_mode = gtk.CheckButton(label=_('Expert mode'))
        self.pack_start(self.expert_mode, False, False, 0)
        
    def get_page_title(self):
        return _("Digital TV configuration")
        
    def get_page_type(self):
        return gtk.ASSISTANT_PAGE_INTRO
        
    def has_expert_mode(self):
        return self.expert_mode.get_active()
    
