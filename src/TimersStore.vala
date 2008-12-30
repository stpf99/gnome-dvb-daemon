using GLib;

namespace DVB {

    public interface TimersStore : GLib.Object {
        
        public abstract Gee.ArrayList<Timer> get_all_timers_of_device_group (DeviceGroup dev);
        public abstract void add_timer_to_device_group (Timer timer, DeviceGroup dev);
        public abstract void remove_timer_from_device_group (uint timer_id, DeviceGroup dev);
        
    }

}
