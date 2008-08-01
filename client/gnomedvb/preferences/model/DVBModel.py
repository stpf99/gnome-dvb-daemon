# -*- coding: utf-8 -*-
import gnomedvb
import re
from Device import Device

class DVBModel (gnomedvb.DVBManagerClient):

    def __init__(self):
        gnomedvb.DVBManagerClient.__init__(self)
        self._adapter_pattern = re.compile("adapter(\d+?)/frontend(\d+?)")
        
    def get_registered_device_groups(self):
        """
        @returns: dict of list of Device
        """
        groups = {}
        for group_id in gnomedvb.DVBManagerClient.get_registered_device_groups(self):
            groups[group_id] = self.get_device_group_members(group_id)
            
        return groups
        
    def get_all_devices(self):
        """
        @returns: list of Device
        """
        devs = []
        for info in gnomedvb.get_dvb_devices():
            dev = Device (0, info["name"], info["adapter"], info["frontend"],
                info["type"])
            devs.append(dev)
        return devs
        
    def get_unregistered_devices(self):
        """
        @returns: set of Device
        """
        devgroups = self.get_registered_device_groups()
        registered = set()
        for group in devgroups.values():
            for dev in group:
                registered.add(dev)
                
        alldevs = set()
        for dev in self.get_all_devices():
            alldevs.add(dev)
        
        return alldevs - registered
        
    def remove_device_from_group(self, device):
        return gnomedvb.DVBManagerClient.remove_device_from_group(self, device.adapter,
            device.frontend, device.group)
            
    def get_device_group_members(self, group_id):
        devices = []
        for device_path in gnomedvb.DVBManagerClient.get_device_group_members(self, group_id):
            match = self._adapter_pattern.search(device_path)
            if match != None:
                adapter = int(match.group(1))
                info = gnomedvb.get_adapter_info(adapter)
                frontend = int(match.group(2))
                dev = Device (group_id, info["name"], adapter, frontend, info["type"])
                devices.append(dev)
        return devices


