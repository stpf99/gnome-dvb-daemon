# -*- coding: utf-8 -*-
# Copyright (C) 2009 Sebastian Pölsterl
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
from gnomedvb import global_error_handler
from cgi import escape

class RunningNextStore(gtk.ListStore):

    (COL_CHANNEL,
     COL_RUNNING,
     COL_NEXT,
     COL_SID) = range(4)

    def __init__(self, group):
        gtk.ListStore.__init__(self, str, str, str, int)
        
        self.set_sort_column_id(self.COL_CHANNEL,
            gtk.SORT_ASCENDING)
          
        self._group = group
        self._fill()
        
    def _fill(self):
        channellist = self._group.get_channel_list()
    
        def add_channels(channels):
            for sid in channels:
                aiter = self.append()
                self.set(aiter, self.COL_CHANNEL, channellist.get_channel_name(sid))
                self.set(aiter, self.COL_SID, sid)
                
                sched = self._group.get_schedule(sid)
                now = sched.now_playing()
                if now != 0:
                    self.set(aiter, self.COL_RUNNING, escape(sched.get_name(now)))
                    next = sched.next(now)
                    if next != 0:
                        self.set(aiter, self.COL_NEXT, escape(sched.get_name(next)))
        
        channellist.get_channels(reply_handler=add_channels,
            error_handler=global_error_handler)
        
