using GLib;
using Gee;

namespace DVB {

    /**
     * Represents a series of events of a channel
     */
    public class Schedule : GLib.Object {
    
        private Sequence<Event> events;
        private HashMap<uint, SequenceIter<Event>> event_id_map;
        
        construct {
            this.events = new Sequence<Event> (null);
            //this.event_id_map = new HashMap<uint, SequenceIter<Event>> ();
        }
        
        public void remove_expired_events () {
            SList<int> expired_events = new SList <int> ();
            
            for (int i=0; i<this.events.get_length (); i++) {
                SequenceIter<Event> iter = this.events.get_iter_at_pos (i);
                
                Event e = this.events.get (iter);
                if (e.has_expired ()) expired_events.prepend (i);
            }
            
            foreach (int i in expired_events) {
                SequenceIter<Event> iter = this.events.get_iter_at_pos (i);
                this.events.remove (iter);
            }
        }
        
        public weak Event? get (uint event_id) {
            if (!this.event_id_map.contains (event_id)) return null;
            
            SequenceIter<Event> iter = this.event_id_map.get (event_id);
        
            return this.events.get (iter);
        }
        
        public void add (Event# event) {
            //if (!this.event_id_map.contains (event.id)) {
                SequenceIter<Event> iter = this.events.insert_sorted (#event, Event.compare);
            //    this.event_id_map.set (event.id, iter);
            //}
        }
        /*
        public weak Event get_present_event () {
            return new Event ();
        }*/
    
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
