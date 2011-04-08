/*
 * Copyright (C) 2008-2011 Sebastian Pölsterl
 *
 * This file is part of GNOME DVB Daemon.
 *
 * GNOME DVB Daemon is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * GNOME DVB Daemon is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with GNOME DVB Daemon.  If not, see <http://www.gnu.org/licenses/>.
 */

using GLib;
using Gee;
using DVB.database;

namespace DVB {

    /**
     * Represents a series of events of a channel
     */
    public class Schedule : GLib.Object, IDBusSchedule {

        private static const int MATCH_THRESHOLD = 100;
        private static const double MIN_EVENT_OVERLAP = 0.5;

        // Use weak to avoid ref cycle
        public weak Channel channel {get; construct;}

        private static StaticRecMutex mutex = StaticRecMutex ();

        private EPGStore epgstore;
        private EventStorage events;
        
        construct {
            this.events = new EventStorage ();
            this.epgstore = Factory.get_epg_store ();

            Idle.add (this.restore);
        }

        private bool restore () {
            Gee.List<Event> levents;
            try {                        
                levents = this.epgstore.get_events (
                    this.channel.Sid, this.channel.GroupId);
            } catch (SqlError e) {
                critical ("%s", e.message);
                return false;
            }

            int newest_expired = -1;
            for (int i=0; i<levents.size; i++) {
                Event event = levents.get (i);
                if (event.has_expired ()) {
                    /* events are sorted by starttime */
                    newest_expired = i;
                } else {
                    this.events.insert (event);
                }
            }

            if (newest_expired != -1) {
                Event event = levents.get (newest_expired);
                try {
                    this.epgstore.remove_events_older_than (event,
                        this.channel.Sid, this.channel.GroupId);
                } catch (SqlError e) {
                    critical ("%s", e.message);
                    return false;
                }
            }

            debug ("Finished restoring EPG events for channel %u",
                this.channel.Sid);
            return false;
        }
        
        public Schedule (Channel channel) {
            base (channel: channel);
        }
        
        public void remove_expired_events () {
            int last_expired = -1;

            lock (this.events) {
                for (int i=0; i<this.events.size; i++) {
                    EventElement element = this.events.get (i);
                    Event? e = this.get_event (element.id);
                    if (e != null && e.has_expired ()) {
                        last_expired = i;
                    } else {
                        // events are sorted, all other events didn't expire, too
                        break;
                    }
                }

                debug ("Removing expired events of channel %s (%u)",
                    channel.Name, channel.Sid);

                for (int i=0; i<=last_expired; i++) {
                    EventElement element = this.events.get (i);
                    Event? event = this.get_event (element.id);
                    try {
                        this.epgstore.remove_events_older_than (event,
                            this.channel.Sid, this.channel.GroupId);
                    } catch (SqlError e) {
                        critical ("%s", e.message);
                    }
                }

                if (last_expired > -1) {
                    this.events.remove_range (0, last_expired);
                }
            }
        }

        public Event? get_event (uint event_id) {
            try {
                return this.epgstore.get_event (event_id,
                    this.channel.Sid, this.channel.GroupId);
            } catch (SqlError e) {
                critical ("%s", e.message);
                return null;
            }
        }

        /**
         * When an event with the same id already exists, it's replaced
         */
        public void add (Event event) {
            if (event.has_expired ()) return;
            
            lock (this.events) {
                try {
                    this.store_event (event);
                } catch (SqlError e) {
                    critical ("%s", e.message);
                }
            }
        }

        public void add_all (Collection<Event> new_events) {
            lock (this.events) {
                try {
                    mutex.lock ();
                    ((database.sqlite.SqliteDatabase)this.epgstore).begin_transaction ();

                    foreach (Event event in new_events) {
                        if (!event.has_expired ())
                            this.store_event (event);
                    }

                    ((database.sqlite.SqliteDatabase)this.epgstore).end_transaction ();                    
                } catch (SqlError e) {
                    critical ("%s", e.message);
                } finally {
                    mutex.unlock ();
                }
            }
        }

        private void store_event (Event event) throws SqlError {
            Gee.List<Event> overlap = this.get_overlapping_events (event);
            int s = match_events (overlap, event);
            if (s > MATCH_THRESHOLD) {
                this.events.remove_all (overlap);
            }

            this.epgstore.add_or_update_event (event, this.channel.Sid,
                this.channel.GroupId);

            if (!this.events.contains_event_with_id (event.id)) {
                this.events.insert (event);
            }
        }

        private Gee.List<Event> get_overlapping_events (Event event) {
            Gee.List<EventElement> elements = this.events.get_overlapping_events (event);

            Gee.List<Event> overlap = new ArrayList<Event> ();
            foreach (EventElement data in elements) {
                Event? e = this.get_event (data.id);
                if (e != null && e.get_overlap_percentage (event) >= MIN_EVENT_OVERLAP)
                    overlap.add (e);
            }

            return overlap;
        }

