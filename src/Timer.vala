using GLib;

namespace DVB {

    /**
     * This class represents an event that should be recorded
     */
    public class Timer : GLib.Object {
    
        public uint Id {get; construct;}
        public DVB.Channel Channel {get; construct;}
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
        
        public Timer (uint id, DVB.Channel channel,
        int year, int month, int day, int hour, int minute, uint duration,
        string? name=null) {
            this.Id = id;
            this.Channel = channel;
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
            int64 this_start = (int64)this.get_start_time_timestamp ();
            int64 other_start = (int64)t2.get_start_time_timestamp ();
            
            if (this_start <= other_start) {
                // No conflict when this timer ends before other starts
                int64 this_end = (int64)this.get_end_time_timestamp ();
                return (this_end > other_start);
            } else {
                // No conflict when other timer ends before this starts
                int64 other_end = (int64)t2.get_end_time_timestamp ();
                return (other_end > this_start);
            }
        }
        
        /**
         * Whether the timer is scheduled somewhere in the given timeframe
         */
        public bool is_in_range (uint start_year, uint start_month,
        uint start_day, uint start_hour, uint start_minute, uint duration) {
            int64 this_start = (int64)this.get_start_time_timestamp ();
            
            Time other_time = Utils.create_time ((int)start_year, (int)start_month,
                (int)start_day, (int)start_hour, (int)start_minute);
            int64 other_start = (int64)other_time.mktime ();
            
            if (this_start <= other_start) {
                // No conflict when this timer ends before other starts
                int64 this_end = (int64)this.get_end_time_timestamp ();
                return (this_end > other_start);
            } else {
                // No conflict when other timer ends before this starts
                other_time.minute += (int)duration;
                int64 other_end = (int64)other_time.mktime ();
                return (other_end > this_start);
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
            int64 current_time = (int64)time_t ();
            int64 end_time = (int64)this.get_end_time_timestamp ();
            
            return (end_time < current_time);
        }
        
        public string serialize () {
            return "%d;%d;%s;%d-%d-%d %d:%d;%d\n".printf(
                this.Id, this.Channel.Sid, (this.Name == null) ? "" : this.Name,
                this.Year, this.Month, this.Day, this.Hour, this.Minute,
                this.Duration);
        }
        
        public string to_string () {
            return "channel: %d, start: %d-%d-%d %d:%d, duration: %d".printf (
                this.Channel.Sid, this.Year, this.Month, this.Day, this.Hour,
                this.Minute, this.Duration);
        }
        
        private time_t get_end_time_timestamp () {
            var t = Utils.create_time ((int)this.Year, (int)this.Month,
                (int)this.Day, (int)this.Hour, (int)this.Minute);
            
            t.minute += (int)this.Duration;
            
            return t.mktime ();
        }
        
        private time_t get_start_time_timestamp () {
            var t = this.get_start_time_time ();
            return t.mktime ();
        }
    
    }

}
