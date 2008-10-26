using GLib;

namespace DVB {

    public abstract class Channel : GLib.Object {

        public uint Sid {
            get { return this.sid; }
            set {
                this.sid = value;
                this.schedule = new DVB.Schedule (this);
            }
        }
        public string Name {get; set;}
        public uint TransportStreamId {get; set;}
        public string Network {get; set;}
        public uint? LogicalChannelNumber {get; set;}
        public uint VideoPID {get; set;}
        public uint AudioPID {get; set;}
        public uint Frequency {get; set;}
        public DVB.Schedule Schedule {
            get { return this.schedule; }
        }
        
        private DVB.Schedule schedule;
        private uint sid;
        
        public virtual bool is_valid () {
            return (this.Name != null && this.Frequency != 0 && this.Sid != 0);
        }
        
        
        /**
         * @source: Either dvbbasebin or dvbsrc
         *
         * Set properties of source so that the channel can be watched
         */
        public abstract void setup_dvb_source (Gst.Element source);
        public abstract string to_string ();
    }
    
}
