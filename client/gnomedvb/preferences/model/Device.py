# -*- coding: utf-8 -*-
PRIME = 31

class Device:

    def __init__(self, group_id, name, adapter, frontend, devtype):
        self.group = group_id
        self.name = name
        self.adapter = adapter
        self.frontend = frontend
        self.type = devtype
        
    def __hash__(self):
        return 2 * PRIME + PRIME * self.adapter + self.frontend
        
    def __eq__(self, other):
        if not isinstance(other, Device):
            return False
        
        return (self.adapter == other.adapter \
            and self.frontend == other.frontend)
            
    def __repr__(self):
        return "/dev/dvb/adapter%d/frontend%d" % (self.adapter, self.frontend)

