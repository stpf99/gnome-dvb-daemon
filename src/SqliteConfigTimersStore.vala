using GLib;
using Gee;
using Sqlite;

namespace DVB {

    public class SqliteConfigTimersStore : GLib.Object, ConfigStore, TimersStore {
    
        private static const string CREATE_DEVICE_GROUPS =
        """CREATE TABLE device_groups (
        group_id INTEGER,
        adapter_type INTEGER(1),
        channels_file VARCHAR(255),
        recordings_dir VARCHAR(255),
        name VARCHAR(255),
        PRIMARY KEY(group_id))""";
    
        private static const string CREATE_DEVICES =
        """CREATE TABLE devices (
        group_id INTEGER,
        adapter INTEGER,
        frontend INTEGER,
        PRIMARY KEY(adapter, frontend))""";
        
        private static const string CREATE_TIMERS =
        """CREATE TABLE timers (
        timer_id INTEGER,
        group_id INTEGER,
        channel_sid INTEGER,
        year INTEGER,
        month INTEGER,
        day INTEGER,
        hour INTEGER,
        minute INTEGER,
        duration INTEGER,
        PRIMARY KEY(timer_id))""";
        
        private static const string SELECT_ALL_GROUPS =
        "SELECT * FROM device_groups";
        
        private static const string SELECT_DEVICES =
        "SELECT * FROM devices WHERE group_id=?";
        
        private static const string DELETE_GROUP =
        "DELETE FROM device_groups WHERE group_id=?";
        
        private static const string INSERT_GROUP =
        "INSERT INTO device_groups VALUES (?, ?, ?, ?, ?)";
        
        private static const string CONTAINS_GROUP =
        "SELECT COUNT(*) FROM device_groups WHERE group_id=?";
        
        private static const string DELETE_DEVICE =
        "DELETE FROM devices WHERE adapter=? AND frontend=?";
        
        private static const string INSERT_DEVICE =
        "INSERT INTO devices VALUES (?, ?, ?)";
        
        private static const string SELECT_TIMERS =
        "SELECT * FROM timers WHERE group_id=?";
        
        private static const string DELETE_TIMER =
        "DELETE FROM timers WHERE timer_id=?";
        
        private static const string INSERT_TIMER =
        "INSERT INTO timers VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)";
        
        private static const string CONTAINS_TIMER =
        "SELECT COUNT(*) FROM timers WHERE timer_id=?";
        
        private Statement select_devices_statement;
        private Statement delete_group_statement;
        private Statement insert_group_statement;
        private Statement delete_device_statement;
        private Statement insert_device_statement;
        private Statement select_timers_statement;
        private Statement delete_timer_statement;
        private Statement insert_timer_statement;
        private Statement contains_group_statement;
        private Statement contains_timer_statement;
        
        // Database must be the last parameter, because the statements
        // MUST be finalized first before the database is closed
        private Database db;
        
        construct {
            this.db = get_db_handler ();
            
            this.db.prepare (SELECT_DEVICES, -1,
                out this.select_devices_statement);
            this.db.prepare (DELETE_GROUP, -1,
                out this.delete_group_statement);
            this.db.prepare (INSERT_GROUP, -1,
                out this.insert_group_statement);
            this.db.prepare (DELETE_DEVICE, -1,
                out this.delete_device_statement);
            this.db.prepare (INSERT_DEVICE, -1,
                out this.insert_device_statement);
            this.db.prepare (SELECT_TIMERS, -1,
                out this.select_timers_statement);
            this.db.prepare (DELETE_TIMER, -1,
                out this.delete_timer_statement);
            this.db.prepare (INSERT_TIMER, -1,
                out this.insert_timer_statement);
            this.db.prepare (CONTAINS_GROUP, -1,
                out this.contains_group_statement);
            this.db.prepare (CONTAINS_TIMER, -1,
                out this.contains_timer_statement);
        }
        
