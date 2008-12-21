using GLib;
using Gee;

namespace DVB {

    /**
     * A group of devices that share the same settings
     * (list of channels, recordings dir)
     */
    public class DeviceGroup : GLib.Object, Iterable<Device> {
    
        public int size {
            get { return this.devices.size; }
        }
        public uint Id {get; construct;}
        public ChannelList Channels {
            get { return this.reference_device.Channels; }
        }
        public File RecordingsDirectory {
            get { return this.reference_device.RecordingsDirectory; }
        }
        public AdapterType Type {
            get { return this.reference_device.Type; }
        }
        // All settings are copied from this one
        public Device reference_device {get; construct;}
        public string Name {get; set;}
                
        private Set<Device> devices;
        
        construct {
            this.devices = new HashSet<Device> (Device.hash, Device.equal);
            this.add (this.reference_device);
        }
        
        /**
         * @reference_device: All devices of this group will inherit
         * the settings from this device
         */
        public DeviceGroup (uint id, Device reference_device) {
            this.Id = id;
            this.reference_device = reference_device;
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
        
            // Set settings from reference device
            device.Channels = this.reference_device.Channels;
            device.RecordingsDirectory = this.reference_device.RecordingsDirectory;
            
            return this.devices.add (device);
        }
        
        public bool contains (Device device) {
            return this.devices.contains (device);
        }
        
        public bool remove (Device device) {
            return this.devices.remove (device);
        }
        
        /**
         * Get first device that isn't busy.
         * If all devices are busy NULL is returned.
         */
        public Device? get_next_free_device () {
            foreach (Device dev in this.devices) {
                if (!dev.is_busy ()) return dev;
            }
            
            return null;
        }
        
        public GLib.Type get_element_type () {
            return typeof(Device);
        }
        
        public Iterator<Device> iterator () {
            return this.devices.iterator();
        }
        
    }
    
}
