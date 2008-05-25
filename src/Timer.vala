using GLib;

namespace DVB {

    public class Timer : GLib.Object {
    
        public uint Id {get; construct;}
        public DVB.Channel Channel {get; construct;}
        public string? Name {get; construct;}
        public string? Description {get; construct;}
        public Time TimeTM {get; construct;}
        public uint Duration {get; construct;}
        
        public uint Year {
            get { return this.TimeTM.year + 1900; }
        }
        public uint Month {
            get { return this.TimeTM.month + 1; }
        }
        public uint Day {
            get { return this.TimeTM.day; }
        }
        public uint Hour {
            get { return this.TimeTM.hour; }
        }
        public uint Minute {
            get { return this.TimeTM.minute; }
        }
        
        public Timer (uint id, DVB.Channel channel, string? name, string? description,
        int year, int month, int day, int hour, int minute, uint duration) {
            this.Id = id;
            this.Channel = channel;
            this.Name = name;
            this.Description = description;
            
            this.TimeTM = this.create_time (year, month, day, hour, minute);
            
            this.Duration = duration;
        }
        
        private Time create_time (int year, int month, int day, int hour, int minute) {
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
            uint minutes = this.Minute + this.Duration;
            uint hours = this.Hour + (minutes / 60);
            uint days = this.Day + (hours / 24);
            // FIXME: month
            uint months = this.Month + (days / 30);
            uint year = this.Year + (days / 365);
        
            uint end_min = minutes % 60;
            uint end_hour = hours % 24;
            uint end_day = days % 365;
            uint end_month = months % 30;
            
            return new uint[] {
                year,
                end_month,
                end_day,
                end_hour,
                end_min
            };
        }
        
        public bool is_due () {
            var localtime = Time.local (time_t ());
            
            return (this.TimeTM.year >= localtime.year && this.TimeTM.month >= localtime.month
                    && this.TimeTM.day >= localtime.day && this.TimeTM.hour >= localtime.hour
                    && this.TimeTM.minute >= localtime.minute);
        }
        
        public string to_string () {
            return "channel: %d, start: %d-%d-%d %d:%d, duration: %d".printf (
                this.Channel.Sid, this.Year, this.Month, this.Day, this.Hour,
                this.Minute, this.Duration
            );
        }
    
    }

}
