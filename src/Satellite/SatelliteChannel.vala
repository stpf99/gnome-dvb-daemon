
namespace DVB {

    public class SatelliteChannel : Channel {
        
        public string Polarization {get; set;}
        public uint SymbolRate {get; set;}
        public uint DiseqcSource {get; set;}
        
        public string to_string () {
            return "%s:%d:%s:%d:%d:%d:%d:%d".printf(base.Name, base.Frequency,
                this.Polarization, this.DiseqcSource, this.SymbolRate,
                base.VideoPID, base.AudioPID, base.Sid);
        }
    }

}    
