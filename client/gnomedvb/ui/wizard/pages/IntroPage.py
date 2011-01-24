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

from gi.repository import Gtk
from gettext import gettext as _
from gnomedvb.ui.wizard.pages.BasePage import BasePage

class IntroPage(BasePage):
    
    def __init__(self):
        BasePage.__init__(self)
        
        text = "<b>%s</b>" % _('Welcome to the digital television Assistant.')
        self._label.set_markup(text)
        self._label.set_line_wrap(False)

        text1 = _('It will automatically configure your devices and search for channels, if necessary.')
        text2 = _("Click \"Forward\" to begin.")
        label2 = Gtk.Label(text1 + "\n\n" + text2)
        label2.set_line_wrap(True)
        label2.set_halign(Gtk.Align.START)
        label2.set_valign(Gtk.Align.START)
        self.pack_start(label2, True, True, 0)
        
        self.expert_mode = Gtk.CheckButton.new_with_mnemonic(_('_Expert mode'))
        self.pack_start(self.expert_mode, False, False, 0)
        
    def get_page_title(self):
        return _("Digital TV configuration")
        
    def get_page_type(self):
        return Gtk.AssistantPageType.INTRO
        
    def has_expert_mode(self):
        return self.expert_mode.get_active()
    
