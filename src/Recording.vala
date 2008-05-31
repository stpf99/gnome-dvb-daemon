
namespace DVB {

    public struct Recording {
        public uint id;
        public uint channel_sid;
        public string location;
        public string? name;
        public string? description;
        public GLib.Time start_time;
        public int64 length;
        
        public uint[] get_start () {
            return new uint[] {
                this.start_time.year + 1900,
                this.start_time.month + 1,
                this.start_time.day,
                this.start_time.hour,
                this.start_time.minute
            };
        }
    }

}
