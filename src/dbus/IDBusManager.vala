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

namespace DVB {

    public struct ChannelGroupInfo {
	    public int id;
	    public string name;
    }
	
    [DBus (name = "org.gnome.DVB.Manager")]
    public interface IDBusManager : GLib.Object {
    
        public abstract signal void group_added (uint group_id);
        public abstract signal void group_removed (uint group_id);
         
        /**
         * @adapter: Number of the device's adapter
         * @frontend: Number of the device's frontend
         * @opath: Object path of the scanner service
         * @dbusiface: DBus interface of the scanner service
         * @returns: TRUE on success
         *
         * Get the object path of the channel scanner for this device.
         */
        public abstract bool GetScannerForDevice (uint adapter, uint frontend,
                out DBus.ObjectPath opath, out string dbusiface) throws DBus.Error;
        
        /**
         * @returns: Device groups' DBus path
         */
        public abstract DBus.ObjectPath[] GetRegisteredDeviceGroups () throws DBus.Error;
        
        /**
         * @group_id: A group ID
         * @opath: Device group's DBus path
         * @returns: TRUE on success
         */
        public abstract bool GetDeviceGroup (uint group_id, out DBus.ObjectPath opath) throws DBus.Error;
        
        /**
         * @adapter: Number of the device's adapter
         * @frontend: Number of the device's frontend
         * @channels_conf: Path to channels.conf for this device
         * @recordings_dir: Path where the recordings should be stored
         * @name: Name of group
         * @returns: TRUE when the device has been registered successfully
         *
         * Creates a new DeviceGroup and new DVB device whereas the
         * DVB device is the reference device of this group (i.e.
         * all other devices of this group will inherit the settings
         * of the reference device).
         */
        public abstract bool AddDeviceToNewGroup (uint adapter, uint frontend,
                string channels_conf, string recordings_dir, string name) throws DBus.Error;

        /**
         * @adapter: Adapter of device
         * @frontend: Frontend of device
         * @name: The name of the device or "Unknown"
         * @returns: TRUE on success
         *
         * The device must be part of group, otherwise "Unknown"
         * is returned.
         */
        public abstract bool GetNameOfRegisteredDevice (uint adapter, uint frontend,
        	out string name) throws DBus.Error;
        
        /**
         * @returns: the numner of configured device groups
         */
        public abstract int GetDeviceGroupSize () throws DBus.Error;

        /**
         * @returns: ID and name of each channel group
         */
        public abstract ChannelGroupInfo[] GetChannelGroups () throws DBus.Error;

        /**
         * @name: Name of the new group
         * @channel_group_id: ID of the ChannelGroup
         * @returns: TRUE on success
         */
        public abstract bool AddChannelGroup (string name, out int channel_group_id) throws DBus.Error;

        /**
         * @channel_group_id: ID of the ChannelGroup
         * @returns: TRUE on success
         */
        public abstract bool RemoveChannelGroup (int channel_group_id) throws DBus.Error;

    }

}
