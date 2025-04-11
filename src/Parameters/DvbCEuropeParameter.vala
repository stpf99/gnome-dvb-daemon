/*
 * DvbCEuropeParameter.vala
 *
 * Copyright (C) 2014 Stefan Ringel
 *
 * GNOME DVB Daemon is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * GNOME DVB Daemon is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with GNOME DVB Daemon.  If not, see <http://www.gnu.org/licenses/>.
 */

using GLib;
using GstMpegts;
using DVB.Logging;

namespace DVB {
    public class DvbCEuropeParameter : Parameter {
        private static Logger log = LogManager.getLogManager().getDefaultLogger();

        public uint SymbolRate { get; private set; }
        public ModulationType Modulation { get; private set; }
        public DVBCodeRate InnerFEC { get; private set; }
        
        // C2 specific parameters
        public uint DataSlice { get; private set; }
        public uint PlpId { get; private set; }
        public bool IsC2 { get; private set; }

        // Constructor for DVB-C
        public DvbCEuropeParameter () {
            base (DvbSrcDelsys.SYS_DVBC_ANNEX_A);
            this.IsC2 = false;
        }

        // Constructor for DVB-C with parameters
        public DvbCEuropeParameter.with_parameter (uint frequency, uint symbol_rate,
                ModulationType modulation, DVBCodeRate inner_fec) {
            base (DvbSrcDelsys.SYS_DVBC_ANNEX_A);
            this.Frequency = frequency;
            this.SymbolRate = symbol_rate;
            this.Modulation = modulation;
            this.InnerFEC = inner_fec;
            this.IsC2 = false;
        }
        
        // Constructor for DVB-C2
        public DvbCEuropeParameter.c2 () {
            base (DvbSrcDelsys.SYS_DVBC2);
            this.IsC2 = true;
        }
        
        // Constructor for DVB-C2 with parameters
        public DvbCEuropeParameter.c2_with_parameter (uint frequency, uint symbol_rate,
                ModulationType modulation, DVBCodeRate inner_fec, uint data_slice, uint plp_id) {
            base (DvbSrcDelsys.SYS_DVBC2);
            this.Frequency = frequency;
            this.SymbolRate = symbol_rate;
            this.Modulation = modulation;
            this.InnerFEC = inner_fec;
            this.DataSlice = data_slice;
            this.PlpId = plp_id;
            this.IsC2 = true;
        }

        public override bool add_scanning_data (HashTable<string, Variant> data) {
            unowned Variant _var;

            _var = data.lookup ("frequency");
            if (_var == null)
                return false;
            this.Frequency = _var.get_uint32 ();

            _var = data.lookup ("symbol-rate");
            if (_var == null)
                return false;
            this.SymbolRate = _var.get_uint32 ();

            _var = data.lookup ("inner-fec");
            if (_var == null)
                return false;
            this.InnerFEC = getCodeRateEnum (_var.get_string ());

            _var = data.lookup ("modulation");
            if (_var == null)
                return false;
            this.Modulation = getModulationEnum (_var.get_string ());
            
            // Check if this is C2
            _var = data.lookup ("delsys");
            if (_var != null && _var.get_string () == "SYS_DVBC2") {
                this.IsC2 = true;
                this.Delsys = DvbSrcDelsys.SYS_DVBC2;
                
                _var = data.lookup ("data-slice");
                if (_var == null)
                    return false;
                this.DataSlice = _var.get_uint32 ();
                
                _var = data.lookup ("plp-id");
                if (_var == null)
                    return false;
                this.PlpId = _var.get_uint32 ();
            } else {
                this.IsC2 = false;
                this.Delsys = DvbSrcDelsys.SYS_DVBC_ANNEX_A;
            }

            return true;
        }

        public override bool equal (Parameter param) {
            if (param == null)
                return false;

            if (param.Delsys != this.Delsys)
                return false;

            DvbCEuropeParameter cparam = (DvbCEuropeParameter)param;

            if (cparam.Frequency == this.Frequency &&
                cparam.SymbolRate == this.SymbolRate &&
                cparam.InnerFEC == this.InnerFEC &&
                cparam.Modulation == this.Modulation) {
                
                // For C2, also check C2-specific parameters
                if (this.IsC2) {
                    if (cparam.IsC2 && cparam.DataSlice == this.DataSlice && cparam.PlpId == this.PlpId)
                        return true;
                    return false;
                }
                return true;
            }

            return false;
        }

        public override void prepare (Gst.Element source) {
            if (this.IsC2) {
                log.debug ("Prepare DVB-C2 Scanning Parameter");
            } else {
                log.debug ("Prepare DVB-C Scanning Parameter");
            }
            
            source.set ("frequency", this.Frequency);
            source.set ("symbol-rate", this.SymbolRate / 1000);
            source.set ("modulation", this.Modulation);
            source.set ("code-rate-hp", this.InnerFEC);
            source.set ("delsys", this.Delsys);
            
            if (this.IsC2) {
                source.set ("data-slice", this.DataSlice);
                source.set ("plp-id", this.PlpId);
            }
        }

        public override string to_string () {
            if (this.IsC2) {
                return "DVBC2:%u:%u:%s:%s:%u:%u".printf (this.Frequency, this.SymbolRate / 1000,
                    getModulationString (this.Modulation), getCodeRateString (this.InnerFEC),
                    this.DataSlice, this.PlpId);
            } else {
                return "DVBC/ANNEX_A:%u:%u:%s:%s".printf (this.Frequency, this.SymbolRate / 1000,
                    getModulationString (this.Modulation), getCodeRateString (this.InnerFEC));
            }
        }
    }
}
