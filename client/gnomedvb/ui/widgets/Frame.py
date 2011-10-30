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

from gi.repository import GObject
from gi.repository import Gtk

__all__ = ["Frame", "BaseFrame", "TextFieldLabel"]

class BaseFrame(Gtk.Box):

    def __init__(self, markup, child, expand=True, fill=True, padding=0):
        GObject.GObject.__init__(self, orientation=Gtk.Orientation.VERTICAL,
            spacing=6)
    
        label = Gtk.Label()
        label.set_halign(Gtk.Align.START)
        label.set_markup(markup)
        label.show()
        self.pack_start(label, False, False, 0)
        
        self.child_widget = child
        self.child_widget.set_margin_left(12)
        self.child_widget.show()
        self.pack_start(self.child_widget, expand, fill, padding)
        
    def set_aligned_child(self, child, expand=True, fill=True, padding=0):
        self.remove(self.child_widget)
        self.child_widget = child
        self.child_widget.set_margin_left(12)
        self.child_widget.show()
        self.pack_start(self.child_widget, expand, fill, padding)

class TextFieldLabel(Gtk.Label):

    def __init__(self, markup=None, **kwargs):
        GObject.GObject.__init__(self, **kwargs)
        
        if markup:
            self.set_markup(markup)
        self.set_halign(Gtk.Align.START)
        self.set_valign(Gtk.Align.CENTER)

class Frame (BaseFrame):

    def __init__(self, markup, treeview):
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_shadow_type(Gtk.ShadowType.ETCHED_IN)
        scrolled.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        scrolled.add(treeview)
        
        BaseFrame.__init__(self, markup, scrolled)
        
