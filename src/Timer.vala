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
        uint year, uint month, uint day, uint hour, uint minute, uint duration) {
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
    
    }

}
