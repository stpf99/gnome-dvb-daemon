using GLib;

namespace DVB {
    
    [DBus (name = "org.gnome.DVB.Scanner.Satellite")]
    public class SatelliteScanner : Scanner {
    
        public SatelliteScanner (DVB.Device device) {
            base.Device = device;
        }
     
        /* Show up in D-Bus interface */
        public void Run () {
            base.Run ();
        }
        
        protected override void prepare () {
            debug("Setting up pipeline for DVB-S scan");
        
            Gst.Element dvbsrc = ((Gst.Bin)base.pipeline).get_by_name ("dvbsrc");
           
            string[] uint_keys = new string[] {"frequency", "symbol-rate"};
            
            foreach (string key in uint_keys) {
                base.set_uint_property (dvbsrc, base.current_tuning_params, key);
            }
            
            // TODO
            //dvbsrc.set_property("polarity", tuning_params["polarization"][0])
            
            uint code_rate;
            base.current_tuning_params.get_uint ("inner-fec", out code_rate);
            dvbsrc.set ("code-rate-hp", code_rate);
        }
        
        protected override ScannedItem get_scanned_item (uint frequency) {
            weak string pol =
                base.current_tuning_params.get_string ("polarization");
            return new ScannedSatteliteItem (frequency, pol);
        }
        
        protected override Channel get_new_channel () {
            return new SatelliteChannel ();
        }
    }
    
}
