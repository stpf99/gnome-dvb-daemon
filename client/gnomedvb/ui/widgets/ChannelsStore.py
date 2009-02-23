# -*- coding: utf-8 -*-
import gtk
import gnomedvb
from gnomedvb import global_error_handler

class ChannelsStore(gtk.ListStore):

    (COL_NAME,
     COL_SID,) = range(2)

    def __init__(self, device_group):
        """
        @param device_group: ID of device group the
        list of channels should be retrieved
        """
    
        gtk.ListStore.__init__(self, str, int)
        
        self.set_sort_column_id(self.COL_NAME,
            gtk.SORT_ASCENDING)
            
        self._add_channels(device_group)
        
    def _add_channels(self, device_group):
        channellist = gnomedvb.DVBChannelListClient(device_group)
        
        def append_channel(channels):
            for channel_id in channels:
                name = channellist.get_channel_name(channel_id)
                self.append([name, channel_id])
        
        channellist.get_channels(reply_handler=append_channel, error_handler=global_error_handler)


class ChannelsTreeStore(gtk.TreeStore):

    (COL_GROUP_ID,
     COL_NAME,
     COL_SID,) = range(3)
     
    def __init__(self):
        gtk.TreeStore.__init__(self, int, str, int)
        
        self.set_sort_column_id(self.COL_NAME,
            gtk.SORT_ASCENDING)
            
        self._add_channels()
            
    def _add_channels(self):
        manager = gnomedvb.DVBManagerClient ()
        dev_groups = manager.get_registered_device_groups()
    
        for group_id in dev_groups:
            group_name = manager.get_device_group_name(group_id)
            group_iter = self.append(None, [group_id, group_name, 0])
            channellist = gnomedvb.DVBChannelListClient(group_id)
            append_channel = lambda channels: [self.append(group_iter, [group_id, channellist.get_channel_name(channel_id), channel_id]) for channel_id in channels]
            channellist.get_channels(reply_handler=append_channel, error_handler=global_error_handler)
         
