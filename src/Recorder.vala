using GLib;
using Gst;
using Gee;

namespace DVB {

    /**
     * This class does the actual recording for a single device.
     * It record more than one channel, if the channels are part
     * of the same transport stream
     */
    public class RecordingThread : GLib.Object {
    
        private static const string DVBBASEBIN_NAME = "dvbbasebin";
        
        public signal void recording_stopped (Recording rec, Timer timer);
        public signal void recording_aborted ();
    
        public Device device {get; construct;}
        public EPGScanner? epgscanner {get; construct;}
        public uint count {
            get { return this.recordings.size; }
        }
        
        private Element? pipeline;
        private string? sid;
        // Maps timer id to Recording
        private Map<uint, Recording> recordings;
    
        construct {
            this.recordings = new HashMap<uint, Recording> ();
        }
    
        public RecordingThread (Device device, EPGScanner? epgscanner) {
            this.device = device;
            this.epgscanner = epgscanner;
        }
        
        private void reset () {
            if (this.pipeline != null) {
                debug ("Stopping pipeline");
                this.pipeline.set_state (State.NULL);
            }
            this.pipeline = null;
            this.recordings.clear ();
        }
        
        public void stop_recording (Timer timer) {
            string sink_name = "sink_%u".printf (timer.ChannelSid);
            Element sink = ((Bin) this.pipeline).get_by_name (sink_name);
            string location;
            sink.get ("location", out location);
            
            if (this.count > 1) {
                // Still have other recordings,
                // just remove sid from program-numbers
            
                Element dvbbasebin = ((Bin) this.pipeline).get_by_name (
                    DVBBASEBIN_NAME);
                if (dvbbasebin == null) {
                    critical ("No element with name %s", DVBBASEBIN_NAME);
                    return;
                }
                
                string programs;
                dvbbasebin.get ("program-numbers", out programs);
                string[] programs_arr = programs.split (":");
                
                string channel_sid_string = timer.ChannelSid.to_string ();
                
                SList<string> new_programs_list = new SList<string> ();
                for (int i=0; i<programs_arr.length; i++) {
                    string val = programs_arr[i];
                    if (val != channel_sid_string)
                        new_programs_list.prepend (val);
                }
                
                StringBuilder new_programs = new StringBuilder (new_programs_list.nth_data (0));
                for (int i=1; i<new_programs_list.length (); i++) {
                    new_programs.append (":" + new_programs_list.nth_data (i));
                }
                
                this.pipeline.set_state (State.PAUSED);
                dvbbasebin.set ("program-numbers", new_programs.str);
                this.pipeline.set_state (State.PLAYING);
            }
            
            Recording rec = this.recordings.get (timer.Id);
            rec.Length = Utils.difftime (Time.local (time_t ()),
                rec.StartTime);
            try {
                rec.save_to_disk ();
            } catch (Error e) {
                critical ("Could not save recording: %s", e.message);
            }
            
            this.recordings.remove (timer.Id);
            
            if (this.count == 0) {
                // No more active recordings
                this.reset ();
            }
            
            this.recording_stopped (rec, timer);
        }
        
