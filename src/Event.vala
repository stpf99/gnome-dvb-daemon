using GLib;

namespace DVB {

    /**
     * Represents an EPG event (i.e. a show with all its information)
     */
    public class Event {
    
        public uint id;
        /* Time is stored in UTC */
        public uint year;
        public uint month; 
        public uint hour;
        public uint day;
        public uint minute;
        public uint second;
        public uint duration; // in seconds
        public uint running_status;
        public bool free_ca_mode;
        public string name;
        public string description;
        /* Components */
        public SList<AudioComponent> audio_components;
        public SList<VideoComponent> video_components;
        public SList<TeletextComponent> teletext_components;
        
        construct {
            this.audio_components = new SList<AudioComponent> ();
            this.video_components = new SList<VideoComponent> ();
            this.teletext_components = new SList<TeletextComponent> ();
            
            this.year = 0;
            this.month = 0; 
            this.hour = 0;
            this.day = 0;
            this.minute = 0;
            this.second = 0;
            this.duration = 0;
        }
        
        public string serialize () {
            return "";
        }
        
        public static Event deserialize () {
            return new Event ();
        }
        
        /**
         * Whether the event has started and ended in the past
         */
        public bool has_expired () {
            int64 current_time = (int64)time_t ();
            
            int64 end_timestamp = this.get_end_timestamp ();
            debug ("%u, Current: %s, End: %s", this.id, current_time.to_string(), end_timestamp.to_string());
            return (end_timestamp < current_time);
        }
        
        public string to_string () {
            string text = "ID: %u\nDate: %04u-%02u-%02u %02u:%02u:%02u\n".printf (this.id,
            this.year, this.month, this.day, this.hour, this.minute, this.second)
            + "Duration: %u\nName: %s\nDescription: %s\n".printf (
            this.duration, this.name, this.description);
            
            for (int i=0; i<this.audio_components.length (); i++) {
                text += "%s ".printf(this.audio_components.nth_data (i).type);
            }
            return text;
        }
        
        /**
         * @returns: UNIX time stamp
         */
        private int64 get_end_timestamp () {
            Time end_time = Utils.create_utc_time ((int)this.year, (int)this.month,
                (int)this.day, (int)this.hour, (int)this.minute,
                (int)this.second);
                
            int64 before = (int64)end_time.mktime ();
            
            end_time.second += (int)this.duration;
            
            int64 after = (int64)end_time.mktime ();
            
            assert (after > before && after - before == this.duration);
            
            return after;
        }
        
        /**
         * @returns: negative value if event1 starts before event2,
         * positive value if event1 starts after event2 and zero else
         *
         * Compare the starting time of two events
         */
        public static int compare (Event* event1, Event* event2) {
            if (event1 == null && event2 == null) return 0;
            else if (event1 == null && event2 != null) return +1;
            else if (event1 != null && event2 == null) return -1;
        
            int64 event1_time = event1->get_end_timestamp ();
            int64 event2_time = event2->get_end_timestamp ();
            
            if (event1_time < event2_time) return -1;
            else if (event1_time > event2_time) return +1;
            else return 0;
        }
        
        /**
         * @returns: TRUE if event1 and event2 represent the same event,
         * else FALSE
         *
         * event1 and event2 must be part of the same transport stream
         */
        public static bool equal (Event* event1, Event* event2) {
            if (event1 == null || event2 == null) return false;
            
            return (event1->id == event2->id);
        }
        
        public class AudioComponent {
            public string type;
        }
        
        public class VideoComponent {
            public bool high_definition;
            public string aspect_ratio;
            public int frequency;
        }
        
        public class TeletextComponent {
            public string type;
        }
    }
    
}
