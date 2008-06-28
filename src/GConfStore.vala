using GLib;
using Gee;

namespace DVB {

    public class GConfStore : GLib.Object {
    
        public static const string BASE_DIR = "/apps/dvb-daemon";
        
        private static const string DEVICES_DIR_KEY = "/devices";
        private static const string DEVICE_DIR_NAME = "/device_%d_%d";
        private static const string DEVICE_ADAPTER_KEY = "/adapter"; // int
        private static const string DEVICE_FRONTEND_KEY = "/frontend"; // int
        private static const string DEVICE_CHANNELS_FILE_KEY = "/channels_file"; // string
        private static const string DEVICE_ADAPTER_TYPE_KEY = "/adapter_type"; // int
        private static const string DEVICE_RECORDINGS_DIR_KEY = "/recordings_dir";
    
        private static const string TIMERS_DIR_KEY = "/timers";
        private static const string TIMER_DIR_NAME = "/timer_%d";
        private static const string TIMER_ID_KEY = "/id"; // int
        private static const string TIMER_CHANNEL_SID_KEY = "/channel_sid"; // int
        private static const string TIMER_YEAR_KEY = "/year"; // int
        private static const string TIMER_MONTH_KEY = "/month"; // int
        private static const string TIMER_DAY_KEY = "/day"; // int
        private static const string TIMER_HOUR_KEY = "/hour"; // int
        private static const string TIMER_MINUTE_KEY = "/minute"; // int
        private static const string TIMER_DURATION_KEY = "/duration"; // int
        
        private static GConfStore instance;
    
        private GConf.Client client;
    
        construct {
            this.client = GConf.Client.get_default ();
        }
        
        public static GConfStore get_instance () {
            // TODO make thread-safe
            if (instance == null) {
                instance = new GConfStore ();
            }
            return instance;
        }
         
        public ArrayList<Device> get_all_devices () {
            string devices_path = BASE_DIR + DEVICES_DIR_KEY;
        
            ArrayList<Device> devs = new ArrayList<Device> ();
            
            try {
                weak SList<string> dirs =
                    this.client.all_dirs (devices_path);
                foreach (string base_path in dirs)  {
                    int gconf_adapter =
                        this.client.get_int (base_path + DEVICE_ADAPTER_KEY);
                    if (gconf_adapter < 0) continue;
                        
                    int gconf_frontend =
                        this.client.get_int (base_path + DEVICE_FRONTEND_KEY);
                    if (gconf_frontend < 0) continue;
                        
                    int gconf_type =
                        this.client.get_int (base_path + DEVICE_ADAPTER_TYPE_KEY);
                    AdapterType type;
                    switch (gconf_type) {
                        case 0: type = AdapterType.DVB_T; break;
                        case 1: type = AdapterType.DVB_S; break;
                        case 2: type = AdapterType.DVB_C; break;
                        default: continue;
                    }
                    
                    File channels_file = File.new_for_path (
                        this.client.get_string (
                            base_path + DEVICE_CHANNELS_FILE_KEY));
                    
                    ChannelList channels;
                    try {
                        channels = ChannelList.restore_from_file (
                            channels_file, type);
                    } catch (Error e) {
                        warning (e.message);
                        continue;
                    }
                        
                    File recordings_dir = File.new_for_path (
                        this.client.get_string (
                            base_path + DEVICE_RECORDINGS_DIR_KEY));
                            
                    devs.add (Device.new_full ((uint)gconf_adapter,
                                               (uint)gconf_frontend,
                                               channels,
                                               recordings_dir));
                }
            } catch (Error e) {
                warning (e.message);
            }
            
            return devs;
        }
        
        public void add_device (Device dev) {
            string base_path = get_device_path (dev);
                
            try {
                if (!this.client.dir_exists (base_path)) {
                    this.client.set_int (base_path + DEVICE_ADAPTER_KEY,
                        (int)dev.Adapter);
                    this.client.set_int (base_path + DEVICE_FRONTEND_KEY,
                        (int)dev.Frontend);
                    this.client.set_string (base_path + DEVICE_CHANNELS_FILE_KEY,
                        dev.Channels.channels_file.get_path ());
                    this.client.set_int (base_path + DEVICE_ADAPTER_TYPE_KEY,
                        dev.Type);
                    this.client.set_string (base_path + DEVICE_RECORDINGS_DIR_KEY,
                        dev.RecordingsDirectory.get_path ());
                }
            } catch (Error e) {
                warning (e.message);
            }
        }
        
