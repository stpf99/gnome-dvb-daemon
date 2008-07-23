using GLib;

namespace DVB {
    
    [DBus (name = "org.gnome.DVB.Scanner.Satellite")]
    public interface IDBusSatelliteScanner : GLib.Object {
    
        public abstract signal void frequency_scanned (uint frequency);
        public abstract signal void finished ();
        public abstract signal void channel_added (uint frequency, uint sid,
            string name, string network, string type);
        
        public abstract void Run ();
        public abstract void Abort ();
        public abstract bool WriteChannelsToFile (string path);
        
        public abstract void AddScanningData (uint frequency,
                                     string polarization, // "horizontal", "vertical"
                                     uint symbol_rate);
    }
    
    public class SatelliteScanner : Scanner, IDBusSatelliteScanner {
    
        public SatelliteScanner (DVB.Device device) {
            base.Device = device;
        }
     
        public void AddScanningData (uint frequency,
                string polarization, uint symbol_rate) {
            var tuning_params = new Gst.Structure ("tuning_params",
            "frequency", typeof(uint), frequency,
            "symbol-rate", typeof(uint), symbol_rate,
            "polarization", typeof(string), polarization);
            
            base.add_structure_to_scan (#tuning_params);
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
            
            uint freq;
            delivery.get_uint ("frequency", out freq);
            sc.Frequency = freq;
            
            sc.Polarization = delivery.get_string ("polarization").substring (0, 1);

            uint srate;
            delivery.get_uint ("symbol-rate", out srate);            
            sc.SymbolRate = srate;
            
            // TODO
            sc.DiseqcSource = -1;
        }
    }
    
}
