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
        
        public override string to_string () {
            return "%s:%u:%s:%s:%s:%s:%s:%s:%s:%s:%u:%u:%u".printf(base.Name, base.Frequency,
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
                base.VideoPID, base.AudioPID, base.Sid);
        }
    
    }

}
