using GLib;
using Gee;

namespace DVB {

    public class ChannelList : GLib.Object, Iterable<Channel>, IDBusChannelList {
        
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
            Channel? val = null;
            lock (this.channels) {
                if (this.channels.contains (sid))
                    val = this.channels.get (sid);
            }
            return val;
        }
        
        public void add (Channel# channel) {
            lock (this.channels) {
                this.channels.set (channel.Sid, channel);
            }
        }
        
        public bool contains (uint sid) {
            bool val;
            lock (this.channels) {
                val = this.channels.contains (sid);
            }
            return val;
        }
        
        public void clear () {
            lock (this.channels) {
                this.channels.clear ();
            }
        }
        
        public Type get_element_type () {
            return typeof(Channel);
        }
        
        public Iterator<Channel> iterator () {
            return this.channels.get_values().iterator();
        }
        
        public static ChannelList restore_from_file (File channelsfile, AdapterType type) throws Error {
            // FIXME make thread-safe
            var reader = new DVB.ChannelListReader (channelsfile, type);
            return reader.read ();
        }
        
        /**
         * @returns: List of channel IDs
         */
        public uint[] GetChannels () {
            uint[] ids = new uint32[this.size];
            int i=0;
            lock (this.channels) {
                foreach (uint id in this.channels.get_keys ()) {
                    ids[i] = id;
                    i++;
                }
            }
            
            return ids;
        }
        
        /**
         * @channel_id: ID of channel
         * @returns: Name of channel if channel with id exists
         * otherwise an empty string
         */
        public string GetChannelName (uint channel_id) {
            string val = "";
            
            lock (this.channels) {
                if (this.channels.contains (channel_id))
                    val = this.channels.get (channel_id).Name;   
            }
            
            return val;
        }
        
        /**
         * @channel_id: ID of channel
         * @returns: Name of network the channel belongs to
         * if the channel with id exists, otherwise an empty
         * string
         */
        public string GetChannelNetwork (uint channel_id) {
            string val = "";
            lock (this.channels) {
                if (this.channels.contains (channel_id))
                    val = this.channels.get (channel_id).Network;   
            }
            
            return val;
        }
        
        /**
         * @channel_id: ID of channel
         * @returns: SID of channel or 0 if channel
         * with given ID doesn't exist
         */
        public uint GetChannelSid (uint channel_id) {
            uint val = 0;
            lock (this.channels) {
                if (this.channels.contains (channel_id))
                    val = this.channels.get (channel_id).Sid;   
            }
            
            return val;
        }
    }

}
