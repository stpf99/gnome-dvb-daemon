/*
 * Copyright (C) 2008,2009 Sebastian Pölsterl
 *
 * This file is part of GNOME DVB Daemon.
 *
 * GNOME DVB Daemon is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * GNOME DVB Daemon is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with GNOME DVB Daemon.  If not, see <http://www.gnu.org/licenses/>.
 */

using GLib;
using Gee;
using DVB.database;

namespace DVB {

    /**
     * A group of devices that share the same settings
     * (list of channels, recordings dir)
     */
    public class DeviceGroup : GLib.Object, IDBusDeviceGroup, Iterable<Device> {
    
        public int size {
            get { return this.devices.size; }
        }
        public uint Id {get; construct;}
        public ChannelList Channels {
            get { return this.reference_device.Channels; }
        }
        public File RecordingsDirectory {
            get { return this.reference_device.RecordingsDirectory; }
            set {
                this.reference_device.RecordingsDirectory = value;
                this.update_all_devices ();
            }
        }
        public AdapterType Type {
            get { return this.reference_device.Type; }
        }
        public Recorder recorder {
            get { return this._recorder; }
        }
        public EPGScanner epgscanner {
            get { return this._epgscanner; }
        }
        public ChannelFactory channel_factory {
            get { return this._channelfactory; }
        }
        public string Name {get; set;}
                
        // All settings are copied from this one
        public Device reference_device {get; construct;}
        
        private Set<Device> devices;
        private Recorder _recorder;
        private EPGScanner? _epgscanner;
        private ChannelFactory _channelfactory;
        
        // Containss object paths to Schedule 
        private HashSet<string> schedules;
        
        construct {
            this.devices = new HashSet<Device> (Device.hash, Device.equal);
            this.schedules = new HashSet<string> (GLib.str_hash,
                GLib.str_equal);
            this.devices.add (this.reference_device);
            this._channelfactory = new ChannelFactory (this);
            this._recorder = new Recorder (this);
        }
        
        /**
         * @id: ID of group
         * @reference_device: All devices of this group will inherit
         * the settings from this device
         * @with_epg_scanner: Whether to provide an EPG scanner
         */
        public DeviceGroup (uint id, Device reference_device,
                bool with_epg_scanner=true) {
            this.Id = id;
            this.reference_device = reference_device;
            this.reference_device.Channels.GroupId = id;
            if (with_epg_scanner) {
                this._epgscanner = new EPGScanner (this);
            } else {
                this._epgscanner = null;
            }
            this.register_channel_list ();
            this.register_recorder ();
        }

        public void destroy () {
            debug ("Destroying group %u", this.Id);
            if (this._epgscanner != null) {
                this._epgscanner.stop ();
            }
            this._recorder.stop ();
            this._channelfactory.destroy ();
            this.schedules.clear ();
            lock (this.devices) {
                this.devices.clear ();
            }
        }
        
        /**
         * @adapter: Number of the device's adapter
         * @frontend: Number of the device's frontend
         *
         * Creates a new device first and adds it to the group.
         * The new device inherits the settings from the reference
         * device.
         */
        public void create_and_add_device (uint adapter, uint frontend) {
            Device new_dev = new Device (adapter, frontend);
            this.add (new_dev);
        }
        
        /**
         * Add device to group. The device's settings will be overridden
         * with those of the reference device.
         */
        public bool add (Device device) {
            if (device.Type != this.Type) {
                warning ("Cannot add device, because it is not of same type");
                return false;
            }
        
            bool result;
            lock (this.devices) {
                // Set settings from reference device
                device.Channels = this.reference_device.Channels;
                device.RecordingsDirectory = this.reference_device.RecordingsDirectory;
                
                result = this.devices.add (device);
            }
            return result;
        }
        
        public bool contains (Device device) {
            bool result;
            lock (this.devices) {
                result = this.devices.contains (device);
            }
            return result;
        }
        
        public bool remove (Device device) {
            bool result;
            lock (this.devices) {
                result = this.devices.remove (device);
            }
            return result;
        }
        
        /**
         * Get first device that isn't busy.
         * If all devices are busy NULL is returned.
         */
        public Device? get_next_free_device () {
            Device? result = null;
            lock (this.devices) {
                foreach (Device dev in this.devices) {
                    if (!dev.is_busy ()) {
                        result = dev;
                        break;
                    }
                }
            }
            
            return result;
        }
        
        /**
         * @returns: Name of adapter type the group holds
         * or an empty string when group with given id doesn't exist.
         */
        public string GetType () {
            string type_str;
            switch (this.Type) {
                case AdapterType.DVB_T: type_str = "DVB-T"; break;
                case AdapterType.DVB_S: type_str = "DVB-S"; break;
                case AdapterType.DVB_C: type_str = "DVB-C"; break;
                default: type_str = ""; break;
            }
            return type_str;
        }
        
        /**
         * @adapter: Number of the device's adapter
         * @frontend: Number of the device's frontend
         * @returns: TRUE when the device has been registered successfully
         *
         * Creates a new device and adds it to the DeviceGroup.
         * The new device will inherit all settings from the group's
         * reference device.
         */
        public bool AddDevice (uint adapter, uint frontend)throws DBus.Error {
            // When the device is already registered we
            // might see some errors if the device is
            // currently in use
            Device device = new Device (adapter, frontend);
                
            if (device == null) return false;
            
            Manager manager = Manager.get_instance ();
            if (manager.device_is_in_any_group (device)) {
                debug ("Device with adapter %u, frontend %u is" + 
                    "already part of a group", adapter, frontend);
                return false;
            }
                
            uint group_id = this.Id;
            debug ("Adding device with adapter %u, frontend %u to group %u",
                adapter, frontend, group_id);

            if (this.add (device)) {
                try {
                    Factory.get_config_store ().add_device_to_group (device,
                        this);
                } catch (SqlError e) {
                    critical ("%s", e.message);
                    return false;
                }
                
                this.device_added (adapter, frontend);
            
                return true;
            }
            
            return false;
        }
        
