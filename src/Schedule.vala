using GLib;
using Gee;

namespace DVB {

    /**
     * Represents a series of events of a channel
     */
    public class Schedule : GLib.Object, IDBusSchedule {
    
        private Sequence<Event> events;
        private HashMap<uint, weak SequenceIter<Event>> event_id_map;
        
        construct {
            this.events = new Sequence<Event> (null);
            this.event_id_map = new HashMap<uint, weak SequenceIter<Event>> ();
        }
        
        public void remove_expired_events () {
            SList<weak SequenceIter<Event>> expired_events = new SList <weak SequenceIter<Event>> ();
            
            lock (this.events) {
                for (int i=0; i<this.events.get_length (); i++) {
                    weak SequenceIter<Event> iter = this.events.get_iter_at_pos (i);
                    
                    Event e = this.events.get (iter);
                    if (e.has_expired ()) {
                        expired_events.prepend (iter);
                    } else {
                        // events are sorted, all other events didn't expire, too
                        break;
                    }
                }
                
                foreach (weak SequenceIter<Event> iter in expired_events) {
                    debug ("Removing expired event");
                    Event event = this.events.get (iter);
                    debug (event.to_string ());
                    this.event_id_map.remove (event.id);
                    this.events.remove (iter);
                }
            }
        }
        
        public weak Event? get (uint event_id) {
            Event? val = null;
            
            lock (this.events) {
                if (this.event_id_map.contains (event_id)) {            
                    weak SequenceIter<Event> iter = this.event_id_map.get (event_id);
                    val = this.events.get (iter);
                }
            }
            
            return val;
        }
        
        /**
         * When an event with the same id already exists, it's replaced
         */
        public void add (Event# event) {
            lock (this.events) {
                if (this.event_id_map.contains (event.id)) {
                    // Remove old event
                    weak SequenceIter<Event> iter = this.event_id_map.get (event.id);
                    
                    this.event_id_map.remove (event.id);
                    this.events.remove (iter);
                }
                weak SequenceIter<Event> iter = this.events.insert_sorted (event, Event.compare);
                this.event_id_map.set (event.id, iter);
                
                assert (this.events.get_length () == this.event_id_map.size);
            }
        }
        
        public bool contains (uint event_id) {
            bool val;
            lock (this.events) {
                val = this.event_id_map.contains (event_id);
            }
            return val;
        }
        
        public weak Event? get_running_event () {
             Event? running_event = null;
             lock (this.events) {
                 for (int i=0; i<this.events.get_length (); i++) {
                    weak SequenceIter<Event> iter = this.events.get_iter_at_pos (i);
                    
                    Event event = this.events.get (iter);
                    if (event.running_status == Event.RUNNING_STATUS_RUNNING) {
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
        
        public uint32 NowPlaying () {
            weak Event? event = this.get_running_event ();
            
            return (event == null) ? 0 : event.id;
        }
        
        public uint32 Next (uint32 event_id) {
            weak Event? event = this.get_running_event ();
            
            uint32 next_event = 0;
            if (event != null) {
                lock (this.events) {
                    weak SequenceIter<Event> iter = this.event_id_map.get (event_id);
                    weak SequenceIter<Event> next_iter = iter.next ();
                    // Check if a new event follows
                    if (iter != next_iter) {
                        next_event = this.events.get (next_iter).id;
                    }
                }
            }
            
            return next_event;
        }
        
        public string GetName (uint32 event_id) {
            string name = "";

            lock (this.events) {        
                if (this.event_id_map.contains (event_id)) {
                    weak SequenceIter<Event> iter = this.event_id_map.get (event_id);
                    Event event = this.events.get (iter);
                    name = event.name;
                }
            }
        
            return name;
        }
        
        public string GetShortDescription (uint32 event_id) {
            string desc = "";
            
            lock (this.events) {
                if (this.event_id_map.contains (event_id)) {
                    weak SequenceIter<Event> iter = this.event_id_map.get (event_id);
                    Event event = this.events.get (iter);
                    desc = event.description;
                }
            }
            
            return desc;
        }
        
        public string GetExtendedDescription (uint32 event_id) {
             string desc = "";
            
            lock (this.events) {
                if (this.event_id_map.contains (event_id)) {
                    weak SequenceIter<Event> iter = this.event_id_map.get (event_id);
                    Event event = this.events.get (iter);
                    desc = event.extended_description;
                }
            }
            
            return desc;
        }
        
        public uint GetDuration (uint32 event_id) {
            uint duration = 0;
        
            lock (this.events) {
                if (this.event_id_map.contains (event_id)) {
                    weak SequenceIter<Event> iter = this.event_id_map.get (event_id);
                    Event event = this.events.get (iter);
                    duration = event.duration;
                }
            }
            
            return duration;
        }
        
        public uint[] GetLocalStartTime (uint32 event_id) {
            uint[] start = new uint[] {};
        
            lock (this.events) {
                if (this.event_id_map.contains (event_id)) {
                    weak SequenceIter<Event> iter = this.event_id_map.get (event_id);
                    Event event = this.events.get (iter);
                    Time local_time = event.get_local_start_time ();
                    uint[] start = new uint[6];
                    start[0] = local_time.year + 1900;
                    start[1] = local_time.month + 1;
                    start[2] = local_time.day;
                    start[3] = local_time.hour;
                    start[4] = local_time.minute;
                    start[5] = local_time.second;
                }
            }
            
            return start;
        }
        
        public bool IsRunning (uint32 event_id) {
            bool val = false;
        
            lock (this.events) {
                if (this.event_id_map.contains (event_id)) {
                    weak SequenceIter<Event> iter = this.event_id_map.get (event_id);
                    Event event = this.events.get (iter);
                    val = (event.running_status == Event.RUNNING_STATUS_RUNNING);
                }
            }
            
            return val;
        }
        
        public bool IsScrambled (uint32 event_id) {
            bool val = false;
        
            lock (this.events) {
                if (this.event_id_map.contains (event_id)) {
                    weak SequenceIter<Event> iter = this.event_id_map.get (event_id);
                    Event event = this.events.get (iter);
                    val = (!event.free_ca_mode);
                }
            }
            
            return val;
        }
    }

}
