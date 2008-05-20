#!/usr/bin/env python
# -*- coding: utf-8 -*-
import dbus
import dbus.glib
import gobject

service = "org.gnome.DVB"
manager_iface = "org.gnome.DVB.Manager"
manager_path = "/org/gnome/DVB/Manager"
scanner_iface = "org.gnome.DVB.Scanner.Terrestrial"

pro7 = [690000000, 4, 0, 1, 0, 9, 3, 4]

class DVBClient:

    def __init__(self):
        self.bus = dbus.SessionBus()
        # Get proxy object
        proxy = self.bus.get_object(service, manager_path)
        # Apply the correct interace to the proxy object
        self.manager = dbus.Interface(proxy, manager_iface)
        
    def get_scanner_for_device(self, adapter, frontend):
        objpath = self.manager.GetScannerForDevice (adapter, frontend)
        print objpath
        proxy = self.bus.get_object(service, objpath)
        self.scanner = dbus.Interface(proxy, scanner_iface)
        
    def add_scanning_data(self):
        self.scanner.AddScanningData (*pro7)
        
    def scan(self):
        self.scanner.Run()
        
c = DVBClient()
c.get_scanner_for_device(0,0)
c.add_scanning_data()
c.scan()

loop = gobject.MainLoop()
loop.run()
