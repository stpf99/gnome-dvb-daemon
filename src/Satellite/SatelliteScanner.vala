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

namespace DVB {
    
    [DBus (name = "org.gnome.DVB.Scanner.Satellite")]
    public interface IDBusSatelliteScanner : GLib.Object {
    
        public abstract signal void frequency_scanned (uint frequency, uint freq_left);
        public abstract signal void finished ();
        public abstract signal void channel_added (uint frequency, uint sid,
            string name, string network, string type, bool scrambled);
        public abstract signal void frontend_stats (double signal_strength,
            double signal_noise_ratio);
        
        public abstract void Run () throws DBus.Error;
        public abstract void Destroy () throws DBus.Error;
        public abstract bool WriteAllChannelsToFile (string path) throws DBus.Error;
        public abstract bool WriteChannelsToFile (uint[] channel_sids, string path) throws DBus.Error;
        
        public abstract void AddScanningData (uint frequency,
                                     string polarization, // "horizontal", "vertical"
                                     uint symbol_rate) throws DBus.Error;
        
        /**
         * @path: Path to file containing scanning data
         * @returns: TRUE when the file has been parsed successfully
         *
         * Parses initial tuning data from a file as provided by dvb-apps
         */                            
        public abstract bool AddScanningDataFromFile (string path) throws DBus.Error;
    }
    
    public class SatelliteScanner : Scanner, IDBusSatelliteScanner {
    
        public SatelliteScanner (DVB.Device device) {
            Object (Device: device);
        }
     
        public void AddScanningData (uint frequency,
                string polarization, uint symbol_rate) throws DBus.Error {
            this.add_scanning_data (frequency, polarization, symbol_rate);
        }
                
        private inline void add_scanning_data (uint frequency,
                string polarization, uint symbol_rate) {
            var tuning_params = new Gst.Structure ("tuning_params",
            "frequency", typeof(uint), frequency,
            "symbol-rate", typeof(uint), symbol_rate,
            "polarization", typeof(string), polarization);
            
            base.add_structure_to_scan (tuning_params);
        }
        
        protected override void add_scanning_data_from_string (string line) {
            // line looks like:
            // S freq pol sr fec
            string[] cols = Regex.split_simple ("\\s+", line);
            
            int cols_length = 0;
            while (cols[cols_length] != null)
                cols_length++;
            cols_length++;
            
            if (cols_length < 5) return;
            
            uint freq = (uint)cols[1].to_int ();
            uint symbol_rate = (uint)cols[3].to_int () / 1000;
            
            string pol;
            string lower_pol = cols[2].down ();
            if (lower_pol == "h")
                pol = "horizontal";
            else if (lower_pol == "v")
                pol = "vertical";
            else
                return;
            
            // TODO what about fec?
            
            this.add_scanning_data (freq, pol, symbol_rate);
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
        
        protected override ScannedItem get_scanned_item (Gst.Structure structure) {
            // dup string because get_string returns weak string
            string pol = "%s".printf (
                structure.get_string ("polarization"));
            
            uint freq;
            structure.get_uint ("frequency", out freq);
            return new ScannedSatteliteItem (freq, pol);
        }
        
        protected override Channel get_new_channel () {
            return new SatelliteChannel.without_schedule ();
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
