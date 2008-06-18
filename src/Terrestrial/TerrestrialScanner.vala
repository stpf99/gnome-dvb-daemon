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
            
            base.set_uint_property (dvbsrc, base.current_tuning_params, "frequency");
            
            uint bandwidth;
            this.current_tuning_params.get_uint ("bandwidth", out bandwidth);
            dvbsrc.set ("bandwidth", get_bandwidth_val (bandwidth));
            
            uint hierarchy;
            this.current_tuning_params.get_uint ("hierarchy", out hierarchy);
            dvbsrc.set ("hierarchy", get_hierarchy_val (hierarchy));
            
            string constellation = this.current_tuning_params.get_string ("constellation");
            dvbsrc.set ("modulation", get_constellation_val (constellation));
                
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
            // FIXME set inversion
            uint bandwidth;
            delivery.get_uint ("bandwidth", out bandwidth);
            tc.Bandwidth = get_bandwidth_val (bandwidth);
            
            uint hierarchy;
            delivery.get_uint ("hierarchy", out hierarchy);
            tc.Hierarchy = get_hierarchy_val (hierarchy);
            
            string constellation = delivery.get_string ("constellation");
            tc.Constellation = get_constellation_val (constellation);
            
            tc.CodeRateHP = get_code_rate_val (delivery.get_string ("code-rate-hp"));
            tc.CodeRateLP = get_code_rate_val (delivery.get_string ("code-rate-lp"));
            
            uint guard;
            delivery.get_uint ("guard-interval", out guard);
            tc.GuardInterval = get_guard_interval_val (guard);
            
            string transmode = delivery.get_string ("transmission-mode");
            tc.TransmissionMode = get_transmission_mode_val (transmode);
        }
        
        private static DvbSrcBandwidth get_bandwidth_val (uint bandwidth) {
            DvbSrcBandwidth val;
            switch (bandwidth) {
                case 0: val = DvbSrcBandwidth.BANDWIDTH_AUTO; break;
                case 6: val = DvbSrcBandwidth.BANDWIDTH_6_MHZ; break;
                case 7: val = DvbSrcBandwidth.BANDWIDTH_7_MHZ; break;
                case 8: val = DvbSrcBandwidth.BANDWIDTH_8_MHZ; break;
            }
            return val;
        }
        
        private static DvbSrcHierarchy get_hierarchy_val (uint hierarchy) {
            DvbSrcHierarchy val;
            switch (hierarchy) {
                case 0: val = DvbSrcHierarchy.HIERARCHY_NONE; break;
                case 1: val = DvbSrcHierarchy.HIERARCHY_1; break;
                case 2: val = DvbSrcHierarchy.HIERARCHY_2; break;
                case 3: val = DvbSrcHierarchy.HIERARCHY_4; break;
                default: val = DvbSrcHierarchy.HIERARCHY_AUTO; break;
            }
            return val;
        }
        
        private static DvbSrcModulation get_constellation_val (string constellation) {
            DvbSrcModulation val;
            if (constellation == "QPSK")
                val = DvbSrcModulation.QPSK;
            else if (constellation == "QAM16")
                val = DvbSrcModulation.QAM_16;
            else if (constellation == "QAM64")
                val = DvbSrcModulation.QAM_64;
            else
                val = DvbSrcModulation.QAM_AUTO;
            
            return val;
        }
        
        private static DvbSrcCodeRate get_code_rate_val (string code_rate_string) {
            DvbSrcCodeRate val;
            if (code_rate_string == "NONE")
                val = DvbSrcCodeRate.FEC_NONE;
            else if (code_rate_string == "1/2")
                val = DvbSrcCodeRate.FEC_1_2;
            else if (code_rate_string == "2/3")
                val = DvbSrcCodeRate.FEC_2_3;
            else if (code_rate_string == "3/4")
                val = DvbSrcCodeRate.FEC_3_4;
            else if (code_rate_string == "4/5")
                val = DvbSrcCodeRate.FEC_4_5;
            else if (code_rate_string == "5/6")
                val = DvbSrcCodeRate.FEC_5_6;
            else if (code_rate_string == "7/8")
                val = DvbSrcCodeRate.FEC_7_8;
            else if (code_rate_string == "8/9")
                val = DvbSrcCodeRate.FEC_8_9;
            else
                val = DvbSrcCodeRate.FEC_AUTO;
            
            return val;
        }
        
        private static DvbSrcGuard get_guard_interval_val (uint guard) {
            DvbSrcGuard val;
            switch (guard) {
                case 4:
                val = DvbSrcGuard.GUARD_INTERVAL_1_4; break;
                case 8:
                val = DvbSrcGuard.GUARD_INTERVAL_1_8; break;
                case 16:
                val = DvbSrcGuard.GUARD_INTERVAL_1_16; break;
                case 32:
                val = DvbSrcGuard.GUARD_INTERVAL_1_32; break;
                default:
                val = DvbSrcGuard.GUARD_INTERVAL_AUTO; break;
            }
            return val;
        }
        
        private static DvbSrcTransmissionMode get_transmission_mode_val (
            string transmode) {
            DvbSrcTransmissionMode val;
            if (transmode == "2k")
                val = DvbSrcTransmissionMode.TRANSMISSION_MODE_2K;
            else if (transmode == "8k")
                val = DvbSrcTransmissionMode.TRANSMISSION_MODE_8K;
            else
                val = DvbSrcTransmissionMode.TRANSMISSION_MODE_AUTO;
                
            return val;
        }
    }
    
}
