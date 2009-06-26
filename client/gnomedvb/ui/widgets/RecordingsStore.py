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
from gnomedvb import DVBRecordingsStoreClient, global_error_handler
from cgi import escape

class RecordingsStore(gtk.ListStore):
    
    (COL_START,
    COL_CHANNEL,
    COL_NAME,
    COL_DURATION,
    COL_LOCATION,
    COL_ID,) = range(6)

    def __init__(self):
        gtk.ListStore.__init__(self, int, str, str, int, str, int)
        
        self._recstore = DVBRecordingsStoreClient()
        self._recstore.connect("changed", self._on_changed)
        
        self._fill()
        
    def get_recordings_store_client(self):
        return self._recstore
        
    def _append_recording(self, rec_id):
        channame = self._recstore.get_channel_name(rec_id)
        name = escape(self._recstore.get_name(rec_id))
        start = self._recstore.get_start_timestamp(rec_id)
        duration = self._recstore.get_length(rec_id)
        location = self._recstore.get_location(rec_id)
        #print "Desc", recstore.get_description(rec_id)
    
        self.append([start, channame, name, duration, location, rec_id])
        
    def _fill(self):
        def append_rec(rids):
            for rid in rids:
                self._append_recording(rid)
    
        self._recstore.get_recordings(reply_handler=append_rec, error_handler=global_error_handler)

    def _on_changed(self, recstore, rec_id, change_type):
        if change_type == 0:
            # Added
            self._append_recording(rec_id)
        elif change_type == 1:
            # Deleted
            for row in self:
                if row[self.COL_ID] == rec_id:
                    self.remove(row.iter)
                    return
        elif change_type == 2:
            # Updated
            pass
        