        public void start_recording (Timer timer, File location) {
            uint channel_sid = timer.ChannelSid;
            this.sid = channel_sid.to_string ();
            string sink_name = "sink_%u".printf (channel_sid);
        
            debug ("Starting recording of channel %u",
                channel_sid);
            
            if (this.pipeline == null) {
                // Setup new pipeline
            
                Gst.Element dvbbasebin = ElementFactory.make ("dvbbasebin",
                    DVBBASEBIN_NAME);
                DVB.Channel channel = this.device.Channels.get (
                    channel_sid);
                channel.setup_dvb_source (dvbbasebin);
                
                this.pipeline = new Pipeline ("recording");
                
                weak Gst.Bus bus = this.pipeline.get_bus();
                bus.add_signal_watch();
                bus.message += this.bus_watch_func;
                    
                dvbbasebin.pad_added += this.on_dvbbasebin_pad_added;
                dvbbasebin.set ("program-numbers", this.sid);
                dvbbasebin.set ("adapter", this.device.Adapter);
                dvbbasebin.set ("frontend", this.device.Frontend);
                
                // don't use add_many because of problems with ownership transfer    
                ((Bin) this.pipeline).add (dvbbasebin);
                
                string queue_name = "queue_%u".printf (channel_sid);
                Element? queue = this.add_new_queue (queue_name);
                Element? filesink = this.add_new_filesink (sink_name,
                    location.get_path ());
                    
                if (queue != null && filesink != null) {
                    if (!queue.link (filesink)) {
                        critical ("Could not link queue and filesink");
                        return;
                    }
                    
                    debug ("Starting pipeline");
                    this.pipeline.set_state (State.PLAYING);
                }
            } else {
                // Use current pipeline and add new filesink
            
                Element dvbbasebin = ((Bin) this.pipeline).get_by_name (DVBBASEBIN_NAME);
                if (dvbbasebin == null) {
                    critical ("No element with name %s", DVBBASEBIN_NAME);
                    return;
                }
                
                string queue_name = "queue_%u".printf (channel_sid);
                Element? queue = this.add_new_queue (queue_name);
                Element? filesink = this.add_new_filesink (
                    sink_name, location.get_path ());
                    
                if (queue != null && filesink != null) {
                    if (!queue.link (filesink)) {
                        critical ("Could not link queue and filesink");
                        return;
                    }
                
                    string programs;
                    this.pipeline.set_state (State.PAUSED);
                    dvbbasebin.get ("program-numbers", out programs);
                    dvbbasebin.set ("program-numbers", "%s:%s".printf (programs, this.sid) );
                    this.pipeline.set_state (State.PLAYING);
                }
            }
            
            Recording recording = new Recording ();
            recording.Name = null;
            recording.Description = null;
            recording.Id = timer.Id;
            recording.ChannelSid = timer.ChannelSid;
            recording.StartTime =
                timer.get_start_time_time ();
            recording.Location = location;
            
            this.recordings.set (recording.Id, recording);
        }
        
        private Element? add_new_filesink (string sink_name, string location) {
            Element filesink = ElementFactory.make ("filesink", sink_name);
            filesink.set ("location", location);
            if (!((Bin) this.pipeline).add (filesink)) {
                critical ("Could not add filesink sink %s", sink_name);
                return null;
            }
            debug ("Filesink %s added to pipeline", sink_name);
            return filesink;
        }
        
        private Element? add_new_queue (string queue_name) {
            Element queue = ElementFactory.make ("queue", queue_name);
            
            queue.set ("max-size-buffers", 0);
            //queue.set ("max-size-time", 0);
            
            if (!((Bin) this.pipeline).add (queue)) {
                critical ("Could not add queue element to pipeline %s",
                    queue_name);
                return null;
            }
            debug ("Queue %s added to pipeline", queue_name);
            return queue;
        }
        
        private void on_dvbbasebin_pad_added (Gst.Element elem, Gst.Pad pad) {
            debug ("Pad %s added", pad.get_name());
            
            string program = "program_" + this.sid;
            if (pad.get_name() == program) {
                string sink_name = "queue_" + this.sid;
                Element sink = ((Bin) this.pipeline).get_by_name (sink_name);
                if (sink == null) {
                    critical ("No element with name %s", sink_name);
                } else {
                    Pad sinkpad = sink.get_pad ("sink");
                    
                    PadLinkReturn rc = pad.link (sinkpad);
                    if (rc != PadLinkReturn.OK) {
                        critical ("Could not link pads");
                    }
                    debug ("Src pad %s linked with sink pad %s",
                        program, sink_name);
                }
            }
            
            this.sid = null;
        }
        
        private void bus_watch_func (Gst.Bus bus, Gst.Message message) {
            switch (message.type) {
                case Gst.MessageType.ELEMENT:
                    string structure_name = message.structure.get_name();
                    if (structure_name == "dvb-read-failure") {
                        critical ("Could not read from DVB device");
                        this.reset ();
                        this.recording_aborted ();
                    } else if (structure_name == "eit") {
                        this.on_eit_structure (message.structure);
                    }
                break;
                
                case Gst.MessageType.ERROR:
                    Error gerror;
                    string debug_text;
                    message.parse_error (out gerror, out debug_text);
                    
                    critical (gerror.message);
                    critical (debug_text);
                        
                    this.reset ();
                    this.recording_aborted ();
                break;
                
                default:
                break;
            }
        }
        