        public Gee.List<DeviceGroup> get_all_device_groups () {
            Gee.List<DeviceGroup> groups = new ArrayList<DeviceGroup> ();
        
            Statement statement;
            if (this.db.prepare (SELECT_ALL_GROUPS, -1, out statement) != Sqlite.OK) {
                this.print_last_error ();
                return groups;
            }
            
            while (statement.step () == Sqlite.ROW) {
                int group_id = statement.column_int (0);
                
                this.select_devices_statement.reset ();
                if (this.select_devices_statement.bind_int (1, group_id) != Sqlite.OK) {
                    this.print_last_error ();
                    continue;
                }
                
                // Get devices of group
                Gee.List<Device> devs = new ArrayList<Device> ();
                while (this.select_devices_statement.step () == Sqlite.ROW) {
                    uint adapter =
                        (uint)this.select_devices_statement.column_int (1);
                    uint frontend =
                        (uint)this.select_devices_statement.column_int (2);
                        
                    // Create new device
                    devs.add (new Device (adapter, frontend));
                }
                
                // No devices for this group
                if (devs.size == 0) {
                    debug ("Group %d has no devices", group_id);
                    continue;
                }
                
                // Get adapter type
                int group_type = statement.column_int (1);
                AdapterType type;
                switch (group_type) {
                    case 0: type = AdapterType.DVB_T; break;
                    case 1: type = AdapterType.DVB_S; break;
                    case 2: type = AdapterType.DVB_C; break;
                    default:
                    debug ("Group %d has unknown type %d",
                        group_id, group_type);
                    continue;
                }
                
                // Get channel list
                File channels_file = File.new_for_path (
                    statement.column_text (2));
                ChannelList channels; 
                try {
                    channels = ChannelList.restore_from_file (
                        channels_file, type);
                } catch (Error e) {
                    warning ("Could not read channels: %s", e.message);
                    continue;
                }
                    
                File rec_dir = File.new_for_path (
                    statement.column_text (3));
                    
                // Set reference device
                Device ref_dev = devs.get (0);
                ref_dev.Channels = channels;
                ref_dev.RecordingsDirectory = rec_dir;
                
                // Create device group
                DeviceGroup group = new DeviceGroup ((uint)group_id, ref_dev);
                group.Name = statement.column_text (4);
                
                groups.add (group);
            }
            
            return groups;
        }
        
        public void add_device_group (DeviceGroup dev_group) {
            if (this.contains_group (dev_group.Id)) return;
        
            string channels = dev_group.Channels.channels_file.get_path ();
            string recdir = dev_group.RecordingsDirectory.get_path ();
        
            this.insert_group_statement.reset ();
            if (this.insert_group_statement.bind_int (1, (int)dev_group.Id) != Sqlite.OK
                || this.insert_group_statement.bind_int (2, (int)dev_group.Type) != Sqlite.OK
                || this.insert_group_statement.bind_text (3, channels) != Sqlite.OK
                || this.insert_group_statement.bind_text (4, recdir) != Sqlite.OK
                || this.insert_group_statement.bind_text (5, dev_group.Name) != Sqlite.OK) {
                this.print_last_error ();
                return;
            }
            
            if (this.insert_group_statement.step () != Sqlite.DONE) {
                this.print_last_error ();
                return;
            }
            
            foreach (Device dev in dev_group)
                this.add_device_to_group (dev, dev_group);
        }
        
        public void remove_device_group (DeviceGroup devgroup) {
            this.delete_group_statement.reset ();
            if (this.delete_group_statement.bind_int (1, (int)devgroup.Id) != Sqlite.OK) {
                this.print_last_error ();
                return;
            }
            
            if (this.delete_group_statement.step () != Sqlite.DONE)
                this.print_last_error ();
        }
        
        public bool contains_group (uint group_id) {
            this.contains_group_statement.reset ();
            if (this.contains_group_statement.bind_int (1, (int)group_id) != Sqlite.OK)
            {
                this.print_last_error ();
                return false;
            }
            
            int c = 0;
            while (this.contains_group_statement.step () == Sqlite.ROW) {
                c = this.contains_group_statement.column_int (0);
            }
            
            return (c > 0);
        }
        
        public void add_device_to_group (Device dev, DeviceGroup devgroup) {
            this.insert_device_statement.reset ();
            if (this.insert_device_statement.bind_int (1, (int)devgroup.Id) != Sqlite.OK
                || this.insert_device_statement.bind_int (2, (int)dev.Adapter) != Sqlite.OK
                || this.insert_device_statement.bind_int (3, (int)dev.Frontend) != Sqlite.OK)
            {
                this.print_last_error ();
                return;
            }
            
            if (this.insert_device_statement.step () != Sqlite.DONE)
                this.print_last_error ();
        }
        
        public void remove_device_from_group (Device dev, DeviceGroup devgroup) {
            this.delete_device_statement.reset ();
            if (this.delete_device_statement.bind_int (1, (int)dev.Adapter) != Sqlite.OK
                || this.delete_device_statement.bind_int (2, (int)dev.Frontend) != Sqlite.OK)
            {
                this.print_last_error ();
                return;
            }
            
            if (this.delete_device_statement.step () != Sqlite.DONE)
                this.print_last_error ();        
        }
        
