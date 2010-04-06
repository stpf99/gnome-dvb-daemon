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
import gnomedvb.udev

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
    success = False
    while bus.have_pending():
        msg = bus.pop()
        if msg.type == gst.MESSAGE_ELEMENT and msg.src == dvbelement:
            structure = msg.structure
            if structure.get_name() == "dvb-adapter":
                info["type"] = structure["type"]
                info["name"] = structure["name"]
                success = True
                break
        elif msg.type == gst.MESSAGE_ERROR:
            info = msg.structure["debug"]
            global_error_handler(info)
    pipeline.set_state(gst.STATE_NULL)
    return (success, info)

def get_dvb_devices():
    devices = gnomedvb.udev.get_dvb_devices()   

    deviceslist = []
    for dev in devices:
        match = re.search("adapter(\d+?)/frontend(\d+?)", dev["device_file"])
        if match != None:
            adapter = int(match.group(1))
            info = {}
            info["adapter"] = adapter
            info["frontend"] = int(match.group(2))
            deviceslist.append(info)
            
    return deviceslist
    
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
        objpath, scanner_iface, success = self.manager.GetScannerForDevice (adapter, frontend)
        if success:
            return DVBScannerClient(objpath, scanner_iface)
        else:
            return None
        
    def get_device_group(self, group_id):
        path, success = self.manager.GetDeviceGroup(group_id)
        if success:
            return DVBDeviceGroupClient(path)
        else:
            return None
        
    def get_registered_device_groups(self, **kwargs):
        if "reply_handler" in kwargs:
            reply_handler = kwargs["reply_handler"]
        else:
            reply_handler = None

        def groups_handler(paths):
            reply_handler([DVBDeviceGroupClient(path) for path in paths])
        
        if reply_handler != None:
            self.manager.GetRegisteredDeviceGroups(reply_handler=groups_handler,
                error_handler=kwargs["error_handler"])
        else:
            return [DVBDeviceGroupClient(path) for path in self.manager.GetRegisteredDeviceGroups()]
       
    def add_device_to_new_group (self, adapter, frontend, channels_file, recordings_dir, name, **kwargs):
        return self.manager.AddDeviceToNewGroup(adapter, frontend, channels_file, recordings_dir, name, **kwargs)
       
    def get_name_of_registered_device(self, adapter, frontend, **kwargs):
        return self.manager.GetNameOfRegisteredDevice(adapter, frontend, **kwargs)
        
    def get_device_group_size(self, **kwargs):
        return self.manager.GetDeviceGroupSize(**kwargs)
        
    def get_channel_groups(self, **kwargs):
        return self.manager.GetChannelGroups(**kwargs)
        
    def add_channel_group(self, name, **kwargs):
        return self.manager.AddChannelGroup(name, **kwargs)
        
    def remove_channel_group(self, group_id, **kwargs):
        return self.manager.RemoveChannelGroup(group_id, **kwargs)
    
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
        
    def remove_device(self, adapter, frontend, **kwargs):
        return self.devgroup.RemoveDevice(adapter, frontend, **kwargs)
    
    def get_channel_list(self):
        path = self.devgroup.GetChannelList()
        return DVBChannelListClient(path)
    
    def get_members(self, **kwargs):
        return self.devgroup.GetMembers(**kwargs)
        
    def get_name(self, **kwargs):
        return self.devgroup.GetName(**kwargs)
    
    def set_name(self, name, **kwargs):
        return self.devgroup.SetName(name, **kwargs)
        
    def get_type(self, **kwargs):
        return self.devgroup.GetType(**kwargs)
        
    def get_schedule(self, channel_sid):
        path, success = self.devgroup.GetSchedule(channel_sid)
        if success:
            return DVBScheduleClient(path)
        else:
            return None
        
    def get_recordings_directory (self, **kwargs):
        return self.devgroup.GetRecordingsDirectory(**kwargs)
        
    def set_recordings_directory (self, location, **kwargs):
        return self.devgroup.SetRecordingsDirectory(location, **kwargs)
     
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
        
    def add_scanning_data(self, data, **kwargs):
        self.scanner.AddScanningData (*data, **kwargs)
        
    def add_scanning_data_from_file(self, path, **kwargs):
        return self.scanner.AddScanningDataFromFile(path, **kwargs)
        
    def run(self, **kwargs):
        self.scanner.Run(**kwargs)
        
    def destroy(self, **kwargs):
        self.scanner.Destroy(**kwargs)
        
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
        
    def get_location(self, rid, **kwargs):
        return self.recstore.GetLocation(rid, **kwargs)
        
    def get_name(self, rid, **kwargs):
        return self.recstore.GetName(rid, **kwargs)
        
    def get_description(self, rid, **kwargs):
        return self.recstore.GetDescription(rid, **kwargs)
        
    def get_length(self, rid, **kwargs):
        return self.recstore.GetLength(rid, **kwargs)
        
    def get_start_time(self, rid, **kwargs):
        return self.recstore.GetStartTime(rid, **kwargs)
        
    def get_start_timestamp(self, rid, **kwargs):
        return self.recstore.GetStartTimestamp(rid, **kwargs)
        
    def delete(self, rid, **kwargs):
        return self.recstore.Delete(rid, **kwargs)
        
    def get_channel_name(self, rid, **kwargs):
        return self.recstore.GetChannelName(rid, **kwargs)
        
    def get_all_informations(self, rid, **kwargs):
        return self.recstore.GetAllInformations(rid, **kwargs)
        
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
        
    def add_timer (self, channel, year, month, day, hour, minute, duration, **kwargs):
        return self.recorder.AddTimer(channel, year, month, day, hour, minute, duration, **kwargs)
        
    def add_timer_with_margin (self, channel, year, month, day, hour, minute, duration, **kwargs):
        return self.recorder.AddTimerWithMargin(channel, year, month, day, hour, minute, duration, **kwargs)
        
    def add_timer_for_epg_event(self, event_id, channel_sid, **kwargs):
        return self.recorder.AddTimerForEPGEvent(event_id, channel_sid, **kwargs)
        
    def delete_timer(self, tid, **kwargs):
        return self.recorder.DeleteTimer(tid, **kwargs)
        
    def get_timers(self, **kwargs):
        return self.recorder.GetTimers(**kwargs)
        
    def get_start_time(self, tid, **kwargs):
        return self.recorder.GetStartTime(tid, **kwargs)

    def set_start_time(self, tid, year, month, day, hour, minute, **kwargs):
        return self.recorder.SetStartTime (tid, year, month, day, hour, minute)
        
    def get_end_time(self, tid, **kwargs):
        return self.recorder.GetEndTime(tid, **kwargs)
        
    def get_duration(self, tid, **kwargs):
        return self.recorder.GetDuration(tid, **kwargs)

    def set_duration(self, tid, duration, **kwargs):
        return self.recorder.SetDuration(tid, duration, **kwargs)
        
    def get_channel_name(self, tid, **kwargs):
        return self.recorder.GetChannelName(tid, **kwargs)

    def get_title(self, tid, **kwargs):
        return self.recorder.GetTitle(tid, **kwargs)

    def get_all_informations(self, tid, **kwargs):
        return self.recorder.GetAllInformations(tid, **kwargs)
        
    def get_active_timers(self, **kwargs):
        return self.recorder.GetActiveTimers(**kwargs)
        
    def is_timer_active(self, tid, **kwargs):
        return self.recorder.IsTimerActive(tid, **kwargs)
        
    def has_timer(self, year, month, day, hour, minute, duration, **kwargs):
        return self.recorder.HasTimer(year, month, day, hour, minute, duration, **kwargs)
        
    def has_timer_for_event(self, event_id, channel_sid, **kwargs):
        return self.recorder.HasTimerForEvent(event_id, channel_sid, **kwargs)
        
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
        
    def get_channel_name(self, cid, **kwargs):
        return self.channels.GetChannelName(cid, **kwargs)
        
    def get_channel_network(self, cid, **kwargs):
        return self.channels.GetChannelNetwork(cid, **kwargs)
        
    def is_radio_channel(self, cid, **kwargs):
        return self.channels.IsRadioChannel(cid, **kwargs)
        
    def get_channel_url(self, cid, **kwargs):
        return self.channels.GetChannelURL(cid, **kwargs)
        
    def get_channel_infos(self, **kwargs):
        return self.channels.GetChannelInfos(**kwargs)
        
    def get_channels_of_group(self, group_id, **kwargs):
        return self.channels.GetChannelsOfGroup(group_id, **kwargs)
        
    def add_channel_to_group(self, cid, group_id, **kwargs):
        return self.channels.AddChannelToGroup(cid, group_id, **kwargs)
        
    def remove_channel_from_group(self, cid, group_id, **kwargs):
        return self.channels.RemoveChannelFromGroup(cid, group_id, **kwargs)
        
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
        
    def get_all_event_infos(self, **kwargs):
        return self.schedule.GetAllEventInfos(**kwargs)
        
    def get_informations(self, eid, **kwargs):
        return self.schedule.GetInformations(eid, **kwargs)
        
    def now_playing(self, **kwargs):
        return self.schedule.NowPlaying(**kwargs)
        
    def next(self, eid, **kwargs):
        return self.schedule.Next(eid, **kwargs)
        
    def get_name(self, eid, **kwargs):
        return self.schedule.GetName(eid, **kwargs)
        
    def get_short_description(self, eid, **kwargs):
        return self.schedule.GetShortDescription(eid, **kwargs)
        
    def get_extended_description(self, eid, **kwargs):
        return self.schedule.GetExtendedDescription(eid, **kwargs)
        
    def get_duration(self, eid, **kwargs):
        return self.schedule.GetDuration(eid, **kwargs)
        
    def get_local_start_time(self, eid):
        return self.schedule.GetLocalStartTime(eid)
        
    def get_local_start_timestamp(self, eid, **kwargs):
        return self.schedule.GetLocalStartTimestamp(eid, **kwargs)
        
    def is_running(self, eid, **kwargs):
        return self.schedule.IsRunning(eid, **kwargs)
        
    def is_scrambled(self, eid, **kwargs):
        return self.schedule.IsScrambled(eid, **kwargs)

