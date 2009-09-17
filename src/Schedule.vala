/*
 * Copyright (C) 2008,2009 Sebastian Pölsterl
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

namespace DVB {

    /**
     * We don't want to hold the complete information about
     * every event in memory. Just remember id and starttime
     * so we can have a sorted list.
     */
    class EventElement : GLib.Object {
    
        public uint id;
        /* Time is stored in UTC */
        public time_t starttime;
    
        public static int compare (EventElement* event1, EventElement* event2) {
            if (event1 == null && event2 == null) return 0;
            else if (event1 == null && event2 != null) return +1;
            else if (event1 != null && event2 == null) return -1;
        
            if (event1->starttime < event2->starttime) return -1;
            else if (event1->starttime > event2->starttime) return +1;
            else return 0;
        }
        
        public static void destroy (void* data) {
            EventElement e = (EventElement) data;
            g_object_unref (e);
        }
        
    }

    /**
     * Represents a series of events of a channel
     */
    public class Schedule : GLib.Object, IDBusSchedule {
    
        // Use weak to avoid ref cycle
        public weak Channel channel {get; construct;}
    
        private Sequence<EventElement> events;
        private Map<uint, weak SequenceIter<EventElement>> event_id_map;
        private weak EPGStore epgstore;
        
        construct {
            this.events = new Sequence<EventElement> (EventElement.destroy);
            this.event_id_map = new HashMap<uint, weak SequenceIter<EventElement>> ();
            this.epgstore = Factory.get_epg_store ();
            
        	Gee.List<Event> events = this.epgstore.get_events (
        	    this.channel.Sid, this.channel.GroupId);
        	foreach (Event event in events) {
        	    if (event.has_expired ()) {
        	        this.epgstore.remove_event (event.id, this.channel.Sid,
        	            this.channel.GroupId);
        	    } else {
        		    this.create_and_add_event_element (event);
        		}
        	}
        }
        
        public Schedule (Channel channel) {
            this.channel = channel;
        }
        
        public void remove_expired_events () {
            SList<weak SequenceIter<EventElement>> expired_events = new SList <weak SequenceIter<EventElement>> ();
            
            lock (this.events) {
                for (int i=0; i<this.events.get_length (); i++) {
                    SequenceIter<EventElement> iter = this.events.get_iter_at_pos (i);
                    
                    EventElement element = this.events.get (iter);
                    Event? e = this.get_event (element.id);
                    if (e != null && e.has_expired ()) {
                        expired_events.prepend (iter);
                    } else {
                        // events are sorted, all other events didn't expire, too
                        break;
                    }
                }
                
                foreach (weak SequenceIter<EventElement> iter in expired_events) {
                    debug ("Removing expired event");
                    EventElement element = this.events.get (iter);
                    
                    this.event_id_map.remove (element.id);
                    this.events.remove (iter);
                    this.epgstore.remove_event (
                        element.id, this.channel.Sid, this.channel.GroupId);
                }
            }
        }
        
        public Event? get_event (uint event_id) {
            return this.epgstore.get_event (event_id,
                this.channel.Sid, this.channel.GroupId);
        }
        
        /**
         * When an event with the same id already exists, it's replaced
         */
        public void add (Event event) {
            if (event.has_expired ()) return;
            
            lock (this.events) {
                if (!this.event_id_map.contains (event.id)) {
                    this.create_and_add_event_element (event);
                }
                
                this.epgstore.add_or_update_event (event, this.channel.Sid,
                    this.channel.GroupId);
            }
        }
        
        /**
         * Create event element from @event and add it to list of events
         */
        private void create_and_add_event_element (Event event) {
            EventElement element = new EventElement ();
            element.id = event.id;
            Time utc_starttime = event.get_utc_start_time ();
            element.starttime = utc_starttime.mktime ();
            
            SequenceIter<EventElement> iter = this.events.insert_sorted (element, EventElement.compare);
            this.event_id_map.set (event.id, iter);
            
            assert (this.events.get_length () == this.event_id_map.size);
        }
        
        public bool contains (uint event_id) {
            bool val;
            lock (this.events) {
                val = this.event_id_map.contains (event_id);
            }
            return val;
        }
        
        public Event? get_running_event () {
             Event? running_event = null;
             lock (this.events) {
                 for (int i=0; i<this.events.get_length (); i++) {
                    SequenceIter<EventElement> iter = this.events.get_iter_at_pos (i);
                    
                    EventElement element = this.events.get (iter);
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
            time_t start_t = start.mktime ();
            time_t end_t = start_t + duration * 60;
            lock (this.events) {
                // Difference between end of timer and end of event
                time_t last_diff = -3600;
                for (int i=0; i<this.events.get_length (); i++) {
                    SequenceIter<EventElement> iter = this.events.get_iter_at_pos (i);
                    EventElement element = this.events.get (iter);
                    // convert UTC to local time
                    time_t event_start = cUtils.timegm (Time.local (element.starttime));

                    // Check if event starts after timer and ends before timer
                    if (event_start >= start_t && event_start <= end_t) {
                        Event? event = this.get_event (element.id);
                        if (event != null) {
                            time_t event_end = event_start + event.duration;
                            time_t end_diff = end_t - event_end;
                            // If the difference is bigger we are sure that
                            // this one is the right event
                            if (last_diff < end_diff) {
                                last_diff = end_diff;
                                result = event;
                            }
                        }
                    } else if (event_start > end_t) {
                        // All other events are too far in the future
                        break;
                    }
                }
            }
            return result;
        }

        public uint32[] GetAllEvents () {
            uint32[] event_ids = new uint32[this.events.get_length ()];
            
            lock (this.events) {
                 for (int i=0; i<this.events.get_length (); i++) {
                    SequenceIter<EventElement> iter = this.events.get_iter_at_pos (i);
                    EventElement element = this.events.get (iter);
                    event_ids[i] = element.id;
                 }
            }
            
            return event_ids;
        }

        public EventInfo[] GetAllEventInfos () {
            EventInfo[] events = new EventInfo[this.events.get_length ()];
            lock (this.events) {
                SequenceIter<EventElement> iter = this.events.get_begin_iter ();
                if (!iter.is_end ()) {
                    EventElement element = this.events.get (iter);
                    int i = 0;
                    while (!iter.is_end ()) {
                        EventInfo event_info = EventInfo();
                        Event? event = this.get_event (element.id);
                        
                        event_info.id = element.id;
                        event_info.name = event.name;
                        event_info.duration = event.duration;
                        event_info.short_description = event.description;
                        /*
                        Time local_time = event.get_local_start_time ();
                        event_info.local_start = to_time_array (local_time);
                        */
                        iter = iter.next ();
                        if (iter.is_end ()) {
                            event_info.next = 0;
                        } else {
                            element = this.events.get (iter);
                            event_info.next = element.id;
                        }
                        events[i] = event_info;
                        
                        i++;
                     }
                }
            }
            
            return events;
        }

        public bool GetInformations (uint32 event_id, out EventInfo event_info) {
            bool ret = false;
            event_info = EventInfo();
            
            lock (this.events) {        
                if (this.event_id_map.contains (event_id)) {
                    SequenceIter<EventElement> iter = this.event_id_map.get (event_id);
                    EventElement element = this.events.get (iter);
                    Event? event = this.get_event (element.id);
                    
                    event_info.id = element.id;
                    event_info.name = event.name;
                    event_info.duration = event.duration;
                    event_info.short_description = event.description;
                    /*
                    Time local_time = event.get_local_start_time ();
                    event_info.local_start = to_time_array (local_time);
                    */
                    iter = iter.next ();
                    if (iter.is_end ()) {
                        event_info.next = 0;
                    } else {
                        element = this.events.get (iter);
                        event_info.next = element.id;
                    }
                    ret = true;
                }
            }
            
            return ret;
        }
        
        public uint32 NowPlaying () {
            Event? event = this.get_running_event ();
            
            return (event == null) ? 0 : event.id;
        }
        
        public uint32 Next (uint32 event_id) {
            uint32 next_event = 0;
            lock (this.events) {
                if (this.event_id_map.contains (event_id)) {
                    weak SequenceIter<EventElement> iter = this.event_id_map.get (event_id);
                    SequenceIter<EventElement> next_iter = iter.next ();
                    // Check if a new event follows
                    if (!next_iter.is_end ()) {
                        EventElement element = this.events.get (next_iter);
                        next_event = element.id;
                    }
                } else {
                    debug ("No event with id %u", event_id);
                }
            }
            
            return next_event;
        }
        
        public bool GetName (uint32 event_id, out string name) {
            bool ret = false;

            lock (this.events) {        
                if (this.event_id_map.contains (event_id)) {
                    weak SequenceIter<EventElement> iter = this.event_id_map.get (event_id);
                    EventElement element = this.events.get (iter);
                    Event? event = this.get_event (element.id);
                    if (event.name != null) {
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
        
        public bool GetShortDescription (uint32 event_id, out string description) {
            bool ret = false;
            
            lock (this.events) {
                if (this.event_id_map.contains (event_id)) {
                    weak SequenceIter<EventElement> iter = this.event_id_map.get (event_id);
                    EventElement element = this.events.get (iter);
                    Event? event = this.get_event (element.id);
                    if (event.description != null) {
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
        
        public bool GetExtendedDescription (uint32 event_id, out string description) {
            bool ret = false;
            
            lock (this.events) {
                if (this.event_id_map.contains (event_id)) {
                    weak SequenceIter<EventElement> iter = this.event_id_map.get (event_id);
                    EventElement element = this.events.get (iter);
                    Event? event = this.get_event (element.id);
                    if (event.extended_description != null) {
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
        
        public bool GetDuration (uint32 event_id, out uint duration) {
            bool ret = false;
        
            lock (this.events) {
                if (this.event_id_map.contains (event_id)) {
                    weak SequenceIter<EventElement> iter = this.event_id_map.get (event_id);
                    EventElement element = this.events.get (iter);
                    Event? event = this.get_event (element.id);
                    duration = event.duration;
                    ret = true;
                } else {
                    debug ("No event with id %u", event_id);
                }
            }
            
            return ret;
        }
        
        public bool GetLocalStartTime (uint32 event_id, out uint[] start_time) {
            bool ret = false;
        
            lock (this.events) {
                if (this.event_id_map.contains (event_id)) {
                    weak SequenceIter<EventElement> iter = this.event_id_map.get (event_id);
                    EventElement element = this.events.get (iter);
                    Event? event = this.get_event (element.id);
                    Time local_time = event.get_local_start_time ();
                    start_time = to_time_array (local_time);
                    ret = true;
                } else {
                    debug ("No event with id %u", event_id);
                    start_time = new uint[] {};
                }
            }
            
            return ret;
        }
        
        public bool GetLocalStartTimestamp (uint32 event_id, out int64 timestamp) {
            bool ret = false;
            lock (this.events) {
                if (this.event_id_map.contains (event_id)) {
                    weak SequenceIter<EventElement> iter = this.event_id_map.get (event_id);
                    EventElement element = this.events.get (iter);
                    Event? event = this.get_event (element.id);
                    Time local_time = event.get_local_start_time ();
                    timestamp = (int64)local_time.mktime ();
                    ret = true;
                }
            }
            return ret;
        }
        
        public bool IsRunning (uint32 event_id, out bool running) {
            bool ret = false;
        
            lock (this.events) {
                if (this.event_id_map.contains (event_id)) {
                    weak SequenceIter<EventElement> iter = this.event_id_map.get (event_id);
                    EventElement element = this.events.get (iter);
                    Event? event = this.get_event (element.id);
                    running = (event.is_running ());
                    ret = true;
                } else {
                    debug ("No event with id %u", event_id);
                }
            }
            
            return ret;
        }
        
        public bool IsScrambled (uint32 event_id, out bool scrambled) {
            bool ret = false;
        
            lock (this.events) {
                if (this.event_id_map.contains (event_id)) {
                    weak SequenceIter<EventElement> iter = this.event_id_map.get (event_id);
                    EventElement element = this.events.get (iter);
                    Event? event = this.get_event (element.id);
                    scrambled = (!event.free_ca_mode);
                    ret = true;
                } else {
                    debug ("No event with id %u", event_id);
                }
            }
            
            return ret;
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
    }

}
