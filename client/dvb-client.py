#!/usr/bin/env python
# -*- coding: utf-8 -*-
import dbus
import dbus.glib
import gobject

service = "org.gnome.DVB"
manager_iface = "org.gnome.DVB.Manager"
manager_path = "/org/gnome/DVB/Manager"
recstore_iface = "org.gnome.DVB.RecordingsStore"
recstore_path = "/org/gnome/DVB/RecordingsStore"

pro7 = [690000000, 4, 0, 1, 0, 9, 3, 4]
rtl =  [578000000, 4, 0, 2, 0, 9, 3, 4]

a = [586000000, 0, 8, "8k", "2/3", "1/4", "QAM16", 4]

class DVBScannerClient:

    def __init__(self):
        self.bus = dbus.SessionBus()
        # Get proxy object
        proxy = self.bus.get_object(service, manager_path)
        # Apply the correct interace to the proxy object
        self.manager = dbus.Interface(proxy, manager_iface)
        
    def get_scanner_for_device(self, adapter, frontend):
        objpath, scanner_iface = self.manager.GetScannerForDevice (adapter, frontend)
        print objpath, scanner_iface
        proxy = self.bus.get_object(service, objpath)
        self.scanner = dbus.Interface(proxy, scanner_iface)
        self.scanner.connect_to_signal ("Finished", self.on_finished)
        
    def add_scanning_data(self):
        self.scanner.AddScanningData (*a)
        
    def scan(self):
        self.scanner.Run()
        
    def on_finished(self):
        print "Done scanning"
        self.scanner.WriteChannelsToFile ("/home/sebp/channels.conf")
        
class DVBRecordingsStoreClient:

    def __init__(self):
        self.bus = dbus.SessionBus()
        # Get proxy object
        proxy = self.bus.get_object(service, recstore_path)
        # Apply the correct interace to the proxy object
        self.recstore = dbus.Interface(proxy, recstore_iface)
        
    def get_recordings(self):
        return self.recstore.GetRecordings()
        
    def get_location(self, rid):
        return self.recstore.GetLocation(rid)
        
    def get_length(self, rid):
        return self.recstore.GetLength(rid)
        
    def get_start_time(self, rid):
        return self.recstore.GetStartTime(rid)
        
#c = DVBScannerClient()
#c.get_scanner_for_device(0,0)
#c.add_scanning_data()
#c.scan()
rec = DVBRecordingsStoreClient()
rids = rec.get_recordings()
print rec.get_location(rids[0])
print rec.get_length(rids[0])
print rec.get_start_time(rids[0])

loop = gobject.MainLoop()
loop.run()
