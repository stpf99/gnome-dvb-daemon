#!/usr/bin/env python
# -*- coding: utf-8 -*-
import dbus
import dbus.glib
import gobject
import gst
import re

__all__= [
    "get_adapter_info",
    "get_dvb_devices",
    "DVBManagerClient",
    "DVBScannerClient",
    "DVBRecordingsStoreClient",
    "DVBRecorderClient",
    "DVBChannelListClient",
    "DVBScheduleClient",
]

service = "org.gnome.DVB"
manager_iface = "org.gnome.DVB.Manager"
manager_path = "/org/gnome/DVB/Manager"
recstore_iface = "org.gnome.DVB.RecordingsStore"
recstore_path = "/org/gnome/DVB/RecordingsStore"
recorder_iface = "org.gnome.DVB.Recorder"
channel_list_iface = "org.gnome.DVB.ChannelList"
schedule_iface = "org.gnome.DVB.Schedule"
sat_scanner_iface = "org.gnome.DVB.Scanner.Satellite"
cable_scanner_iface = "org.gnome.DVB.Scanner.Cable"
terrestrial_scanner_iface = "org.gnome.DVB.Scanner.Terrestrial"

HAL_MANAGER_IFACE = "org.freedesktop.Hal.Manager"
HAL_DEVICE_IFACE = "org.freedesktop.Hal.Device"
HAL_MANAGER_PATH = "/org/freedesktop/Hal/Manager"
HAL_SERVICE = "org.freedesktop.Hal"

def get_adapter_info(adapter):
    dvbelement = gst.element_factory_make ("dvbsrc", "test_dvbsrc")
    dvbelement.set_property("adapter", int(adapter))
    pipeline = gst.Pipeline("")
    pipeline.add(dvbelement)
    pipeline.set_state(gst.STATE_READY)
    pipeline.get_state()
    bus = pipeline.get_bus()
    info = {}
    while bus.have_pending():
        msg = bus.pop()
        if msg.type == gst.MESSAGE_ELEMENT and msg.src == dvbelement:
            structure = msg.structure
            if structure.get_name() == "dvb-adapter":
                info["type"] = structure["type"]
                info["name"] = structure["name"]
                break
    pipeline.set_state(gst.STATE_NULL)
    return info

def get_dvb_devices():
    bus = dbus.SystemBus()
    # Get proxy object
    proxy = bus.get_object(HAL_SERVICE, HAL_MANAGER_PATH)
    # Apply the correct interace to the proxy object
    halmanager = dbus.Interface(proxy, HAL_MANAGER_IFACE)
    objects = halmanager.FindDeviceByCapability("dvb")

    deviceslist = []
    for o in objects:
	    proxy = bus.get_object(HAL_SERVICE, o)
	    dev = dbus.Interface(proxy, HAL_DEVICE_IFACE)

	    dev_file = dev.GetProperty("linux.device_file")
	
	    match = re.search("adapter(\d+?)/frontend(\d+?)", dev_file)
	    if match != None:
		    adapter = int(match.group(1))
		    info = {}
		    info["adapter"] = adapter
		    info["frontend"] = int(match.group(2))
		    deviceslist.append(info)
			
    return deviceslist

