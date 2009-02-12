# -*- coding: utf-8 -*-
import gtk
import gnomedvb
import datetime
from cgi import escape

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

    def __init__(self, schedule_client):
        gtk.ListStore.__init__(self, int, int, int, int, int, int, str, str, str, int, int)
        self._client = schedule_client
        self._recorder = gnomedvb.DVBRecorderClient(schedule_client.get_group_id())
        self._fill_all()
        
    def _fill_from_now(self):
        current = self._client.now_playing()
        
        while current != 0:
            self._append_event(current)
            current = self._client.next(current)
            
    def _fill_all(self):
        prev_date = (0,0,0,)
        for event_id in self._client.get_all_events():
            new_iter = self._append_event(event_id)
            new_date = self.get_date(new_iter)
            # Insert bogus entry to mark that a new day starts
            if prev_date < new_date:
                date_iter = self.insert_before(new_iter, None)
                self.set(date_iter, self.COL_YEAR, new_date[0])
                self.set(date_iter, self.COL_MONTH, new_date[1])
                self.set(date_iter, self.COL_DAY, new_date[2])
                self.set(date_iter, self.COL_EVENT_ID, self.NEW_DAY)
            prev_date = new_date
        
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
        
    def _append_event(self, event_id):
        name = escape(self._client.get_name(event_id))
        short_desc = escape(self._client.get_short_description(event_id))
        ext_desc = escape(self._client.get_extended_description(event_id))
        start_arr = self._client.get_local_start_time(event_id)
                
        # We want minutes
        duration = self._client.get_duration(event_id) / 60
        
        rec = self._recorder.has_timer_for_event(event_id,
            self._client.get_channel_sid())
        
        return self.append([start_arr[0], start_arr[1], start_arr[2],
            start_arr[3], start_arr[4],
            duration, name, short_desc, ext_desc,
            rec, event_id])
        
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

