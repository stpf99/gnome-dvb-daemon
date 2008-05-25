
namespace DVB {

    public struct Recording {
        public uint id;
        public uint channel_sid;
        public string location;
        public string? name;
        public string? description;
        public uint[] start;
        public uint length;
    }

}
