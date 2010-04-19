/*
 * Copyright (C) 2008-2010 Sebastian Pölsterl
 *
 * This file is part of GNOME DVB Daemon.
 *
 * GNOME DVB Daemon is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * GNOME DVB Daemon is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with GNOME DVB Daemon.  If not, see <http://www.gnu.org/licenses/>.
 */

using GLib;

namespace DVB.io {

    public class ChannelListReader : GLib.Object {

        public ChannelList channels {get; construct;}
        public AdapterType Type {get; construct;}
        
        public ChannelListReader (ChannelList channels, AdapterType type) {
            base (channels: channels, Type: type);
        }

        public void read_into () throws Error {
            return_if_fail (this.channels.channels_file != null);
        
            var reader = new DataInputStream (
                this.channels.channels_file.read (null));
        	
        	string line = null;
        	size_t len;
        	while ((line = reader.read_line (out len, null)) != null) {
            if (len > 0) {
                Channel c = this.parse_line (line);
                if (c != null) {
                    channels.add (c);
                } else
                    warning ("Could not parse channel");
                }
        	}
        	reader.close (null);
        }

        private Channel? parse_line (string line) {
            Channel? c = null;
            switch (this.Type) {
                case AdapterType.DVB_T:
                c = parse_terrestrial_channel (line);
                break;
                
                case AdapterType.DVB_S:
                c = parse_satellite_channel (line);
                break;
                
                case AdapterType.DVB_C:
                c = parse_cable_channel (line);
                break;
                
                default:
                critical ("Unknown adapter type");
                break;
            }
            
            if (c != null && c.is_valid ()) {
                c.GroupId = this.channels.GroupId;
                return c;
            } else {
                string val = (c == null) ? "(null)" : c.to_string ();
                warning ("Channel is not valid: %s", val);
                return null;
            }
        }
        
        /**
         * @line: The line to parse
         * @returns: #TerrestrialChannel representing that line
         * 
         * A line looks like
         * Das Erste:212500000:INVERSION_AUTO:BANDWIDTH_7_MHZ:FEC_3_4:FEC_1_2:QAM_16:TRANSMISSION_MODE_8K:GUARD_INTERVAL_1_4:HIERARCHY_NONE:513:514:32
         */
        private TerrestrialChannel? parse_terrestrial_channel (string line) {
            var channel = new TerrestrialChannel ();
            
            string[] fields = line.split(":");
            
            int i=0;
            string val;
            bool failed = false;
            while ( (val = fields[i]) != null) {
                if (i == 0) {
                    if (val.validate())
                        channel.Name = val;
                    else {
                        warning ("Bad UTF-8 encoded channel name");
                        channel.Name = "Bad encoding";
                    }
                } else if (i == 1) {
                    channel.Frequency = (uint)val.to_int ();
                } else if (i == 2) {
                    int eval;
                    if (get_value_with_prefix (typeof(DvbSrcInversion), val,
                            "DVB_DVB_SRC_INVERSION_", out eval)) {
                        channel.Inversion = (DvbSrcInversion) eval;
                    } else {
                        failed = true;
                        break;
                    }
                } else if (i == 3) {
                    int eval;
                    if (get_value_with_prefix (typeof(DvbSrcBandwidth), val,
                            "DVB_DVB_SRC_BANDWIDTH_", out eval)) {
                        channel.Bandwidth = (DvbSrcBandwidth) eval;
                    } else {
                        failed = true;
                        break;
                    }
                } else if (i == 4) {
                    int eval;
                    if (get_value_with_prefix (typeof(DvbSrcCodeRate), val,
                            "DVB_DVB_SRC_CODE_RATE_", out eval)) {
                        channel.CodeRateHP = (DvbSrcCodeRate) eval;
                    } else {
                        failed = true;
                        break;
                    }
                } else if (i == 5) {
                    int eval;
                    if (get_value_with_prefix (typeof(DvbSrcCodeRate), val,
                            "DVB_DVB_SRC_CODE_RATE_", out eval)) {
                        channel.CodeRateLP = (DvbSrcCodeRate) eval;
                    } else {
                        failed = true;
                        break;
                    }
                } else if (i == 6) {
                    int eval;
                    if (get_value_with_prefix (typeof(DvbSrcModulation), val,
                            "DVB_DVB_SRC_MODULATION_", out eval)) {
                        channel.Constellation = (DvbSrcModulation) eval;
                    } else {
                        failed = true;
                        break;
                    }
                } else if (i == 7) {
                    int eval;
                    if (get_value_with_prefix (typeof(DvbSrcTransmissionMode),
                            val, "DVB_DVB_SRC_TRANSMISSION_MODE_", out eval)) {
                        channel.TransmissionMode = (DvbSrcTransmissionMode) eval;
                    } else {
                        failed = true;
                        break;
                    }
                } else if (i == 8) {
                    int eval;
                    if (get_value_with_prefix (typeof(DvbSrcGuard), val,
                            "DVB_DVB_SRC_GUARD_", out eval)) {
                        channel.GuardInterval = (DvbSrcGuard) eval;
                    } else {
                        failed = true;
                        break;
                    }
                } else if (i == 9) {
                    int eval;
                    if (get_value_with_prefix (typeof(DvbSrcHierarchy), val,
                            "DVB_DVB_SRC_HIERARCHY_", out eval)) {
                        channel.Hierarchy = (DvbSrcHierarchy) eval;
                    } else {
                        failed = true;
                        break;
                    }
                } else if (i == 10) {                
                    channel.VideoPID = (uint)val.to_int ();
                } else if (i == 11) {
                    channel.AudioPIDs.add ((uint)val.to_int ());
                } else if (i == 12) {
                    channel.Sid = (uint)val.to_int ();
                }
                
                i++;
            }
            
            if (failed) return null;
            else return channel;
        }
        
