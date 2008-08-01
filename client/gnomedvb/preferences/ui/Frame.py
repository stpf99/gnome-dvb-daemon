# -*- coding: utf-8 -*-
import gtk

__all__ = ["AlignedLabel", "AlignedScrolledWindow", "Frame"]

class AlignedLabel (gtk.Alignment):

    def __init__(self, markup):
        gtk.Alignment.__init__(self)
        
        self.label = gtk.Label()
        self.label.set_markup(markup)
        self.label.show()
        self.add(self.label)


class AlignedScrolledWindow (gtk.Alignment):

    def __init__(self, treeview):
        gtk.Alignment.__init__(self, xscale=1.0, yscale=1.0)
        
        self.set_padding(0, 0, 12, 0)
        
        scrolled = gtk.ScrolledWindow()
        scrolled.set_shadow_type(gtk.SHADOW_ETCHED_IN)
        scrolled.set_policy(gtk.POLICY_AUTOMATIC, gtk.POLICY_AUTOMATIC)
        scrolled.add(treeview)
        scrolled.show()
        self.add(scrolled)

class Frame (gtk.VBox):

    def __init__(self, markup, child):
        gtk.VBox.__init__(self, spacing=6)
    
        label = AlignedLabel(markup)
        label.show()
        self.pack_start(label, False, False, 0)
        
        view = AlignedScrolledWindow(child)
        view.show()
        self.pack_start(view)
        