        private int match_events (Gee.List<Event> events, Event ref_event) {
            time_t ref_start = ref_event.get_start_timestamp ();
            time_t ref_end = ref_event.get_end_timestamp ();

            double max_score = 0;            
            foreach (Event event in events) {
                double score = 0;
                time_t e_start = event.get_start_timestamp ();
                time_t e_end = event.get_end_timestamp ();

                score += Math.fabs (ref_start - e_start);
                score += Math.fabs (ref_end - e_end);

                score += Math.fabs (ref_event.duration - event.duration) / 60.0;

                if (ref_event.name != null && event.name != null) {
                    long unmatched;
                    long diff = Utils.strdiff (ref_event.name, event.name, out unmatched);
                    score += 10 * (diff + 5 * unmatched);
                }

                if (score > max_score) {
                    max_score = score;
                }
            }

            return (int)max_score;
        }

        public bool contains (uint event_id) {
            bool val;
            lock (this.events) {
                val = this.events.contains_event_with_id (event_id);
            }
            return val;
        }

        public Event? get_running_event () {
             Event? running_event = null;
             lock (this.events) {
                 foreach (EventElement element in this.events) {;
                    Event? event = this.get_event (element.id);
                    if (event != null && event.is_running ()) {
                        running_event = event;
                        break;
                    }
                }
            }
            
            return running_event;
        }

        /**
         * @start: local time of event
         * @duration: how long the event is
         * @returns: the event that starts after @start
         * and spans the given time period
         */
        public Event? get_event_around (Time start, uint duration) {
            Event? result = null;
            time_t timer_start = start.mktime ();
            time_t timer_end = timer_start + duration * 60;
            lock (this.events) {
                // Difference between end of timer and end of event
                time_t last_diff = 0;
                foreach (EventElement element in this.events) {
                    // convert UTC to local time
                    time_t event_start = cUtils.timegm (Time.local (element.starttime));
                    Event? event = this.get_event (element.id);
                    if (event == null) continue;

                    time_t event_end = event_start + event.duration;

                    time_t min_end = (timer_end < event_end) ? timer_end : event_end;
                    time_t max_start = (timer_start > event_start) ? timer_start : event_start;
                    time_t overlap = min_end - max_start;

                    // If the difference is bigger we are sure that
                    // this one is the right event
                    if (last_diff < overlap) {
                        last_diff = overlap;
                        result = event;
                    }
                    if (event_start > timer_end) {
                        // All other events are too far in the future
                        break;
                    }
                }
            }
            return result;
        }

        public uint32[] GetAllEvents () throws DBusError {
            ArrayList<uint32> events = new ArrayList<uint32> ();
            lock (this.events) {
                 foreach (EventElement element in this.events) {
                    Event? event = this.get_event (element.id);
                    if (event == null || event.has_expired ()) continue;
                    events.add (element.id);
                 }
            }

            uint32[] event_ids = new uint32[events.size];
            for (int i=0; i<event_ids.length; i++) {
                event_ids[i] = events.get (i);
            }
            return event_ids;
        }

        public EventInfo[] GetAllEventInfos () throws DBusError {
            ArrayList<Event> all_events = new ArrayList<Event> ();
            lock (this.events) {
                foreach (EventElement element in this.events) {
                    Event? event = this.get_event (element.id);
                    if (event != null && !event.has_expired ())
                        all_events.add (event);
                }
            }

            int n_events = all_events.size;
            EventInfo[] event_infos = new EventInfo[n_events];
            int i = 0;
            Event event = null;
            if (n_events > i)
                event = all_events.get (i);
            while (event != null) {
                event_infos[i] = event_to_event_info (event);

                if (i+1 == n_events) {
                    event_infos[i].next = 0;
                    event = null;
                } else {
                    event = all_events.get (i+1);
                    event_infos[i].next = event.id;
                }
                i++;
            }

            return event_infos;
        }

        public bool GetInformations (uint32 event_id, out EventInfo event_info)
                throws DBusError
        {
            bool ret;
            
            lock (this.events) {        
                if (this.events.contains_event_with_id (event_id)) {
                    EventElement element = this.events.get_by_id (event_id);
                    Event? event = this.get_event (element.id);
                    
                    event_info = event_to_event_info (event);
                    EventElement? next_element = this.events.next (element);
                    if (next_element == null) {
                        event_info.next = 0;
                    } else {
                        element = next_element;
                        event_info.next = element.id;
                    }
                    ret = true;
                } else {
                    event_info.id = 0;
                    event_info.name = "";
                    event_info.duration = 0;
                    event_info.short_description = "";
                    event_info.next = 0;
                    ret = false;
                }
            }
            
            return ret;
        }
        
        public uint32 NowPlaying () throws DBusError {
            Event? event = this.get_running_event ();
            
            return (event == null) ? 0 : event.id;
        }
        
        public uint32 Next (uint32 event_id) throws DBusError {
            uint32 next_event = 0;
            lock (this.events) {
                if (this.events.contains_event_with_id (event_id)) {
                    EventElement element = this.events.get_by_id (event_id);
                    EventElement? next = this.events.next (element);

                    // Check if a new event follows
                    if (next != null) {
                        next_event = next.id;
                    }
                } else {
                    debug ("No event with id %u", event_id);
                }
            }
            
            return next_event;
        }
        
