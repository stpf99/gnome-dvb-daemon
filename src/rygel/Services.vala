/*
 * Copyright (C) 2009 Sebastian Pölsterl
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

namespace DVB {
    
    private static const string SERVICE_NAME = "org.gnome.UPnP.MediaServer1.DVBDaemon";
    private static const string ROOT_PATH = "/org/gnome/UPnP/MediaServer1/DVBDaemon";
    
    private static const string GROUP_PATH = "/org/gnome/UPnP/MediaServer1/DVBDaemon/Group%u";
    private static const string CHANNEL_PATH = GROUP_PATH + "/Channel%u";
    
    /**
     * Holds all device groups
     *
     * It only contains containers only and no items
     */
    public class DeviceGroupsMediaContainer : GLib.Object, MediaContainer1, MediaObject1 {
        
        private HashMap<uint, ChannelsMediaContainer> containers;
        private DBus.ObjectPath path;
        
        construct {
            containers = new  HashMap<uint, ChannelsMediaContainer> ();
        
            Manager manager = Manager.get_instance ();
            manager.group_added.connect (this.on_device_added);
            manager.group_removed.connect (this.on_device_removed);
            
            this.path = new DBus.ObjectPath (ROOT_PATH);
        }
        
        public void create_container_services () {
            Manager manager = Manager.get_instance ();
            
            foreach (DeviceGroup devgroup in manager.device_groups) {
                this.create_service (devgroup);
            }
        }
        
        private void create_service (DeviceGroup devgroup) {
            debug ("Creating container for device group %u", devgroup.Id);
        
            var conn = Utils.get_dbus_connection ();
            if (conn == null) {
                critical ("Could not get DBus connection");
                return;
            }
            var devgroup_container = new ChannelsMediaContainer (
                    devgroup, this.path);
            conn.register_object (
                    devgroup_container.Path,
                    devgroup_container);
            devgroup_container.create_item_services ();
                    
            this.containers.set (devgroup.Id, devgroup_container);
        }
        
        public DBus.ObjectPath Parent {
            owned get {
                // root container => ref to itsself
                return this.path;
            }
        }
        
        public string DisplayName {
            get {
                return Config.PACKAGE_NAME;
            }
        }
    
        public DBus.ObjectPath[] Items {
            owned get {
                return new DBus.ObjectPath[0];
            }
        }
        
        public uint ItemCount {
            get {
                return 0;
            }
        }
        
        public DBus.ObjectPath[] Containers {
            owned get {
                DBus.ObjectPath[] paths = new DBus.ObjectPath[this.containers.size];
                int i = 0;
                foreach (ChannelsMediaContainer container in this.containers.get_values ()) {
                    paths[i] = new DBus.ObjectPath (container.Path);
                    i++;
                }
                return paths;
            }
        }
        
        public uint ContainerCount {
            get {
                return this.containers.size;
            }
        }
        
        private void on_device_added (uint group_id) {
            Manager manager = Manager.get_instance ();
            DeviceGroup devgroup = manager.get_device_group_if_exists (group_id);
            this.create_service (devgroup);
            this.Updated ();
        }
        
        private void on_device_removed (uint group_id) {
            this.containers.remove (group_id);
            this.Updated ();
        }
    }
    

    /**
     * Holds a list of channels for a single device group
     *
     * It only contains items only and no containers
     */
    public class ChannelsMediaContainer : GLib.Object, MediaContainer1, MediaObject1 {
    
        public DeviceGroup device_group {
            get; construct;
        }
        public string Path {
            owned get {
                return GROUP_PATH.printf (this.device_group.Id);
            }
        }
        public DBus.ObjectPath parent;
        
        private HashMap<uint, ChannelMediaItem> items;
        
        construct {
            this.items = new HashMap<uint, ChannelMediaItem> ();
        }
        
        public ChannelsMediaContainer(DeviceGroup devgroup, DBus.ObjectPath parent) {
            this.device_group = devgroup;
            this.parent = parent;
        }
        
        public void create_item_services () {
            foreach (Channel channel in this.device_group.Channels) {
                this.create_service (channel);
            }
        }
        
        public void create_service (Channel channel) {
            debug ("Creating container for channel %u", channel.Sid);
        
            var conn = Utils.get_dbus_connection ();
            if (conn == null) {
                critical ("Could not get DBus connection");
                return;
            }
            var channel_item = new ChannelMediaItem (
                    channel, new DBus.ObjectPath (this.Path));
            conn.register_object (
                    channel_item.Path,
                    channel_item);
                    
            this.items.set (channel.Sid, channel_item);
        }
    
        public DBus.ObjectPath Parent {
            get {
                return this.parent;
            }
        }
        
        public string DisplayName {
            get {
                return this.device_group.Name;
            }
        }
    
        public DBus.ObjectPath[] Items {
            owned get {
                DBus.ObjectPath[] paths = new DBus.ObjectPath[this.items.size];
                int i = 0;
                foreach (ChannelMediaItem item in this.items.get_values ()) {
                    paths[i] = new DBus.ObjectPath (item.Path);
                    i++;
                }
                return paths;
            }
        }
        
        public uint ItemCount {
            get {
                return this.items.size;
            }
        }
        
        public DBus.ObjectPath[] Containers {
            owned get {
                return new DBus.ObjectPath[0];
            }
        }
        
        public uint ContainerCount {
            get {
                return 0;
            }
        }
    }
    
    
    /**
     * Holds a single channel
     */
    public class ChannelMediaItem : GLib.Object, MediaItem1, MediaObject1 {
    
        public Channel channel {
            get; construct;
        }
        public string Path {
            owned get {
                return CHANNEL_PATH.printf (channel.GroupId, channel.Sid);
            }
        }
        
        private DBus.ObjectPath parent;
        
        public ChannelMediaItem(Channel channel, DBus.ObjectPath parent) {
            this.channel = channel;
            this.parent = parent;
        }
    
        public DBus.ObjectPath Parent {
            get {
                return this.parent;
            }
        }
        
        public string DisplayName {
            get {
                return this.channel.Name;
            }
        }
    
         public string[] URLs {
            owned get {
                return new string[] {
                    this.channel.URL
                };
            }
        }
        
        public string MIMEType {
            get {
                return "video/mpegts";
            }
        }
        
        public string Type {
            get {
                return "video";
            }
        }
    }

    public class RygelService {
        
        private static DeviceGroupsMediaContainer root_container;
        
        public static bool start_rygel_services () {
            try {
                var conn = DBus.Bus.get (DBus.BusType.SESSION);
                
                dynamic DBus.Object bus = conn.get_object (
                        "org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus");
                
                // try to register service in session bus
                uint request_name_result = bus.RequestName (SERVICE_NAME, (uint) 0);

                if (request_name_result == DBus.RequestNameReply.PRIMARY_OWNER) {
                    message ("Creating new Rygel MediaServer D-Bus service");
                
                    root_container = new DeviceGroupsMediaContainer ();
                    root_container.create_container_services ();
                                    
                    conn.register_object (
                        root_container.Parent,
                        root_container);
                } else {
                    warning ("Rygel MediaServer D-Bus service is already running");
                    return false;
                }

            } catch (Error e) {
                error ("Oops %s", e.message);
                return false;
            }
            return true;
        }
    }
    
}
