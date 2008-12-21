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
        groups = []
        for group_id in gnomedvb.DVBManagerClient.get_registered_device_groups(self):
            groups.append({"id": group_id,
                "name": gnomedvb.DVBManagerClient.get_device_group_name(self, group_id),
                "devices": self.get_device_group_members(group_id)})
            
        return groups
        
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
        
    def remove_device_from_group(self, device):
        return gnomedvb.DVBManagerClient.remove_device_from_group(self, device.adapter,
            device.frontend, device.group)
            
    def get_device_group_members(self, group_id):
        devices = []
        for device_path in gnomedvb.DVBManagerClient.get_device_group_members(self, group_id):
            match = self._adapter_pattern.search(device_path)
            if match != None:
                adapter = int(match.group(1))
                frontend = int(match.group(2))
                devtype = self.get_type_of_device_group(group_id)
                devname = self.get_name_of_registered_device(adapter, frontend)
                dev = Device (group_id, devname, adapter, frontend, devtype)
                devices.append(dev)
        return devices


