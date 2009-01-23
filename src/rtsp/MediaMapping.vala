using GLib;

namespace DVB {

    public class MediaMapping : Gst.RTSPMediaMapping {
        
        private static Gst.RTSPMediaFactory factory_instance = new MediaFactory ();
        
        public override Gst.RTSPMediaFactory? find_media (Gst.RTSPUrl url) {
            return factory_instance;
        }
        
    }

}
