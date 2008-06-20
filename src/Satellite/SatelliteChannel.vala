
namespace DVB {

    public class SatelliteChannel : Channel {
        
        public string Polarization {get; set;}
        public uint SymbolRate {get; set;}
        public int DiseqcSource {get; set;}
        
        public override void setup_dvb_source (Gst.Element source) {
            source.set ("frequency", this.Frequency);
            source.set ("polarity", this.Polarization);
            source.set ("symbol-rate", this.SymbolRate);
            source.set ("diseqc-source", this.DiseqcSource);
        }
        
        public override string to_string () {
            return "%s:%u:%s:%d:%u:%u:%u:%u".printf(base.Name, base.Frequency,
                this.Polarization, this.DiseqcSource, this.SymbolRate,
                base.VideoPID, base.AudioPID, base.Sid);
        }
    }

}    