class DVBManagerClient(gobject.GObject):
    
    __gsignals__ = {
        "changed":        (gobject.SIGNAL_RUN_LAST, gobject.TYPE_NONE, [int, int]),
        "group-changed":  (gobject.SIGNAL_RUN_LAST, gobject.TYPE_NONE, [int, int, int, int]),
    }
    
    def __init__(self):
        gobject.GObject.__init__(self)
    
        bus = dbus.SessionBus()
        # Get proxy object
        proxy = bus.get_object(service, manager_path)
        # Apply the correct interace to the proxy object
        self.manager = dbus.Interface(proxy, manager_iface)
        self.manager.connect_to_signal("Changed", self.on_changed)
        self.manager.connect_to_signal("GroupChanged", self.on_group_changed)
        
    def get_scanner_for_device(self, adapter, frontend):
        objpath, scanner_iface = self.manager.GetScannerForDevice (adapter, frontend)
        return DVBScannerClient(objpath, scanner_iface)
        
    def get_registered_device_groups(self):
        return self.manager.GetRegisteredDeviceGroups()
        
    def get_recorder(self, group_id):
        return self.manager.GetRecorder(group_id)
        
    def add_device_to_new_group (self, adapter, frontend, channels_file, recordings_dir, name):
        return self.manager.AddDeviceToNewGroup(adapter, frontend, channels_file, recordings_dir, name)
        
    def add_device_to_existing_group (self, adapter, frontend, group_id):
        return self.manager.AddDeviceToExistingGroup(adapter, frontend, group_id)
        
    def remove_device_from_group(self, adapter, frontend, group_id):
        return self.manager.RemoveDeviceFromGroup(adapter, frontend, group_id)
        
    def get_device_group_members(self, group_id):
        return self.manager.GetDeviceGroupMembers(group_id)
        
    def get_device_group_name(self, group_id):
        return self.manager.GetDeviceGroupName(group_id)
        
    def get_type_of_device_group(self, group_id):
        return self.manager.GetTypeOfDeviceGroup(group_id)
        
    def get_name_of_registered_device(self, adapter, frontend):
        return self.manager.GetNameOfRegisteredDevice(adapter, frontend)
        
    def get_schedule(self, group_id, channel_sid):
        return DVBScheduleClient(self.manager.GetSchedule(group_id, channel_sid))
        
    def on_changed(self, group_id, change_type):
        self.emit("changed", group_id, change_type)
        
    def on_group_changed(self, group_id, adapter, frontend, change_type):
        self.emit("group-changed", group_id, adapter, frontend, change_type)
        
class DVBScannerClient(gobject.GObject):

    __gsignals__ = {
        "finished":          (gobject.SIGNAL_RUN_LAST, gobject.TYPE_NONE, []),
        "frequency-scanned": (gobject.SIGNAL_RUN_LAST, gobject.TYPE_NONE, [int]),
        "channel-added":     (gobject.SIGNAL_RUN_LAST, gobject.TYPE_NONE, [int, int, str, str, str]), 
        "destroyed":         (gobject.SIGNAL_RUN_LAST, gobject.TYPE_NONE, []),
    }

    def __init__(self, objpath, scanner_iface):
        gobject.GObject.__init__(self)
        
        bus = dbus.SessionBus()
        proxy = bus.get_object(service, objpath)
        self.scanner = dbus.Interface(proxy, scanner_iface)
        self.scanner.connect_to_signal ("Finished", self.on_finished)
        self.scanner.connect_to_signal ("FrequencyScanned", self.on_frequency_scanned)
        self.scanner.connect_to_signal ("ChannelAdded", self.on_channel_added)
        self.scanner.connect_to_signal ("Destroyed", self.on_destroyed)
        
    def add_scanning_data(self, data):
        self.scanner.AddScanningData (*data)
        
    def add_scanning_data_from_file(self, path):
        return self.scanner.AddScanningDataFromFile(path)
        
    def run(self):
        self.scanner.Run()
        
    def destroy(self):
        self.scanner.Destroy()
        
    def write_channels_to_file(self, channelfile):
        self.scanner.WriteChannelsToFile(channelfile)
        
    def get_queue_size(self):
        return self.scanner.GetQueueSize()
        
    def on_finished(self):
        self.emit("finished")
        
    def on_frequency_scanned(self, freq):
        self.emit("frequency-scanned", freq)
        
    def on_channel_added(self, freq, sid, name, network, channeltype):
        self.emit("channel-added", freq, sid, name, network, channeltype)
        
    def on_destroyed(self):
        self.emit("destroyed")
        
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
        
    def get_name(self, rid):
        return self.recstore.GetName(rid)
        
    def get_description(self, rid):
        return self.recstore.GetDescription(rid)
        
    def get_length(self, rid):
        return self.recstore.GetLength(rid)
        
    def get_start_time(self, rid):
        return self.recstore.GetStartTime(rid)
        
    def get_start_timestamp(self, rid):
        return self.recstore.GetStartTimestamp(rid)
        
    def delete(self, rid):
        return self.recstore.Delete(rid)
        
    def on_changed(self, rid, typeid):
        self.emit("changed", rid, typeid)
        
