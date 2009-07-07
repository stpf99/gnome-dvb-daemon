#!/usr/bin/env python
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

import dbus
import dbus.glib
import gobject
import gst
import re
import sys

__all__ = [
    "global_error_handler",
    "get_adapter_info",
    "get_dvb_devices",
    "DVBManagerClient",
    "DVBDeviceGroupClient",
    "DVBScannerClient",
    "DVBRecordingsStoreClient",
    "DVBRecorderClient",
    "DVBChannelListClient",
    "DVBScheduleClient",
]

SERVICE = "org.gnome.DVB"
MANAGER_IFACE = "org.gnome.DVB.Manager"
MANAGER_PATH = "/org/gnome/DVB/Manager"
DEVICE_GROUP_IFACE = "org.gnome.DVB.DeviceGroup"
RECSTORE_IFACE = "org.gnome.DVB.RecordingsStore"
RECSTORE_PATH = "/org/gnome/DVB/RecordingsStore"
RECORDER_IFACE = "org.gnome.DVB.Recorder"
CHANNEL_LIST_IFACE = "org.gnome.DVB.ChannelList"
SCHEDULE_IFACE = "org.gnome.DVB.Schedule"

HAL_MANAGER_IFACE = "org.freedesktop.Hal.Manager"
HAL_DEVICE_IFACE = "org.freedesktop.Hal.Device"
HAL_MANAGER_PATH = "/org/freedesktop/Hal/Manager"
HAL_SERVICE = "org.freedesktop.Hal"

def _default_error_handler_func(e):
    print >> sys.stderr, "Error: "+str(e)

global_error_handler = _default_error_handler_func

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

def get_dvb_devices(reply_handler, error_handler):
    def find_devices_handler(objects):
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
                
        reply_handler(deviceslist)
    
    bus = dbus.SystemBus()
    # Get proxy object
    proxy = bus.get_object(HAL_SERVICE, HAL_MANAGER_PATH)
    # Apply the correct interace to the proxy object
    halmanager = dbus.Interface(proxy, HAL_MANAGER_IFACE)
    objects = halmanager.FindDeviceByCapability("dvb", reply_handler=find_devices_handler, error_handler=error_handler)

class DVBManagerClient(gobject.GObject):
    
    __gsignals__ = {
        "group-added":  (gobject.SIGNAL_RUN_LAST, gobject.TYPE_NONE, [int]),
        "group-removed":  (gobject.SIGNAL_RUN_LAST, gobject.TYPE_NONE, [int]),
    }
    
    def __init__(self):
        gobject.GObject.__init__(self)
    
        bus = dbus.SessionBus()
        # Get proxy object
        proxy = bus.get_object(SERVICE, MANAGER_PATH)
        # Apply the correct interace to the proxy object
        self.manager = dbus.Interface(proxy, MANAGER_IFACE)
        self.manager.connect_to_signal("GroupAdded", self.on_group_added)
        self.manager.connect_to_signal("GroupRemoved", self.on_group_removed)
        
    def get_scanner_for_device(self, adapter, frontend):
        objpath, scanner_iface = self.manager.GetScannerForDevice (adapter, frontend)
        return DVBScannerClient(objpath, scanner_iface)
        
    def get_device_group(self, group_id):
        path = self.manager.GetDeviceGroup(group_id)
        return DVBDeviceGroupClient(path)
        
    def get_registered_device_groups(self, reply_handler, error_handler):
        def groups_handler(paths):
            reply_handler([DVBDeviceGroupClient(path) for path in paths])
        self.manager.GetRegisteredDeviceGroups(reply_handler=groups_handler, error_handler=error_handler)
       
    def add_device_to_new_group (self, adapter, frontend, channels_file, recordings_dir, name, **kwargs):
        return self.manager.AddDeviceToNewGroup(adapter, frontend, channels_file, recordings_dir, name, **kwargs)
       
    def get_name_of_registered_device(self, adapter, frontend):
        return self.manager.GetNameOfRegisteredDevice(adapter, frontend)
        
    def get_device_group_size(self):
        return self.manager.GetDeviceGroupSize()
    
    def on_group_added(self, group_id):
        self.emit("group-added", group_id)
 
    def on_group_removed(self, group_id):
        self.emit("group-removed", group_id)

