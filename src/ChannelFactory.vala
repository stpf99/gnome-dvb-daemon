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
using Gst;

namespace DVB {

    /**
     * This class handles watching channels one physical device.
     * 
     * It's possible to watch multiple channels at the same time
     * if they are all on the same transport stream.
     *
     * The class is able to reuse channels that are already watched
     * and forward EPG data to #EPGScanner.
     */
    public class PlayerThread : GLib.Object {
        
        private class ChannelElements {
            public Gst.Element sink;
            public Gst.Element tee;
        }

        /** 
         * Emitted when we came across EIT table
         */
        public signal void eit_structure (Gst.Structure structure);
        
        // List of channels that are currently in use
        public HashSet<Channel> active_channels {get; construct;}
        // The device in use
        public Device device {get; construct;}
        
        private Element? pipeline;
        private HashMap<string, ChannelElements> elements_map;
        private EPGScanner? epgscanner;
        private Element? dvbbasebin;
        
        construct {
            this.elements_map = new HashMap<string, ChannelElements> (GLib.str_hash, GLib.str_equal,
                    GLib.direct_equal);
            this.active_channels = new HashSet<Channel> ();
        }
        
        /**
         * @device: The device to use
         * @epgscanner: #EPGScanner to forward EIT to
         */
        public PlayerThread (Device device, EPGScanner? epgscanner) {
            this.device = device;
            this.epgscanner = epgscanner;
        }
        
        public Gst.Element? get_pipeline () {
            return this.pipeline;
        }
        
        public Gst.Element? get_dvbbasebin () {
            return this.dvbbasebin;
        }
        
        /**
         * @returns: GstBin containing queue and @sink_element 
         *
         * Start watching @channel and link it with @sink_element
         */
        public Gst.Element? get_element (Channel channel, owned Gst.Element? sink_element) {
            uint channel_sid = channel.Sid;
            string channel_sid_str = channel_sid.to_string ();
            
            Element? bin, tee = null;
            if (this.pipeline == null) {
                debug ("Creating new pipeline");
                // Setup new pipeline
                this.pipeline = new Pipeline ("recording");
            
                Gst.Bus bus = this.pipeline.get_bus();
                bus.add_signal_watch();
                bus.message += this.bus_watch_func;
                
                this.dvbbasebin = ElementFactory.make ("dvbbasebin", null);
                if (this.dvbbasebin == null) {
                    critical ("Could not create dvbbasebin element");
                    return null;
                }
                this.dvbbasebin.pad_added += this.on_dvbbasebin_pad_added;
                
                channel.setup_dvb_source (this.dvbbasebin);
                
                this.dvbbasebin.set ("program-numbers", channel_sid_str);
                this.dvbbasebin.set ("adapter", this.device.Adapter);
                this.dvbbasebin.set ("frontend", this.device.Frontend);
                
                // don't use add_many because of problems with ownership transfer    
                ((Bin) this.pipeline).add (this.dvbbasebin);
                
                tee = ElementFactory.make ("tee", null);
                this.add_element (tee);
                
                bin = this.add_sink_bin (sink_element);
                if (!tee.link (bin)) critical ("Could not link tee and bin");
            } else {
                // Use current pipeline and add new sink
                debug ("Reusing existing pipeline");
                
                if (this.dvbbasebin == null) {
                    critical ("No dvbbasebin element");
                    return null;
                }
                
                if (!this.active_channels.contains (channel)) {
                    tee = ElementFactory.make ("tee", null);
                    this.add_element (tee);
                    
                    bin = this.add_sink_bin (sink_element);
                    if (!tee.link (bin)) critical ("Could not link tee and bin");
                
                    this.pipeline.set_state (State.PAUSED);
                    
                    string programs;
                    dvbbasebin.get ("program-numbers", out programs);
                    
                    string new_programs = "%s:%s".printf (programs,
                        channel_sid_str);
                    debug ("Changing program-numbers from %s to %s", programs,
                        new_programs);
                    this.dvbbasebin.set ("program-numbers", new_programs);
                } else {
                    tee = this.elements_map.get (channel_sid_str).tee;
                    
                    bin = this.add_sink_bin (sink_element);
                    if (!tee.link (bin)) critical ("Could not link tee and bin");
                }
            }
            
            // TODO same channel different queue and sink?
            ChannelElements celems = new ChannelElements ();
            celems.sink = bin;
            celems.tee = tee;
                    
            this.elements_map.set (channel_sid_str, celems);
            
            this.active_channels.add (channel);
            
            return bin;
        }
        
