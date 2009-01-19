# -*- coding: utf-8 -*-
import gtk
import gnomedvb
from cgi import escape

class ScheduleStore(gtk.ListStore):

    (COL_START,
     COL_DURATION,
     COL_TITLE,
     COL_SHORT_DESC,
     COL_EVENT_ID,) = range(5)

    def __init__(self, schedule_client):
        gtk.ListStore.__init__(self, str, int, str, str, int)
        self._client = schedule_client
        self._fill_all()
        
    def _fill_from_now(self):
        current = self._client.now_playing()
        
        while current != 0:
            self._append_event(current)
            current = self._client.next(current)
            
    def _fill_all(self):
        for event_id in self._client.get_all_events():
            self._append_event(event_id)
        
    def _append_event(self, event_id):
        name = escape(self._client.get_name(event_id))
        desc = escape(self._client.get_short_description(event_id))
        start_arr = self._client.get_local_start_time(event_id)
        
        start_str = "Unknown"
        if len(start_arr) != 0:
            start_str = "%04d-%02d-%02d %02d:%02d" % (start_arr[0], start_arr[1],
                start_arr[2], start_arr[3], start_arr[4])
        # We want minutes
        duration = self._client.get_duration(event_id) / 60
        
        self.append([start_str, duration, name, desc, event_id])
        

