using GLib;
using Gee;

namespace DVB {

    /**
     * Represents a series of events of a channel
     */
    public class Schedule : GLib.Object {
    
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
                Event e = this.events.get (iter);
                debug (e.to_string ());
                this.event_id_map.remove (e.id);
                this.events.remove (iter);
            }
        }
        
        public weak Event? get (uint event_id) {
            if (!this.event_id_map.contains (event_id)) return null;
            
            weak SequenceIter<Event> iter = this.event_id_map.get (event_id);
        
            return this.events.get (iter);
        }
        
        public void add (Event# event) {
            if (!this.event_id_map.contains (event.id)) {
                weak SequenceIter<Event> iter = this.events.insert_sorted (event, Event.compare);
                this.event_id_map.set (event.id, iter);
            }
            
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
    
        /**
         * @returns: The event following the present event
         */
        /*public weak Event get_following_event () {
            return new Event ();
        }
        
        public weak Event get_event_around (Time time) {
            return new Event ();
        }*/
    }

}
