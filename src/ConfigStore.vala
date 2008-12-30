using GLib;

namespace DVB {

    public interface ConfigStore : GLib.Object {
        
        public abstract Gee.ArrayList<DeviceGroup> get_all_device_groups ();
        public abstract void add_device_group (DeviceGroup dev_group);
        public abstract void remove_device_group (DeviceGroup devgroup);
        public abstract void add_device_to_group (Device dev, DeviceGroup devgroup);
        public abstract void remove_device_from_group (Device dev, DeviceGroup devgroup);
        
    }

}
