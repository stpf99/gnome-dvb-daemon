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
        
        public weak Event? get (uint event_id) {
            if (!this.event_id_map.contains (event_id)) return null;
            
            weak SequenceIter<Event> iter = this.event_id_map.get (event_id);
        
            return this.events.get (iter);
        }
        
        /**
         * When an event with the same id already exists, it's replaced
         */
        public void add (Event# event) {
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
        
        public bool contains (uint event_id) {
            return this.event_id_map.contains (event_id);
        }
        
        public weak Event? get_running_event () {
             for (int i=0; i<this.events.get_length (); i++) {
                weak SequenceIter<Event> iter = this.events.get_iter_at_pos (i);
                
                Event event = this.events.get (iter);
                if (event.running_status == Event.RUNNING_STATUS_RUNNING) {
                    return event;
                }
            }
            
            return null;
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
            
            if (event != null) {
                weak SequenceIter<Event> iter = this.event_id_map.get (event_id);
                weak SequenceIter<Event> next_iter = iter.next ();
                // Check if a new event follows
                if (iter != next_iter) {
                    return this.events.get (next_iter).id;
                }
            }
            
            return 0;
        }
        
        public string GetName (uint32 event_id) {
            if (this.event_id_map.contains (event_id)) {
                weak SequenceIter<Event> iter = this.event_id_map.get (event_id);
                Event event = this.events.get (iter);
                return event.name;
            }
        
            return "";
        }
        
        public string GetShortDescription (uint32 event_id) {
            if (this.event_id_map.contains (event_id)) {
                weak SequenceIter<Event> iter = this.event_id_map.get (event_id);
                Event event = this.events.get (iter);
                return event.description;
            }
            
            return "";   
        }
        
        public string GetExtendedDescription (uint32 event_id) {
            if (this.event_id_map.contains (event_id)) {
                weak SequenceIter<Event> iter = this.event_id_map.get (event_id);
                Event event = this.events.get (iter);
                return event.extended_description;
            }
            
            return "";
        }
        
        public uint GetDuration (uint32 event_id) {
            if (this.event_id_map.contains (event_id)) {
                weak SequenceIter<Event> iter = this.event_id_map.get (event_id);
                Event event = this.events.get (iter);
                return event.duration;
            }
            
            return 0;
        }
        
        public uint[] GetLocalStartTime (uint32 event_id) {
            if (this.event_id_map.contains (event_id)) {
                weak SequenceIter<Event> iter = this.event_id_map.get (event_id);
                Event event = this.events.get (iter);
            }
            
            return new uint[] {};
        }
        
        public bool IsRunning (uint32 event_id) {
            if (this.event_id_map.contains (event_id)) {
                weak SequenceIter<Event> iter = this.event_id_map.get (event_id);
                Event event = this.events.get (iter);
                return (event.running_status == Event.RUNNING_STATUS_RUNNING);
            }
            
            return true;
        }
        
        public bool IsScrambled (uint32 event_id) {
            if (this.event_id_map.contains (event_id)) {
                weak SequenceIter<Event> iter = this.event_id_map.get (event_id);
                Event event = this.events.get (iter);
                return (!event.free_ca_mode);
            }
            
            return true;
        }
    }

}