class DVBDeviceGroupClient(gobject.GObject):

    __gsignals__ = {
        "device-added":  (gobject.SIGNAL_RUN_LAST, gobject.TYPE_NONE, [int, int]),
        "device-removed":  (gobject.SIGNAL_RUN_LAST, gobject.TYPE_NONE, [int, int]),
    }
    
    def __init__(self, objpath):
        gobject.GObject.__init__(self)
        
        elements = objpath.split("/")
        
        self._id = int(elements[5])
        
        bus = dbus.SessionBus()
        # Get proxy object
        proxy = bus.get_object(SERVICE, objpath)
        # Apply the correct interace to the proxy object
        self.devgroup = dbus.Interface(proxy, DEVICE_GROUP_IFACE)
        self.devgroup.connect_to_signal("DeviceAdded", self.on_device_added)
        self.devgroup.connect_to_signal("DeviceRemoved", self.on_device_removed)
        
    def get_id(self):
        return self._id
         
    def get_recorder(self):
        path = self.devgroup.GetRecorder()
        return DVBRecorderClient(path)
        
    def add_device (self, adapter, frontend, **kwargs):
        return self.devgroup.AddDevice(adapter, frontend, **kwargs)
        
    def remove_device(self, adapter, frontend):
        return self.devgroup.RemoveDevice(adapter, frontend)
    
    def get_channel_list(self):
        path = self.devgroup.GetChannelList()
        return DVBChannelListClient(path)
    
    def get_members(self):
        return self.devgroup.GetMembers()
        
    def get_name(self):
        return self.devgroup.GetName()
    
    def set_name(self, name):
        return self.devgroup.SetName(name)
        
    def get_type(self):
        return self.devgroup.GetType()
        
    def get_schedule(self, channel_sid):
        path = self.devgroup.GetSchedule(channel_sid)
        return DVBScheduleClient(path)
        
    def get_recordings_directory (self):
        return self.devgroup.GetRecordingsDirectory()
        
    def set_recordings_directory (self, location):
        return self.devgroup.SetRecordingsDirectory(location)
     
    def on_device_added(self, adapter, frontend):
        self.emit("device-added", adapter, frontend)
 
    def on_device_removed(self, adapter, frontend):
        self.emit("device-removed", adapter, frontend)

class DVBScannerClient(gobject.GObject):

    __gsignals__ = {
        "finished":          (gobject.SIGNAL_RUN_LAST, gobject.TYPE_NONE, []),
        "frequency-scanned": (gobject.SIGNAL_RUN_LAST, gobject.TYPE_NONE, [int, int]),
        "channel-added":     (gobject.SIGNAL_RUN_LAST, gobject.TYPE_NONE, [int, int, str, str, str, bool]),
        "destroyed":         (gobject.SIGNAL_RUN_LAST, gobject.TYPE_NONE, []),
    }

    def __init__(self, objpath, scanner_iface):
        gobject.GObject.__init__(self)
        
        bus = dbus.SessionBus()
        proxy = bus.get_object(SERVICE, objpath)
        self.scanner = dbus.Interface(proxy, scanner_iface)
        self.scanner.connect_to_signal ("Finished", self.on_finished)
        self.scanner.connect_to_signal ("FrequencyScanned", self.on_frequency_scanned)
        self.scanner.connect_to_signal ("ChannelAdded", self.on_channel_added)
        self.scanner.connect_to_signal ("Destroyed", self.on_destroyed)
        
    def add_scanning_data(self, data):
        self.scanner.AddScanningData (*data)
        
    def add_scanning_data_from_file(self, path, **kwargs):
        return self.scanner.AddScanningDataFromFile(path, **kwargs)
        
    def run(self):
        self.scanner.Run()
        
    def destroy(self):
        self.scanner.Destroy()
        
    def write_channels_to_file(self, channel_sids, channelfile, **kwargs):
        self.scanner.WriteChannelsToFile(channel_sids, channelfile, **kwargs)
        
    def write_all_channels_to_file(self, channelfile, **kwargs):
        self.scanner.WriteAllChannelsToFile(channelfile, **kwargs)
    
    def on_finished(self):
        self.emit("finished")
        
    def on_frequency_scanned(self, freq, freq_left):
        self.emit("frequency-scanned", freq, freq_left)
        
    def on_channel_added(self, freq, sid, name, network, channeltype, scrambled):
        self.emit("channel-added", freq, sid, name, network, channeltype, scrambled)
        
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
        proxy = bus.get_object(SERVICE, RECSTORE_PATH)
        # Apply the correct interace to the proxy object
        self.recstore = dbus.Interface(proxy, RECSTORE_IFACE)
        self.recstore.connect_to_signal ("Changed", self.on_changed)
        
    def get_recordings(self, **kwargs):
        return self.recstore.GetRecordings(**kwargs)
        
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
        
    def delete(self, rid, **kwargs):
        return self.recstore.Delete(rid, **kwargs)
        
    def get_channel_name(self, rid):
        return self.recstore.GetChannelName(rid)
        
    def get_all_informations(self, rid):
        return self.recstore.GetAllInformations(rid)
        
    def on_changed(self, rid, typeid):
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
        proxy = bus.get_object(SERVICE, object_path)
        # Apply the correct interace to the proxy object
        self.recorder = dbus.Interface(proxy, RECORDER_IFACE)
        self.recorder.connect_to_signal("RecordingStarted", self.on_recording_started)
        self.recorder.connect_to_signal("RecordingFinished", self.on_recording_finished)
        self.recorder.connect_to_signal("Changed", self.on_changed)
        self.object_path = object_path
        
    def get_path(self):
        return self.object_path
        
    def add_timer (self, channel, year, month, day, hour, minute, duration):
        return self.recorder.AddTimer(channel, year, month, day, hour, minute, duration)
        
    def add_timer_with_margin (self, channel, year, month, day, hour, minute, duration):
        return self.recorder.AddTimerWithMargin(channel, year, month, day, hour, minute, duration)
        
    def add_timer_for_epg_event(self, event_id, channel_sid):
        return self.recorder.AddTimerForEPGEvent(event_id, channel_sid)
        
    def delete_timer(self, tid):
        return self.recorder.DeleteTimer(tid)
        
    def get_timers(self, **kwargs):
        return self.recorder.GetTimers(**kwargs)
        
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
        
    def has_timer_for_event(self, event_id, channel_sid):
        return self.recorder.HasTimerForEvent(event_id, channel_sid)
        
    def on_recording_started(self, timer_id):
        self.emit("recording-started", timer_id)
        
    def on_recording_finished(self, timer_id):
        self.emit("recording-finished", timer_id)
         
    def on_changed(self, rid, typeid):
        self.emit("changed", rid, typeid)
           
