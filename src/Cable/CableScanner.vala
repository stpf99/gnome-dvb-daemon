using GLib;

namespace DVB {
    
    [DBus (name = "org.gnome.DVB.Scanner.Cable")]
    public interface IDBusCableScanner : GLib.Object {
    
        public abstract signal void finished ();
        
        public abstract void Run ();
        public abstract void Abort ();
        public abstract bool WriteChannelsToFile (string path);
        
        public abstract void AddScanningData (uint frequency, string modulation,
            uint symbol_rate, string code_rate);
    }
    
    public class CableScanner : Scanner, IDBusCableScanner {
        
        public CableScanner (DVB.Device device) {
            base.Device = device;
        }
        
        public void AddScanningData (uint frequency, string modulation,
                uint symbol_rate, string code_rate) {
            var tuning_params = new Gst.Structure ("tuning_params",
            "frequency", typeof(uint), frequency,
            "symbol-rate", typeof(uint), symbol_rate,
            "inner-fec", typeof(string), code_rate,
            "modulation", typeof(string), modulation);
            
            base.add_structure_to_scan (#tuning_params);  
        }
       
        protected override void prepare () {
            debug("Setting up pipeline for DVB-C scan");
        
            Gst.Element dvbsrc = ((Gst.Bin)this.pipeline).get_by_name ("dvbsrc");
            
            string[] keys = new string[] {
                "frequency",
                "symbol-rate"
            };
            
            foreach (string key in keys) {
                this.set_uint_property (dvbsrc, this.current_tuning_params, key);
            }
            
            dvbsrc.set ("modulation",
                get_modulation_val (this.current_tuning_params.get_string ("modulation")));
            
            dvbsrc.set ("code-rate-hp", get_code_rate_val (
                this.current_tuning_params.get_string ("inner-fec")));
        }
        
        protected override ScannedItem get_scanned_item (uint frequency) {
            // TODO
            return new ScannedItem (frequency);
        }
        
        protected override Channel get_new_channel () {
            return new CableChannel ();
        }
        
        protected override void add_values_from_structure_to_channel (
            Gst.Structure delivery, Channel channel) {
            if (!(channel is CableChannel)) return;
            
            CableChannel cc = (CableChannel)channel;
            
            // structure doesn't contain information about inversion
            // set it to auto
            cc.Inversion = DvbSrcInversion.INVERSION_AUTO;
            
            cc.Modulation = get_modulation_val (delivery.get_string ("modulation"));
            
            uint freq;
            delivery.get_uint ("frequency", out freq);
            cc.Frequency = freq;
            
            uint symbol_rate;
            delivery.get_uint ("symbol-rate", out symbol_rate);
            cc.SymbolRate = symbol_rate;
            
            cc.CodeRate = get_code_rate_val (delivery.get_string ("inner-fec"));
        }
    }
    
}
