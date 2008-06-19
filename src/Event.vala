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
        
        public string to_string () {
            return "ID: %u\nDate: %u-%u-%u %u:%u:%u\n".printf (this.id,
            this.year, this.month, this.day, this.hour, this.minute, this.second)
            + "Duration: %u\nName: %s\nDescription: %s".printf (
            this.duration, this.name, this.description);
        }
    
    }
    
}
