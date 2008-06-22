using GLib;

namespace DVB {
        
    [DBus (name = "org.gnome.DVB.Scanner.Terrestrial")]
    public class TerrestrialScanner : Scanner {
    
        public TerrestrialScanner (DVB.Device device) {
            base.Device = device;
        }
        
        /**
          * See enums in MpegTsEnums
          */
        public void AddScanningData (uint frequency,
                                     uint hierarchy, // 0-3
                                     uint bandwith, // 0, 6, 7, 8
                                     string transmode, // "2k", "8k"
                                     string code_rate_hp, // "1/2", "2/3", "3/4", ..., "8/9"
                                     string code_rate_lp,
                                     string constellation, // QPSK, QAM16, QAM64
                                     uint guard) { // 4, 8, 16, 32
            Gst.Structure tuning_params = new Gst.Structure ("tuning_params",
                "frequency", typeof(uint), frequency,
                "hierarchy", typeof(uint), hierarchy,
                "bandwidth", typeof(uint), bandwith,
                "transmission-mode", typeof(string), transmode,
                "code-rate-hp", typeof(string), code_rate_hp,
                "code-rate-lp", typeof(string), code_rate_lp,
                "constellation", typeof(string), constellation,
                "guard-interval", typeof(uint), guard);
            
            base.add_structure_to_scan (#tuning_params);
        }
        
        protected override void prepare () {
            debug("Setting up pipeline for DVB-T scan");
        
            Gst.Element dvbsrc = ((Gst.Bin)base.pipeline).get_by_name ("dvbsrc");
            
            base.set_uint_property (dvbsrc, base.current_tuning_params, "frequency");
            
            uint bandwidth;
            this.current_tuning_params.get_uint ("bandwidth", out bandwidth);
            dvbsrc.set ("bandwidth", get_bandwidth_val (bandwidth));
            
            uint hierarchy;
            this.current_tuning_params.get_uint ("hierarchy", out hierarchy);
            dvbsrc.set ("hierarchy", get_hierarchy_val (hierarchy));
            
            string constellation = this.current_tuning_params.get_string ("constellation");
            dvbsrc.set ("modulation", get_modulation_val (constellation));
                
            dvbsrc.set ("code-rate-hp", get_code_rate_val (
                this.current_tuning_params.get_string ("code-rate-hp")));
            dvbsrc.set ("code-rate-lp", get_code_rate_val (
                this.current_tuning_params.get_string ("code-rate-lp")));
            
            uint guard;
            this.current_tuning_params.get_uint ("guard-interval", out guard);
            dvbsrc.set ("guard", get_guard_interval_val (guard));
            
            string transmode = this.current_tuning_params.get_string ("transmission-mode");
            dvbsrc.set ("trans-mode", get_transmission_mode_val (transmode));
        }
        
        protected override ScannedItem get_scanned_item (uint frequency) {
            return new ScannedItem (frequency);
        }
        
        protected override Channel get_new_channel () {
            return new TerrestrialChannel ();
        }
        
        protected override void add_values_from_structure_to_channel (
            Gst.Structure delivery, Channel channel) {
            if (!(channel is TerrestrialChannel)) return;
            
            TerrestrialChannel tc = (TerrestrialChannel)channel;
            
            // structure doesn't contain information about inversion
            // set it to auto
            tc.Inversion = DvbSrcInversion.INVERSION_AUTO;
            
            uint freq;
            delivery.get_uint ("frequency", out freq);
            tc.Frequency = freq;
            
            uint bandwidth;
            delivery.get_uint ("bandwidth", out bandwidth);
            tc.Bandwidth = get_bandwidth_val (bandwidth);
            
            uint hierarchy;
            delivery.get_uint ("hierarchy", out hierarchy);
            tc.Hierarchy = get_hierarchy_val (hierarchy);
            
            string constellation = delivery.get_string ("constellation");
            tc.Constellation = get_modulation_val (constellation);
            
            tc.CodeRateHP = get_code_rate_val (delivery.get_string ("code-rate-hp"));
            tc.CodeRateLP = get_code_rate_val (delivery.get_string ("code-rate-lp"));
            
            uint guard;
            delivery.get_uint ("guard-interval", out guard);
            tc.GuardInterval = get_guard_interval_val (guard);
            
            string transmode = delivery.get_string ("transmission-mode");
            tc.TransmissionMode = get_transmission_mode_val (transmode);
        }
        
    }
    
}
