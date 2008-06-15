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
            
            string polarity =
                base.current_tuning_params.get_string ("polarization")
                .substring (0, 1);
            dvbsrc.set ("polarity", polarity);
            
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
        
        protected override void add_values_from_structure_to_channel (
            Gst.Structure delivery, Channel channel) {
            if (!(channel is SatelliteChannel)) return;
            
            SatelliteChannel sc = (SatelliteChannel)channel;
            sc.Polarization = delivery.get_string ("polarization");

            uint srate;
            delivery.get_uint ("symbol-rate", out srate);            
            sc.SymbolRate = srate;
            
            // TODO
            sc.DiseqcSource = -1;
        }
    }
    
}
