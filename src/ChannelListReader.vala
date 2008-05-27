using GLib;

namespace DVB {

    public class ChannelListReader : GLib.Object {
    
        public File ChannelFile {get; construct;}
        public AdapterType Type {get; construct;}
        public weak ChannelList Channels {
            get { return this.channels; }
        }
        
        private ChannelList channels;
        
        construct {
            this.channels = new ChannelList ();
        }
        
        public ChannelListReader (File file, AdapterType type) {
            this.ChannelFile = file;
            this.Type = type;
        }
        
        public void read () {
            FileInputStream stream;
            try {
                stream = this.ChannelFile.read (null);
            } catch (IOError e) {
                error(e.message);
                return;
            }
            
            FileInfo info;
            try {
                info = stream.query_info (
                    FILE_ATTRIBUTE_STANDARD_SIZE, null);
            } catch (Error e) {
                error(e.message);
                return;
            }
            
            uint64 filesize = info.get_attribute_uint64 (
                FILE_ATTRIBUTE_STANDARD_SIZE);
                
            StringBuilder sb = new StringBuilder ();               
            char[] buffer = new char[4096];
            try {
                long bytes_read;
                while ((bytes_read = stream.read (buffer, 4096, null)) > 0) {
                    for (int i=0; i<bytes_read; i++) {
                        sb.append_c (buffer[i]);
                    }
                }
                stream.close (null);
            } catch (Error e) {
                error(e.message);
                return;
            }
            
            foreach (string line in sb.str.split("\n")) {
                if (line.size () > 0) {
                    Channel c = this.parse_line (line);
                    if (c != null)
                        this.channels.add (#c);
                    else
                        warning("Could not parse channel");
                }
            }
        }
        
        private Channel?# parse_line (string line) {
            Channel c;
            switch (this.Type) {
                case AdapterType.DVB_T:
                c = this.parse_terrestrial_channel (line);
                break;
                
                case AdapterType.DVB_S:
                c = this.parse_satellite_channel (line);
                break;
                
                case AdapterType.DVB_C:
                c = null;
                break;
            }
            return c;
        }
        
        /**
         * @line: The line to parse
         * @returns: #TerrestrialChannel representing that line
         * 
         * A line looks like
         * Das Erste:212500000:INVERSION_AUTO:BANDWIDTH_7_MHZ:FEC_3_4:FEC_1_2:QAM_16:TRANSMISSION_MODE_8K:GUARD_INTERVAL_1_4:HIERARCHY_NONE:513:514:32
         */
        private TerrestrialChannel# parse_terrestrial_channel (string line) {
            var channel = new TerrestrialChannel ();
            
            string[] fields = line.split(":");
            
            int i=0;
            string val;
            weak EnumValue enumval;
            while ( (val = fields[i]) != null) {
                if (i == 0) {
                    channel.Name = val;
                } else if (i == 1) {
                    channel.Frequency = val.to_int ();
                } else if (i == 2) {
                    val = "DVB_DVB_SRC_INVERSION_"+val;
                    channel.Inversion = Utils.get_value_by_name_from_enum (
                        typeof(DvbSrcInversion), val);
                } else if (i == 3) {
                    val = "DVB_DVB_SRC_BANDWIDTH_"+val;
                    channel.Bandwith = Utils.get_value_by_name_from_enum (
                        typeof(DvbSrcBandwidth), val);
                } else if (i == 4) {
                    val = "DVB_DVB_SRC_CODE_RATE_"+val;
                    channel.CodeRateHP = Utils.get_value_by_name_from_enum (
                        typeof(DvbSrcCodeRate), val);
                } else if (i == 5) {
                    val = "DVB_DVB_SRC_CODE_RATE_"+val;
                    channel.CodeRateLP = Utils.get_value_by_name_from_enum (
                        typeof(DvbSrcCodeRate), val);
                } else if (i == 6) {
                    val = "DVB_DVB_SRC_MODULATION_"+val;
                    channel.Constellation = Utils.get_value_by_name_from_enum (
                        typeof(DvbSrcModulation), val);
                } else if (i == 7) {
                    val = "DVB_DVB_SRC_TRANSMISSION_MODE_"+val;
                    channel.TransmissionMode = Utils.get_value_by_name_from_enum (
                        typeof(DvbSrcTransmissionMode), val);
                } else if (i == 8) {
                    val = "DVB_DVB_SRC_GUARD_"+val;
                    channel.GuardInterval = Utils.get_value_by_name_from_enum (
                        typeof(DvbSrcGuard), val);
                } else if (i == 9) {
                    val = "DVB_DVB_SRC_HIERARCHY_"+val;
                    channel.Hierarchy = Utils.get_value_by_name_from_enum (
                        typeof(DvbSrcHierarchy), val);
                } else if (i == 10) {                
                    channel.VideoPID = val.to_int ();
                } else if (i == 11) {
                    channel.AudioPID = val.to_int ();
                } else if (i == 12) {
                    channel.Sid = val.to_int ();
                }
                
                i++;
            }
            
            return channel;
        }
        
        /**
         *
         * A line looks like
         * Das Erste:11836:h:0:27500:101:102:28106
         */
        private SatelliteChannel# parse_satellite_channel (string line) {
            var channel = new SatelliteChannel ();
            
            string[] fields = line.split(":");
            
            int i=0;
            string val;
            while ( (val = fields[i]) != null) {
                if (i == 0) {
                    channel.Name = val;
                } else if (i == 1) {
                    // frequency is stored in MHz
                    channel.Frequency = val.to_int () * 1000;
                } else if (i == 2) {
                    channel.Polarization = val;
                } else if (i == 3) {
                    // Sat number
                    channel.DiseqcSource = val.to_int ();
                } else if (i == 4) {
                    // symbol rate is stored in kBaud
                    channel.SymbolRate = val.to_int() * 1000;
                } else if (i == 5) {                
                    channel.VideoPID = val.to_int ();
                } else if (i == 6) {
                    channel.AudioPID = val.to_int ();
                } else if (i == 7) {
                    channel.Sid = val.to_int ();
                }
                
                i++;
            }
            
            return channel;
        }
        
    }
    
}