        private void on_eit_structure (Gst.Structure structure) {
            if (this.epgscanner != null)
                this.epgscanner.on_eit_structure (structure);
            
            // Find name and description for recordings
            foreach (Recording rec in this.recordings.get_values ()) {
                if (rec.Name == null) {
                    Channel chan = this.device.Channels.get (rec.ChannelSid);
                    Schedule sched = chan.Schedule;
                    
                    Event? event = sched.get_running_event ();
                    if (event != null) {
                        debug ("Found running event for active recording");
                        rec.Name = event.name;
                        rec.Description = event.description;
                    }
                }
            }
        }
        
    }

    /**
     * This class is responsible for managing upcoming recordings and
     * already recorded items for a single group of devices
     */
    public class Recorder : GLib.Object, IDBusRecorder {
    
        /* Set in constructor of sub-classes */
        public DVB.DeviceGroup DeviceGroup { get; construct; }
        
        protected Map<Timer, RecordingThread> active_recording_threads;
        // Contains timer ids
        protected Set<uint32> active_timers;
        
        private bool have_check_timers_timeout;
        // Maps timer id to timer
        private HashMap<uint32, Timer> timers;
        
        private static const int CHECK_TIMERS_INTERVAL = 5;
        
        construct {
            this.active_recording_threads = new HashMap<Timer, RecordingThread> ();
            this.active_timers = new HashSet<uint32> ();
            this.timers = new HashMap<uint, Timer> ();
            this.have_check_timers_timeout = false;
            RecordingsStore.get_instance ().restore_from_dir (
                this.DeviceGroup.RecordingsDirectory);
        }
        
        public Recorder (DVB.DeviceGroup dev) {
            this.DeviceGroup = dev;
        }
        
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
            debug ("Adding new timer: channel: %u, start: %d-%d-%d %d:%d, duration: %u",
                channel, start_year, start_month, start_day,
                start_hour, start_minute, duration);
                
            if (!this.DeviceGroup.Channels.contains (channel)) {
                debug ("No channel %u for device group %u", channel,
                    this.DeviceGroup.Id);
                return 0;
            }
            
            uint32 timer_id = RecordingsStore.get_instance ().get_next_id ();
                
            // TODO Get name for timer
            var new_timer = new Timer (timer_id,
                                       this.DeviceGroup.Channels.get(channel).Sid,
                                       start_year, start_month, start_day,
                                       start_hour, start_minute, duration,
                                       null);
            return this.add_timer (new_timer);
        }
        
