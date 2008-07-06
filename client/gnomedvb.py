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
recorder_iface = "org.gnome.DVB.Recorder"
channel_list_iface = "org.gnome.DVB.ChannelList"

class DVBManagerClient:

    def __init__(self):
        bus = dbus.SessionBus()
        # Get proxy object
        proxy = bus.get_object(service, manager_path)
        # Apply the correct interace to the proxy object
        self.manager = dbus.Interface(proxy, manager_iface)
        
    def get_scanner_for_device(self, adapter, frontend):
        objpath, scanner_iface = self.manager.GetScannerForDevice (adapter, frontend)
        return DVBScannerClient(objpath, scanner_iface)
        
    def get_recorders(self):
        return self.manager.GetRecorders()
        
    def get_registered_devices(self):
        return self.manager.GetRegisteredDevices()
        
    def get_recorder(self, adapter, frontend):
        self.manager.GetRecorder(adapter, frontend)
        
    def register_device (self, adapter, frontend, channels_file, recordings_dir):
        self.manager.RegisterDevice(adapter, frontend, channels_file, recordings_dir)
        
class DVBScannerClient(gobject.GObject):

    __gsignals__ = {
        "finished": (gobject.SIGNAL_RUN_LAST, gobject.TYPE_NONE, []),
    }

    def __init__(self, objpath, scanner_iface):
        gobject.GObject.__init__(self)
        
        bus = dbus.SessionBus()
        proxy = bus.get_object(service, objpath)
        self.scanner = dbus.Interface(proxy, scanner_iface)
        self.scanner.connect_to_signal ("Finished", self.on_finished)
        
    def add_scanning_data(self, data):
        self.scanner.AddScanningData (*data)
        
    def run(self):
        self.scanner.Run()
        
    def abort(self):
        self.scanner.Abort()
        
    def write_channels_to_file(self, channelfile):
        self.scanner.WriteChannelsToFile(channelfile)
        
    def on_finished(self):
        print "Done scanning"
        self.emit("finished")
        
class DVBRecordingsStoreClient(gobject.GObject):

    __gsignals__ = {
        "changed": (gobject.SIGNAL_RUN_LAST, gobject.TYPE_NONE, [int, int]),
    }

    def __init__(self):
        gobject.GObject.__init__(self)
        
        bus = dbus.SessionBus()
        # Get proxy object
        proxy = bus.get_object(service, recstore_path)
        # Apply the correct interace to the proxy object
        self.recstore = dbus.Interface(proxy, recstore_iface)
        self.recstore.connect_to_signal ("Changed", self.on_changed)
        
    def get_recordings(self):
        return self.recstore.GetRecordings()
        
    def get_location(self, rid):
        return self.recstore.GetLocation(rid)
        
    def get_length(self, rid):
        return self.recstore.GetLength(rid)
        
    def get_start_time(self, rid):
        return self.recstore.GetStartTime(rid)
        
    def get_start_timestamp(self, rid):
        return self.recstore.GetStartTimestamp(rid)
        
    def delete(self, rid):
        return self.recstore.Delete(rid)
        
    def on_changed(self, rid, typeid):
        if (typeid == 0):
            print "Recording %d added" % rid
        elif (typeid == 1):
            print "Recording %d deleted" % rid
        elif (typeid == 2):
            print "Recording %d changed" % rid
        else:
            print "Unknown change type"
        self.emit("changed", rid, typeid)
        
