using GLib;

namespace DVB {

    /**
     * This class represents a finished recording
     */
    public class Recording : GLib.Object {
    
        public uint32 Id {get; set;}
        public uint ChannelSid {get; set;}
        public string ChannelName {get; set;}
        public File Location {get; set;}
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
        
        /**
         * Stores all information of the timer in info.rec
         * in the directory of this.Location
         */
        public void save_to_disk () throws GLib.Error {
            File parentdir = this.Location.get_parent ();
        
            File recfile = parentdir.get_child ("info.rec");
            
            debug ("Saving recording to %s", recfile.get_path() );
            
            if (recfile.query_exists (null)) {
                debug ("Deleting old info.rec");
                recfile.delete (null);
            }
            
            FileOutputStream stream = recfile.create (0, null);
            
            string text = this.serialize ();
            stream.write (text, text.size (), null);
            
            stream.close (null);
        }
        
        public string serialize () {
            uint[] started = this.get_start ();
            return "%u\n%s\n%s\n%u-%u-%u %u:%u\n%lld\n%s\n%s".printf (
                this.Id, this.ChannelName, this.Location.get_path (),                
                started[0], started[1], started[2], started[3],
                started[4], this.Length,
                (this.Name == null) ? "" : this.Name,
                (this.Description == null) ? "" : this.Description
            );
        }
        
        // TODO throw error
        public static Recording? deserialize (File file) throws Error {
            string? contents = Utils.read_file_contents (file);
            
            if (contents == null) return null;
        
            string [] fields = contents.split ("\n", 7);
            
            var rec = new Recording ();
            
            string field;
            int i = 0;
            while ((field = fields[i]) != null) {
                switch (i) {
                    case 0:
                        rec.Id = (uint32)field.to_int ();
                    break;
                    
                    case 1:
                        rec.ChannelName = field;
                    break;
                    
                    case 2:
                        if (field == "") rec.Location = null;
                        else rec.Location = File.new_for_path (field);
                    break;
                    
                    case 3: {
                        int year = 0;
                        int month = 0;
                        int day = 0;
                        int hour = 0;
                        int minute = 0;
                        field.scanf ("%d-%d-%d %d:%d", &year, &month, &day,
                            &hour, &minute);
                        if (year >= 1900 && month >= 1 && day >= 1 && hour >= 0
                                && minute >= 0) {
                            rec.StartTime = Utils.create_time (year, month, day, hour, minute);
                        }
                    break;
                    }
                    
                    case 4:
                        rec.Length = (int64)field.to_int ();
                    break;
                    
                    case 5:
                        rec.Name = (field == "") ? null : field;
                    break;
                    
                    default:
                        rec.Description = field;
                    break;
                }            
            
                i++;
            }
            
            return rec;
        }
        
    }

}
