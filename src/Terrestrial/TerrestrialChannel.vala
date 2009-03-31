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

    public class TerrestrialChannel : Channel {
    
        public DvbSrcInversion Inversion {get; set;}
        public DvbSrcBandwidth Bandwidth {get; set;}
        public DvbSrcCodeRate CodeRateHP {get; set;}
        public DvbSrcCodeRate CodeRateLP {get; set;}
        public DvbSrcModulation Constellation {get; set;}
        public DvbSrcTransmissionMode TransmissionMode {get; set;}
        public DvbSrcGuard GuardInterval {get; set;}
        public DvbSrcHierarchy Hierarchy {get; set;}
        
        public override void setup_dvb_source (Gst.Element source) {
            source.set ("modulation", this.Constellation);
            source.set ("trans-mode", this.TransmissionMode);
            source.set ("code-rate-hp", this.CodeRateHP);
            source.set ("code-rate-lp", this.CodeRateLP);
            source.set ("guard", this.GuardInterval);
            source.set ("bandwidth", this.Bandwidth);
            source.set ("frequency", this.Frequency);
            source.set ("hierarchy", this.Hierarchy);
            source.set ("inversion", this.Inversion);
        }
        
        public override string to_string () {
            return "%s:%u:%s:%s:%s:%s:%s:%s:%s:%s:%u:%s:%u".printf(base.Name, base.Frequency,
                Utils.get_nick_from_enum (typeof(DvbSrcInversion),
                                          this.Inversion),
                Utils.get_nick_from_enum (typeof(DvbSrcBandwidth),
                                          this.Bandwidth),
                Utils.get_nick_from_enum (typeof(DvbSrcCodeRate),
                                          this.CodeRateHP),
                Utils.get_nick_from_enum (typeof(DvbSrcCodeRate),
                                          this.CodeRateLP),
                Utils.get_nick_from_enum (typeof(DvbSrcModulation),
                                          this.Constellation),
                Utils.get_nick_from_enum (typeof(DvbSrcTransmissionMode),
                                          this.TransmissionMode),
                Utils.get_nick_from_enum (typeof(DvbSrcGuard),
                                          this.GuardInterval),
                Utils.get_nick_from_enum (typeof(DvbSrcHierarchy),
                                          this.Hierarchy),
                base.VideoPID, base.get_audio_pids_string (), base.Sid);
        }
    
    }

}
