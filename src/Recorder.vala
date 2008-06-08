using GLib;
using Gst;
using Gee;

namespace DVB {

    /**
     * This class is responsible for managing upcoming recordings and
     * already recorded items for a single device
     */
    public abstract class Recorder : GLib.Object {
    
        public signal void recording_started (uint32 timer_id);
        public signal void recording_finished (uint32 recording_id);
        
        /* Set in constructor of sub-classes */
        public DVB.Device Device { get; construct; }
        
        protected Element? pipeline;
        protected Recording active_recording;
        protected Timer? active_timer;
        
        private HashMap<uint32, Timer> timers;
        private static const int CHECK_TIMERS_INTERVAL = 5;
        
        construct {
            this.timers = new HashMap<uint, Timer> ();
            this.reset ();
        }
        
        /**
         * Setup dvbbasebin element with name "dvbbasebin"
         */
        protected abstract weak Element? get_dvbbasebin (Channel channel);
        
        /**
         * @channel: Channel number
         * @start_year: The year when the recording should start
         * @start_month: The month when recording should start
         * @start_day: The day when recording should start
         * @start_hour: The hour when recording should start
         * @start_minute: The minute when recording should start
         * @duration: How long the channel should be recorded (in minutes)
         * @returns: The new timer's id on success, or 0 if timer couldn't
         * be created
         * 
         * Add a new timer
         */
        public uint32 AddTimer (uint channel,
            int start_year, int start_month, int start_day,
            int start_hour, int start_minute, uint duration) {
            debug ("Adding new timer: channel: %d, start: %d-%d-%d %d:%d, duration: %d",
                channel, start_year, start_month, start_day,
                start_hour, start_minute, duration);
                
            if (!this.Device.Channels.contains (channel)) {
                debug ("No channel %d for device %d %d", channel,
                    this.Device.Adapter, this.Device.Frontend);
                return 0;
            }
            
            uint32 timer_id = RecordingsStore.get_instance ().get_next_id ();
                
            // TODO Get name for timer
            var new_timer = new Timer (timer_id, this.Device.Channels.get(channel),
                                       start_year, start_month, start_day,
                                       start_hour, start_minute, duration,
                                       null);
            lock (this.timers) {
                // Check for conflicts
                foreach (uint32 key in this.timers.get_keys()) {
                    if (this.timers.get(key).conflicts_with (new_timer)) {
                        debug ("Timer is conflicting with another timer: %s",
                            this.timers.get(key).to_string ());
                        return 0;
                    }
                }
                
                this.timers.set (timer_id, new_timer);
                               
                if (this.timers.size == 1) {
                    debug ("Creating new check timers");
                    Timeout.add_seconds (
                        CHECK_TIMERS_INTERVAL, this.check_timers
                    );
                }
            }
            return timer_id;
        }
        
        /**
         * @timer_id: The id of the timer you want to delete
         * @returns: TRUE on success
         *
         * Delete timer. If the id belongs to the currently
         * active timer recording is aborted.
         */
        public bool DeleteTimer (uint32 timer_id) {
            if (this.active_timer != null && this.IsTimerActive (timer_id)) {
                this.stop_current_recording ();
                return true;
            }
            
            bool val;
            lock (this.timers) {
                if (this.timers.contains (timer_id)) {
                    this.timers.remove (timer_id);
                    val = true;
                } else {
                    val = false;
                }
            }
            return val;
        }
        
        /**
         * dvb_recorder_GetTimers
         * @returns: A list of all timer ids
         */
        public uint32[] GetTimers () {
            uint32[] timer_arr;
            lock (this.timers) {
                timer_arr = new uint32[this.timers.size];
                
                int i=0;
                foreach (uint32 key in this.timers.get_keys()) {
                    timer_arr[i] = this.timers.get(key).Id;
                    i++;
                }
            }
        
            return timer_arr;
        }
        
        /**
         * @timer_id: Timer's id
         * @returns: An array of length 5, where index 0 = year, 1 = month,
         * 2 = day, 3 = hour and 4 = minute.
         */
        public uint[]? GetStartTime (uint32 timer_id) {
            uint[]? val = null;
            lock (this.timers) {
                if (this.timers.contains (timer_id))
                    val = this.timers.get(timer_id).get_start_time ();
            }
            return val;
        }
        