class DVBRecorderClient(gobject.GObject):

    __gsignals__ = {
        "recording-started": (gobject.SIGNAL_RUN_LAST, gobject.TYPE_NONE, [int]),
        "recording-finished": (gobject.SIGNAL_RUN_LAST, gobject.TYPE_NONE, [int]),
        "changed": (gobject.SIGNAL_RUN_LAST, gobject.TYPE_NONE, [int, int]),
    }

    def __init__(self, object_path):
        gobject.GObject.__init__(self)
        
        bus = dbus.SessionBus()
        # Get proxy object
        proxy = bus.get_object(service, object_path)
        # Apply the correct interace to the proxy object
        self.recorder = dbus.Interface(proxy, recorder_iface)
        self.recorder.connect_to_signal("RecordingStarted", self.on_recording_started)
        self.recorder.connect_to_signal("RecordingFinished", self.on_recording_finished)
        self.recorder.connect_to_signal("Changed", self.on_changed)
        self.object_path = object_path
        
    def get_path(self):
        return self.object_path
        
    def add_timer (self, channel, year, month, day, hour, minute, duration):
        return self.recorder.AddTimer(channel, year, month, day, hour, minute, duration)
        
    def delete_timer(self, tid):
        return self.recorder.DeleteTimer(tid)
        
    def get_timers(self):
        return self.recorder.GetTimers()
        
    def get_start_time(self, tid):
        return self.recorder.GetStartTime(tid)
        
    def get_end_time(self, tid):
        return self.recorder.GetEndTime(tid)
        
    def get_duration(self, tid):
        return self.recorder.GetDuration(tid)
        
    def get_channel_name(self, tid):
        return self.recorder.GetChannelName(tid)
        
    def get_active_timer(self):
        return self.recorder.GetActiveTimer()
        
    def is_timer_active(self, tid):
        return self.recorder.IsTimerActive(tid)
        
    def has_timer(self, year, month, day, hour, minute, duration):
        return self.recorder.HasTimer(year, month, day, hour, minute, duration)
        
    def on_recording_started(self, timer_id):
        print "Recording %d started" % timer_id
        self.emit("recording-started", timer_id)
        
    def on_recording_finished(self, timer_id):
        print "Recording %d finished" % timer_id
        self.emit("recording-finished", timer_id)
         
    def on_changed(self, rid, typeid):
        if (typeid == 0):
            print "Timer %d added" % rid
        elif (typeid == 1):
            print "Timer %d deleted" % rid
        elif (typeid == 2):
            print "Timer %d changed" % rid
        else:
            print "Unknown change type"
        self.emit("changed", rid, typeid)
           
class DVBChannelListClient:

    def __init__(self, object_path):
        bus = dbus.SessionBus()
        # Get proxy object
        proxy = bus.get_object(service, object_path)
        # Apply the correct interace to the proxy object
        self.channels = dbus.Interface(proxy, channel_list_iface)
        self.object_path = object_path
        
    def get_path(self):
        return self.object_path
        
    def get_channels(self):
        return self.channels.GetChannels()
        
    def get_channel_name(self, cid):
        return self.channels.GetChannelName(cid)
        
    def get_channel_network(self, cid):
        return self.channels.GetChannelNetwork(cid)
           
if __name__ == '__main__':
    loop = gobject.MainLoop()
    
    channelsfile = "/home/sebp/.gstreamer-0.10/dvb-channels.conf"
    #channelsfile = "/home/sebp/DVB/dvb-s-channels.conf"
    recdir = "/home/sebp/TV"
        
    pro7 = [690000000, 4, 0, 1, 0, 9, 3, 4]
    rtl =  [578000000, 4, 0, 2, 0, 9, 3, 4]

    a = [586000000, 0, 8, "8k", "2/3", "1/4", "QAM16", 4]

    manager = DVBManagerClient ()
    manager.register_device (0, 0, channelsfile, recdir)
    #print manager.get_registered_devices()
    recorder_paths = manager.get_recorders()
    print recorder_paths
    
    for path in recorder_paths:
        rec = DVBRecorderClient(path)
        timers = rec.get_timers()
        print timers
        for tid in timers:
            print rec.get_start_time(tid)
            print rec.get_end_time(tid)
            print rec.get_duration(tid)
            
        print rec.get_active_timer()
        
        print rec.add_timer(32, 2008, 7, 28, 23, 42, 2)
        
    recstore = DVBRecordingsStoreClient()
    for rid in recstore.get_recordings():
        print recstore.get_location(rid)
        print recstore.get_start_time(rid)
        print recstore.get_start_timestamp(rid)
        print recstore.get_length(rid)    
        
    channel_list_path = "/org/gnome/DVB/ChannelList/0/0"
    channellist = DVBChannelListClient(channel_list_path)
    for channel_id in channellist.get_channels():
        print "SID", channel_id
        print "Name", channellist.get_channel_name(channel_id)
        print "Network", channellist.get_channel_network(channel_id)
    
    loop.run()
