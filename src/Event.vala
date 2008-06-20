using GLib;

namespace DVB {

    /**
     * Represents an EPG event (i.e. a show with all its information)
     */
    public class Event {
    
        public uint id;
        public uint year;
        public uint month; 
        public uint hour;
        public uint day;
        public uint minute;
        public uint second;
        public uint duration;
        public uint running_status;
        public bool free_ca_mode;
        public string name;
        public string description;
        /* Components */
        public string audio_type;
        public string teletext_type;
        public bool high_definition;
        public string aspect_ratio;
        public int frequency;
        
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
            
            return (end_timestamp < current_time);
        }
        
        public string to_string () {
            return "ID: %u\nDate: %u-%u-%u %u:%u:%u\n".printf (this.id,
            this.year, this.month, this.day, this.hour, this.minute, this.second)
            + "Duration: %u\nName: %s\nDescription: %s".printf (
            this.duration, this.name, this.description);
        }
        
        private int64 get_end_timestamp () {
            Time end_time = Utils.create_time ((int)this.year, (int)this.month,
                (int)this.day, (int)this.hour, (int)this.minute,
                (int)this.second);
            end_time.second += (int)this.duration;
            
            return (int64)end_time.mktime ();
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
    }
    
}