        public Gee.List<Timer> get_all_timers_of_device_group (DeviceGroup dev) {
            Gee.List<Timer> timers = new ArrayList<Timer> ();
            
            this.select_timers_statement.reset ();
            if (this.select_timers_statement.bind_int (1, (int)dev.Id) != Sqlite.OK) {
                this.print_last_error ();
                return timers;
            }
            
            while (this.select_timers_statement.step () == Sqlite.ROW) {
                uint tid, sid, duration;
                int year, month, day, hour, minute;
                
                tid = (uint)this.select_timers_statement.column_int (0);
                sid = (uint)this.select_timers_statement.column_int (2);
                year = this.select_timers_statement.column_int (3);
                month = this.select_timers_statement.column_int (4);
                day = this.select_timers_statement.column_int (5);
                hour = this.select_timers_statement.column_int (6);
                minute = this.select_timers_statement.column_int (7);
                duration = (uint)this.select_timers_statement.column_int (8);
                
                timers.add (new Timer (tid, sid, year, month, day, hour,
                    minute, duration));
            }
            
            return timers;
        }
        
        public void add_timer_to_device_group (Timer timer, DeviceGroup dev) {
            if (this.contains_timer (timer.Id)) return;
            
            this.insert_timer_statement.reset ();
            if (this.insert_timer_statement.bind_int (1, (int)timer.Id) != Sqlite.OK
                || this.insert_timer_statement.bind_int (2, (int)dev.Id) != Sqlite.OK
                || this.insert_timer_statement.bind_int (3, (int)timer.ChannelSid) != Sqlite.OK
                || this.insert_timer_statement.bind_int (4, (int)timer.Year) != Sqlite.OK
                || this.insert_timer_statement.bind_int (5, (int)timer.Month) != Sqlite.OK
                || this.insert_timer_statement.bind_int (6, (int)timer.Day) != Sqlite.OK
                || this.insert_timer_statement.bind_int (7, (int)timer.Hour) != Sqlite.OK
                || this.insert_timer_statement.bind_int (8, (int)timer.Minute) != Sqlite.OK
                || this.insert_timer_statement.bind_int (9, (int)timer.Duration) != Sqlite.OK)
            {
                this.print_last_error ();
                return;
            }
            
            if (this.insert_timer_statement.step () != Sqlite.DONE)
                this.print_last_error ();
        }
        
        public void remove_timer_from_device_group (uint timer_id, DeviceGroup dev) {
            this.delete_timer_statement.reset ();
            
            if (this.delete_timer_statement.bind_int (1, (int)timer_id) != Sqlite.OK)
            {
                this.print_last_error ();
                return;
            }
            
            if (this.delete_timer_statement.step () != Sqlite.DONE)
                this.print_last_error ();
        }
        
        public bool contains_timer (uint timer_id) {
            this.contains_timer_statement.reset ();
            if (this.contains_timer_statement.bind_int (1, (int)timer_id) != Sqlite.OK)
            {
                this.print_last_error ();
                return false;
            }
            
            int c = 0;
            while (this.contains_timer_statement.step () == Sqlite.ROW) {
                c = this.contains_timer_statement.column_int (0);
            }
            
            return (c > 0);
        }
        
        private void print_last_error () {
            critical ("SQLite error: %d, %s",
                this.db.errcode (), this.db.errmsg ());
        }
        
        private static Database? get_db_handler () {
            File config_dir = File.new_for_path (
                Environment.get_user_config_dir ());
            File config_cache = config_dir.get_child ("gnome-dvb-daemon");
            File dbfile = config_cache.get_child ("configtimers.sqlite3");
           
            if (!config_cache.query_exists (null)) {
                try {
                    Utils.mkdirs (config_cache);
                } catch (Error e) {
                    critical (e.message);
                    return null;
                }
            }
            
            bool create_tables = (!dbfile.query_exists (null));
            Database db;
            Database.open (dbfile.get_path (), out db);
            if (create_tables) {
                string errormsg;
                int val = db.exec (CREATE_DEVICE_GROUPS,
                    null, out errormsg);
                if (val != Sqlite.OK) {
                    critical ("SQLite error: %s", errormsg);
                    return null;
                }
                val = db.exec (CREATE_DEVICES,
                    null, out errormsg);
                if (val != Sqlite.OK) {
                    critical ("SQLite error: %s", errormsg);
                    return null;
                }
                val = db.exec (CREATE_TIMERS,
                    null, out errormsg);
                if (val != Sqlite.OK) {
                    critical ("SQLite error: %s", errormsg);
                    return null;
                }
            }
            
            return db;
        }
    
    }

}