        private Gst.Element add_sink_bin (Gst.Element sink_element) {
            Element queue = ElementFactory.make ("queue", null);
            queue.set ("max-size-buffers", 0);
            
            Gst.Element bin = new Gst.Bin (null);
            ((Gst.Bin)bin).add_many (queue, sink_element);
            queue.link (sink_element);
            
            var pad = queue.get_static_pad ("sink");
            bin.add_pad (new Gst.GhostPad ("sink", pad));
            
            this.add_element (bin);

            return bin;
        }
        
        /**
         * @sid: Channel SID
         * @returns: GstBin containing queue and sink for the specified channel
         */
        public Gst.Element? get_sink_bin (uint sid) {
            ChannelElements? celems = this.elements_map.get (sid.to_string ());
            if (celems == null) return null;
            
            return celems.sink;
        }
        
        /**
         * Stop watching @channel
         */
        public bool remove_channel (Channel channel) {
            if (!this.active_channels.contains (channel)) {
                critical ("Could not find channel with SID %u", channel.Sid);
                return false;
            }
            
            // Check if that's the only channel in use
            if (this.active_channels.size > 1) {
                string channel_sid_string = channel.Sid.to_string ();
                
                string programs;
                dvbbasebin.get ("program-numbers", out programs);
                string[] programs_arr = programs.split (":");
                
                // Remove SID of channel from program-numbers
                SList<string> new_programs_list = new SList<string> ();
                for (int i=0; i<programs_arr.length; i++) {
                    string val = programs_arr[i];
                    if (val != channel_sid_string)
                        new_programs_list.prepend (val);
                }
                
                StringBuilder new_programs = new StringBuilder (new_programs_list.nth_data (0));
                for (int i=1; i<new_programs_list.length (); i++) {
                    new_programs.append (":" + new_programs_list.nth_data (i));
                }
                
                ChannelElements celements = this.elements_map.get (channel_sid_string);
                Element? sink = celements.sink;
                
                debug ("Setting state of queue and sink to NULL");
                sink.set_state (State.NULL);
                
                debug ("Removing queue and sink from pipeline");
                ((Bin)this.pipeline).remove (sink);
                
                debug ("Changing program-numbers from %s to %s", programs,
                        new_programs.str);
                this.pipeline.set_state (State.PAUSED);
                
                dvbbasebin.set ("program-numbers", new_programs.str);
                
                this.pipeline.set_state (State.PLAYING);
                
                this.active_channels.remove (channel);
            } else {
                this.destroy ();
            }
        
            return false;
        }
        
        /**
         * Stop pipeline and clean up everything else
         */
        public virtual void destroy () {
            if (this.pipeline != null) {
                debug ("Stopping pipeline");
                Gst.Bus bus = this.pipeline.get_bus ();
                bus.remove_signal_watch ();
                this.pipeline.set_state (State.NULL);
            }
            this.pipeline = null;
            this.elements_map.clear ();
            this.active_channels.clear ();
        }

        private bool add_element (owned Gst.Element elem) {
            string elem_name = elem.get_name ();
            if (!((Bin) this.pipeline).add (elem)) {
                critical ("Could not add element %s", elem_name);
                return false;
            }
            debug ("Element %s added to pipeline", elem_name);
            return true;
        }
        
