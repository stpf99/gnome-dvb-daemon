
namespace DVB {

    public class Recording : GLib.Object {
        public uint Id {get; set;}
        public uint ChannelSid {get; set;}
        public string Location {get; set;}
        public string? Name {get; set;}
        public string? Description {get; set;}
        public GLib.Time StartTime {get; set;}
        public int64 Length {get; set;}
        
        public uint[] get_start () {
            return new uint[] {
                this.StartTime.year + 1900,
                this.StartTime.month + 1,
                this.StartTime.day,
                this.StartTime.hour,
                this.StartTime.minute
            };
        }
    }

}
