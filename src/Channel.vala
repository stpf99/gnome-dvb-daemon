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
        public Gee.List<uint> AudioPIDs {get; set;}
        public uint Frequency {get; set;}
        public bool Scrambled {get; set;}
        public DVB.Schedule Schedule {
            get { return this.schedule; }
        }
        
        private DVB.Schedule schedule;
        private uint sid;
        
        construct {
            this.AudioPIDs = new Gee.ArrayList<uint> ();
        }
        
        public string get_audio_pids_string () {
            StringBuilder apids = new StringBuilder ();
            int i = 1;
            foreach (uint pid in this.AudioPIDs) {
                if (i == this.AudioPIDs.size)
                    apids.append (pid.to_string ());
                else
                    apids.append ("%u,".printf (pid));
                i++;
            }
            
            return apids.str;
        }
        
        public virtual bool is_valid () {
            return (this.Name != null && this.Frequency != 0&& this.Sid != 0
                && (this.VideoPID != 0 || this.AudioPIDs.size != 0));
        }
        
        /**
         * @returns: TRUE if both channels are part of the same
         * transport stream (TS).
         *
         * Channels that are part of the same TS can be viewed/recorded
         * at the same time with a single device.
         */
        public virtual bool on_same_transport_stream (Channel channel) {
            return (this.Frequency == channel.Frequency);
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
