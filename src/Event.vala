using GLib;

namespace DVB {

    /**
     * Represents an EPG event (i.e. a show with all its information)
     */
    [Compact]
    public class Event {
    
        public uint id;
        public uint year;
        public uint month; 
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
    
    }
    
}
