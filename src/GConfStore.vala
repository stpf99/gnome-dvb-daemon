using GLib;
using Gee;

namespace DVB {

    /**
     * Example tree:
     * /app/dvb-daemon
     *     /device_groups
     *         /group_0
     *             /devices
     *                 /device_0_0
     *                      adapter
     *                      frontend
     *                  /device_1_0
     *                      adapter
     *                     frontend
     *             /timers
     *                 /timer_0
     *                     id
     *                     channel_sid
     *                     year
     *                 /timer_1
     *                     id
     *                     channel_sid
     *                     year
     *             channels_file
     *             adapter_type
     *             recordings_dir
     *         /group_1
     *             /devices
     *                  /device_2_0
     *                      adapter
     *                      frontend
     *                  /device_3_0
     *                      adapter
     *                      frontend
     *             channels_file
     *             adapter_type
     *             recordings_dir
     */
    public class GConfStore : GLib.Object {
    
        public static const string BASE_DIR = "/apps/dvb-daemon";
        
        private static const string DEVICE_GROUPS_DIR_KEY = "/device_groups";
        private static const string DEVICE_GROUP_DIR_NAME = "/group_%d";
        private static const string DEVICE_GROUP_CHANNELS_FILE_KEY = "/channels_file"; // string
        private static const string DEVICE_GROUP_ADAPTER_TYPE_KEY = "/adapter_type"; // int
        private static const string DEVICE_GROUP_RECORDINGS_DIR_KEY = "/recordings_dir";
    
        private static const string DEVICES_DIR_KEY = "/devices";
        private static const string DEVICE_DIR_NAME = "/device_%d_%d";
        private static const string DEVICE_ADAPTER_KEY = "/adapter"; // int
        private static const string DEVICE_FRONTEND_KEY = "/frontend"; // int
        
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
         
        private ArrayList<Device> get_all_devices (string root_dir) {
            string devices_path = root_dir + DEVICES_DIR_KEY;
            
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
                         
                    devs.add (new Device ((uint)gconf_adapter,
                                          (uint)gconf_frontend));
                }
            } catch (Error e) {
                warning (e.message);
            }
            
