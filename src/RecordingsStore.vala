using GLib;

namespace DVB {

    /**
     * This class manages the recordings off all devices
     */
    public class RecordingsStore : GLib.Object {
    
        /**
         * @returns: A list of ids for all recordings
         */
        public uint[] GetRecordings () {
            return new uint[] {0};
        }
        
        /**
         * @rec_id: The id of the recording
         * @returns: The location of the recording on the filesystem
         */
        public string GetLocationOfRecording (uint rec_id) {
           
            return "";
        }
        
        /**
         * @rec_id: The id of the recording
         * @returns: The name of the recording (e.g. the name of
         * a TV show)
         */
        public string GetNameOfRecording (uint rec_id) {
        
            return "";
        }
        
        /**
         * @rec_id: The id of the recording
         * @returns: A short text describing the recorded item
         * (e.g. the description from EPG)
         */
        public string GetDescriptionOfRecording (uint rec_id) {
        
            return "";
        }
    
    }
    
}
