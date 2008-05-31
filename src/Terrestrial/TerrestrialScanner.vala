using GLib;

namespace DVB {
        
    [DBus (name = "org.gnome.DVB.Scanner.Terrestrial")]
    public class TerrestrialScanner : Scanner {
    
        public TerrestrialScanner (DVB.Device device) {
            base.Device = device;
        }
        
        /* Show up in D-Bus interface */
        public void Run () {
            base.Run ();
        }
        
        /**
          * See enums in MpegTsEnums
          */
        public void AddScanningData (uint frequency,
                                     uint hierarchy,
                                     uint bandwith,
                                     uint transmode,
                                     uint code_rate_hp,
                                     uint code_rate_lp,
                                     uint constellation,
                                     uint guard) {
            Gst.Structure tuning_params = new Gst.Structure ("tuning_params",
                "frequency", typeof(uint), frequency,
                "hierarchy", typeof(uint), hierarchy,
                "bandwidth", typeof(uint), bandwith,
                "transmission-mode", typeof(uint), transmode,
                "code-rate-hp", typeof(uint), code_rate_hp,
                "code-rate-lp", typeof(uint), code_rate_lp,
                "constellation", typeof(uint), constellation,
                "guard-interval", typeof(uint), guard);
            base.add_structure_to_scan (#tuning_params);
        }
        
        protected override void prepare () {
            debug("Setting up pipeline for DVB-T scan");
        
            Gst.Element dvbsrc = ((Gst.Bin)base.pipeline).get_by_name ("dvbsrc");
            string[] uint_keys = new string[] {
                "bandwidth",
                "hierarchy",
                "frequency",
                "code-rate-lp",
                "code-rate-hp"
            };
            
            foreach (string key in uint_keys) {
                base.set_uint_property (dvbsrc, base.current_tuning_params, key);
            }
            
            uint guard;
            base.current_tuning_params.get_uint ("guard-interval", out guard);
            dvbsrc.set ("guard", guard);
            
            uint transmode;
            base.current_tuning_params.get_uint ("transmission-mode", out transmode);
            dvbsrc.set ("trans-mode", transmode);
            
            uint mod;
            base.current_tuning_params.get_uint ("constellation", out mod);
            dvbsrc.set ("modulation", mod);
        }
        
        protected override void add_scanned_item (uint frequency) {
            base.scanned_frequencies.add (new ScannedItem (frequency));
        }
        
        protected override Channel get_new_channel () {
            return new TerrestrialChannel ();
        }
    }
    
}