        /**
         * @returns: Object path of the device's recorder
         * 
         * Returns the object path to the device's recorder.
         */
        public DBus.ObjectPath GetRecorder () throws DBus.Error {
            return new DBus.ObjectPath (
                Constants.DBUS_RECORDER_PATH.printf (this.Id));
        }   
            
        protected bool register_recorder () {
            debug ("Creating new Recorder D-Bus service for group %u",
                this.Id);
            
            Recorder recorder = this.recorder;
            
            var conn = Utils.get_dbus_connection ();
            if (conn == null) return false;
            
            string path = Constants.DBUS_RECORDER_PATH.printf (this.Id);
            conn.register_object (
                path,
                recorder);
                
            return true;
        }
        
        /**
         * @adapter: Number of the device's adapter
         * @frontend: Number of the device's frontend
         * @returns: TRUE when device has been removed successfully
         *
         * Removes the device from the group. If the group contains
         * no devices after the removal it's removed as well.
         */
        public bool RemoveDevice (uint adapter, uint frontend) throws DBus.Error {
            Device dev = new Device (adapter, frontend, false);
            
            if (this.contains (dev)) {
                if (this.remove (dev)) {
                    // Stop epgscanner, because it might use the
                    // device we want to unregister
                    if (this.epgscanner != null) this.epgscanner.stop ();

                    try {
                        Factory.get_config_store ().remove_device_from_group (
                            dev, this);
                    } catch (SqlError e) {
                        critical ("%s", e.message);
                        return false;
                    }
                    // Group has no devices anymore, delete it
                    if (this.size > 0 && this.epgscanner != null) {
                        // We still have a device, start EPG scanner again
                        this.epgscanner.start ();
                    }

                    this.device_removed (adapter, frontend);
                    
                    return true;
                }
            }
            
            return false;
        }
        
        /**
         * @returns: Name of the device group
         */
        public string GetName () throws DBus.Error {
            return this.Name;
        }
        
        /**
         * @name: Name of the group
         * @returns: TRUE on success
         */
        public bool SetName (string name) throws DBus.Error {
            this.Name = name;
            try {
                ConfigStore config = Factory.get_config_store();
                config.update_from_group (this);
            } catch (SqlError e) {
                critical ("%s", e.message);
                return false;
            }
            return true;
        }
        
        /**
         * @returns: Object path to the ChannelList service for this device
         */
        public DBus.ObjectPath GetChannelList () throws DBus.Error {
            return new DBus.ObjectPath (
                Constants.DBUS_CHANNEL_LIST_PATH.printf (this.Id));
        }
        
        protected bool register_channel_list () {
            debug ("Creating new ChannelList D-Bus service for group %u",
                this.Id);
            
            ChannelList channels = this.Channels;
            
            var conn = Utils.get_dbus_connection ();
            if (conn == null) return false;
            
            string path = Constants.DBUS_CHANNEL_LIST_PATH.printf (this.Id);
            conn.register_object (
                path,
                channels);
            
            return true;
        }
        
        /**
         * @returns: List of paths to the devices that are part of
         * the group (e.g. /dev/dvb/adapter0/frontend0)
         */
        public string[] GetMembers () throws DBus.Error {
            string[] groupdevs = new string[this.size];
            
            int i=0;
            lock (this.devices) {
                foreach (Device dev in this.devices) {
                    groupdevs[i] = Constants.DVB_DEVICE_PATH.printf (
                        dev.Adapter, dev.Frontend);
                    i++;
                }
            }
            
            return groupdevs;
        }
        /**
         * @channel_sid: ID of the channel
         * @returns: Object path to Schedule service
         */
        public DBus.ObjectPath GetSchedule (uint channel_sid) throws DBus.Error {
            if (this.Channels.contains (channel_sid)) {
                string path = Constants.DBUS_SCHEDULE_PATH.printf (this.Id, channel_sid);
                
                if (!this.schedules.contains (path)) {
                    var conn = Utils.get_dbus_connection ();
                    if (conn == null) new DBus.ObjectPath ("");
                    
                    Schedule schedule = this.Channels.get_channel (
                        channel_sid).Schedule;
                    
                    conn.register_object (
                        path,
                        schedule);
                        
                    this.schedules.add (path);
                }
                
                return new DBus.ObjectPath (path);
            }
        
            return new DBus.ObjectPath ("");
        }

        /**
         * @returns: Location of the recordings directory
         */
        public string GetRecordingsDirectory () throws DBus.Error {
            return this.RecordingsDirectory.get_path ();
        }
        
        /**
         * @location: Location of the recordings directory
         * @returns: TRUE on success
         */
        public bool SetRecordingsDirectory (string location) throws DBus.Error {
            this.RecordingsDirectory = File.new_for_path (location);
            try {
                ConfigStore config = Factory.get_config_store();
                config.update_from_group (this);
            } catch (SqlError e) {
                critical ("%s", e.message);
                return false;
            }
            return true;
        }
        
        public Type element_type { get { return typeof (Device); } }
        
        public Iterator<Device> iterator () {
            return this.devices.iterator();
        }
        
        /**
         * Set RecordingsDirectory property of all
         * devices to the values of the reference device
         */
        private void update_all_devices () {
            lock (this.devices) {
                foreach (Device device in this.devices) {
                    if (device != this.reference_device) {
                        device.RecordingsDirectory = this.reference_device.RecordingsDirectory;
                    }
                }
            }
        }
        
    }
    
}
