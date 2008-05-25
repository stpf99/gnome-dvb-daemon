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

            // Convert to values of struct tm aka Time            
            int year = (int)this.Year - 1900;
            int month = (int)this.Month - 1;
            
            return (year == localtime.year && month == localtime.month
                    && this.Day == localtime.day && this.Hour == localtime.hour
                    && this.Minute == localtime.minute);
        }
        
        public string to_string () {
            return "channel: %d, start: %d-%d-%d %d:%d, duration: %d".printf (
                this.Channel.Sid, this.Year, this.Month, this.Day, this.Hour,
                this.Minute, this.Duration
            );
        }
    
    }

}
