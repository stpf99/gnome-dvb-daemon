/*
 * Copyright (C) 2008,2009 Sebastian Pölsterl
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

namespace DVB {
    
    /**
     * Example:
     * try {
     *     var writer = new DVB.ChannelListWriter (File.new_for_path ("/path/to/channels.conf"));
     *     foreach (DVB.Channel c in reader.Channels) {
     *         writer.write (c);
     *     }
     *     writer.close ();
     * } catch (IOError e) {
     *     error (e.message);
     * }
     */
    public class ChannelListWriter : GLib.Object {
    
        public File file {get; construct;}
    
        private OutputStream stream;
        
        private void open_stream () throws Error {
            FileOutputStream fostream = null;
            
            if (file.query_exists (null)) {
                fostream = this.file.replace (null, true, 0, null);
            } else {
                fostream = this.file.create (0, null);
            }
            
            this.stream = new BufferedOutputStream (fostream);
        }
        
        public ChannelListWriter (File file) throws Error {
            this.file = file;
        }
        
        public void write (Channel channel) throws Error {
            if (this.stream == null) this.open_stream ();
            if (this.stream == null) return;
        
            string buffer;
        
            // Write channel name
            buffer = "%s:".printf (channel.Name);
            this.stream.write (buffer, buffer.size(), null);
            
            // Write special data
            if (channel is TerrestrialChannel) {
                this.write_terrestrial_channel ((TerrestrialChannel)channel);
            } else if (channel is SatelliteChannel) {
                this.write_satellite_channel ((SatelliteChannel)channel);
            } else if (channel is CableChannel) {
                this.write_cable_channel ((CableChannel)channel);
            } else {
                warning ("Unknown channel type");
            }
            
            uint apid;
            if (channel.AudioPIDs.size == 0)
                apid = 0;
            else
                apid = channel.AudioPIDs.get (0);
            
            // Write common data
            buffer = ":%u:%u:%u\n".printf (channel.VideoPID,
                apid, channel.Sid);
            this.stream.write (buffer, buffer.size(), null);
        }
        
        public bool close () throws Error {
            return this.stream.close (null);
        } 
    
        private void write_terrestrial_channel (TerrestrialChannel channel) throws Error {
            string[] elements = new string[9];
            
            elements[0] = "%u".printf (channel.Frequency);
            
            elements[1] = get_name_without_prefix (typeof(DvbSrcInversion),
                                                      channel.Inversion,
                                                      "DVB_DVB_SRC_INVERSION_");
            
            elements[2] = get_name_without_prefix (typeof(DvbSrcBandwidth),
                                                      channel.Bandwidth,
                                                      "DVB_DVB_SRC_BANDWIDTH_");
            
            elements[3] = get_name_without_prefix (typeof(DvbSrcCodeRate),
                                                      channel.CodeRateHP,
                                                      "DVB_DVB_SRC_CODE_RATE_");
            
            elements[4] = get_name_without_prefix (typeof(DvbSrcCodeRate),
                                                      channel.CodeRateLP,
                                                      "DVB_DVB_SRC_CODE_RATE_");
            
            elements[5] = get_name_without_prefix (typeof(DvbSrcModulation),
                                                      channel.Constellation,
                                                      "DVB_DVB_SRC_MODULATION_");
            
            elements[6] = get_name_without_prefix (typeof(DvbSrcTransmissionMode),
                                                      channel.TransmissionMode,
                                                      "DVB_DVB_SRC_TRANSMISSION_MODE_");
            
            elements[7] = get_name_without_prefix (typeof(DvbSrcGuard),
                                                      channel.GuardInterval,
                                                      "DVB_DVB_SRC_GUARD_");
            
            elements[8] = get_name_without_prefix (typeof(DvbSrcHierarchy),
                                                      channel.Hierarchy,
                                                      "DVB_DVB_SRC_HIERARCHY_");
                                                      
            string buffer = string.joinv (":", elements);
            this.stream.write (buffer, buffer.size(), null);
        }
        
        private void write_satellite_channel (SatelliteChannel channel) throws Error {
            string buffer = "%u:%s:%d:%u".printf (channel.Frequency / 1000,
                                                  channel.Polarization,
                                                  channel.DiseqcSource,
                                                  channel.SymbolRate);
            this.stream.write (buffer, buffer.size(), null);
        }
        
        private void write_cable_channel (CableChannel channel) throws Error {
            string[] elements = new string [5];
            
            elements[0] = "%u".printf (channel.Frequency);
                        
            elements[1] = get_name_without_prefix (typeof(DvbSrcInversion),
                                                      channel.Inversion,
                                                      "DVB_DVB_SRC_INVERSION_");
            
            elements[2] = "%u".printf (channel.SymbolRate * 1000);
                                    
            elements[3] = get_name_without_prefix (typeof(DvbSrcCodeRate),
                                                      channel.CodeRate,
                                                      "DVB_DVB_SRC_CODE_RATE_");
                                                      
            elements[4] = get_name_without_prefix (typeof(DvbSrcModulation),
                                                      channel.Modulation,
                                                      "DVB_DVB_SRC_MODULATION_");
                                                      
            string buffer = string.joinv (":", elements);
            this.stream.write (buffer, buffer.size(), null);
        }
        
        private static string? get_name_without_prefix (GLib.Type enumtype,
                                                             int val, string prefix) {
            string? name = Utils.get_name_by_value_from_enum (enumtype,
                                                             val);
            if (name == null) return null;
            else return name.substring (prefix.size (),
                name.size () - prefix.size ());
        }
        
    }
    
}
