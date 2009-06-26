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

import gnomedvb
import re
from gnomedvb.Device import Device

class DVBModel (gnomedvb.DVBManagerClient):

    def __init__(self):
        gnomedvb.DVBManagerClient.__init__(self)
        
    def get_device_group(self, group_id):
        path = self.manager.GetDeviceGroup(group_id)
        return DeviceGroup(path)
        
    def get_registered_device_groups(self, reply_handler,
            error_handler=gnomedvb.global_error_handler):
        def groups_handler(paths):
            reply_handler([DeviceGroup(path) for path in paths])
            
        if reply_handler:
            self.manager.GetRegisteredDeviceGroups(reply_handler=groups_handler,
                error_handler=error_handler)
        else:
            return [DeviceGroup(path) for path in self.manager.GetRegisteredDeviceGroups()]

    def get_all_devices(self, reply_handler,
            error_handler=gnomedvb.global_error_handler):
        """
        @returns: list of Device
        """
        def devices_handler(devices):
            devs = []
            for info in devices:
                dev = Device (0, "Unknown", info["adapter"], info["frontend"],
                    "Unknown")
                devs.append(dev)
            reply_handler(devs)
        
        gnomedvb.get_dvb_devices(reply_handler=devices_handler,
            error_handler=error_handler)
        
    def get_unregistered_devices(self, reply_handler,
            error_handler=gnomedvb.global_error_handler):
        """
        @returns: set of Device
        """
        def devices_handler(devices):
            unregistered = set()
            for dev in devices:
                if dev not in registered:
                    info = gnomedvb.get_adapter_info(dev.adapter)
                    dev.name = info["name"]
                    dev.type = info["type"]
                    unregistered.add(dev)
            reply_handler(unregistered)
        
        def registered_handler(devgroups):
            for group in devgroups:
                for dev in group["devices"]:
                    registered.add(dev)
            self.get_all_devices(reply_handler=devices_handler,
                error_handler=error_handler)
        
        registered = set()
        self.get_registered_device_groups(reply_handler=registered_handler,
            error_handler=error_handler)

class DeviceGroup(gnomedvb.DVBDeviceGroupClient):

    def __init__(self, objpath):
        gnomedvb.DVBDeviceGroupClient.__init__(self, objpath)
        
        self._adapter_pattern = re.compile("adapter(\d+?)/frontend(\d+?)")
        self._name = self.get_name()
        self._type = self.get_type()
        self._members = self.get_members()
        
    def __getitem__(self, key):
        if key == "id":
            return self._id
        elif key == "name":
            return self._name
        elif key == "devices":
            return self._members
        elif key == "type":
            return self._type
        else:
            raise KeyError("Unknown key "+key)
    
    def get_members(self):
        devices = []
        manager = gnomedvb.DVBManagerClient()
        for device_path in gnomedvb.DVBDeviceGroupClient.get_members(self):
            match = self._adapter_pattern.search(device_path)
            if match != None:
                adapter = int(match.group(1))
                frontend = int(match.group(2))
                devname = manager.get_name_of_registered_device(adapter, frontend)
                dev = Device (self._id, devname, adapter, frontend, self["type"])
                dev.group_name = self._name
                devices.append(dev)
        return devices

    def remove_device(self, device):
        return gnomedvb.DVBDeviceGroupClient.remove_device(self, device.adapter,
            device.frontend)
     
