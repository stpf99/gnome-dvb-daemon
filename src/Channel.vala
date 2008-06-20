using GLib;

namespace DVB {

    public abstract class Channel : GLib.Object {

        public uint Sid {get; set;}
        public string Name {get; set;}
        public uint TransportStreamId {get; set;}
        public string Network {get; set;}
        public uint? LogicalChannelNumber {get; set;}
        public uint VideoPID {get; set;}
        public uint AudioPID {get; set;}
        public uint Frequency {get; set;}
        
        private Sequence<Event> schedule;
        
        construct {
            this.schedule = new Sequence<Event> (null);
        }
        
        /**
         * @source: Either dvbbasebin or dvbsrc
         *
         * Set properties of source so that the channel can be watched
         */
        public abstract void setup_dvb_source (Gst.Element source);
        public abstract string to_string ();
        
        public void insert_event (Event# event) {
            // XXX Vala bug
            //this.schedule.insert_sorted (#event, Event.compare);
        }
    }
    
}
