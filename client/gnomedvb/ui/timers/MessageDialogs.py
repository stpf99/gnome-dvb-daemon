# -*- coding: utf-8 -*-
# Copyright (C) 2009 Sebastian Pölsterl
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

import gobject
from gi.repository import Gtk
from gettext import gettext as _

class TimerFailureDialog(Gtk.MessageDialog):

    def __init__(self, parent_window):
        Gtk.MessageDialog.__init__(self, parent=parent_window,
            flags=Gtk.DialogFlags.MODAL|Gtk.DialogFlags.DESTROY_WITH_PARENT,
            type=Gtk.MessageType.ERROR, buttons=Gtk.ButtonsType.OK)
        self.set_markup ("<big><span weight=\"bold\">%s</span></big>" % _("Timer could not be created"))
        self.format_secondary_text(
            _("Make sure that the timer doesn't conflict with another one and doesn't start in the past.")
        )

class TimerSuccessDialog(Gtk.MessageDialog):

    def __init__(self, parent_window):
        Gtk.MessageDialog.__init__(self, parent=parent_window,
                    flags=Gtk.DialogFlags.MODAL|Gtk.DialogFlags.DESTROY_WITH_PARENT,
                    type=Gtk.MessageType.INFO, buttons=Gtk.ButtonsType.OK)
        self.set_markup("<big><span weight=\"bold\">%s</span></big>" % (
            _("Recording has been scheduled successfully"))
        )

