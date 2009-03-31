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


namespace DVB {

    public class SatelliteChannel : Channel {
        
        public string Polarization {get; set;}
        public uint SymbolRate {get; set;}
        public int DiseqcSource {get; set;}
        
        public override bool is_valid () {
            return (base.is_valid () && this.SymbolRate != 0
                && (this.Polarization == "v" || this.Polarization == "h"));
        }
        
        public override void setup_dvb_source (Gst.Element source) {
            source.set ("frequency", this.Frequency);
            source.set ("polarity", this.Polarization);
            source.set ("symbol-rate", this.SymbolRate);
            source.set ("diseqc-source", this.DiseqcSource);
        }
        
        public override string to_string () {
            return "%s:%u:%s:%d:%u:%u:%s:%u".printf(base.Name, base.Frequency,
                this.Polarization, this.DiseqcSource, this.SymbolRate,
                base.VideoPID, base.get_audio_pids_string (), base.Sid);
        }
    }

}