        public ArrayList<Timer> get_all_timers_of_device (Device dev) {
            string timers_path = get_device_path (dev) +
                TIMERS_DIR_KEY;
            
            ArrayList<Timer> timers = new ArrayList<Timer> ();
            
            try {
                weak SList<string> dirs =
                    this.client.all_dirs (timers_path);
                foreach (string base_path in dirs)  {
                    int gconf_id = this.client.get_int
                        (base_path + TIMER_ID_KEY);
                    if (gconf_id < 0) continue;
                    
                    int gconf_sid = this.client.get_int
                        (base_path + TIMER_CHANNEL_SID_KEY);
                    if (gconf_sid < 0) continue;
                    
                    int gconf_year = this.client.get_int
                        (base_path + TIMER_YEAR_KEY);
                    if (gconf_year < 0) continue;
                    
                    int gconf_month = this.client.get_int
                        (base_path + TIMER_MONTH_KEY);
                    if (gconf_month < 0) continue;
                    
                    int gconf_day = this.client.get_int
                        (base_path + TIMER_DAY_KEY);
                    if (gconf_day < 0) continue;
                    
                    int gconf_hour = this.client.get_int
                        (base_path + TIMER_HOUR_KEY);
                    if (gconf_hour < 0) continue;
                    
                    int gconf_minute = this.client.get_int
                        (base_path + TIMER_MINUTE_KEY);
                    if (gconf_minute < 0) continue;
                    
                    int gconf_duration = this.client.get_int
                        (base_path + TIMER_DURATION_KEY);
                    if (gconf_duration < 0) continue;
                    
                    timers.add (new Timer ((uint32)gconf_id, (uint)gconf_sid,
                                           gconf_year, gconf_month, gconf_day,
                                           gconf_hour, gconf_minute,
                                           (uint)gconf_duration));
                }
            } catch (Error e) {
                warning (e.message);
            }
            
            return timers;
        }
        
        public void add_timer_to_device (Timer timer, Device dev) {
            string base_path = get_device_path (dev) +
                TIMERS_DIR_KEY +
                TIMER_DIR_NAME.printf (timer.Id);
            try {
                if (!this.client.dir_exists (base_path)) {
                    this.client.set_int (base_path + TIMER_ID_KEY,
                        (int)timer.Id);
                    this.client.set_int (base_path + TIMER_CHANNEL_SID_KEY,
                        (int)timer.ChannelSid);
                    this.client.set_int (base_path + TIMER_YEAR_KEY,
                        (int)timer.Year);
                    this.client.set_int (base_path + TIMER_MONTH_KEY,
                        (int)timer.Month);
                    this.client.set_int (base_path + TIMER_DAY_KEY,
                        (int)timer.Day);
                    this.client.set_int (base_path + TIMER_HOUR_KEY,
                        (int)timer.Hour);
                    this.client.set_int (base_path + TIMER_MINUTE_KEY,
                        (int)timer.Minute);
                    this.client.set_int (base_path + TIMER_DURATION_KEY,
                        (int)timer.Duration);
                }
            } catch (Error e) {
                warning (e.message);
            }
        }
        
        public void remove_timer_from_device (uint timer_id, Device dev) {
            string base_path = get_device_path (dev) +
                TIMERS_DIR_KEY +
                TIMER_DIR_NAME.printf (timer_id);
            try {
                if (this.client.dir_exists (base_path)) {
                    this.client.recursive_unset (base_path,
                        GConf.UnsetFlags.NAMES);
                }
            } catch (Error e) {
                warning (e.message);
            }
        }
        
        private static string get_device_path (Device dev) {
            return BASE_DIR + DEVICES_DIR_KEY +
                DEVICE_DIR_NAME.printf (dev.Adapter, dev.Frontend);
        }
    
    }
}
