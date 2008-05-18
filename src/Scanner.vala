using GLib;
using Gee;

namespace DVB {

    [DBus (name = "org.gnome.DVB.Scanner")]
    public class Scanner : GLib.Object {

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
        
        private HashSet<ScannedItem> scanned_frequencies;
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
            this.channels = new HashMap<uint, Channel> ();
            
            this.nit_arrived = false;
            this.sdt_arrived = false;
            this.pat_arrived = false;
            this.locked = false;
            this.check_for_lock_event_id = null;
            this.channels = new HashMap<uint, Channel> ();
        }
        
        public Scanner (DVB.Device device) {
            this.Device = device;
        }
        
        public void Run() {
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
        
        protected void add_frequency (Gst.Structure# structure) {
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
            
            switch (this.Device.Type) {
                case AdapterType.DVB_T:
                this.prepare_dvb_t();
                break;
                
                case AdapterType.DVB_S:
                this.prepare_dvb_s();
                break;
                
                case AdapterType.DVB_C:
                this.prepare_dvb_c();
                break;
                
                default:
                return;
            }
            
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
        
        protected void prepare_dvb_t () {
            debug("Setting up pipeline for DVB-T scan");
        
            Gst.Element dvbsrc = ((Gst.Bin)this.pipeline).get_by_name ("dvbsrc");
            string[] uint_keys = new string[] {
                "bandwidth",
                "hierarchy",
                "frequency",
                "code-rate-lp",
                "code-rate-hp"
            };
            
            foreach (string key in uint_keys) {
                this.set_uint_property (dvbsrc, this.current_tuning_params, key);
            }
            
            uint guard;
            this.current_tuning_params.get_uint ("guard-interval", out guard);
            dvbsrc.set ("guard", guard);
            
            uint transmode;
            this.current_tuning_params.get_uint ("transmission-mode", out transmode);
            dvbsrc.set ("trans-mode", transmode);
            
            uint mod;
            this.current_tuning_params.get_uint ("constellation", out mod);
            dvbsrc.set ("modulation", mod);
        }
        
        protected void prepare_dvb_s () {
            debug("Setting up pipeline for DVB-S scan");
        
            Gst.Element dvbsrc = ((Gst.Bin)this.pipeline).get_by_name ("dvbsrc");
           
            string[] uint_keys = new string[] {"frequency", "symbol-rate"};
            
            foreach (string key in uint_keys) {
                this.set_uint_property (dvbsrc, this.current_tuning_params, key);
            }
            
            // TODO
            //dvbsrc.set_property("polarity", tuning_params["polarization"][0])
            
            uint code_rate;
            this.current_tuning_params.get_uint ("inner-fec", out code_rate);
            dvbsrc.set ("code-rate-hp", code_rate);
        }
        
        protected void prepare_dvb_c () {
            debug("Setting up pipeline for DVB-C scan");
        
            Gst.Element dvbsrc = ((Gst.Bin)this.pipeline).get_by_name ("dvbsrc");
            
            string[] keys = new string[] {
                "inversion", 
                "frequency",
                "modulation",
                "symbol-rate"
            };
            
            foreach (string key in keys) {
                this.set_uint_property (dvbsrc, this.current_tuning_params, key);
            }
            
            uint code_rate;
            this.current_tuning_params.get_uint ("inner-fec", out code_rate);
            dvbsrc.set ("code-rate-hp", code_rate);
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
        
        protected void add_found_frequency () {
            this.pipeline.set_state(Gst.State.READY);
            
            this.locked = false;        
            
            uint freq;
            this.current_tuning_params.get_uint ("frequency", out freq);
            
            switch (this.Device.Type) {
                case AdapterType.DVB_T:
                this.scanned_frequencies.add (new ScannedItem (freq));
                break;
                
                case AdapterType.DVB_S:
                weak string pol =
                    this.current_tuning_params.get_string ("polarization");
                this.scanned_frequencies.add (
                    new ScannedSatteliteItem (freq, pol)
                );
                break;
                
                case AdapterType.DVB_C:
                // TODO
                break;
            }
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
        
    }
    
}