        /**
         *
         * A line looks like
         * Das Erste:11836:h:0:27500:101:102:28106
         */
        private SatelliteChannel? parse_satellite_channel (string line) {
            var channel = new SatelliteChannel ();
            
            string[] fields = line.split(":");
            
            int i=0;
            string val;
            while ( (val = fields[i]) != null) {
                if (i == 0) {
                    if (val.validate())
                        channel.Name = val;
                    else {
                        warning ("Bad UTF-8 encoded channel name");
                        channel.Name = "Bad encoding";
                    }
                } else if (i == 1) {
                    // frequency is stored in MHz
                    channel.Frequency = (uint)(val.to_int () * 1000);
                } else if (i == 2) {
                    channel.Polarization = val;
                } else if (i == 3) {
                    // Sat number
                    channel.DiseqcSource = val.to_int ();
                } else if (i == 4) {
                    // symbol rate is stored in kBaud
                    channel.SymbolRate = (uint)val.to_int();
                } else if (i == 5) {                
                    channel.VideoPID = (uint)val.to_int ();
                } else if (i == 6) {
                    channel.AudioPIDs.add ((uint)val.to_int ());
                } else if (i == 7) {
                    channel.Sid = (uint)val.to_int ();
                }
                
                i++;
            }
            
            return channel;
        }
        
        /**
         *
         * line looks like
         * ProSieben:330000000:INVERSION_AUTO:6900000:FEC_NONE:QAM_64:255:256:898
         */
        private CableChannel? parse_cable_channel (string line) {
            var channel = new CableChannel ();
            
            string[] fields = line.split(":");
            
            int i=0;
            string val;
            bool failed = false;
            while ( (val = fields[i]) != null) {
                if (i == 0) {
                    if (val.validate())
                        channel.Name = val;
                    else {
                        warning ("Bad UTF-8 encoded channel name");
                        channel.Name = "Bad encoding";
                    }
                } else if (i == 1) {
                    channel.Frequency = (uint)val.to_int ();
                } else if (i == 2) {
                    int eval;
                    if (get_value_with_prefix (typeof(DvbSrcInversion), val,
                            "DVB_DVB_SRC_INVERSION_", out eval)) {
                        channel.Inversion = (DvbSrcInversion) eval;
                    } else {
                        failed = true;
                        break;
                    }
                } else if (i == 3) {
                    channel.SymbolRate = (uint)(val.to_int () / 1000);
                } else if (i == 4) {
                    int eval;
                    if (get_value_with_prefix (typeof(DvbSrcCodeRate), val,
                            "DVB_DVB_SRC_CODE_RATE_", out eval)) {
                        channel.CodeRate = (DvbSrcCodeRate) eval;
                    } else {
                        failed = true;
                        break;
                    }
                } else if (i == 5) {
                    int eval;
                    if (get_value_with_prefix (typeof(DvbSrcModulation), val,
                            "DVB_DVB_SRC_MODULATION_", out eval)) {
                        channel.Modulation = (DvbSrcModulation) eval;
                    } else {
                        failed = true;
                        break;
                    }
                } else if (i == 6) {                
                    channel.VideoPID = (uint)val.to_int ();
                } else if (i == 7) {
                    channel.AudioPIDs.add ((uint)val.to_int ());
                } else if (i == 8) {
                    channel.Sid = (uint)val.to_int ();
                }
                
                i++;
            }
            
            if (failed) return null;
            else return channel;
        }
        
        private static bool get_value_with_prefix (GLib.Type enumtype, string name,
                                                  string prefix, out int val) {
            return Utils.get_value_by_name_from_enum (enumtype, prefix + name, out val);
        }
    }
    
}
