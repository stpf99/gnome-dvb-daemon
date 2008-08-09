using GLib;
using Gee;

namespace DVB {

    public class EPGScanner : GLib.Object {
    
        private static const int CHECK_EIT_INTERVAL = 120*60;
        // how long to wait for EIT data for each channel in seconds
        private static const int WAIT_FOR_EIT_DURATION = 10;
        
        public DVB.DeviceGroup DeviceGroup {get; set;}
        
        private Gst.Element? pipeline;
        private Queue<Channel> channels;
        
        construct {
            this.channels = new Queue<Channel> ();
        }
        
        /**
         * @device: The device where EPG should be collected from
         */
        public EPGScanner (DVB.DeviceGroup device) {
            this.DeviceGroup = device;
        }
        
        /**
         * Stop collecting EPG data
         */
        public void stop () {
            if (this.pipeline != null)
                this.pipeline.set_state (Gst.State.NULL);
            this.pipeline = null;
            this.channels.clear ();
        }
        
        /**
         * Start collection EPG data for all channels
         */
        public void start () {
            // TODO scan all channels?
            HashSet<uint> unique_frequencies = new HashSet<uint> ();
            foreach (Channel c in this.DeviceGroup.Channels) {
                uint freq = c.Frequency;
                if (!unique_frequencies.contains (freq)) {
                    unique_frequencies.contains (freq);
                    this.channels.push_tail (c);
                }
            }
            
            DVB.Device? device = this.DeviceGroup.get_next_free_device ();
            if (device == null) return;
        
            // pids: 0=pat, 16=nit, 17=sdt, 18=eit
            try {
                this.pipeline = Gst.parse_launch (
                    "dvbsrc name=dvbsrc adapter=%u frontend=%u ".printf(
                    device.Adapter, device.Frontend)
                    + "pids=0:16:17:18 stats-reporting-interval=0 "
                    + "! mpegtsparse ! fakesink silent=true");
            } catch (Error e) {
                error (e.message);
                return;
            }
            
            weak Gst.Bus bus = this.pipeline.get_bus ();
            bus.add_signal_watch ();
            bus.message += this.bus_watch_func;
            
            Timeout.add_seconds (WAIT_FOR_EIT_DURATION,
                this.scan_new_frequency);
            
            return;
        }
        
        /**
         * Scan the next frequency for EPG data
         */
        private bool scan_new_frequency () {
            if (this.channels.is_empty ()) {
                this.stop ();
                return false;
            }
            
            Channel channel = this.channels.pop_head ();
            channel.Schedule.remove_expired_events ();
            
            debug ("Scanning channel %s", channel.to_string ());
            
            this.pipeline.set_state (Gst.State.READY);
            
            Gst.Element dvbsrc = ((Gst.Bin)this.pipeline).get_by_name ("dvbsrc");
            channel.setup_dvb_source (dvbsrc);
            
            this.pipeline.set_state (Gst.State.PLAYING);
            
            return true;
        }
        
        private void bus_watch_func (Gst.Bus bus, Gst.Message message) {
            switch (message.type) {
                case Gst.MessageType.ELEMENT:
                    if (message.structure.get_name() == "dvb-read-failure") {
                        critical ("Could not read from DVB device");
                        this.stop ();
                    } else if (message.structure.get_name() == "eit") {
                        this.on_eit_structure (message.structure);
                    }
                break;
                
                case Gst.MessageType.ERROR:
                    Error gerror;
                    string debug;
                    message.parse_error (out gerror, out debug);
                    critical ("%s %s", gerror.message, debug);
                    this.stop ();
                break;
                
                default:
                break;
            }
        }
        
        private void on_eit_structure (Gst.Structure structure) {
            Gst.Value events = structure.get_value ("events");
            
            if (!(events.holds (Gst.Value.list_get_type ())))
                return;
            
            uint size = events.list_get_size ();
            Gst.Value val;
            weak Gst.Structure event;
            // Iterate over events
            for (uint i=0; i<size; i++) {
                val = events.list_get_value (i);
                event = val.get_structure ();
                
                uint sid = get_uint_val (structure, "service-id");
                Channel channel = this.DeviceGroup.Channels.get (sid);
                if (channel == null) {
                    warning ("Could not find channel %u for this device", sid);
                    return;
                }
                
                uint event_id = get_uint_val (event, "event-id");
                
                if (!channel.Schedule.contains (event_id)) {
                    var event_class = new Event ();
                    event_class.id = event_id;
                    event_class.year = get_uint_val (event, "year");
                    event_class.month = get_uint_val (event, "month");
                    event_class.day = get_uint_val (event, "day");
                    event_class.hour = get_uint_val (event, "hour");
                    event_class.minute = get_uint_val (event, "minute");
                    event_class.second = get_uint_val (event, "second");
                    event_class.duration = get_uint_val (event, "duration");
                    event_class.running_status = get_uint_val (event, "running-status");
                    event_class.name = event.get_string ("name"); 
                    event_class.description = event.get_string ("description");
                    event_class.extended_description = event.get_string ("extended-text");
                    bool free_ca;
                    event.get_boolean ("free-ca-mode", out free_ca);
                    event_class.free_ca_mode = free_ca;
                    
                    Gst.Value components = event.get_value ("components");
                    uint components_len = components.list_get_size ();
                    
                    Gst.Value comp_val;
                    weak Gst.Structure component;
                    for (uint j=0; j<components_len; j++) {
                        comp_val = components.list_get_value (j);
                        component = comp_val.get_structure ();
                        
                        if (component.get_name () == "audio") {
                            var audio = new Event.AudioComponent ();
                            audio.type = component.get_string ("type");
                            
                            event_class.audio_components.append (audio);
                        } else if (component.get_name () == "video") {
                            var video = new Event.VideoComponent ();
                            
                            bool highdef;
                            component.get_boolean ("high-definition", out highdef);
                            video.high_definition = highdef;
                            
                            video.aspect_ratio = component.get_string ("high-definition");
                            
                            int freq;
                            component.get_int ("frequency", out freq);
                            video.frequency = freq;
                            
                            event_class.video_components.append (video);
                        } else if (component.get_name () == "teletext") {
                            var teletext = new Event.TeletextComponent ();
                            teletext.type = component.get_string ("type");
                            
                            event_class.teletext_components.append (teletext);
                        }
                    }
                    
                    debug ("Adding new event: %s", event_class.to_string ());
                    channel.Schedule.add (#event_class);
                   
                }
            }
        }
        
        private static uint get_uint_val (Gst.Structure structure, string name) {
            uint val;
            structure.get_uint (name, out val);
            return val;
        }
    }
}