        /**
         * @timer_id: Timer's id
         * @returns: Same as dvb_recorder_GetStartTime()
         */
        public uint[]? GetEndTime (uint32 timer_id) {
            uint[]? val = null;
            lock (this.timers) {
                if (this.timers.contains (timer_id))
                    val = this.timers.get(timer_id).get_end_time ();
            }
            return val;
        }
        
        /**
         * @timer_id: Timer's id
         * @returns: Duration in seconds
         */
        public uint? GetDuration (uint32 timer_id) {
            uint? val = null;
            lock (this.timers) {
                if (this.timers.contains (timer_id))
                    val = this.timers.get(timer_id).Duration;
            }
            return val;
        }
        
        /**
         * @returns: The currently active timer
         * (i.e.currently active recording)
         */
        public uint32? GetActiveTimer () {
            uint32? val = null;
            lock (this.timers) {
                if (this.active_timer != null)
                val = this.active_timer.Id;
            }
            return val;
        }
        
        /**
         * @timer_id: Timer's id
         * @returns: TRUE if timer is currently active
         */
        public bool IsTimerActive (uint32 timer_id) {

            return (timer_id == this.active_timer.Id);
        }
        
        /**
         * @returns: TRUE if a timer is already scheduled in the given
         * period of time
         */
        public bool HasTimer (uint start_year, uint start_month,
        uint start_day, uint start_hour, uint start_minute, uint duration) {
            bool val = false;
            lock (this.timers) {
                foreach (uint32 key in this.timers.get_keys()) {
                    if (this.timers.get(key).is_in_range (start_year, start_month,
                    start_day, start_hour, start_minute, duration))
                        val = true;
                        break;
                }
            }
        
            return val;
        }
        
        protected void reset () {
            if (this.pipeline != null)
                this.pipeline.set_state (State.NULL);
            this.pipeline = null;
            this.active_timer = null;
        }
        
        protected void stop_current_recording () {
            this.active_recording.Length = Utils.difftime (Time.local (time_t ()),
                this.active_recording.StartTime);
        
            debug ("Stopping recording of channel %d after %d seconds",
                this.active_recording.ChannelSid, this.active_recording.Length);
            
            try {
                this.active_recording.save_to_disk ();
            } catch (Error e) {
                critical ("Could not save recording: %s", e.message);
            }
            
            RecordingsStore.get_instance().add (this.active_recording);
            
            this.recording_finished (this.active_recording.Id);
            this.reset ();
        }
        
        protected void start_recording (Timer timer) {
            debug ("Starting recording of channel %d", timer.Channel.Sid);
        
            Element dvbbasebin = this.get_dvbbasebin (timer.Channel);
            
            if (dvbbasebin == null) return;
            
            this.active_timer = timer;
            
            this.active_recording = new Recording ();
            this.active_recording.Id = timer.Id;
            this.active_recording.ChannelSid = timer.Channel.Sid;
            this.active_recording.StartTime = timer.get_start_time_time ();
            this.active_recording.Length = timer.Duration;
            
            if (!this.create_recording_dirs (timer.Channel)) return;
            
            this.pipeline = new Pipeline (
                "recording_%d".printf(this.active_recording.ChannelSid));
            
            weak Gst.Bus bus = this.pipeline.get_bus();
            bus.add_signal_watch();
            bus.message += this.bus_watch_func;
                
            dvbbasebin.pad_added += this.on_dvbbasebin_pad_added;
            dvbbasebin.set ("program-numbers",
                            this.active_recording.ChannelSid.to_string());
            dvbbasebin.set ("adapter", this.Device.Adapter);
            dvbbasebin.set ("frontend", this.Device.Frontend);
            
            Element filesink = ElementFactory.make ("filesink", "sink");
            filesink.set ("location", this.active_recording.Location);
            ((Bin) this.pipeline).add_many (dvbbasebin, filesink);
            
            this.pipeline.set_state (State.PLAYING);
            
            this.recording_started (timer.Id);
        }
        
