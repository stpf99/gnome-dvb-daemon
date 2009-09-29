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

__all__ = ["AlignedLabel", "Frame", "BaseFrame"]

class AlignedChild(gtk.Alignment):
    
    def __init__(self, child):
        gtk.Alignment.__init__(self, xscale=1.0, yscale=1.0)
        
        self.set_padding(0, 0, 12, 0)
        self.add(child)
        child.show()
       
class BaseFrame(gtk.VBox):

    def __init__(self, markup, child):
        gtk.VBox.__init__(self, spacing=6)
    
        label = AlignedLabel(markup)
        label.show()
        self.pack_start(label, False, False, 0)
        
        achild = AlignedChild(child)
        achild.show()
        self.pack_start(achild)

class AlignedLabel (gtk.Alignment):

    def __init__(self, markup):
        gtk.Alignment.__init__(self)
        
        self.label = gtk.Label()
        self.label.set_markup(markup)
        self.label.show()
        self.add(self.label)

class Frame (BaseFrame):

    def __init__(self, markup, treeview):
        scrolled = gtk.ScrolledWindow()
        scrolled.set_shadow_type(gtk.SHADOW_ETCHED_IN)
        scrolled.set_policy(gtk.POLICY_AUTOMATIC, gtk.POLICY_AUTOMATIC)
        scrolled.add(treeview)
        
        BaseFrame.__init__(self, markup, scrolled)
        
