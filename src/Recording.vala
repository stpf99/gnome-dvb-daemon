
namespace DVB {

    public class Recording : GLib.Object {
        public uint Id {get; set;}
        public uint ChannelSid {get; set;}
        public string Location {get; set;}
        public string? Name {get; set;}
        public string? Description {get; set;}
        public GLib.Time StartTime {get; set;}
        public int64 Length {get; set;}
        
        public uint[] get_start () {
            return new uint[] {
                this.StartTime.year + 1900,
                this.StartTime.month + 1,
                this.StartTime.day,
                this.StartTime.hour,
                this.StartTime.minute
            };
        }
        
        public string serialize () {
            uint[] started = this.get_start ();
            return "%d;%d;%s;%s;%s;%d-%d-%d %d:%d;%d".printf (
                this.Id, this.ChannelSid, this.Location,
                (this.Name == null) ? "" : this.Name,
                (this.Description == null) ? "" : this.Description,
                started[0], started[1], started[2], started[3],
                started[4], this.Length
            );
        }
        
        public Recording deserialize (string line) {
            string [] fields = line.split (";");
            
            var rec = new Recording ();
            int year, month, day, hour, minute, length;
            
            string field;
            int i = 0;
            while ((field = fields[0]) != null) {
                switch (i) {
                    case 0:
                        rec.Id = (uint)field.to_int ();
                    break;
                    
                    case 1:
                        rec.ChannelSid = (uint)field.to_int ();
                    break;
                    
                    case 2:
                        rec.Location = (field == "") ? null : field;
                    break;
                    
                    case 3:
                        rec.Name = (field == "") ? null : field;
                    break;
                    
                    case 4:
                        rec.Description = field;
                    break;
                    
                    case 5:
                        field.scanf ("%d-%d-%d %d:%d", &year, &month, &day,
                            &hour, &minute);
                    break;
                    
                    case 6:
                        rec.Length = (int64)field.to_int ();
                    break;
                    
                    default:
                    break;
                }            
            
                i++;
            }
            
            return rec;
        }
        
    }

}