            return devs;
        }
        
        public ArrayList<DeviceGroup> get_all_device_groups () {
            string groups_path = BASE_DIR + DEVICE_GROUPS_DIR_KEY;
            
            ArrayList<DeviceGroup> groups = new ArrayList<DeviceGroup> ();
            
            try {
                weak SList<string> dirs =
                    this.client.all_dirs (groups_path);
                foreach (string base_path in dirs)  {
                    // base_path looks like
                    // /apps/dvb-daemon/device_groups/group_1
                    File groupfile = File.new_for_path (base_path);
                    string group_dir = groupfile.get_basename ();
                    
                    uint group_id = (uint)(group_dir.split("_")[1]).to_int ();

                    string recdir = this.client.get_string (
                            base_path + DEVICE_GROUP_RECORDINGS_DIR_KEY);
                    if (recdir == null) {
                        warning ("Could not retrieve location of recordings directory for group %u",
                            group_id);
                        continue;
                    }
                            
                    File recordings_dir = File.new_for_path (recdir);
                
                    int gconf_type =
                        this.client.get_int (base_path + DEVICE_GROUP_ADAPTER_TYPE_KEY);
                    AdapterType type;
                    switch (gconf_type) {
                        case 0: type = AdapterType.DVB_T; break;
                        case 1: type = AdapterType.DVB_S; break;
                        case 2: type = AdapterType.DVB_C; break;
                        default: continue;
                    }
                    
                    string channelsfilepath = this.client.get_string (
                            base_path + DEVICE_GROUP_CHANNELS_FILE_KEY);
                    if (channelsfilepath == null) {
                        warning ("Could not retrieve location of channels file for group %u",
                            group_id);
                        continue;
                    }
                            
                    File channels_file = File.new_for_path (channelsfilepath);
                    
                    ChannelList channels;
                    try {
                        channels = ChannelList.restore_from_file (
                            channels_file, type);
                        channels.group_id = group_id;
                    } catch (Error e) {
                        warning (e.message);
                        continue;
                    }
                    
                    DeviceGroup? new_group = null;
                    
                    ArrayList<Device> devs = this.get_all_devices (base_path);
                    
                    assert (devs.size > 0);
                    
                    foreach (Device dev in devs) {
                        if (new_group == null) {
                            dev.Channels = channels;
                            dev.RecordingsDirectory = recordings_dir;
                            new_group = new DeviceGroup (group_id, dev);
                        } else
                            new_group.add (dev);
                    }
                    
                    assert (new_group != null);
                    assert (new_group.size > 0);
                    
                    groups.add (new_group);
                }
            } catch (Error e) {
                warning (e.message);
            }
            
            return groups;
        }
        
        public void add_device_group (DeviceGroup dev_group) {
            string base_path = get_device_group_path (dev_group);
            
            assert (dev_group.Channels != null);
            assert (dev_group.RecordingsDirectory != null);
                
            try {
                if (!this.client.dir_exists (base_path)) {
                    this.client.set_int (base_path + DEVICE_GROUP_ADAPTER_TYPE_KEY,
                        dev_group.Type);
                    if (!this.client.set_string (base_path + DEVICE_GROUP_CHANNELS_FILE_KEY,
                        dev_group.Channels.channels_file.get_path ()))
                            critical ("Could not save location of channels file in GConf");

                    if (!this.client.set_string (base_path + DEVICE_GROUP_RECORDINGS_DIR_KEY,
                            dev_group.RecordingsDirectory.get_path ()))
                        critical ("Could not save location of recordings in GConf");
                        
                    foreach (Device dev in dev_group) {
                        this.add_device_to_group (dev, dev_group);
                    }
                }
            } catch (Error e) {
                warning (e.message);
            }
        }
        
        public void remove_device_group (DeviceGroup devgroup) {
            string base_path = get_device_group_path (devgroup);
            
            try {
                if (this.client.dir_exists (base_path)) {
                    this.client.recursive_unset (base_path,
                        GConf.UnsetFlags.NAMES);
                }
            } catch (Error e) {
                warning (e.message);
            }
        }
        
        public void add_device_to_group (Device dev, DeviceGroup devgroup) {
            string base_path = get_device_group_path (devgroup) + get_device_path (dev);
        
            try {
                if (!this.client.set_int (base_path + DEVICE_ADAPTER_KEY,
                        (int)dev.Adapter))
                    critical ("Could not save adapter in GConf");
                if (!this.client.set_int (base_path + DEVICE_FRONTEND_KEY,
                        (int)dev.Frontend))
                    critical ("Could not save frontend in GConf");
            } catch (Error e) {
                warning (e.message);
            }
        }
        
        public void remove_device_from_group (Device dev, DeviceGroup devgroup) {
            string base_path = get_device_group_path (devgroup) + get_device_path (dev);
            
            try {
                if (this.client.dir_exists (base_path)) {
                    this.client.recursive_unset (base_path,
                        GConf.UnsetFlags.NAMES);
                }
            } catch (Error e) {
                warning (e.message);
            }
        }
        
        public ArrayList<Timer> get_all_timers_of_device_group (DeviceGroup dev) {
            string timers_path = get_device_group_path (dev) +
                TIMERS_DIR_KEY;
            
            ArrayList<Timer> timers = new ArrayList<Timer> ();
            
            try {
                weak SList<string> dirs =
                    this.client.all_dirs (timers_path);
                foreach (string base_path in dirs)  {
                    int gconf_id = this.client.get_int
                        (base_path + TIMER_ID_KEY);
                    if (gconf_id <= 0) continue;
                    
                    int gconf_sid = this.client.get_int
                        (base_path + TIMER_CHANNEL_SID_KEY);
                    if (gconf_sid <= 0) continue;
                    
                    int gconf_year = this.client.get_int
                        (base_path + TIMER_YEAR_KEY);
                    if (gconf_year <= 0) continue;
                    
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
                    if (gconf_duration <= 0) continue;
                    
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
        
        public void add_timer_to_device_group (Timer timer, DeviceGroup dev) {
            string base_path = get_device_group_path (dev) +
                TIMERS_DIR_KEY +
                TIMER_DIR_NAME.printf (timer.Id);
            try {
                if (!this.client.dir_exists (base_path)) {
                    bool ret = true;
                    ret &= this.client.set_int (base_path + TIMER_ID_KEY,
                        (int)timer.Id);
                    ret &= this.client.set_int (base_path + TIMER_CHANNEL_SID_KEY,
                        (int)timer.ChannelSid);
                    ret &= this.client.set_int (base_path + TIMER_YEAR_KEY,
                        (int)timer.Year);
                    ret &= this.client.set_int (base_path + TIMER_MONTH_KEY,
                        (int)timer.Month);
                    ret &= this.client.set_int (base_path + TIMER_DAY_KEY,
                        (int)timer.Day);
                    ret &= this.client.set_int (base_path + TIMER_HOUR_KEY,
                        (int)timer.Hour);
                    ret &= this.client.set_int (base_path + TIMER_MINUTE_KEY,
                        (int)timer.Minute);
                    ret &= this.client.set_int (base_path + TIMER_DURATION_KEY,
                        (int)timer.Duration);
                    if (!ret)
                        critical ("Could not store timer in GConf");
                }
            } catch (Error e) {
                warning (e.message);
            }
        }
        
        public void remove_timer_from_device_group (uint timer_id, DeviceGroup dev) {
            string base_path = get_device_group_path (dev) +
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
            return DEVICES_DIR_KEY +
                DEVICE_DIR_NAME.printf (dev.Adapter, dev.Frontend);
        }
        
        private static string get_device_group_path (DeviceGroup dev) {
            return BASE_DIR + DEVICE_GROUPS_DIR_KEY +
                DEVICE_GROUP_DIR_NAME.printf (dev.Id);
        }
    
    }
}
