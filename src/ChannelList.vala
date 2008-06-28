using GLib;
using Gee;

namespace DVB {

    public class ChannelList : GLib.Object, Iterable<Channel> {
        
        public File channels_file {get; construct;}
        public int size {
            get { return this.channels.size; }
        }
        
        /**
         * Maps channels' SID to the channels' data
         */
        protected HashMap<uint, Channel> channels;
        
        private File? channelsfile;
        
        construct {
            this.channels = new HashMap<uint, Channel> ();
        }
        
        public ChannelList (File? channelsfile = null) {
            this.channels_file = channelsfile;
        }
        
        public Channel? get (uint sid) {
            if (this.channels.contains (sid))
                return this.channels.get (sid);
            else
                return null;
        }
        
        public void add (Channel# channel) {
            this.channels.set (channel.Sid, channel);
        }
        
        public bool contains (uint sid) {
            return this.channels.contains (sid);
        }
        
        public void clear () {
            this.channels.clear ();
        }
        
        public Type get_element_type () {
            return typeof(Channel);
        }
        
        public Iterator<Channel> iterator () {
            return this.channels.get_values().iterator();
        }
        
        public static ChannelList restore_from_file (File channelsfile, AdapterType type) throws Error {
            var reader = new DVB.ChannelListReader (channelsfile, type);
            return reader.read ();
        }
    }

}
