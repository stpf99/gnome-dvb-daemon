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


namespace DVB {

    public class SatelliteChannel : Channel {

        public string Polarization {get; set;}
        public uint SymbolRate {get; set;}
        public int DiseqcSource {get; set;}

        public SatelliteChannel (uint group_id) {
            base (group_id);
        }

        public SatelliteChannel.without_schedule () {
            Channel.without_schedule ();
        }

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
            return "%s:%u:%s:%d:%u:%u:%s:%u".printf(this.Name, this.Frequency,
                this.Polarization, this.DiseqcSource, this.SymbolRate,
                this.VideoPID, this.get_audio_pids_string (), this.Sid);
        }
    }

}