        public bool GetName (uint32 event_id, out string name) throws DBusError {
            bool ret = false;

            lock (this.events) {        
                if (this.events.contains_event_with_id (event_id)) {
                    Event? event = this.get_extended_event_by_id (event_id);
                    if (event != null && event.name != null) {
                        name = event.name;
                        ret = true;
                    }
                } else {
                    debug ("No event with id %u", event_id);
                }
            }
            if (!ret) name = "";
            return ret;
        }
        
        public bool GetShortDescription (uint32 event_id,
                out string description) throws DBusError
        {
            bool ret = false;
            
            lock (this.events) {
                if (this.events.contains_event_with_id (event_id)) {
                    Event? event = this.get_extended_event_by_id (event_id);
                    if (event != null && event.description != null) {
                        description = event.description;
                        ret = true;
                    }
                } else {
                    debug ("No event with id %u", event_id);
                }
            }
            if (!ret) description = "";
            return ret;
        }
        
        public bool GetExtendedDescription (uint32 event_id,
                out string description) throws DBusError
        {
            bool ret = false;
            
            lock (this.events) {
                if (this.events.contains_event_with_id (event_id)) {
                    Event? event = this.get_extended_event_by_id (event_id);
                    if (event != null && event.extended_description != null) {
                        description = event.extended_description;
                        ret = true;
                    }
                } else {
                    debug ("No event with id %u", event_id);
                }
            }
            if (!ret) description = "";
            return ret;
        }
        
        public bool GetDuration (uint32 event_id, out uint duration)
                throws DBusError
        {
            bool ret = false;
        
            lock (this.events) {
                if (this.events.contains_event_with_id (event_id)) {
                    Event? event = this.get_extended_event_by_id (event_id);
                    if (event != null) {
                        duration = event.duration;
                        ret = true;
                    }
                } else {
                    debug ("No event with id %u", event_id);
                }
            }
            
            return ret;
        }
        
        public bool GetLocalStartTime (uint32 event_id, out uint[] start_time)
                throws DBusError
        {
            bool ret = false;
        
            lock (this.events) {
                if (this.events.contains_event_with_id (event_id)) {
                    Event? event = this.get_extended_event_by_id (event_id);
                    if (event != null) {
                        Time local_time = event.get_local_start_time ();
                        start_time = to_time_array (local_time);
                        ret = true;
                    }
                } else {
                    debug ("No event with id %u", event_id);
                    start_time = new uint[] {};
                }
            }

            if (!ret) start_time = new uint[0];
            
            return ret;
        }
        
        public bool GetLocalStartTimestamp (uint32 event_id, out int64 timestamp)
                throws DBusError
        {
            bool ret = false;
            lock (this.events) {
                if (this.events.contains_event_with_id (event_id)) {
                    Event? event = this.get_extended_event_by_id (event_id);
                    if (event != null) {
                        Time local_time = event.get_local_start_time ();
                        timestamp = (int64)local_time.mktime ();
                        ret = true;
                    }
                }
            }
            return ret;
        }
        
        public bool IsRunning (uint32 event_id, out bool running)
                throws DBusError
        {
            bool ret = false;
        
            lock (this.events) {
                if (this.events.contains_event_with_id (event_id)) {
                    Event? event = this.get_extended_event_by_id (event_id);
                    if (event != null) {
                        running = (event.is_running ());
                        ret = true;
                    }
                } else {
                    debug ("No event with id %u", event_id);
                }
            }
            
            return ret;
        }
        
        public bool IsScrambled (uint32 event_id, out bool scrambled)
                throws DBusError
        {
            bool ret = false;
        
            lock (this.events) {
                if (this.events.contains_event_with_id (event_id)) {
                    Event? event = this.get_extended_event_by_id (event_id);
                    if (event != null) {
                        scrambled = (!event.free_ca_mode);
                        ret = true;
                    }
                } else {
                    debug ("No event with id %u", event_id);
                }
            }
            
            return ret;
        }

        private Event? get_extended_event_by_id (uint event_id) {
            EventElement element = this.events.get_by_id (event_id);
            return this.get_event (element.id);
        }

        private static uint[] to_time_array (Time local_time) {
            uint[] start = new uint[6];
            start[0] = local_time.year + 1900;
            start[1] = local_time.month + 1;
            start[2] = local_time.day;
            start[3] = local_time.hour;
            start[4] = local_time.minute;
            start[5] = local_time.second;
            return start;
        }

        private static EventInfo event_to_event_info (Event event) {
            EventInfo event_info = EventInfo();
            event_info.id = event.id;
            event_info.name = event.name;
            event_info.duration = event.duration;
            event_info.short_description = event.description;
            /*
            Time local_time = event.get_local_start_time ();
            event_info.local_start = to_time_array (local_time);
            */
            return event_info;
        }

    }

}
