using GLib;
using Gst;
using Gee;

namespace DVB {

    /**
     * This class is responsible for managing upcoming recordings and
     * already recorded items for a single device
     */
    public abstract class Recorder : GLib.Object {
    
        public signal void recording_started (uint timer_id);
        public signal void recording_finished (uint recording_id);
        
        public DVB.Device Device { get; construct; }
        public ChannelList Channels { get; construct; }
        
        protected Element pipeline;
        protected Timer active_timer;
        
        private HashMap<uint, Timer> timers;
        private uint timer_counter;
        private uint? check_timers_event_id;
        
        construct {
            this.timers = new HashMap<uint, Timer> ();
            this.timer_counter = 0;
            this.check_timers_event_id = null;
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
         * @returns: The new timer's id on success
         * 
         * Add a new timer
         */
        public uint AddTimer (uint channel,
            uint start_year, uint start_month, uint start_day,
            uint start_hour, uint start_minute, uint duration) {
            // FIXME thread-safety
            this.timer_counter++;
            this.timers.set (this.timer_counter,
                new Timer (this.timer_counter, this.Channels.get(channel),
                           null, null,
                           start_year, start_month, start_day,
                           start_hour, start_minute, duration));
                           
            if (this.check_timers_event_id == null) {
                this.check_timers_event_id = Timeout.add_seconds (
                    30, this.check_timers
                );
            }
            
            return this.timer_counter;
        }
        
        /**
         * @timer_id: The id of the timer you want to delete
         * @returns: TRUE on success
         *
         * Delete timer
         */
        public bool DeleteTimer (uint timer_id) {
            // TODO: Check if timer is active
            // FIXME thread-safety
            if (this.timers.contains (timer_id)) {
                this.timers.remove (timer_id);
                return true;
            } else {
                return false;
            }
        }
        
        /**
         * dvb_recorder_GetTimers
         * @returns: A list of all timer ids
         */
        public uint[] GetTimers () {
            uint[] timer_arr = new uint[this.timers.size];
            // FIXME thread-safety
            int i=0;
            foreach (uint key in this.timers.get_keys()) {
                timer_arr[i] = this.timers.get(key).Id;
                i++;
            }
        
            return timer_arr;
        }
        
        /**
         * @timer_id: Timer's id
         * @returns: An array of length 5, where index 0 = year, 1 = month,
         * 2 = day, 3 = hour and 4 = minute.
         */
        public uint[]? GetStartTime (uint timer_id) {
            // FIXME thread-safety
            if (!this.timers.contains (timer_id)) return null;
        
            return this.timers.get(timer_id).get_start_time ();
        }
        
        /**
         * @timer_id: Timer's id
         * @returns: Same as dvb_recorder_GetStartTime()
         */
        public uint[]? GetEndTime (uint timer_id) {
            // FIXME thread-safety
            if (!this.timers.contains (timer_id)) return null;
        
            return this.timers.get(timer_id).get_end_time ();
        }
        
        /**
         * @timer_id: Timer's id
         * @returns: Duration in seconds
         */
        public uint? GetDuration (uint timer_id) {
            // FIXME thread-safety
            if (!this.timers.contains (timer_id)) return null;
        
            return this.timers.get(timer_id).Duration;
        }
        
        /**
         * @returns: A list of ids for the currently active timers
         * (i.e.currently active recordings)
         */
        public uint[] GetActiveTimers () {
            // TODO: Move to other class
            return new uint[] {0};
        }
        
        /**
         * @timer_id: Timer's id
         * @returns: TRUE if timer is currently active
         */
        public bool IsTimerActive (uint timer_id) {

            return (timer_id == this.active_timer.Id);
        }
        
        /**
         * @returns: TRUE if a timer is already scheduled in the given
         * period of time
         */
        public bool HasTimer (uint start_year, uint start_month,
        uint start_day, uint start_hour, uint start_minute, uint duration) {
        
            return true;
        }
        
        protected void stop_recording () {
            this.pipeline.set_state (State.NULL);
            this.pipeline = null;
            this.recording_finished (active_timer.Id);
        }
        
        protected void start_recording (Timer timer) {
            Element dvbbasebin = this.get_dvbbasebin (timer.Channel);
            
            if (dvbbasebin == null) return;
            
            this.pipeline = new Pipeline ("recording_%s".printf(timer.Channel.Sid));
            dvbbasebin.pad_added += this.on_dvbbasebin_pad_added;
            Element filesink = ElementFactory.make ("filesink", "sink");
            //TODO: filesink.set ("location", );
            ((Bin) this.pipeline).add_many (dvbbasebin, filesink);
            
            this.pipeline.set_state (State.PLAYING);
        }
        
        private void on_dvbbasebin_pad_added (Pad pad) {
            string sid = this.active_timer.Channel.Sid.to_string();
            string program = "program_%s".printf(sid);
            if (pad.get_name() == program) {
                Element dvbbasebin = ((Bin) this.pipeline).get_by_name ("dvbbasebin");
                dvbbasebin.set ("program-numbers", sid);
                
                Element sink = ((Bin) this.pipeline).get_by_name ("sink");
                Pad sinkpad = sink.get_pad ("sink");
                
                pad.link (sinkpad);
            }
        }
        
        private bool check_timers () {
            Time localtime = Time.local (time_t ());
            // FIXME thread-safety
            foreach (uint key in this.timers.get_keys()) {
                Timer timer = this.timers.get (key);
                
                if (timer.Year >= localtime.year && timer.Month >= localtime.month
                    && timer.Day >= localtime.day && timer.Hour >= localtime.hour
                    && timer.Minute >= localtime.minute) {
                    this.active_timer = timer;
                    this.start_recording (timer);
                    this.timers.remove (timer);
                    break;   
                }
            }
            
            if (this.timers.size == 0) {
                // We don't have any timers
                this.check_timers_event_id = null;
                return false;
            } else {
                // We still have timers
                return true;
            }
        }
    }

}