        /**
         * Link program_%d pad with tee
         */
        private void on_dvbbasebin_pad_added (Gst.Element elem, Gst.Pad pad) {
            string pad_name = pad.get_name();
            debug ("Pad %s added", pad_name);
            
            if (!pad_name.has_prefix ("program_"))
                return;
            
            string sid = pad_name.substring (8, pad_name.size() - 8);
            
            debug ("SID is '%s'", sid);
            // Check if we're interested in the pad
            if (this.elements_map.contains (sid)) {
                Element? sink = this.elements_map.get (sid).tee;
                if (sink == null) {
                    critical ("Could not find sink for SID %s", sid);
                    return;
                }
                
                debug ("Linking elements %s and %s", elem.get_name(), sink.get_name ());
                Pad sinkpad = sink.get_static_pad ("sink");
                
                PadLinkReturn rc = pad.link (sinkpad);
                if (rc != PadLinkReturn.OK) {
                    critical ("Could not link pads %s and %s", pad.get_name (),
                        sinkpad.get_name ());
                } else {
                    debug ("Src pad %s linked with sink pad %s",
                        pad.get_name (), sinkpad.get_name ());
                }
            }
        }
        
        /**
         * Forward EIT structure
         */
        private void bus_watch_func (Gst.Bus bus, Gst.Message message) {
            switch (message.type) {
                case Gst.MessageType.ELEMENT:
                    string structure_name = message.structure.get_name();
                    if (structure_name == "eit") {
                        if (this.epgscanner != null)
                            this.epgscanner.on_eit_structure (message.structure);
                        this.eit_structure (message.structure);
                    }
                break;
                
                default:
                break;
            }
        }
    }

    /**
     * This class handles watching channels for a single #DeviceGroup
     */
    public class ChannelFactory : GLib.Object {
    
        // The device group the factory belongs to
        public unowned DeviceGroup device_group {get; construct;}
        
        // List of players that are currently in use
        private HashSet<PlayerThread> active_players;
        
        public ChannelFactory (DeviceGroup devgroup) {
            this.device_group = devgroup;
            this.active_players = new HashSet<PlayerThread> ();
        }
        
        public void destroy () {
            foreach (PlayerThread active_player in this.active_players) {
                active_player.destroy ();
            }
            this.active_players.clear ();
        }

        /**
         * @returns: The #PlayerThread used to watch @channel
         *
         * Watch @channel and use @sink_element as sink element
         */
        public PlayerThread? watch_channel (Channel channel, owned Gst.Element? sink_element) {
            debug ("Watching channel %s (%u)", channel.Name, channel.Sid);
        
            bool create_new = true;
            PlayerThread player = null;
            foreach (PlayerThread active_player in this.active_players) {
                foreach (Channel other_channel in active_player.active_channels) {
                    if (channel.on_same_transport_stream (other_channel)) {
                        create_new = false;
                        player = active_player;
                        break;
                    }
                }
            }
            
            debug ("Creating new PlayerThread: %s", create_new.to_string ());
            if (create_new) {
                // Stop epgscanner before starting recording
                EPGScanner? epgscanner = this.device_group.epgscanner;
                if (epgscanner != null) epgscanner.stop ();

                DVB.Device? free_device = this.device_group.get_next_free_device ();
                if (free_device == null) {
                    critical ("All devices are busy");
                    return null;
                }

                player = this.create_player (free_device);
            }

            player.get_element (channel, sink_element);
            this.active_players.add (player);
            
            return player;
        }
        
        /**
         * @returns: TRUE on success
         *
         * Stop watching @channel
         */
        public bool stop_channel (Channel channel) {
            debug ("Stopping channel %s (%u)", channel.Name, channel.Sid);
        
            bool success = false;
            PlayerThread? player = null;
            foreach (PlayerThread active_player in this.active_players) {
                if (active_player.active_channels.contains (channel)) {
                    success = active_player.remove_channel (channel);
                    player = active_player;
                    break;
                }
            }
            
            if (success && player.active_channels.size == 0)
                this.active_players.remove (player);
            
            if (this.active_players.size == 0) {
                // Start EPG scanner again
                EPGScanner? epgscanner = this.device_group.epgscanner;
                if (epgscanner != null) epgscanner.start ();
            }
            
            return success;
        }
        
        /**
         * @returns: a new #PlayerThread instance for @device
         */
        public virtual PlayerThread create_player (Device device) {
            return new PlayerThread (device, this.device_group.epgscanner);
        }
    
    }

}
