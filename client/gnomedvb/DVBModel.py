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
from Device import Device

class DVBModel (gnomedvb.DVBManagerClient):

    def __init__(self):
        gnomedvb.DVBManagerClient.__init__(self)
        
    def get_device_group(self, group_id):
        path = self.manager.GetDeviceGroup(group_id)
        return DeviceGroup(path)
        
    def get_registered_device_groups(self):
        return [DeviceGroup(path) for path in self.manager.GetRegisteredDeviceGroups()]

    def get_all_devices(self):
        """
        @returns: list of Device
        """
        devs = []
        for info in gnomedvb.get_dvb_devices():
            dev = Device (0, "Unknown", info["adapter"], info["frontend"],
                "Unknown")
            devs.append(dev)
        return devs
        
    def get_unregistered_devices(self):
        """
        @returns: set of Device
        """
        devgroups = self.get_registered_device_groups()
        registered = set()
        for group in devgroups:
            for dev in group["devices"]:
                registered.add(dev)
                
        unregistered = set()
        for dev in self.get_all_devices():
            if dev not in registered:
                info = gnomedvb.get_adapter_info(dev.adapter)
                dev.name = info["name"]
                dev.type = info["type"]
                unregistered.add(dev)
        
        return unregistered

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
                devices.append(dev)
        return devices

    def remove_device(self, device):
        return gnomedvb.DVBDeviceGroupClient.remove_device(self, device.adapter,
            device.frontend)
     
