using GLib;

namespace DVB {

    /**
     * This class represents an event that should be recorded
     */
    public class Timer : GLib.Object {
    
        public uint32 Id {get; construct;}
        public uint ChannelSid {get; construct;}
        public string? Name {get; construct;}
        // TODO Create values from starttime
        public uint Year {get; construct;}
        public uint Month {get; construct;}
        public uint Day {get; construct;}
        public uint Hour {get; construct;}
        public uint Minute {get; construct;}
        public uint Duration {get; construct;}
        
        private Time starttime;
        
        construct {
            this.starttime = Utils.create_time ((int)this.Year, (int)this.Month,
                (int)this.Day, (int)this.Hour, (int)this.Minute);
        }
        
        public Timer (uint32 id, uint channel_sid,
        int year, int month, int day, int hour, int minute, uint duration,
        string? name=null) {
            this.Id = id;
            this.ChannelSid = channel_sid;
            this.Name = name;
            
            this.Year = year;
            this.Month = month;
            this.Day = day;
            this.Hour = hour;
            this.Minute = minute;
           
            this.Duration = duration;
        }
        
        /**
         * Whether the timer conflicts with the other one
         */
        public bool conflicts_with (Timer t2) {
            time_t this_start = this.get_start_time_timestamp ();
            time_t other_start = t2.get_start_time_timestamp ();
            
            if (this_start <= other_start) {
                // No conflict when this timer ends before other starts
                time_t this_end = this.get_end_time_timestamp ();
                return (this_end > other_start);
            } else {
                // No conflict when other timer ends before this starts
                time_t other_end = t2.get_end_time_timestamp ();
                return (other_end > this_start);
            }
        }
        
        /**
         * @duration: in minutes
         * @returns: The overlap between the timer and the given time range.
         * The timer is the reference, i.e. if the time range is completely
         * contained in the timer OverlapType.COMPLETE is returned.
         *
         * The given time range must be in local time.
         */
        public OverlapType get_overlap_local (uint start_year, uint start_month,
                uint start_day, uint start_hour, uint start_minute,
                uint duration) {
            time_t this_start = this.get_start_time_timestamp ();
            time_t this_end = this.get_end_time_timestamp ();
            
            Time other_time = Utils.create_time ((int)start_year, (int)start_month,
                (int)start_day, (int)start_hour, (int)start_minute);
            time_t other_start = other_time.mktime ();
            other_time.minute += (int)duration;
            time_t other_end = other_time.mktime ();
            
            return get_overlap (this_start, this_end, other_start, other_end);
        }   
        
        /**
         * Same as get_overlap_local but the given time range is UTC time.
         */
        public OverlapType get_overlap_utc (uint start_year, uint start_month,
                uint start_day, uint start_hour, uint start_minute,
                uint duration) {
            time_t this_start = this.get_start_time_timestamp ();
            time_t this_end = this.get_end_time_timestamp ();
            
            Time other_time = Utils.create_time ((int)start_year, (int)start_month,
                (int)start_day, (int)start_hour, (int)start_minute);
            time_t other_start = cUtils.timegm (other_time);
            other_time.minute += (int)duration;
            time_t other_end = cUtils.timegm (other_time);
                
            return get_overlap (this_start, this_end, other_start, other_end);
        }
            
        private static OverlapType get_overlap (time_t this_start, time_t this_end,
                time_t other_start, time_t other_end) {
            
            if (this_start <= other_start) {
                // No conflict when this timer ends before other starts
                if (this_end <= other_start) {
                    // this starts before other and ends before other starts
                    return OverlapType.NONE;
                } else {
                    if (this_end >= other_end)
                        // this starts before other and ends after other
                        return OverlapType.COMPLETE;
                    else
                        // this starts before other and ends before other
                        return OverlapType.PARTIAL;
                }   
            } else {
                // No conflict when other timer ends before this starts
                if (this_end <= other_end) {
                    // this starts after other and ends before other
                    return OverlapType.PARTIAL;
                } else {
                    if (this_start < other_end)
                         // this starts before other ends and ends after other
                        return OverlapType.PARTIAL;
                    else
                        // this starts after other ends and ends after other
                        return OverlapType.NONE;
                }
            }
        }
                
        public uint[] get_start_time () {
            uint[] start = new uint[] {
                this.Year,
                this.Month,
                this.Day,
                this.Hour,
                this.Minute
            };
            return start;
        }
        
        public Time get_start_time_time () {
             return this.starttime;
        }
        
        public uint[] get_end_time () {
            var l = Time.local (this.get_end_time_timestamp ());
            
            return new uint[] {
                l.year + 1900,
                l.month + 1,
                l.day,
                l.hour,
                l.minute
            };
        }
        
        /**
         * Whether the start time of the timer equals the current local time
         */
        public bool is_start_due () {
            var localtime = Time.local (time_t ());

            // Convert to values of struct tm aka Time            
            int year = (int)this.Year - 1900;
            int month = (int)this.Month - 1;
            
            return (year == localtime.year && month == localtime.month
                    && this.Day == localtime.day && this.Hour == localtime.hour
                    && this.Minute == localtime.minute);
        }
        
        /**
         * Whether the end time of the timer equals the current local time
         */
        public bool is_end_due () {
            var localtime = Time.local (time_t ());
            var endtime = Time.local (this.get_end_time_timestamp ());
            
            return (endtime.year == localtime.year && endtime.month == localtime.month
                    && endtime.day == localtime.day && endtime.hour == localtime.hour
                    && endtime.minute == localtime.minute);
        }
        
        /**
         * Whether the timer ends in the past
         */
        public bool has_expired () {
            time_t current_time = time_t ();
            time_t end_time = this.get_end_time_timestamp ();
            
            return (end_time < current_time);
        }
        
        public string to_string () {
            return "channel: %u, start: %u-%u-%u %u:%u, duration: %u".printf (
                this.ChannelSid, this.Year, this.Month, this.Day, this.Hour,
                this.Minute, this.Duration);
        }
        
        private time_t get_end_time_timestamp () {
            var t = Utils.create_time ((int)this.Year, (int)this.Month,
                (int)this.Day, (int)this.Hour, (int)this.Minute);
            
            // TODO Do we change the value of this.starttime each time?
            t.minute += (int)this.Duration;
            
            return t.mktime ();
        }
        
        private time_t get_start_time_timestamp () {
            var t = this.get_start_time_time ();
            return t.mktime ();
        }
    
    }

}
