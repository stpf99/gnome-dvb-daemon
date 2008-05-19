using GLib;

namespace DVB {
    
    public class ChannelListWriter : GLib.Object {
    
        public File file {get; construct;}
    
        private OutputStream stream;
        
        construct {
            FileOutputStream fostream = null;
            
            if (file.query_exists (null)) {
                fostream = this.file.replace (null, true, 0, null);
            } else {
                fostream = this.file.create (0, null);
            }
            
            this.stream = new BufferedOutputStream (fostream);
        }
        
        public ChannelListWriter (File file) throws IOError {
            this.file = file;
        }
        
        public void write (Channel channel) {
        
        }
        
        public bool close () throws IOError {
            return this.stream.close (null);
        } 
    
    }
    
}
