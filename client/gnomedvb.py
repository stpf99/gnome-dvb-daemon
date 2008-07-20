#!/usr/bin/env python
# -*- coding: utf-8 -*-
import dbus
import dbus.glib
import gobject
import gst

service = "org.gnome.DVB"
manager_iface = "org.gnome.DVB.Manager"
manager_path = "/org/gnome/DVB/Manager"
recstore_iface = "org.gnome.DVB.RecordingsStore"
recstore_path = "/org/gnome/DVB/RecordingsStore"
recorder_iface = "org.gnome.DVB.Recorder"
channel_list_iface = "org.gnome.DVB.ChannelList"
sat_scanner_iface = "org.gnome.DVB.Scanner.Satellite"
cable_scanner_iface = "org.gnome.DVB.Scanner.Cable"
terrestrial_scanner_iface = "org.gnome.DVB.Scanner.Terrestrial"

def get_adapter_type(adapter):
    dvbelement = gst.element_factory_make ("dvbsrc", "test_dvbsrc")
    dvbelement.set_property("adapter", int(adapter))
    pipeline = gst.Pipeline("")
    pipeline.add(dvbelement)
    pipeline.set_state(gst.STATE_READY)
    pipeline.get_state()
    bus = pipeline.get_bus()
    adaptertype = None
    while bus.have_pending():
        msg = bus.pop()
        if msg.type == gst.MESSAGE_ELEMENT and msg.src == dvbelement:
            structure = msg.structure
            if structure.get_name() == "dvb-adapter":
                adaptertype = structure["type"]
                break
    pipeline.set_state(gst.STATE_NULL)
    return adaptertype

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
        
    def get_registered_device_groups(self):
        return self.manager.GetRegisteredDeviceGroups()
        
    def get_recorder(self, group_id):
        return self.manager.GetRecorder(group_id)
        
    def add_device_to_new_group (self, adapter, frontend, channels_file, recordings_dir):
        return self.manager.AddDeviceToNewGroup(adapter, frontend, channels_file, recordings_dir)
        
    def add_device_to_existing_group (self, adapter, frontend, group_id):
        return self.manager.AddDeviceToExistingGroup(adapter, frontend, group_id)
        
    def remove_device_from_group(self, adapter, frontend, group_id):
        return self.manager.RemoveDeviceFromGroup(adapter, frontend, group_id)
        
    def delete_device_group(group_id):
        return self.manager.DeleteDeviceGroup(group_id)
        
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

    def __init__(self, group_od):
        gobject.GObject.__init__(self)
        
        bus = dbus.SessionBus()
        # Get proxy object
        object_path = "/org/gnome/DVB/Recorder/%d" % group_id
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
        
    def get_active_timers(self):
        return self.recorder.GetActiveTimers()
        
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

    def __init__(self, group_id):
        bus = dbus.SessionBus()
        # Get proxy object
        object_path = "/org/gnome/DVB/ChannelList/%d" % group_id
        proxy = bus.get_object(service, object_path)
        # Apply the correct interace to the proxy object
        self.channels = dbus.Interface(proxy, channel_list_iface)
        self.object_path = object_path
        
    def get_path(self):
        return self.object_path
        
    def get_channels(self):
        return self.channels.GetChannels()
        
    def get_radio_channels(self):
        return self.channels.GetRadioChannels()
        
    def get_tv_channels(self):
        return self.channels.GetTVChannels()
        
    def get_channel_name(self, cid):
        return self.channels.GetChannelName(cid)
        
    def get_channel_network(self, cid):
        return self.channels.GetChannelNetwork(cid)
        
    def is_radio_channel(self, cid):
        return self.channels.IsRadioChannel(cid)
        
if __name__ == '__main__':
    loop = gobject.MainLoop()
    
    channelsfile = "/home/sebp/.gstreamer-0.10/dvb-channels.conf"
    #channelsfile = "/home/sebp/DVB/dvb-s-channels.conf"
    recdir = "/home/sebp/TV"
    
    #a = [586000000, 0, 8, "8k", "2/3", "1/4", "QAM16", 4]

    manager = DVBManagerClient ()
    manager.add_device_to_new_group (0, 0, channelsfile, recdir)
    #manager.add_device_to_existing_group (1, 0, 1)
    
    #pro7_sat = [12544000, "horizontal", 22000]
    
    #scanner = manager.get_scanner_for_device(0, 0)
    #scanner.add_scanning_data(pro7_sat)
    #scanner.run()
    
    dev_groups = manager.get_registered_device_groups()
    
    for group_id in dev_groups:
        rec = DVBRecorderClient(group_id)
        timers = rec.get_timers()
        print timers
        for tid in timers:
            print "Start", rec.get_start_time(tid)
            print "End", rec.get_end_time(tid)
            print "Duration", rec.get_duration(tid)
            
        print rec.get_active_timers()
        
        print rec.add_timer(32, 2008, 7, 28, 23, 42, 2)
            
        channellist = DVBChannelListClient(group_id)
        print "RADIO CHANNELS"
        for channel_id in channellist.get_radio_channels():
            print "SID", channel_id
            print "Name", channellist.get_channel_name(channel_id)
            print "Network", channellist.get_channel_network(channel_id)
        print
        print "TV CHANNELS"
        for channel_id in channellist.get_tv_channels():
            print "SID", channel_id
            print "Name", channellist.get_channel_name(channel_id)
            print "Network", channellist.get_channel_network(channel_id)
        
    recstore = DVBRecordingsStoreClient()
    for rid in recstore.get_recordings():
        print "Location", recstore.get_location(rid)
        print "Start", recstore.get_start_time(rid)
        print recstore.get_start_timestamp(rid)
        print "Length", recstore.get_length(rid)    
    
    loop.run()
