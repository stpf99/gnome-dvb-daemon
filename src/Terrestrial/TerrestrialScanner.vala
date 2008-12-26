using GLib;

namespace DVB {
    
    [DBus (name = "org.gnome.DVB.Scanner.Terrestrial")]    
    public interface IDBusTerrestrialScanner : GLib.Object {
    
        public abstract signal void frequency_scanned (uint frequency, uint freq_left);
        public abstract signal void finished ();
        public abstract signal void channel_added (uint frequency, uint sid,
            string name, string network, string type, bool scrambled);
        
        public abstract void Run ();
        public abstract void Destroy ();
        public abstract bool WriteChannelsToFile (string path);
        
        public abstract void AddScanningData (uint frequency,
                                     uint hierarchy, // 0-3
                                     uint bandwidth, // 0, 6, 7, 8
                                     string transmode, // "2k", "8k"
                                     string code_rate_hp, // "1/2", "2/3", "3/4", ..., "8/9"
                                     string code_rate_lp,
                                     string constellation, // QPSK, QAM16, QAM64
                                     uint guard);  // 4, 8, 16, 32
        
        /**
         * @path: Path to file containing scanning data
         * @returns: TRUE when the file has been parsed successfully
         *
         * Parses initial tuning data from a file as provided by dvb-apps
         */                             
        public abstract bool AddScanningDataFromFile (string path);
    }
    
    public class TerrestrialScanner : Scanner, IDBusTerrestrialScanner {
    
        public TerrestrialScanner (DVB.Device device) {
            base.Device = device;
        }
        
        /**
          * See enums in MpegTsEnums
          */
        public void AddScanningData (uint frequency, uint hierarchy,
                uint bandwidth, string transmode, string code_rate_hp,
                string code_rate_lp, string constellation, uint guard) {
             
            Gst.Structure tuning_params = new Gst.Structure ("tuning_params",
                "frequency", typeof(uint), frequency,
                "hierarchy", typeof(uint), hierarchy,
                "bandwidth", typeof(uint), bandwidth,
                "transmission-mode", typeof(string), transmode,
                "code-rate-hp", typeof(string), code_rate_hp,
                "code-rate-lp", typeof(string), code_rate_lp,
                "constellation", typeof(string), constellation,
                "guard-interval", typeof(uint), guard);
            
            base.add_structure_to_scan (#tuning_params);
        }
        
        public bool AddScanningDataFromFile (string path) {
            File datafile = File.new_for_path(path);
            
            debug ("Reading scanning data from %s", path);
            
            string? contents = null;
            try {
                contents = Utils.read_file_contents (datafile);
            } catch (Error e) {
                critical (e.message);
            }
            
            if (contents == null) return false;
            
            // line looks like:
            // T freq bw fec_hi fec_lo mod transmission-mode guard-interval hierarchy
            foreach (string line in contents.split("\n")) {
                if (line.has_prefix ("#")) continue;
                
                string[] cols = Regex.split_simple ("\\s+", line);
                
                int cols_length = 0;
                while (cols[cols_length] != null)
                    cols_length++;
                cols_length++;
                
                if (cols_length < 9) {
                    continue;
                }
                
                uint freq = (uint)cols[1].to_int ();
                
                uint hierarchy = 0;
                if (cols[8] == "1") {
                    hierarchy = 1;
                } else if (cols[8] == "2") {
                    hierarchy = 2;
                } else if (cols[8] == "4") {
                    hierarchy = 3;
                }
                
                string bandwidth_str = cols[2].split("MHz")[0];
                uint bandwidth = (uint)bandwidth_str.to_int ();
                string transmode = cols[6];
                string code_rate_hp = cols[3];
                string code_rate_lp = cols[4];
                string constellation = cols[5];
                
                string guard_str = cols[7].split("/")[1];
                uint guard = (uint)guard_str.to_int ();
                
                this.AddScanningData (freq, hierarchy,
                    bandwidth, transmode, code_rate_hp,
                    code_rate_lp, constellation, guard);
            }
            
            return true;
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
        
        protected override ScannedItem get_scanned_item (Gst.Structure structure) {
            uint freq;
            structure.get_uint ("frequency", out freq);
            return new ScannedItem (freq);
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