        /**
         * Create directories and set location of recording
         *
         * @returns: TRUE on success
         */
        protected bool create_recording_dirs (Channel channel) {
            Recording rec = this.active_recording;
            uint[] start = rec.get_start ();
            string dirname = "%s/%s/%d-%d-%d_%d-%d".printf (
                this.Device.RecordingsDirectory.get_path (),
                Utils.remove_nonalphanums (channel.Name), start[0], start[1],
                start[2], start[3], start[4], start[5]);
                
            File dir = File.new_for_path (dirname);
            
            if (!dir.query_exists (null)) {
                debug ("Creating %s", dirname);
                try {
                    Utils.mkdirs (dir);
                } catch (Error e) {
                    error (e.message);
                    return false;
                }
            }
            
            string attributes = "%s,%s".printf (FILE_ATTRIBUTE_STANDARD_TYPE,
                                                FILE_ATTRIBUTE_ACCESS_CAN_WRITE);
            FileInfo info;
            try {
                info = dir.query_info (attributes, 0, null);
            } catch (Error e) {
                critical (e.message);
                return false;
            }
            
            if (info.get_attribute_uint32 (FILE_ATTRIBUTE_STANDARD_TYPE)
                != FileType.DIRECTORY) {
                critical ("%s is not a directory", dirname);
                return false;
            }
            
            if (!info.get_attribute_boolean (FILE_ATTRIBUTE_ACCESS_CAN_WRITE)) {
                critical ("Cannot write to %s", dirname);
                return false;
            }
            
            this.active_recording.Location = "%s/001.ts".printf (dirname);
            
            return true;
        }
        
        private void on_dvbbasebin_pad_added (Gst.Element elem, Gst.Pad pad) {
            debug ("Pad %s added", pad.get_name());
        
            string sid = this.active_recording.ChannelSid.to_string();
            string program = "program_%s".printf(sid);
            if (pad.get_name() == program) {
                Element sink = ((Bin) this.pipeline).get_by_name ("sink");
                Pad sinkpad = sink.get_pad ("sink");
                
                pad.link (sinkpad);
            }
        }
        
        private void bus_watch_func (Gst.Bus bus, Gst.Message message) {
            switch (message.type) {
                case Gst.MessageType.ELEMENT:
                    if (message.structure.get_name() == "dvb-read-failure") {
                        critical ("Could not read from DVB device");
                        this.reset ();
                    }
                break;
                
                case Gst.MessageType.ERROR:
                    Error gerror;
                    string debug;
                    message.parse_error (out gerror, out debug);
                    critical ("%s %s", gerror.message, debug);
                    this.stop_current_recording ();
                break;
                
                default:
                break;
            }
        }
        
        private bool check_timers () {
            debug ("Checking timers");
            
            if (this.active_timer != null && this.active_timer.is_end_due()) {
                this.stop_current_recording ();
            }
            
            bool val;
            // Store items we want to delete in here
            SList<uint32> removeable_items = new SList<uint32> ();
            lock (this.timers) {
                foreach (uint32 key in this.timers.get_keys()) {
                    Timer timer = this.timers.get (key);
                    
                    debug ("Checking timer: %s", timer.to_string());
                    
                    if (timer.is_start_due()) {
                        this.start_recording (timer);
                        removeable_items.prepend (key);
                    } else if (timer.has_expired()) {
                        debug ("Removing expired timer: %s", timer.to_string());
                        removeable_items.prepend (key);
                    }
                }
                
                // Delete items from this.timers
                for (int i=0; i<removeable_items.length(); i++) {
                    this.timers.remove (removeable_items.nth_data (i));
                }
                
                if (this.timers.size == 0 && this.active_timer == null) {
                    // We don't have any timers and no recording is in progress
                    debug ("No timers left and no recording in progress");
                    val = false;
                } else {
                    // We still have timers
                    debug ("%d timers and %d active recordings left",
                        this.timers.size,
                        (this.active_timer == null) ? 0 : 1);
                    val = true;
                }
                
            }
            return val;
        }
    }

}
