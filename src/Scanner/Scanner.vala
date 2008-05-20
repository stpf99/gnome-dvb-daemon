using GLib;
using Gee;

namespace DVB {

    public abstract class Scanner : GLib.Object {

        public signal void frequency_scanned (uint frequency);
        public signal void channel_added (Channel channel);
        public signal void finished ();
        
        public DVB.Device Device { get; construct; }

        public HashMap<uint, Channel> Channels {
            get { return this.channels; }
        }
        
        protected HashMap<uint, Channel> channels;
        protected Gst.Element pipeline;
        protected Queue<Gst.Structure> frequencies;
        protected Gst.Structure current_tuning_params;
        protected uint current_sid;
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
            this.found_channels = new HashSet<int> (int_hash, int_equal);
            this.frequencies = new Queue<Gst.Structure> ();
            this.channels = new HashMap<uint, Channel> (int_hash, int_equal, direct_equal);
            
            this.nit_arrived = false;
            this.sdt_arrived = false;
            this.pat_arrived = false;
            this.locked = false;
            this.check_for_lock_event_id = null;
        }
       
        protected abstract void prepare();
        
        protected abstract void add_scanned_item (uint frequency);
        
        public virtual void Run() {
            // pids: 0=pat, 16=nit, 17=sdt, 18=eit
            try {
                this.pipeline = Gst.parse_launch(
                    "dvbsrc name=dvbsrc adapter=%d frontend=%d pids=0:16:17:18" +
                    "stats-reporting-interval=0 ! mpegtsparse ! " +
                    "fakesink silent=true".printf(this.Device.Adapter,
                                                  this.Device.Frontend));
            } catch (Error e) {
                stderr.printf("ERROR: %s\n", e.message);
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
        
        protected void bus_watch_func (Object sender, Gst.Message message) {
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
