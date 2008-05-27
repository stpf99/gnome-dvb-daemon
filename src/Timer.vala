using GLib;

namespace DVB {

    public class Timer : GLib.Object {
    
        public uint Id {get; construct;}
        public DVB.Channel Channel {get; construct;}
        public string? Name {get; construct;}
        public string? Description {get; construct;}
        public uint Year {get; construct;}
        public uint Month {get; construct;}
        public uint Day {get; construct;}
        public uint Hour {get; construct;}
        public uint Minute {get; construct;}
        public uint Duration {get; construct;}
        
        public Timer (uint id, DVB.Channel channel, string? name, string? description,
        int year, int month, int day, int hour, int minute, uint duration) {
            this.Id = id;
            this.Channel = channel;
            this.Name = name;
            this.Description = description;
            
            this.Year = year;
            this.Month = month;
            this.Day = day;
            this.Hour = hour;
            this.Minute = minute;
           
            this.Duration = duration;
        }
        
        private static Time create_time (int year, int month, int day, int hour, int minute) {
            var t = Time ();
            
            t.year = year - 1900;
            t.month = month - 1;
            t.day = day;
            t.hour = hour;
            t.minute = minute;
            
            return t;
        }
        
        /**
         * Whether the timer conflicts with the other one
         */
        public bool conflicts (Timer t2) {
            return false;
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
            var endtime = Time.local(this.get_end_time_timestamp ());
            
            debug ("%d-%d-%d %d:%d %d", endtime.year, endtime.month, endtime.day, endtime.hour, endtime.minute, endtime.isdst);
            debug ("%d-%d-%d %d:%d %d", localtime.year, localtime.month, localtime.day, localtime.hour, localtime.minute, localtime.isdst);
            
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
        
        public string to_string () {
            return "channel: %d, start: %d-%d-%d %d:%d, duration: %d".printf (
                this.Channel.Sid, this.Year, this.Month, this.Day, this.Hour,
                this.Minute, this.Duration);
        }
        
        private time_t get_end_time_timestamp () {
            var t = create_time ((int)this.Year, (int)this.Month,
                (int)this.Day, (int)this.Hour, (int)this.Minute);

            int64 new_time = (int64)t.mktime () + (this.Duration * 60);
            
            return (time_t)new_time;
        }
    
    }

}
