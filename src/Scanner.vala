using GLib;
using Gee;

namespace DVB {

    /**
     * An abstract class responsible for scanning for new channels
     */
    public abstract class Scanner : GLib.Object {

        /**
         * Emitted when the Destroy () method is called
         */
        public signal void destroyed ();

        /**
         * Emitted when a frequency has been scanned.
         * Whether a new channel has been found on that frequency or not.
         */
        public signal void frequency_scanned (uint frequency, uint freq_left);
        
        /**
         * @frequency: Frequency of the channel
         * @sid: SID of the channel
         * @name: Name of the channel
         * @network: Name of network the channel is part of
         * @type: What type of channel this is (Radio or TV)
         * @scrambled: Whether the channel is scrambled
         *
         * Emitted when a new channel has been found
         */
        public signal void channel_added (uint frequency, uint sid,
            string name, string network, string type, bool scrambled);
        
        /**
         * Emitted when all frequencies have been scanned
         */
        public signal void finished ();
        
        /**
         * The DVB device the scanner should use
         */
        [DBus (visible = false)]
        public DVB.Device Device { get; construct; }

        [DBus (visible = false)]
        public ChannelList Channels {
            get { return this.channels; }
        }
        
        protected ChannelList channels;

        /**
         * The Gst pipeline used for scanning
         */
        protected Gst.Element pipeline;
        
        /**
         * Contains the tuning parameters we use for scanning
         */
        protected Queue<Gst.Structure> frequencies;
        
        /**
         * The tuning paramters we're currently using
         */
        protected Gst.Structure? current_tuning_params;
            
        /**
         * All the frequencies that have been scanned already
         */
        protected HashSet<ScannedItem> scanned_frequencies;
        
        protected HashMap<uint, Gst.Structure> transport_streams;
        
        private static const string BASE_PIDS = "0:16:17:18";
        
        // Contains SIDs
        private ArrayList<uint> new_channels;
        private uint check_for_lock_event_id;
        private uint wait_for_tables_event_id;
        private bool nit_arrived;
        private bool sdt_arrived;
        private bool pat_arrived;
        private bool locked;
        private string prev_pids;
        
        construct {
            this.scanned_frequencies =
                new HashSet<ScannedItem> (ScannedItem.hash, ScannedItem.equal);
            this.new_channels = new ArrayList<uint> ();
            this.frequencies = new Queue<Gst.Structure> ();
            this.transport_streams = new HashMap<uint, Gst.Structure> ();
        }
        
        /**
         * Setup the pipeline correctly
         */
        protected abstract void prepare();
        
        /**
         * Use the frequency and possibly other data to
         * mark the tuning paramters as already used
         */
        protected abstract ScannedItem get_scanned_item (Gst.Structure structure);
        
        /**
         * Return a new empty channel
         */
        protected abstract Channel get_new_channel ();
        
        /**
         * Retrieve the data from structure and add it to the Channel
         */
        protected abstract void add_values_from_structure_to_channel (Gst.Structure delivery, Channel channel);
        
        /**
         * Start the scanner
         */
        public void Run () {
            this.channels = new ChannelList ();
            // pids: 0=pat, 16=nit, 17=sdt, 18=eit
            try {
                this.pipeline = Gst.parse_launch(
                    "dvbsrc name=dvbsrc adapter=%u frontend=%u ".printf (
                    this.Device.Adapter, this.Device.Frontend)
                    + "pids=%s stats-reporting-interval=0 ".printf (BASE_PIDS)
                    + "! mpegtsparse ! fakesink silent=true");
            } catch (Error e) {
                error (e.message);
                return;
            }
            
            Gst.Bus bus = this.pipeline.get_bus();
            bus.add_signal_watch();
            bus.message += this.bus_watch_func;
            
            this.pipeline.set_state(Gst.State.READY);
            
            this.start_scan();
        }
        
        /**
         * Abort scanning and cleanup
         */
        public void Destroy () {
            this.remove_check_for_lock_timeout ();
            this.remove_wait_for_tables_timeout ();
            this.clear_and_reset_all ();
            this.channels.clear ();
            this.channels = null;
            this.destroyed ();
        }
        
        /** 
         * @path: Location where the file will be stored
         *
         * Write all the channels stored in this.Channels to file
         */
        public bool WriteChannelsToFile (string path) {
            bool ret = false;
            try {
                var writer = new ChannelListWriter (File.new_for_path (path));
                foreach (DVB.Channel c in this.Channels) {
                    writer.write (c);
                }
                writer.close ();
                ret = true;
            } catch (IOError e) {
                critical (e.message);
            }
            
            return ret;
        }
        
