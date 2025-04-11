/*
 * DvbSParameter.vala
 *
 * Copyright (C) 2014, 2025 Stefan Ringel
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
    public class DvbSParameter : Parameter {
        private static Logger log = LogManager.getLogManager().getDefaultLogger();

        public uint SymbolRate { get; private set; }
        public float OrbitalPosition { get; private set; }
        public SatellitePolarizationType Polarization { get; private set; }
        public int DiseqcSource { get; set; }
        public DVBCodeRate InnerFEC { get; private set; }
        
        // DVB-S2/S2X specific parameters (with default values for DVB-S)
        public ModulationType Modulation { get; private set; default = ModulationType.QPSK; }
        public uint StreamId { get; private set; default = 0; }
        public bool IsMultistream { get; private set; default = false; }
        public uint PLS_Code { get; private set; default = 1; }  // Default Gold code
        public uint PLS_Mode { get; private set; default = 0; }  // Default Root mode

        // Constructor
        public DvbSParameter() {
            base(DvbSrcDelsys.SYS_DVBS);
            this.DiseqcSource = -1;
        }

        // Constructor with custom delivery system
        public DvbSParameter.with_delivery_system(DvbSrcDelsys delsys) {
            base(delsys);
            this.DiseqcSource = -1;
            
            // Handle advanced features for S2/S2X
            if (delsys == DvbSrcDelsys.SYS_DVBS2 || delsys == DvbSrcDelsys.SYS_DVBS2X) {
                this.Modulation = ModulationType.PSK_8;  // Default for S2/S2X
            }
        }

        public DvbSParameter.with_parameter(uint frequency, uint symbol_rate,
                float position, SatellitePolarizationType polarization,
                DVBCodeRate inner_fec, DvbSrcDelsys delsys = DvbSrcDelsys.SYS_DVBS) {
            base(delsys);
            this.Frequency = frequency;
            this.SymbolRate = symbol_rate;
            this.OrbitalPosition = position;
            this.Polarization = polarization;
            this.InnerFEC = inner_fec;
            this.DiseqcSource = -1;
            
            // Default modulation based on delivery system
            if (delsys == DvbSrcDelsys.SYS_DVBS2 || delsys == DvbSrcDelsys.SYS_DVBS2X) {
                this.Modulation = ModulationType.PSK_8;
            }
        }
        
        // Extended constructor for S2/S2X with modulation
        public DvbSParameter.with_extended_parameter(uint frequency, uint symbol_rate,
                float position, SatellitePolarizationType polarization,
                DVBCodeRate inner_fec, ModulationType modulation, DvbSrcDelsys delsys) {
            base(delsys);
            this.Frequency = frequency;
            this.SymbolRate = symbol_rate;
            this.OrbitalPosition = position;
            this.Polarization = polarization;
            this.InnerFEC = inner_fec;
            this.Modulation = modulation;
            this.DiseqcSource = -1;
        }
        
        // Full constructor for S2X with multistream support
        public DvbSParameter.with_s2x_parameter(uint frequency, uint symbol_rate,
                float position, SatellitePolarizationType polarization,
                DVBCodeRate inner_fec, ModulationType modulation, 
                uint stream_id, uint pls_code, uint pls_mode) {
            base(DvbSrcDelsys.SYS_DVBS2X);
            this.Frequency = frequency;
            this.SymbolRate = symbol_rate;
            this.OrbitalPosition = position;
            this.Polarization = polarization;
            this.InnerFEC = inner_fec;
            this.Modulation = modulation;
            this.DiseqcSource = -1;
            this.StreamId = stream_id;
            this.IsMultistream = stream_id > 0;
            this.PLS_Code = pls_code;
            this.PLS_Mode = pls_mode;
        }

        public override bool add_scanning_data(HashTable<string, Variant> data) {
            unowned Variant _var;

            _var = data.lookup("frequency");
            if (_var == null)
                return false;
            this.Frequency = _var.get_uint32();

            _var = data.lookup("symbol-rate");
            if (_var == null)
                return false;
            this.SymbolRate = _var.get_uint32();

            _var = data.lookup("polarization");
            if (_var == null)
                return false;
            this.Polarization = getPolarizationEnum(_var.get_string());

            _var = data.lookup("inner-fec");
            if (_var == null)
                return false;
            this.InnerFEC = getCodeRateEnum(_var.get_string());

            _var = data.lookup("orbital-position");
            if (_var == null)
                return false;
            this.OrbitalPosition = (float)_var.get_double();

            _var = data.lookup("diseqc-source");
            if (_var == null)
                return false;
            this.DiseqcSource = (int)_var.get_int16();
            
            // For S2/S2X modulation
            _var = data.lookup("modulation");
            if (_var != null) {
                this.Modulation = getModulationEnum(_var.get_string());
            }
            
            // For S2X multistream
            _var = data.lookup("stream-id");
            if (_var != null) {
                this.StreamId = _var.get_uint32();
                this.IsMultistream = this.StreamId > 0;
            }
            
            _var = data.lookup("pls-code");
            if (_var != null)
                this.PLS_Code = _var.get_uint32();
                
            _var = data.lookup("pls-mode");
            if (_var != null)
                this.PLS_Mode = _var.get_uint32();

            return true;
        }

        public override bool equal(Parameter param) {
            if (param == null)
                return false;

            // Only compare with the same delivery system
            if (param.Delsys != this.Delsys)
                return false;

            DvbSParameter sparam = (DvbSParameter)param;

            // Basic parameters
            if (sparam.Frequency == this.Frequency &&
                sparam.SymbolRate == this.SymbolRate &&
                sparam.InnerFEC == this.InnerFEC &&
                sparam.Polarization == this.Polarization &&
                sparam.OrbitalPosition == this.OrbitalPosition &&
                sparam.DiseqcSource == this.DiseqcSource) {
                
                // For S2/S2X also check modulation
                if (this.Delsys == DvbSrcDelsys.SYS_DVBS2 || 
                    this.Delsys == DvbSrcDelsys.SYS_DVBS2X) {
                    if (sparam.Modulation != this.Modulation)
                        return false;
                        
                    // For S2X also check multistream parameters
                    if (this.Delsys == DvbSrcDelsys.SYS_DVBS2X) {
                        if (sparam.IsMultistream != this.IsMultistream)
                            return false;
                            
                        // If both are multistream, check stream parameters
                        if (sparam.IsMultistream && this.IsMultistream) {
                            if (sparam.StreamId != this.StreamId ||
                                sparam.PLS_Code != this.PLS_Code ||
                                sparam.PLS_Mode != this.PLS_Mode)
                                return false;
                        }
                    }
                }
                
                return true;
            }

            return false;
        }

        public override void prepare(Gst.Element source) {
            log.debug("Prepare DVB-S%s Scanning Parameter", 
                     this.Delsys == DvbSrcDelsys.SYS_DVBS ? "" : 
                     (this.Delsys == DvbSrcDelsys.SYS_DVBS2 ? "2" : "2X"));
                     
            source.set("frequency", this.Frequency);
            source.set("symbol-rate", this.SymbolRate);
            
            switch (this.Polarization) {
                case SatellitePolarizationType.LINEAR_HORIZONTAL:
                    source.set("polarity", "H");
                    break;
                case SatellitePolarizationType.LINEAR_VERTICAL:
                    source.set("polarity", "V");
                    break;
                case SatellitePolarizationType.CIRCULAR_LEFT:
                    source.set("polarity", "L");
                    break;
                case SatellitePolarizationType.CIRCULAR_RIGHT:
                    source.set("polarity", "R");
                    break;
                default:
                    break;
            }
            
            source.set("code-rate-hp", this.InnerFEC);
            source.set("diseqc-source", this.DiseqcSource);
            source.set("delsys", this.Delsys);
            
            // For S2/S2X
            if (this.Delsys == DvbSrcDelsys.SYS_DVBS2 || 
                this.Delsys == DvbSrcDelsys.SYS_DVBS2X) {
                source.set("modulation", this.Modulation);
                
                // For S2X with multistream
                if (this.Delsys == DvbSrcDelsys.SYS_DVBS2X && this.IsMultistream) {
                    source.set("stream-id", this.StreamId);
                    source.set("pls-code", this.PLS_Code);
                    source.set("pls-mode", this.PLS_Mode);
                }
            }
        }

        public override string to_string() {
            string result;
            
            if (this.Delsys == DvbSrcDelsys.SYS_DVBS) {
                result = "DVBS:%f:%d:%u:%u:%s:%s".printf(
                    this.OrbitalPosition, this.DiseqcSource,
                    this.Frequency, this.SymbolRate, 
                    getCodeRateString(this.InnerFEC),
                    getPolarizationString(this.Polarization));
            }
            else if (this.Delsys == DvbSrcDelsys.SYS_DVBS2) {
                result = "DVBS2:%f:%d:%u:%u:%s:%s:%s".printf(
                    this.OrbitalPosition, this.DiseqcSource,
                    this.Frequency, this.SymbolRate, 
                    getCodeRateString(this.InnerFEC),
                    getPolarizationString(this.Polarization),
                    getModulationString(this.Modulation));
            }
            else { // S2X
                result = "DVBS2X:%f:%d:%u:%u:%s:%s:%s".printf(
                    this.OrbitalPosition, this.DiseqcSource,
                    this.Frequency, this.SymbolRate, 
                    getCodeRateString(this.InnerFEC),
                    getPolarizationString(this.Polarization),
                    getModulationString(this.Modulation));
                    
                if (this.IsMultistream) {
                    result += ":%u:%u:%u".printf(
                        this.StreamId, this.PLS_Code, this.PLS_Mode);
                }
            }
            
            return result;
        }
    }
}
