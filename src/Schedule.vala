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
        public int64 starttime;
    
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
            this.event_id_map = new HashMap<uint, weak Sequence<EventElement>> ();
            this.epgstore = Factory.get_epg_store ();
            
        	Gee.List<Event> events = this.epgstore.get_events (this.channel);
        	foreach (Event event in events) {
        	    if (event.has_expired ()) {
        	        this.epgstore.remove_event (event.id, this.channel);
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
                        element.id, this.channel);
                }
            }
        }
        
        public Event? get_event (uint event_id) {
            return this.epgstore.get_event (event_id, this.channel.Sid);
        }
        
        /**
         * When an event with the same id already exists, it's replaced
         */
        public void add (Event event) {
            if (event.has_expired ()) return;
        
            lock (this.events) {
                if (this.event_id_map.contains (event.id)) {
                    // Remove old event
                    weak SequenceIter<EventElement> iter = this.event_id_map.get (event.id);
                    
                    this.event_id_map.remove (event.id);
                    this.events.remove (iter);
                }
                
                this.create_and_add_event_element (event);
                
                this.epgstore.add_or_update_event (event, this.channel);
            }
        }
        
        /**
         * Create event element from @event and add it to list of events
         */
        private void create_and_add_event_element (Event event) {
            EventElement element = new EventElement ();
            element.id = event.id;
            Time utc_starttime = event.get_utc_start_time ();
            element.starttime = (int64)utc_starttime.mktime ();
            
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
       
        /*
        public weak Event get_event_around (Time time) {
            return new Event ();
        }*/
        
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
        
        public string GetName (uint32 event_id) {
            string name = "";

            lock (this.events) {        
                if (this.event_id_map.contains (event_id)) {
                    weak SequenceIter<EventElement> iter = this.event_id_map.get (event_id);
                    EventElement element = this.events.get (iter);
                    Event? event = this.get_event (element.id);
                    if (event.name != null)
                        name = event.name;
                } else {
                    debug ("No event with id %u", event_id);
                }
            }
        
            return name;
        }
        
        public string GetShortDescription (uint32 event_id) {
            string desc = "";
            
            lock (this.events) {
                if (this.event_id_map.contains (event_id)) {
                    weak SequenceIter<EventElement> iter = this.event_id_map.get (event_id);
                    EventElement element = this.events.get (iter);
                    Event? event = this.get_event (element.id);
                    if (event.description != null)
                        desc = event.description;
                } else {
                    debug ("No event with id %u", event_id);
                }
            }
            
            return desc;
        }
        
        public string GetExtendedDescription (uint32 event_id) {
             string desc = "";
            
            lock (this.events) {
                if (this.event_id_map.contains (event_id)) {
                    weak SequenceIter<EventElement> iter = this.event_id_map.get (event_id);
                    EventElement element = this.events.get (iter);
                    Event? event = this.get_event (element.id);
                    if (event.extended_description != null)
                        desc = event.extended_description;
                } else {
                    debug ("No event with id %u", event_id);
                }
            }
            
            return desc;
        }
        
        public uint GetDuration (uint32 event_id) {
            uint duration = 0;
        
            lock (this.events) {
                if (this.event_id_map.contains (event_id)) {
                    weak SequenceIter<EventElement> iter = this.event_id_map.get (event_id);
                    EventElement element = this.events.get (iter);
                    Event? event = this.get_event (element.id);
                    duration = event.duration;
                } else {
                    debug ("No event with id %u", event_id);
                }
            }
            
            return duration;
        }
        
        public uint[] GetLocalStartTime (uint32 event_id) {
            uint[] start = new uint[] {};
        
            lock (this.events) {
                if (this.event_id_map.contains (event_id)) {
                    weak SequenceIter<EventElement> iter = this.event_id_map.get (event_id);
                    EventElement element = this.events.get (iter);
                    Event? event = this.get_event (element.id);
                    Time local_time = event.get_local_start_time ();
                    start = new uint[6];
                    start[0] = local_time.year + 1900;
                    start[1] = local_time.month + 1;
                    start[2] = local_time.day;
                    start[3] = local_time.hour;
                    start[4] = local_time.minute;
                    start[5] = local_time.second;
                } else {
                    debug ("No event with id %u", event_id);
                }
            }
            
            return start;
        }
        
        public bool IsRunning (uint32 event_id) {
            bool val = false;
        
            lock (this.events) {
                if (this.event_id_map.contains (event_id)) {
                    weak SequenceIter<EventElement> iter = this.event_id_map.get (event_id);
                    EventElement element = this.events.get (iter);
                    Event? event = this.get_event (element.id);
                    val = (event.is_running ());
                } else {
                    debug ("No event with id %u", event_id);
                }
            }
            
            return val;
        }
        
        public bool IsScrambled (uint32 event_id) {
            bool val = false;
        
            lock (this.events) {
                if (this.event_id_map.contains (event_id)) {
                    weak SequenceIter<EventElement> iter = this.event_id_map.get (event_id);
                    EventElement element = this.events.get (iter);
                    Event? event = this.get_event (element.id);
                    val = (!event.free_ca_mode);
                } else {
                    debug ("No event with id %u", event_id);
                }
            }
            
            return val;
        }
    }

}