        protected void clear_and_reset_all () {
            if (this.pipeline != null) {
                this.pipeline.set_state (Gst.State.NULL);
                // Free pipeline
                this.pipeline = null;
            }
            
            this.transport_streams.clear ();
            this.scanned_frequencies.clear ();
            this.clear_frequencies ();
            this.current_tuning_params = null;
            this.new_channels.clear ();
        }
        
        protected void clear_frequencies () {
            while (!this.frequencies.is_empty ()) {
                Gst.Structure? s = this.frequencies.pop_head ();
                // Force that gst_structure_free is called
                s = null;
            }
            this.frequencies.clear ();
        }
        
        protected void add_structure_to_scan (Gst.Structure# structure) {
            if (structure == null) return;
            
            ScannedItem item = this.get_scanned_item (structure);
            
            if (!this.scanned_frequencies.contains (item)) {
                debug ("Queueing new frequency %u", item.Frequency);
                this.frequencies.push_tail (#structure);
                this.scanned_frequencies.add (item);
            }
        }
        
        /**
         * Pick up the next tuning paramters from the queue
         * and start scanning with them
         */
        protected void start_scan () {
            this.nit_arrived = false;
            this.sdt_arrived = false;
            this.pat_arrived = false;
            this.locked = false;
            
            if (this.current_tuning_params != null) {
                uint old_freq;
                this.current_tuning_params.get_uint ("frequency", out old_freq);
                this.frequency_scanned (old_freq, this.frequencies.length);
            }
            
            if (this.frequencies.is_empty()) {
                message("Finished scanning");
                // We don't have all the information for those channels
                // remove them
                debug ("%u channels still have missing TS",
                    this.new_channels.size);
                foreach (uint sid in this.new_channels) {
                    this.channels.remove (sid);
                }
                this.clear_and_reset_all ();
                this.finished ();
                return;
            }
            
            this.current_tuning_params = this.frequencies.pop_head();
            
            // Remember that we already scanned this frequency
            uint freq;
            this.current_tuning_params.get_uint ("frequency", out freq);
            
            debug("Starting scanning frequency %u (%u left)", freq,
                this.frequencies.get_length ());
            
            this.pipeline.set_state (Gst.State.READY);
            
            this.prepare ();
            
            // Reset PIDs
            Gst.Element dvbsrc = ((Gst.Bin)this.pipeline).get_by_name ("dvbsrc");
            dvbsrc.set ("pids", BASE_PIDS);
            this.prev_pids = BASE_PIDS;
            
            this.pipeline.set_state (Gst.State.PLAYING);
            
            this.check_for_lock_event_id =
                Timeout.add_seconds (5, this.check_for_lock);
        }
        
        /**
         * Check if we received a lock with the currently
         * used tuning parameters
         */
        protected bool check_for_lock () {
            this.check_for_lock_event_id = 0;
            if (!this.locked) {
                this.pipeline.set_state (Gst.State.READY);
                this.start_scan ();
            }
            return false;
        }
        
        protected bool wait_for_tables () {
            this.wait_for_tables_event_id = 0;
            if (!(this.sdt_arrived && this.nit_arrived && this.pat_arrived)) {
                this.pipeline.set_state (Gst.State.READY);
                this.start_scan ();
            }
            return false;
        }
        
        protected void remove_check_for_lock_timeout () {
            if (this.check_for_lock_event_id != 0) {
                Source.remove (this.check_for_lock_event_id);
                this.check_for_lock_event_id = 0;
            }
        }
        
        protected void remove_wait_for_tables_timeout () {
            if (this.wait_for_tables_event_id != 0) {
                Source.remove (this.wait_for_tables_event_id);
                this.wait_for_tables_event_id = 0;
            }
        }
        
        protected static void set_uint_property (Gst.Element src,
            Gst.Structure params, string key) {
            uint val;
            params.get_uint (key, out val);
            src.set (key, val);
        }
        
        protected void on_dvb_frontend_stats_structure (Gst.Structure structure) {
            bool has_lock;
            structure.get_boolean ("lock", out has_lock);
            if (has_lock && !this.locked) {
                debug("Got lock");
                this.remove_check_for_lock_timeout ();
                this.wait_for_tables_event_id =
                    Timeout.add_seconds (10, this.wait_for_tables);
            }
        }
        
        protected void on_dvb_read_failure_structure () {
            critical ("Read failure");
            /*
            this.Destroy ();
            */
        }
        
        protected void on_pat_structure (Gst.Structure structure) {
            debug("Received PAT");
        
            Gst.Value programs = structure.get_value ("programs");
            uint size = programs.list_get_size ();
            Gst.Value val;
            weak Gst.Structure program;
            // Iterate over programs
            for (uint i=0; i<size; i++) {
                val = programs.list_get_value (i);
                program = val.get_structure ();
                
                uint sid;
                program.get_uint ("program-number", out sid);
                
                uint pmt;
                program.get_uint ("pid", out pmt);
                
                // We want to parse the pmt as well
                Gst.Element dvbsrc = ((Gst.Bin)this.pipeline).get_by_name ("dvbsrc");
                this.prev_pids = "%s:%u".printf (prev_pids, pmt);
                dvbsrc.set ("pids", this.prev_pids);
            }
            
            this.pat_arrived = true;
        }
        
        protected void on_sdt_structure (Gst.Structure structure) {
            debug("Received SDT");
            
            uint tsid;
            structure.get_uint ("transport-stream-id", out tsid);
            
            Gst.Value services = structure.get_value ("services");
            uint size = services.list_get_size ();
            
            Gst.Value val;
            weak Gst.Structure service;
            // Iterate over services
            for (uint i=0; i<size; i++) {
                val = services.list_get_value (i);
                service = val.get_structure ();
                
                // Returns "service-%d"
                string name = service.get_name ();
                // Get the number at the end
                int sid = name.substring (8, name.size() - 8).to_int ();
                
                if (service.has_field ("name"))
                    name = service.get_string ("name");
                
                if (!this.Channels.contains (sid)) {
                    this.add_new_channel (sid);
                }
                
                Channel channel = this.Channels.get(sid);
                
                if (service.has_field ("scrambled")) {
                    bool scrambled;
                    service.get_boolean ("scrambled", out scrambled);
                    channel.Scrambled = scrambled;
                } else {
                    channel.Scrambled = false;
                }
                
                if (name.validate ()) {
                    channel.Name = name;
                } else {
                    channel.Name = "[%04x]".printf (sid);
                }
                
                channel.TransportStreamId = tsid;
                string provider = service.get_string ("provider-name");
                if (provider != null && provider.validate ()) {
                    channel.Network = provider;
                } else {
                    channel.Network = "";
                }
                
                uint freq;
                this.current_tuning_params.get_uint ("frequency", out freq);
                channel.Frequency = freq;
            }
        
            this.sdt_arrived = true;
        }
        
        protected void on_nit_structure (Gst.Structure structure) {
            debug("Received NIT");
            
            string name;
            if (structure.has_field ("network-name")) {
                name = structure.get_string ("network-name");
            } else {
                uint nid;
                structure.get_uint ("network-id", out nid);
                name = "%u".printf (nid);
            }
            debug ("Network name '%s'", name);
                        
            Gst.Value transports = structure.get_value ("transports");
            uint size = transports.list_get_size ();
            Gst.Value val;
            weak Gst.Structure transport;
            // Iterate over transports
            for (uint i=0; i<size; i++) {
                val = transports.list_get_value (i);
                transport = val.get_structure ();
                
                uint tsid;
                transport.get_uint ("transport-stream-id", out tsid);
                
                if (transport.has_field ("delivery")) {
                    Gst.Value delivery_val = transport.get_value ("delivery");
                    weak Gst.Structure delivery =
                        delivery_val.get_structure ();
                 
                    debug ("Received TS %u", tsid);   
                    this.transport_streams.set (tsid, delivery);
                    
                    uint freq;
                    delivery.get_uint ("frequency", out freq);
                    // Takes care of duplicates
                    this.add_structure_to_scan (delivery);
                }
                
                if (transport.has_field ("channels")) {
                    Gst.Value channels = transport.get_value ("channels");
                    uint channels_size = channels.list_get_size ();
                    
                    Gst.Value channel_val;
                    weak Gst.Structure channel_struct;
                    // Iterate over channels
                    for (int j=0; j<channels_size; j++) {
                        channel_val = channels.list_get_value (j);
                        channel_struct = channel_val.get_structure ();
                        
                        uint sid;
                        channel_struct.get_uint ("service-id", out sid);
                        
                        if (!this.Channels.contains (sid)) {
                            this.add_new_channel (sid);
                        }
                        
                        Channel dvb_channel = this.Channels.get (sid);
                        
                        if (name.validate ()) {
                            dvb_channel.Network = name;
                        } else {
                            dvb_channel.Network = "";
                        }
                        
                        uint lcnumber;
                        channel_struct.get_uint ("logical-channel-number", out lcnumber);
                        dvb_channel.LogicalChannelNumber = lcnumber;
                    }
                }
            }
        
            this.nit_arrived = true;
        }
        
        protected void on_pmt_structure (Gst.Structure structure) {
            debug ("Received PMT");
            
            uint program_number;
            structure.get_uint ("program-number", out program_number);
            
            if (!this.Channels.contains (program_number)) {
                this.add_new_channel (program_number);
            }
            
            Channel dvb_channel = this.Channels.get (program_number);
            
            Gst.Value streams = structure.get_value ("streams");
            uint size = streams.list_get_size ();
            
            Gst.Value stream_val;
            weak Gst.Structure stream;
            // Iterate over streams
            for (int i=0; i<size; i++) {
                stream_val = streams.list_get_value (i);
                stream = stream_val.get_structure ();
                
                uint pid;
                stream.get_uint ("pid", out pid);
                
                // See ISO/IEC 13818-1 Table 2-29
                uint stream_type;
                stream.get_uint ("stream-type", out stream_type);
                
                switch (stream_type) {
                    case 0x01:
                    case 0x02:
                    case 0x1b: /* H.264 video stream */
                        debug ("Found video PID %u", pid);
                        dvb_channel.VideoPID = pid;
                    break;
                    case 0x03:
                    case 0x04:
                    case 0x0f:
                    case 0x11:
                        debug ("Found audio PID %u", pid);
                        dvb_channel.AudioPID = pid;
                    break;
                    default:
                        debug ("Other stream type: 0x%02x", stream_type);
                    break;
                }
            }
        }
        
        protected void bus_watch_func (Gst.Bus bus, Gst.Message message) {
            switch (message.type) {
                case Gst.MessageType.ELEMENT: {
                    if (message.structure.get_name() == "dvb-frontend-stats")
                        this.on_dvb_frontend_stats_structure (message.structure);
                    else if (message.structure.get_name() == "dvb-read-failure")
                        this.on_dvb_read_failure_structure ();
                    else if (message.structure.get_name() == "sdt")
                        this.on_sdt_structure (message.structure);
                    else if (message.structure.get_name() == "nit")
                        this.on_nit_structure (message.structure);
                    else if (message.structure.get_name() == "pat")
                        this.on_pat_structure (message.structure);
                    else if (message.structure.get_name() == "pmt")
                        this.on_pmt_structure (message.structure);
                break;
                }            
                case Gst.MessageType.ERROR: {
                    Error gerror;
                    string debug;
                    message.parse_error (out gerror, out debug);
                    critical ("%s %s", gerror.message, debug);
                    this.Destroy ();
                break;
                }
            }
            
            if (this.sdt_arrived && this.nit_arrived && this.pat_arrived) {
                this.remove_wait_for_tables_timeout ();
                
                ArrayList<uint> del_channels = new ArrayList<uint> ();
                foreach (uint sid in this.new_channels) {
                    DVB.Channel channel = this.channels.get (sid);
                    
                    uint tsid = channel.TransportStreamId;
                    debug ("Searching for TS %u for channel %u", tsid, sid);
                    // Check if already came across the transport stream
                    if (this.transport_streams.contains (tsid)) {
                        // add values from Gst.Structure to Channel
                        this.add_values_from_structure_to_channel (
                            this.transport_streams.get (tsid),
                            channel);
                        
                        if (channel.is_valid ()) {
                            string type = (channel.VideoPID == 0) ? "Radio" : "TV";
                            debug ("Channel added: %s", channel.to_string ());
                            this.channel_added (channel.Frequency, sid,
                                channel.Name, channel.Network, type,
                                channel.Scrambled);
                        } else {
                            debug ("Channel %u is not valid", sid);
                            this.channels.remove (sid);
                        }
                        
                        // Mark channel for deletion of this.new_channels
                        del_channels.add (sid);
                    }
                }
                
                // Only remove those channels which transport streams
                // were already received
                foreach (uint sid in del_channels) {
                    this.new_channels.remove (sid);
                }
                
                this.start_scan ();
            }
        }
        
        protected void add_new_channel (uint sid) {
            debug ("Adding new channel with SID %u", sid);
            Channel new_channel = this.get_new_channel ();
            new_channel.Sid = sid;
            this.channels.add (new_channel);
            this.new_channels.add (sid);
        }
    }
    
}
