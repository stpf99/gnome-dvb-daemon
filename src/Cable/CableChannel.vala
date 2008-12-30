
namespace DVB {

    public class CableChannel : Channel {
    
        public DvbSrcInversion Inversion {get; set;}
        public uint SymbolRate {get; set;}
        public DvbSrcCodeRate CodeRate {get; set;}
        public DvbSrcModulation Modulation {get; set;}
        
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
                this.SymbolRate,
                Utils.get_nick_from_enum (typeof(DvbSrcCodeRate),
                                          this.CodeRate),
                Utils.get_nick_from_enum (typeof(DvbSrcModulation),
                                          this.Modulation),
                base.VideoPID, base.get_audio_pids_string (), base.Sid);
        }
    
    }
    
}
