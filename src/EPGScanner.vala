using GLib;
using Gee;

namespace DVB {

    public class EPGScanner : GLib.Object {
    
        public DVB.Device Device {get; set;}
        
        private static const int CHECK_EIT_INTERVAL = 5;
        private Gst.Element? pipeline;
        private ArrayList<Event> events;
        private Queue<uint> frequencies;
        
        construct {
            this.events = new ArrayList<Event> ();
            this.frequencies = new Queue<uint> ();
        }
        
        public EPGScanner (DVB.Device device) {
            this.Device = device;
        }
    
        public void stop () {
            if (this.pipeline != null)
                this.pipeline.set_state (Gst.State.NULL);
            this.pipeline = null;
        }
        
        public void start () {
            foreach (Channel c in this.Device.Channels) {
                this.frequencies.push_tail (c.Frequency);
            }
        
            // pids: 0=pat, 16=nit, 17=sdt, 18=eit
            try {
                this.pipeline = Gst.parse_launch (
                    "dvbsrc name=dvbsrc adapter=%u frontend=%u ".printf(
                    this.Device.Adapter, this.Device.Frontend)
                    + "pids=0:16:17:18 stats-reporting-interval=0 "
                    + "! mpegtsparse ! fakesink silent=true");
            } catch (Error e) {
                error (e.message);
                return;
            }
            
            weak Gst.Bus bus = this.pipeline.get_bus ();
            bus.add_signal_watch ();
            bus.message += this.bus_watch_func;
            
            this.pipeline.set_state (Gst.State.READY);
            
            Timeout.add_seconds (CHECK_EIT_INTERVAL,
                scan_new_frequency);
            
            return;
        }
        
        private bool scan_new_frequency () {
            if (this.frequencies.is_empty ()) {
                this.stop ();
                return false;
            }
            
            uint freq = this.frequencies.pop_head ();
        
            Gst.Element dvbsrc = ((Gst.Bin)this.pipeline).get_by_name ("dvbsrc");
            dvbsrc.set ("frequency", freq);
            
            this.pipeline.set_state (Gst.State.PLAYING);
            
            return false;
        }
        
        private void bus_watch_func (Gst.Bus bus, Gst.Message message) {
            switch (message.type) {
                case Gst.MessageType.ELEMENT:
                    if (message.structure.get_name() == "dvb-read-failure") {
                        critical ("Could not read from DVB device");
                        this.stop ();
                    } else if (message.structure.get_name() == "eit") {
                        this.on_eit_structure (message.structure);
                    }
                break;
                
                case Gst.MessageType.ERROR:
                    Error gerror;
                    string debug;
                    message.parse_error (out gerror, out debug);
                    critical ("%s %s", gerror.message, debug);
                    this.stop ();
                break;
                
                default:
                break;
            }
        }
        
        private void on_eit_structure (Gst.Structure structure) {
            Gst.Value events = structure.get_value ("events");
            uint size = events.list_get_size ();
            Gst.Value val;
            weak Gst.Structure event;
            // Iterate over events
            for (uint i=0; i<size; i++) {
                val = events.list_get_value (i);
                event = val.get_structure (); 
        
                var event_class = new Event ();
                event_class.id = get_uint_val (event, "id");
                event_class.year = get_uint_val (event, "year");
                event_class.month = get_uint_val (event, "month");
                event_class.day = get_uint_val (event, "day");
                event_class.hour = get_uint_val (event, "hour");
                event_class.minute = get_uint_val (event, "minute");
                event_class.second = get_uint_val (event, "second");
                event_class.duration = get_uint_val (event, "duration");
                event_class.running_status = get_uint_val (event, "running-status");
                event_class.name = structure.get_string ("name"); 
                event_class.description = structure.get_string ("description");
                debug (event_class.to_string ());
                this.events.add (event_class);
            }
        }
        
        private static uint get_uint_val (Gst.Structure structure, string name) {
            uint val;
            structure.get_uint (name, out val);
            return val;
        }
    }
}
