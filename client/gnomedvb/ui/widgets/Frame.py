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

import gobject
from gi.repository import Gtk

__all__ = ["AlignedLabel", "Frame", "BaseFrame", "TextFieldLabel"]

class AlignedChild(Gtk.Alignment):
    
    def __init__(self, child):
        gobject.GObject.__init__(self, xscale=1.0, yscale=1.0)
        
        self.set_padding(0, 0, 12, 0)
        self.add(child)
        child.show()
       
class BaseFrame(Gtk.VBox):

    def __init__(self, markup, child, expand=True, fill=True, padding=0):
        gobject.GObject.__init__(self, spacing=6)
    
        label = AlignedLabel(markup)
        label.show()
        self.pack_start(label, False, False, 0)
        
        self.child_widget = AlignedChild(child)
        self.child_widget.show()
        self.pack_start(self.child_widget, expand, fill, padding)
        
    def set_aligned_child(self, child, expand=True, fill=True, padding=0):
        self.child_widget.remove(self.child_widget.get_children()[0])
        self.child_widget.add(child)
        child.show()

class AlignedLabel (Gtk.Alignment):

    def __init__(self, markup=None):
        gobject.GObject.__init__(self)
        
        self.label = Gtk.Label()
        if markup:
            self.label.set_markup(markup)
        self.label.show()
        self.add(self.label)
        
    def get_label(self):
        return self.label
        
class TextFieldLabel (AlignedLabel):

    def __init__(self, markup=None):
        AlignedLabel.__init__(self, markup)
        
        self.set_property("yalign", 0.5)

class Frame (BaseFrame):

    def __init__(self, markup, treeview):
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_shadow_type(Gtk.ShadowType.ETCHED_IN)
        scrolled.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        scrolled.add(treeview)
        
        BaseFrame.__init__(self, markup, scrolled)
        
