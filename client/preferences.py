#!/usr/bin/env python
# -*- coding: utf-8 -*-
import gtk
import gobject
import gnomedvb

class Device:

    pass

class UnassignedDevicesStore (gtk.ListStore):

    COL_DEVICE = range(1)
    
    def __init__(self):
        gtk.ListStore.__init__(self, gobject.TYPE_PYOBJECT)


class DeviceGroupsStore (gtk.TreeStore):

    COL_DEVICE = range(1)

    def __init__(self):
        gtk.TreeStore.__init__(self, gobject.TYPE_PYOBJECT)
        
        
class DeviceGroupsView (gtk.TreeView):

    def __init__(self, model):
        gtk.TreeView.__init__(self, model)
        
        cell_description = gtk.CellRendererText ()
        column_description = gtk.TreeViewColumn ("Description", cell_description)
        column_description.set_cell_data_func(cell_description, self.get_description_data)
        
    def get_description_data(self, column, cell, model, aiter):
        device = model[aiter][model.COL_DEVICE]


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

class DVBPreferences(gtk.Window):

    def __init__(self):
        gtk.Window.__init__(self)
        
        self.connect('delete-event', gtk.main_quit)
        self.connect('destroy-event', gtk.main_quit)
        self.set_title("Configure DVB")
        self.set_default_size(400, 250)
        self.set_border_width(6)
        
        self.vbox = gtk.VBox(spacing=12)
        self.add(self.vbox)
        self.vbox.show()
        
        self.devicegroups = DeviceGroupsStore()
        self.devicegroupsview = DeviceGroupsView(self.devicegroups)
        self.devicegroupsview.show()
        
        groups_frame = Frame("<b>Registered groups</b>", self.devicegroupsview)
        groups_frame.show()
        self.vbox.pack_start(groups_frame)

        self.unassigned_devices = UnassignedDevicesStore()
        self.unassigned_view = gtk.TreeView(self.unassigned_devices)
        self.unassigned_view.show()
        
        unassigned_frame = Frame("<b>Unassigned devices</b>", self.unassigned_view)
        unassigned_frame.show()
        self.vbox.pack_start(unassigned_frame)
        
        buttonbox = gtk.HButtonBox()
        buttonbox.set_layout(gtk.BUTTONBOX_END)
        buttonbox.show()
        self.vbox.pack_end(buttonbox)
        
        close_button = gtk.Button(stock=gtk.STOCK_CLOSE)
        close_button.connect('clicked', gtk.main_quit)
        buttonbox.pack_start(close_button)
        close_button.show()
        
        separator = gtk.HSeparator()
        separator.show()
        self.vbox.pack_end(separator)

if __name__=='__main__':
    prefs = DVBPreferences()
    prefs.show()
    gtk.main()
