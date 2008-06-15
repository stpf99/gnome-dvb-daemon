
namespace DVB {

    public class SatelliteChannel : Channel {
        
        public string Polarization {get; set;}
        public uint SymbolRate {get; set;}
        public int DiseqcSource {get; set;}
        
        public override string to_string () {
            return "%s:%u:%s:%d:%u:%u:%u:%u".printf(base.Name, base.Frequency,
                this.Polarization, this.DiseqcSource, this.SymbolRate,
                base.VideoPID, base.AudioPID, base.Sid);
        }
    }

}    
