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
    
    [DBus (name = "org.gnome.DVB.Scanner.Cable")]
    public interface IDBusCableScanner : GLib.Object {
    
        public abstract signal void frequency_scanned (uint frequency, uint freq_left);
        public abstract signal void finished ();
        public abstract signal void channel_added (uint frequency, uint sid,
            string name, string network, string type, bool scrambled);
        
        public abstract void Run () throws DBus.Error;
        public abstract void Destroy () throws DBus.Error;
        public abstract bool WriteAllChannelsToFile (string path) throws DBus.Error;
        public abstract bool WriteChannelsToFile (uint[] channel_sids, string path) throws DBus.Error;
        
        public abstract void AddScanningData (uint frequency, string modulation,
            uint symbol_rate, string code_rate) throws DBus.Error;
        
        /**
         * @path: Path to file containing scanning data
         * @returns: TRUE when the file has been parsed successfully
         *
         * Parses initial tuning data from a file as provided by dvb-apps
         */    
        public abstract bool AddScanningDataFromFile (string path) throws DBus.Error;
    }
    
    public class CableScanner : Scanner, IDBusCableScanner {
        
        public CableScanner (DVB.Device device) {
            base.Device = device;
        }
        
        public void AddScanningData (uint frequency, string modulation,
                uint symbol_rate, string code_rate) {
            this.add_scanning_data (frequency, modulation,
                symbol_rate, code_rate);
        }
                
        private inline void add_scanning_data (uint frequency, string modulation,
                uint symbol_rate, string code_rate) {
            var tuning_params = new Gst.Structure ("tuning_params",
            "frequency", typeof(uint), frequency,
            "symbol-rate", typeof(uint), symbol_rate,
            "inner-fec", typeof(string), code_rate,
            "modulation", typeof(string), modulation);
            
            base.add_structure_to_scan (tuning_params);  
        }
        
        public bool AddScanningDataFromFile (string path) {
            File datafile = File.new_for_path(path);
            
            debug ("Reading scanning data from %s", path);
            
            string? contents = null;
            try {
                contents = Utils.read_file_contents (datafile);
            } catch (Error e) {
                critical ("Could not read %s: %s", e.message, path);
            }
            
            if (contents == null) return false;
            
            // line looks like:
            // C freq sr fec mod
            foreach (string line in contents.split("\n")) {
                line = line.chug ();
                if (line.has_prefix ("#")) continue;
                
                string[] cols = Regex.split_simple ("\\s+", line);
                
                int cols_length = 0;
                while (cols[cols_length] != null)
                    cols_length++;
                cols_length++;
                
                if (cols_length < 5) continue;
                
                uint freq = (uint)cols[1].to_int ();
                string modulation = cols[4];
                uint symbol_rate = (uint)(cols[2].to_int () / 1000);
                string code_rate = cols[3];
                
                this.add_scanning_data (freq, modulation, symbol_rate, code_rate);
            }
            
            return true;
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
        
        protected override ScannedItem get_scanned_item (Gst.Structure structure) {
            // TODO
            uint freq;
            structure.get_uint ("frequency", out freq);
            return new ScannedItem (freq);
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
