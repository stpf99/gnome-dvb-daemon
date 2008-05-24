using GLib;

namespace DVB {

    public class TerrestrialChannel : Channel {
    
        public DvbSrcInversion Inversion {get; set;}
        public DvbSrcBandwidth Bandwith {get; set;}
        public DvbSrcCodeRate CodeRateHP {get; set;}
        public DvbSrcCodeRate CodeRateLP {get; set;}
        public string Constellation {get; set;}
        public DvbSrcTransmissionMode TransmissionMode {get; set;}
        public DvbSrcGuard GuardInterval {get; set;}
        public DvbSrcHierarchy Hierarchy {get; set;}
        
        public string to_string () {
            EnumClass eclass = (EnumClass)typeof(DvbSrcTransmissionMode).class_ref();
        
            return "%s:%d:%s:%s:%d:%d:%d".printf(base.Name, base.Frequency,
                this.Constellation,
                eclass.get_value(this.TransmissionMode).value_nick,
                base.VideoPID, base.AudioPID, base.Sid);
        }
    
    }

}
