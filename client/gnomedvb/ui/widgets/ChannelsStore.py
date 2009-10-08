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

import gtk
import gobject
import gnomedvb
from gnomedvb import global_error_handler

class ChannelsStore(gtk.ListStore):

    (COL_NAME,
     COL_SID,) = range(2)
    
    __gsignals__ = {
        "loading-finished":  (gobject.SIGNAL_RUN_LAST, gobject.TYPE_NONE, []),
    }

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
        channellist = device_group.get_channel_list()
        
        def append_channel(channels):
            for channel_id, name in channels:
                self.append([name, channel_id])
            self.emit("loading-finished")
        
        channellist.get_channel_infos(reply_handler=append_channel,
            error_handler=global_error_handler)


class ChannelsTreeStore(gtk.TreeStore):

    (COL_GROUP_ID,
     COL_NAME,
     COL_SID,
     COL_GROUP,) = range(4)
    
    __gsignals__ = {
        "loading-finished":  (gobject.SIGNAL_RUN_LAST, gobject.TYPE_NONE, [int]),
    }
    
    def __init__(self, use_channel_groups=False):
        gtk.TreeStore.__init__(self, int, str, int, gobject.TYPE_PYOBJECT)
        
        self.set_sort_column_id(self.COL_NAME,
            gtk.SORT_ASCENDING)
            
        self._use_channel_groups = use_channel_groups
        self._manager = gnomedvb.DVBManagerClient ()
        self._manager.connect('group-added', self._on_manager_group_added)
        self._manager.connect('group-removed', self._on_manager_group_removed)
        self._add_channels()
            
    def _add_channels(self):
        def append_groups(dev_groups):
            for dev_group in dev_groups:
                self._append_group(dev_group)

        self._manager.get_registered_device_groups(reply_handler=append_groups,
            error_handler=global_error_handler)
    
    def _append_group(self, dev_group):
        group_id = dev_group.get_id()
        group_name = dev_group.get_name()
        group_iter = self.append(None, [group_id, group_name, 0, dev_group])
        channellist = dev_group.get_channel_list()
        
        d = Callback()
        if self._use_channel_groups:   
            d.add_callback(self._append_channel_groups, channellist, group_id,
                group_iter, dev_group)
            self._manager.get_channel_groups(
                reply_handler=lambda x: d.callback(x),
                error_handler=global_error_handler)
        else:
            d.add_callback(self._append_channels, group_id, group_iter,
                dev_group)
            channellist.get_channel_infos(
                reply_handler=lambda x: d.callback(x),
                error_handler=global_error_handler)
     
    def _append_channels(self, channels, group_id, group_iter, dev_group):
        for channel_id, name in channels:
            self.append(group_iter,
                [group_id,
                name,
                channel_id,
                dev_group])
        self.emit("loading-finished", group_id)   

    def _append_channel_groups(self, channel_groups, channellist, group_id, group_iter, dev_group):
        def append_channel(channels, chan_group_iter):
            for channel_id in channels:
                name, success = channellist.get_channel_name(channel_id)
                if success:
                    self.append(chan_group_iter,
                        [group_id,
                        name,
                        channel_id,
                        dev_group])
        
        for chan_group_id, name in channel_groups:
            chan_group_iter = self.append(group_iter, [group_id, name, 0, dev_group])
            d = Callback()
            d.add_callback(append_channel, chan_group_iter)
            channellist.get_channels_of_group(chan_group_id,
                reply_handler=lambda x, success: d.callback(x),
                error_handler=global_error_handler)
                
        self.emit("loading-finished", group_id)
       
    def _on_manager_group_added(self, manager, group_id):
        group, success = manager.get_device_group(group_id)
        if success:
            self._append_group(group)
        
    def _on_manager_group_removed(self, manager, group_id):
        for row in self:
            if row[self.COL_GROUP_ID] == group_id:
                self.remove(row.iter)
                break


class Callback:

    def __init__(self):
        self.callbacks = []
        
    def add_callback(self, callback_function, *args):
        if not callable(callback_function):
            raise TypeError("first argument must be callable")
        self.callbacks.append((callback_function, args))
        
    def callback(self, result):
        for cb, args in self.callbacks:
            cb(result, *args)