        public uint32 add_timer (Timer new_timer) {
            if (new_timer.has_expired()) return 0;
            
            uint32 timer_id = 0;
            lock (this.timers) {
                bool has_conflict = false;
                int conflict_count = 0;
                
                // Check for conflicts
                foreach (uint32 key in this.timers.get_keys()) {
                    if (this.timers.get(key).conflicts_with (new_timer)) {
                        conflict_count++;
                        
                        if (conflict_count >= this.DeviceGroup.size) {
                            debug ("Timer is conflicting with another timer: %s",
                                this.timers.get(key).to_string ());
                            has_conflict = true;
                            break;
                        }
                    }
                }
                
                if (!has_conflict) {
                    this.timers.set (new_timer.Id, new_timer);
                    GConfStore.get_instance ().add_timer_to_device_group (new_timer,
                        this.DeviceGroup);
                    this.changed (new_timer.Id, ChangeType.ADDED);
                                   
                    if (this.timers.size == 1 && !this.have_check_timers_timeout) {
                        debug ("Creating new check timers");
                        Timeout.add_seconds (
                            CHECK_TIMERS_INTERVAL, this.check_timers
                        );
                        this.have_check_timers_timeout = true;
                    }
                    
                    timer_id = new_timer.Id;
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
            if (this.IsTimerActive (timer_id)) {
                // Abort recording
                Timer timer = this.timers.get (timer_id);
                this.stop_recording (timer);
                return true;
            }
            
            bool val;
            lock (this.timers) {
                if (this.timers.contains (timer_id)) {
                    this.timers.remove (timer_id);
                    GConfStore.get_instance ().remove_timer_from_device_group (
                        timer_id, this.DeviceGroup);
                    this.changed (timer_id, ChangeType.DELETED);
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
        public uint32[] GetStartTime (uint32 timer_id) {
            uint32[] val;
            lock (this.timers) {
                if (this.timers.contains (timer_id))
                    val = this.timers.get(timer_id).get_start_time ();
                else
                    val = new uint[] {};
            }
            return val;
        }
        
        /**
         * @timer_id: Timer's id
         * @returns: Same as dvb_recorder_GetStartTime()
         */
        public uint[] GetEndTime (uint32 timer_id) {
            uint[] val;
            lock (this.timers) {
                if (this.timers.contains (timer_id))
                    val = this.timers.get(timer_id).get_end_time ();
                else
                    val = new uint[] {};
            }
            return val;
        }
        
        /**
         * @timer_id: Timer's id
         * @returns: Duration in seconds or 0 if there's no timer with
         * the given id
         */
        public uint GetDuration (uint32 timer_id) {
            uint val = 0;
            lock (this.timers) {
                if (this.timers.contains (timer_id))
                    val = this.timers.get(timer_id).Duration;
            }
            return val;
        }
        
        /**
         * @timer_id: Timer's id
         * @returns: The name of the channel the timer belongs to or an
         * empty string when a timer with the given id doesn't exist
         */
        public string GetChannelName (uint32 timer_id) {
            string name = "";
            lock (this.timers) {
                if (this.timers.contains (timer_id)) {
                    Timer t = this.timers.get (timer_id);
                    name = this.DeviceGroup.Channels.get (t.ChannelSid).Name;
                }
            }
            return name;
        }
        
        /**
         * @returns: The currently active timers
         */
        public uint32[] GetActiveTimers () {
            uint32[] val = new uint32[this.active_timers.size];
            
            int i=0;
            foreach (uint32 timer_id in this.active_timers) {
                Timer timer = this.timers.get (timer_id);
                val[i] = timer.Id;
                i++;
            }
            return val;
        }
        
        /**
         * @timer_id: Timer's id
         * @returns: TRUE if timer is currently active
         */
        public bool IsTimerActive (uint32 timer_id) {
            return this.active_timers.contains (timer_id);
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
        
        /**
         * Start recording of specified timer
         */
        protected void start_recording (Timer timer) {
            Channel channel = this.DeviceGroup.Channels.get (timer.ChannelSid);
            
            File? location = this.create_recording_dirs (channel,
                timer.get_start_time ());
            if (location == null) return;
            
            bool create_new_thread = true;
            RecordingThread recthread;
            // Check if there's already an active recording on the
            // same transport stream
            foreach (uint32 timer_id in this.active_timers) {
                Timer other_timer = this.timers.get (timer_id);
                Channel other_channel =
                    this.DeviceGroup.Channels.get (other_timer.ChannelSid);
                // FIXME
                if (other_channel.Frequency == channel.Frequency) {
                    debug ("Using already active RecordingThread");
                    recthread = this.active_recording_threads.get (other_timer);
                    create_new_thread = false;
                }
            }
        
            if (create_new_thread) {
                debug ("Creating new RecordingThread");
                
                // Stop epgscanner before starting recording
                EPGScanner? epgscanner = Manager.get_instance ().get_epg_scanner (
                    this.DeviceGroup);
                if (epgscanner != null) epgscanner.stop ();
                
                DVB.Device? free_device = this.DeviceGroup.get_next_free_device ();
                if (free_device == null) {
                    critical ("All devices are busy");
                    return;
                }
                
                recthread = new RecordingThread (free_device, epgscanner);
                recthread.recording_stopped += this.on_recording_stopped;
                // FIXME
                //recthread.recording_aborted += this.on_recording_aborted;
            }
            recthread.start_recording (timer, location);
            
            this.active_timers.add (timer.Id);
            this.active_recording_threads.set (timer, recthread);
            
            this.recording_started (timer.Id);
        }
        
        /**
         * Stop recording of specified timer
         */
        protected void stop_recording (Timer timer) {
            RecordingThread recthread =
                this.active_recording_threads.get (timer);
           
            recthread.stop_recording (timer);
            
            uint32 timer_id = timer.Id;
            this.active_timers.remove (timer_id);
            this.timers.remove (timer_id);
            this.changed (timer_id, ChangeType.DELETED);
        }
        
        /**
         * @returns: File on success, NULL otherwise
         * 
         * Create directories and set location of recording
         */
        private File? create_recording_dirs (Channel channel, uint[] start) {
            string channel_name = Utils.remove_nonalphanums (channel.Name);
            string time = "%u-%u-%u_%u-%u".printf (start[0], start[1],
                start[2], start[3], start[4]);
            
            File dir = this.DeviceGroup.RecordingsDirectory.get_child (
                channel_name).get_child (time);
            
            if (!dir.query_exists (null)) {
                try {
                    Utils.mkdirs (dir);
                } catch (Error e) {
                    error (e.message);
                    return null;
                }
            }
            
            string attributes = "%s,%s".printf (FILE_ATTRIBUTE_STANDARD_TYPE,
                                                FILE_ATTRIBUTE_ACCESS_CAN_WRITE);
            FileInfo info;
            try {
                info = dir.query_info (attributes, 0, null);
            } catch (Error e) {
                critical (e.message);
                return null;
            }
            
            if (info.get_attribute_uint32 (FILE_ATTRIBUTE_STANDARD_TYPE)
                != FileType.DIRECTORY) {
                critical ("%s is not a directory", dir.get_path ());
                return null;
            }
            
            if (!info.get_attribute_boolean (FILE_ATTRIBUTE_ACCESS_CAN_WRITE)) {
                critical ("Cannot write to %s", dir.get_path ());
                return null;
            }
            
            return dir.get_child ("001.ts");
        }
        
        private bool check_timers () {
            debug ("Checking timers");
            
            SList<Timer> ended_recordings =
                new SList<Timer> ();
            foreach (uint32 timer_id in this.active_timers) {
                Timer timer =
                    this.timers.get (timer_id);
                if (timer.is_end_due()) {
                    ended_recordings.prepend (timer);
                }
            }
            
            // Delete timers of recordings that have ended
            for (int i=0; i<ended_recordings.length(); i++) {
                Timer timer = ended_recordings.nth_data (i);
                this.stop_recording (timer);
            }
            
            bool val;
            // Store items we want to delete in here
            SList<uint32> deleteable_items = new SList<uint32> ();
            // Don't use this.DeleteTimer for them
            SList<uint32> removeable_items = new SList<uint32> ();
            lock (this.timers) {
                foreach (uint32 key in this.timers.get_keys()) {
                    Timer timer = this.timers.get (key);
                    
                    debug ("Checking timer: %s", timer.to_string());
                    
                    // Check if we should start new recording and if we didn't
                    // start it before
                    if (timer.is_start_due()
                            && !this.active_timers.contains (timer.Id)) {
                        this.start_recording (timer);
                    } else if (timer.has_expired()) {
                        debug ("Removing expired timer: %s", timer.to_string());
                        deleteable_items.prepend (key);
                    }
                }
                
                // Delete items from this.timers using this.DeleteTimer
                for (int i=0; i<deleteable_items.length(); i++) {
                    this.DeleteTimer (deleteable_items.nth_data (i));
                }
                
                if (this.timers.size == 0 && this.active_timers.size == 0) {
                    // We don't have any timers and no recording is in progress
                    debug ("No timers left and no recording in progress");
                    this.have_check_timers_timeout = false;
                    val = false;
                } else {
                    // We still have timers
                    debug ("%d timers and %d active recordings left",
                        this.timers.size,
                        this.active_timers.size);
                    val = true;
                }
                
            }
            return val;
        }
        
        /**
         * Add recording to RecordinsStore and let the world now
         */
        private void on_recording_stopped (RecordingThread recthread,
                Recording recording, Timer timer) {
            debug ("Recording of channel %u stopped after %lli seconds",
                recording.ChannelSid, recording.Length);
            
            RecordingsStore.get_instance().add (recording);
            
            if (recthread.count == 0) {
                this.active_recording_threads.remove (timer);
                // Start epgscanner again after recording ended
                EPGScanner? epgscanner = Manager.get_instance ().get_epg_scanner (
                    this.DeviceGroup);
                if (epgscanner != null) epgscanner.start ();
            }
            
            this.recording_finished (recording.Id);
        }
    }

}
