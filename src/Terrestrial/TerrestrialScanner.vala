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
            
            uint bandwidth;
            delivery.get_uint ("bandwidth", out bandwidth);
            switch (bandwidth) {
                case 0: tc.Bandwidth = DvbSrcBandwidth.BANDWIDTH_AUTO; break;
                case 6: tc.Bandwidth = DvbSrcBandwidth.BANDWIDTH_6_MHZ; break;
                case 7: tc.Bandwidth = DvbSrcBandwidth.BANDWIDTH_7_MHZ; break;
                case 8: tc.Bandwidth = DvbSrcBandwidth.BANDWIDTH_8_MHZ; break;
            }
            
            uint hierarchy;
            delivery.get_uint ("hierarchy", out hierarchy);
            switch (hierarchy) {
                case 0: tc.Hierarchy = DvbSrcHierarchy.HIERARCHY_NONE; break;
                case 1: tc.Hierarchy = DvbSrcHierarchy.HIERARCHY_1; break;
                case 2: tc.Hierarchy = DvbSrcHierarchy.HIERARCHY_2; break;
                default: tc.Hierarchy = DvbSrcHierarchy.HIERARCHY_AUTO; break;
            }
            
            string constellation = delivery.get_string ("constellation");
            if (constellation == "QPSK")
                tc.Constellation = DvbSrcModulation.QPSK;
            else if (constellation == "QAM16")
                tc.Constellation = DvbSrcModulation.QAM_16;
            else if (constellation == "QAM64")
                tc.Constellation = DvbSrcModulation.QAM_64;
            else
                tc.Constellation = DvbSrcModulation.QAM_AUTO;
                
            tc.CodeRateHP = get_code_rate_val (delivery.get_string ("code-rate-hp"));
            tc.CodeRateLP = get_code_rate_val (delivery.get_string ("code-rate-lp"));
            
            uint guard;
            delivery.get_uint ("guard-interval", out guard);
            switch (guard) {
                case 4:
                tc.GuardInterval = DvbSrcGuard.GUARD_INTERVAL_1_4; break;
                case 8:
                tc.GuardInterval = DvbSrcGuard.GUARD_INTERVAL_1_8; break;
                case 16:
                tc.GuardInterval = DvbSrcGuard.GUARD_INTERVAL_1_16; break;
                case 32:
                tc.GuardInterval = DvbSrcGuard.GUARD_INTERVAL_1_32; break;
                default:
                tc.GuardInterval = DvbSrcGuard.GUARD_INTERVAL_AUTO; break;
            }
            
            string transmode = delivery.get_string ("transmission-mode");
            if (transmode == "2k")
                tc.TransmissionMode =
                    DvbSrcTransmissionMode.TRANSMISSION_MODE_2K;
            else if (transmode == "8k")
                tc.TransmissionMode =
                    DvbSrcTransmissionMode.TRANSMISSION_MODE_8K;
            else
                tc.TransmissionMode =
                    DvbSrcTransmissionMode.TRANSMISSION_MODE_AUTO;
        }
        
        private static DvbSrcCodeRate get_code_rate_val (string code_rate_string) {
            DvbSrcCodeRate val;
            if (code_rate_string == "1/2")
                val = DvbSrcCodeRate.FEC_1_2;
            else if (code_rate_string == "2/3")
                val = DvbSrcCodeRate.FEC_2_3;
            else if (code_rate_string == "3/4")
                val = DvbSrcCodeRate.FEC_3_4;
            else if (code_rate_string == "5/6")
                val = DvbSrcCodeRate.FEC_5_6;
            else if (code_rate_string == "7/8")
                val = DvbSrcCodeRate.FEC_7_8;
            else
                val = DvbSrcCodeRate.FEC_AUTO;
            
            return val;
        }
    }
    
}
