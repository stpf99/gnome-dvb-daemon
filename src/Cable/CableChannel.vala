
namespace DVB {

    public class CableChannel : Channel {
    
        public DvbSrcInversion Inversion {get; set;}
        public uint SymbolRate {get; set;}
        public DvbSrcCodeRate CodeRate {get; set;}
        public DvbSrcModulation Modulation {get; set;}
        
        public override string to_string () {
            return "%s:%d:%s:%d:%s:%s:%d:%d:%d".printf(base.Name, base.Frequency,
                Utils.get_nick_from_enum (typeof(DvbSrcInversion),
                                          this.Inversion),
                this.SymbolRate,
                Utils.get_nick_from_enum (typeof(DvbSrcCodeRate),
                                          this.CodeRate),
                Utils.get_nick_from_enum (typeof(DvbSrcModulation),
                                          this.Modulation),
                base.VideoPID, base.AudioPID, base.Sid);
        }
    
    }
    
}
