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

    public class CableChannel : Channel {
    
        public DvbSrcInversion Inversion {get; set;}
        public uint SymbolRate {get; set;}
        public DvbSrcCodeRate CodeRate {get; set;}
        public DvbSrcModulation Modulation {get; set;}

        public CableChannel.without_schedule () {
            Channel.without_schedule ();
        }
        
        public override void setup_dvb_source (Gst.Element source) {
            source.set ("frequency", this.Frequency);
            source.set ("inversion", this.Inversion);
            source.set ("symbol-rate", this.SymbolRate);
            source.set ("code-rate-hp", this.CodeRate);
            source.set ("modulation", this.Modulation);
        }
        
        public override string to_string () {
            return "%s:%u:%s:%u:%s:%s:%u:%s:%u".printf(base.Name, base.Frequency,
                Utils.get_nick_from_enum (typeof(DvbSrcInversion),
                                          this.Inversion),
                this.SymbolRate * 1000,
                Utils.get_nick_from_enum (typeof(DvbSrcCodeRate),
                                          this.CodeRate),
                Utils.get_nick_from_enum (typeof(DvbSrcModulation),
                                          this.Modulation),
                base.VideoPID, base.get_audio_pids_string (), base.Sid);
        }
    
    }
    
}