class DVBRecorderClient(gobject.GObject):

    __gsignals__ = {
        "recording-started": (gobject.SIGNAL_RUN_LAST, gobject.TYPE_NONE, [int]),
        "recording-finished": (gobject.SIGNAL_RUN_LAST, gobject.TYPE_NONE, [int]),
        "changed": (gobject.SIGNAL_RUN_LAST, gobject.TYPE_NONE, [int, int]),
    }

    def __init__(self, group_id):
        gobject.GObject.__init__(self)
        
        bus = dbus.SessionBus()
        # Get proxy object
        object_path = "/org/gnome/DVB/Recorder/%s" % group_id
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
        
    def add_timer_for_epg_event(self, event_id, channel_sid):
        return self.recorder.AddTimerForEPGEvent(event_id, channel_sid)
        
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
        self.emit("recording-started", timer_id)
        
    def on_recording_finished(self, timer_id):
        self.emit("recording-finished", timer_id)
         
    def on_changed(self, rid, typeid):
        self.emit("changed", rid, typeid)
           
class DVBChannelListClient:

    def __init__(self, group_id):
        bus = dbus.SessionBus()
        # Get proxy object
        object_path = "/org/gnome/DVB/ChannelList/%s" % group_id
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
        
    def get_channel_url(self, cid):
        return self.channels.GetChannelURL(cid)
        
class DVBScheduleClient(gobject.GObject):

    def __init__(self, object_path):
        gobject.GObject.__init__(self)
        
        bus = dbus.SessionBus()
        # Get proxy object
        proxy = bus.get_object(service, object_path)
        # Apply the correct interace to the proxy object
        self.schedule = dbus.Interface(proxy, schedule_iface)
        
    def get_all_events(self):
        return self.schedule.GetAllEvents()
        
    def now_playing(self):
        return self.schedule.NowPlaying()
        
    def next(self, eid):
        return self.schedule.Next(eid)
        
    def get_name(self, eid):
        return self.schedule.GetName(eid)
        
    def get_short_description(self, eid):
        return self.schedule.GetShortDescription(eid)
        
    def get_extended_description(self, eid):
        return self.schedule.GetExtendedDescription(eid)
        
    def get_duration(self, eid):
        return self.schedule.GetDuration(eid)
        
    def get_local_start_time(self, eid):
        return self.schedule.GetLocalStartTime(eid)
        
    def is_running(self, eid):
        return self.schedule.IsRunning(eid)
        
    def is_scrambled(self, eid):
        return self.schedule.IsScrambled(eid)
        
if __name__ == '__main__':
    loop = gobject.MainLoop()
    
    channelsfile = "/home/sebp/.gstreamer-0.10/dvb-channels.conf"
    #channelsfile = "/home/sebp/DVB/dvb-s-channels.conf"
    recdir = "/home/sebp/TV"
    
    #a = [586000000, 0, 8, "8k", "2/3", "1/4", "QAM16", 4]

    manager = DVBManagerClient ()
    #manager.add_device_to_new_group (0, 0, channelsfile, recdir)
    #manager.add_device_to_existing_group (1, 0, 1)
    
    #pro7_sat = [12544000, "horizontal", 22000]
    
    #scanner = manager.get_scanner_for_device(0, 0)
    #scanner.add_scanning_data(pro7_sat)
    #scanner.run()
    
    dev_groups = manager.get_registered_device_groups()
    
    for group_id in dev_groups:
        print "Members", manager.get_device_group_members(group_id)
    
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
            print "URL", channellist.get_channel_url(channel_id)
            schedule = manager.get_schedule (group_id, channel_id)
            event_now = schedule.now_playing()
            print u"Now: %s" % schedule.get_name(event_now)
            print u"\tDesc: %s" % schedule.get_short_description(event_now)
            time = schedule.get_local_start_time(event_now)
            if len(time) == 6:
                print u"\tStart: %04d-%02d-%02d %02d:%02d:%02d" % (time[0], time[1], time[2], time[3],
                    time[4], time[5])
            print u"\tDuration: %s" % schedule.get_duration(event_now)
            print
        
    recstore = DVBRecordingsStoreClient()
    for rid in recstore.get_recordings():
        print "Location", recstore.get_location(rid)
        print "Start", recstore.get_start_time(rid)
        print recstore.get_start_timestamp(rid)
        print "Length", recstore.get_length(rid)    
    
    loop.run()
