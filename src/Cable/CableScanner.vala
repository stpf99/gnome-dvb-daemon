using GLib;

namespace DVB {
    
    [DBus (name = "org.gnome.DVB.Scanner.Cable")]
    public class CableScanner : Scanner {
        
        public CableScanner (DVB.Device device) {
            base.Device = device;
        }
        
        /* Show up in D-Bus interface */
        public void Run () {
            base.Run ();
        }

        protected override void prepare () {
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
        
        protected override void add_scanned_item (uint frequency) {
            // TODO
        }
        
        protected override Channel get_new_channel () {
            return new CableChannel ();
        }
    }
    
}
