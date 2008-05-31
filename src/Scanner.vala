using GLib;
using Gee;

namespace DVB {

    /**
     * An abstract class responsible for scanning for new channels
     */
    public abstract class Scanner : GLib.Object {

        /**
         * Emitted when a frequency has been scanned.
         * Whether a new channel has been found on that frequency or not.
         */
        public signal void frequency_scanned (uint frequency);
        
        /**
         * Emitted when a new channel has been found
         */
        public signal void channel_added (Channel channel);
        
        /**
         * Emitted when all frequencies have been scanned
         */
        public signal void finished ();
        
        /**
         * The DVB device the scanner should use
         */
        public DVB.Device Device { get; construct; }

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
        protected Gst.Structure current_tuning_params;
        
        /**
         * The SID of the current channel
         */
        protected uint current_sid;
        
        /**
         * All the frequencies that have been scanned already
         */
        protected HashSet<ScannedItem> scanned_frequencies;
        
        private HashSet<int> found_channels;
        private uint? check_for_lock_event_id;
        private bool nit_arrived;
        private bool sdt_arrived;
        private bool pat_arrived;
        private bool locked;
        
        construct {
            this.scanned_frequencies =
                new HashSet<ScannedItem> (direct_hash, ScannedItem.equal);
            this.found_channels = new HashSet<int> ();
            this.frequencies = new Queue<Gst.Structure> ();
            this.channels = new ChannelList ();
            
            this.nit_arrived = false;
            this.sdt_arrived = false;
            this.pat_arrived = false;
            this.locked = false;
            this.check_for_lock_event_id = null;
        }
        
        /**
         * Setup the pipeline correctly
         */
        protected abstract void prepare();
        
        /**
         * Use the frequency and possibly other data to
         * mark the tuning paramters as already used
         */
        protected abstract void add_scanned_item (uint frequency);
        
        /**
         * Start the scanner
         */
        public virtual void Run() {
            // pids: 0=pat, 16=nit, 17=sdt, 18=eit
            try {
                this.pipeline = Gst.parse_launch(
                    "dvbsrc name=dvbsrc adapter=%d frontend=%d ".printf(
                    this.Device.Adapter, this.Device.Frontend)
                    + "pids=0:16:17:18 stats-reporting-interval=0 "
                    + "! mpegtsparse ! fakesink silent=true");
            } catch (Error e) {
                error (e.message);
                return;
            }
            
            weak Gst.Bus bus = this.pipeline.get_bus();
            bus.add_signal_watch();
            bus.message += this.bus_watch_func;
            
            this.pipeline.set_state(Gst.State.READY);
            
            this.start_scan();
        }
        
        protected void add_structure_to_scan (Gst.Structure# structure) {
            this.frequencies.push_tail (#structure);
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
            
            if (this.frequencies.is_empty()) {
                message("Finished scanning");
                this.finished ();
                return;
            }
            
            this.current_tuning_params = this.frequencies.pop_head();
            
            debug("Starting scan with params %s",
                this.current_tuning_params.to_string());
            
            this.prepare ();
            
            this.pipeline.set_state (Gst.State.PLAYING);
            
            this.check_for_lock_event_id =
                Timeout.add_seconds (5, this.check_for_lock);
            
        }
        
        /**
         * Check if we received a lock with the currently
         * used tuning parameters
         */
        protected bool check_for_lock () {
            if (!this.locked)
                this.pipeline.set_state(Gst.State.READY);
                
            this.start_scan ();
            return false;
        }
        
        protected static void set_uint_property (Gst.Element src,
        Gst.Structure params, string key) {
            uint val;
            params.get_uint (key, out val);
            src.set (key, val);
        }
      
        protected void remove_check_for_lock_timeout () {
            Source.remove (this.check_for_lock_event_id);
            this.check_for_lock_event_id = null;
        }
       
        protected void on_dvb_frontend_stats_structure (Gst.Structure structure) {
            bool has_lock;
            structure.get_boolean ("lock", out has_lock);
            if (has_lock && !this.locked) {
                debug("Got lock");
                this.remove_check_for_lock_timeout ();
            }
        }
        
        protected void on_dvb_read_failure_structure () {
            error("Read failure");
            this.remove_check_for_lock_timeout ();
        }
        
        protected void on_pat_structure (Gst.Structure structure) {
            debug("Received PAT");
        
            //Value programs = structure.get_value ("programs");
            
            this.pat_arrived = true;
        }
        
        protected void on_sdt_structure (Gst.Structure structure) {
            debug("Received SDT");
            
            uint tsid;
            structure.get_uint ("transport-stream-id", out tsid);
            
            bool actual_ts;
            structure.get_boolean ("actual-transport-stream", out actual_ts);
            if (actual_ts) {
                Value services = structure.get_value ("services");
                uint size = ((Gst.Value)services).list_get_size();
                
                Gst.Value val;
                Gst.Structure s;
                for (uint i=0; i<size; i++) {
                    val = ((Gst.Value)services).list_get_value (i);
                    // FIXME we're not supposed to free this
                    s = val.get_structure ();
                    
                    // Returns "service-%d"
                    string name = s.get_name ();
                    // Get the number at the end
                    int sid = name.substring (8, name.size()).to_int ();
                    
                    debug ("%s, %d", name, sid);
                }
            }
        
            this.sdt_arrived = true;
        }
        
        protected void on_nit_structure (Gst.Structure structure) {
            debug("Received NIT");
            
            string name;
            if (structure.has_name ("network-name")) {
                name = structure.get_string ("network-name");
            } else {
                uint nid;
                structure.get_uint ("network-id", out nid);
                name = "%d".printf (nid);
            }
        
            this.nit_arrived = true;
        }
        
        protected void bus_watch_func (Gst.Bus bus, Gst.Message message) {
            if (message.type == Gst.MessageType.ELEMENT) {
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
                else
                    return;
            }
            
            if (this.sdt_arrived && this.nit_arrived && this.pat_arrived) {
                this.add_found_frequency ();
                this.start_scan ();
            }
        }
        
        protected void add_found_frequency () {
            this.pipeline.set_state(Gst.State.READY);
            
            this.locked = false;        
            
            uint freq;
            this.current_tuning_params.get_uint ("frequency", out freq);
            
            this.add_scanned_item (freq);            
        }
    }
    
}
