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
import datetime
from cgi import escape
from gnomedvb import global_error_handler

class ScheduleStore(gtk.ListStore):

    (COL_YEAR,
     COL_MONTH,
     COL_DAY,
     COL_HOUR,
     COL_MINUTE,
     COL_DURATION,
     COL_TITLE,
     COL_SHORT_DESC,
     COL_EXTENDED_DESC,
     COL_RECORDED,
     COL_EVENT_ID,) = range(11)
     
    NEW_DAY = -1
    
    __gsignals__ = {
        "loading-finished":  (gobject.SIGNAL_RUN_LAST, gobject.TYPE_NONE, []),
    }

    def __init__(self, dev_group, sid):
        gtk.ListStore.__init__(self, int, int, int, int, int, int, str, str, str, int, int)
        self._client = dev_group.get_schedule(sid)
        self._recorder = dev_group.get_recorder()
        self._fill_all()
        
    def reload_all(self):
        self.clear()
        self._fill_all()
        
    def _fill_from_now(self):
        current = self._client.now_playing()
        
        while current != 0:
            self._append_event(current)
            current = self._client.next(current)
            
    def _fill_all(self):
        def append_event(events):
            prev_date = (0,0,0,)
            for event in events:
                new_iter = self._append_event(event)
                new_date = self.get_date(new_iter)
                # Insert bogus entry to mark that a new day starts
                if prev_date < new_date:
                    date_iter = self.insert_before(new_iter, None)
                    self.set(date_iter, self.COL_YEAR, new_date[0])
                    self.set(date_iter, self.COL_MONTH, new_date[1])
                    self.set(date_iter, self.COL_DAY, new_date[2])
                    self.set(date_iter, self.COL_EVENT_ID, self.NEW_DAY)
                prev_date = new_date
            self.emit("loading-finished")
        
        self._client.get_all_event_infos(reply_handler=append_event, error_handler=global_error_handler)
        
    def get_date(self, aiter):
        return (self[aiter][self.COL_YEAR],
            self[aiter][self.COL_MONTH],
            self[aiter][self.COL_DAY],)
            
    def get_time(self, aiter):
        return (self[aiter][self.COL_HOUR], self[aiter][self.COL_MINUTE],)
        
    def get_datetime(self, aiter):
        return datetime.datetime(self[aiter][self.COL_YEAR],
            self[aiter][self.COL_MONTH], self[aiter][self.COL_DAY],
            self[aiter][self.COL_HOUR], self[aiter][self.COL_MINUTE])
        
    def _append_event(self, event):
        event_id, next, name, duration, short_desc = event
        name = escape(name)
        short_desc = escape(short_desc)
        
        start_arr = self._client.get_local_start_time(event_id)[0]
        
        rec = self._recorder.has_timer_for_event(event_id,
            self._client.get_channel_sid())
        
        return self.append([start_arr[0], start_arr[1], start_arr[2],
            start_arr[3], start_arr[4],
            duration, name, short_desc, None,
            rec, event_id])
            
    def get_extended_description(self, aiter):
        if aiter != None:
            event_id = self[aiter][self.COL_EVENT_ID] 
            ext_desc = escape(self._client.get_extended_description(event_id)[0])
            self[aiter][self.COL_EXTENDED_DESC] = ext_desc
        return ext_desc
        
    def get_next_day_iter(self, aiter):
        """
        Get the iter pointing to the row that represents
        the next day after the row C{aiter} points to.
        If C{aiter} is C{None} the first iter is used
        as reference. C{None} is returned if there's
        no next day.
        """
        if aiter == None:
            aiter = self.get_iter_first ()
        
        # If the selected row marks a new day
        # we still want the following day
        aiter = self.iter_next (aiter)
            
        while (aiter != None):
            row = self[aiter]
            if row[self.COL_EVENT_ID] == self.NEW_DAY:
                return row.iter
            aiter = self.iter_next (aiter)
                
        return None
        
    def get_previous_day_iter(self, aiter):
        """
        Get the iter pointing to the row that represents
        the day before the day that the row C{aiter} points
        to belongs. C{None} is returned if there's no previous
        day.
        """
        if aiter == None:
            return None
        
        path0 = self.get_path(aiter)[0]
        
        if path0 == 0:
            return None
        
        # If the selected row marks a new day
        # we still want the previous day
        # therefore we have to come across 2 new days
        day_seen = 0
        
        while path0 >= 0:
            aiter = self.get_iter((path0,))
            row = self[aiter]
            if row[self.COL_EVENT_ID] == self.NEW_DAY:
                day_seen += 1
                if day_seen == 2:
                    return row.iter
            path0 -= 1
        
        return None