class DVBChannelListClient:

    def __init__(self, object_path):
        bus = dbus.SessionBus()
        # Get proxy object
        proxy = bus.get_object(SERVICE, object_path)
        # Apply the correct interace to the proxy object
        self.channels = dbus.Interface(proxy, CHANNEL_LIST_IFACE)
        self.object_path = object_path
        
    def get_path(self):
        return self.object_path
        
    def get_channels(self, **kwargs):
        return self.channels.GetChannels(**kwargs)
        
    def get_radio_channels(self, **kwargs):
        return self.channels.GetRadioChannels(**kwargs)
        
    def get_tv_channels(self, **kwargs):
        return self.channels.GetTVChannels(**kwargs)
        
    def get_channel_name(self, cid):
        return self.channels.GetChannelName(cid)
        
    def get_channel_network(self, cid):
        return self.channels.GetChannelNetwork(cid)
        
    def is_radio_channel(self, cid):
        return self.channels.IsRadioChannel(cid)
        
    def get_channel_url(self, cid):
        return self.channels.GetChannelURL(cid)
        
    def get_channel_infos(self, **kwargs):
        return self.channels.GetChannelInfos(**kwargs)
        
class DVBScheduleClient(gobject.GObject):

    def __init__(self, object_path):
        gobject.GObject.__init__(self)
        
        # "/org/gnome/DVB/DeviceGroup/%u/Schedule/%u";
        elements = object_path.split("/")
        
        self._group = int(elements[5])
        self._sid = int(elements[7])
        
        bus = dbus.SessionBus()
        # Get proxy object
        proxy = bus.get_object(SERVICE, object_path)
        # Apply the correct interace to the proxy object
        self.schedule = dbus.Interface(proxy, SCHEDULE_IFACE)
        
    def get_group_id(self):
        return self._group
        
    def get_channel_sid(self):
        return self._sid
        
    def get_all_events(self, **kwargs):
        return self.schedule.GetAllEvents(**kwargs)
        
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
        
    def get_local_start_timestamp(self, eid):
        return self.schedule.GetLocalStartTimestamp(eid)
        
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
    
    def device_handler(dev_groups):
        for dev_group in dev_groups:
            print "Members", dev_group.get_members()
        
            rec = dev_group.get_recorder()
            timers = rec.get_timers()
            print timers
            for tid in timers:
                print "Start", rec.get_start_time(tid)
                print "End", rec.get_end_time(tid)
                print "Duration", rec.get_duration(tid)
                
            print rec.get_active_timers()
            
            print rec.add_timer(32, 2008, 7, 28, 23, 42, 2)
                
            channellist = dev_group.get_channel_list()
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
                schedule = dev_group.get_schedule (channel_id)
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
            print "Channel", recstore.get_channel_name(rid)
            print "Location", recstore.get_location(rid)
            print "Start", recstore.get_start_time(rid)
            print recstore.get_start_timestamp(rid)
            print "Length", recstore.get_length(rid)    
            print "Name", recstore.get_name (rid)
            print "Desc", recstore.get_description(rid)
    
    dev_groups = manager.get_registered_device_groups(reply_handler=device_handler)
    
    loop.run()
