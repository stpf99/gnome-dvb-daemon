import gnomedvb
import gobject
import unittest
import dbus
import sys
import random
import datetime
import time
import re

class DVBTestCase(unittest.TestCase):

    def assertSuccessAndType(self, data, objtype):
        self.assertType(data[1], dbus.Boolean)
        self.assertTrue(data[1])
        self.assertType(data[0], objtype)
        
    def assertTypeAll(self, objlist, objtype):
        for obj in objlist:
            self.assertType(obj, objtype)
            
    def assertType(self, obj, objtype):
        if not isinstance(obj, objtype):
            raise self.failureException, \
                "%r is not %r" % (obj, objtype)


class TestManager(DVBTestCase):

    def setUp(self):
        self.manager = gnomedvb.DVBManagerClient()
            
    def testGetChannelGroups(self):
        data = self.manager.get_channel_groups()
        self.assertType(data, dbus.Array)
        for cid, name in data:
            self.assertType(cid, dbus.Int32)
            self.assertType(name, dbus.String)
            
    def testAddDeleteChannelGroup(self):
        name = "Test Group %f" % random.random()
        data = self.manager.add_channel_group(name)
        self.assertSuccessAndType(data, dbus.Int32)
        has_group = False
        for gid, gname in self.manager.get_channel_groups():
            if gid == data[0]:
                self.assertEqual(name, gname)
                has_group = True
                break
        self.assertTrue(has_group)
        self.assertTrue(self.manager.remove_channel_group(data[0]))
        
    def testAddDeviceNotExists(self):
        adapter = 9
        frontend = 0
        
        self.assertFalse(self.manager.add_device_to_new_group (
            adapter, frontend,
            "channels.conf", "Recordings", "Test Group"))


class DeviceGroupTestCase(DVBTestCase):

    def setUp(self):
        self.manager = gnomedvb.DVBManagerClient()
        self.devgroups = self.manager.get_registered_device_groups()
        self.assertTypeAll(self.devgroups, gnomedvb.DVBDeviceGroupClient)    


class TestDeviceGroup(DeviceGroupTestCase):
        
    def testGetSetType(self):
        for dg in self.devgroups:
            dtype = dg.get_type()
            self.assertType(dtype, dbus.String)
            self.assert_(dtype in ("DVB-C", "DVB-S", "DVB-T"))
            name_before = dg.get_name()
            self.assertType(name_before, dbus.String)
            new_name = "%s %f" % (name_before, random.random())
            self.assertTrue(dg.set_name(new_name))
            self.assertEqual(dg.get_name(), new_name)
            self.assertTrue(dg.set_name(name_before))
            
    def testGetMembers(self):
        for dg in self.devgroups:
            for member in dg.get_members():
                self.assert_(member.startswith("/dev/dvb/adapter"))
                
    def testGetRecordingsDirectory(self):
        for dg in self.devgroups:
            self.assertType(dg.get_recordings_directory(), dbus.String)

class TestScanner(DeviceGroupTestCase):

    def setUp(self):
        DeviceGroupTestCase.setUp(self)
        self.path_regex = re.compile(r"/dev/dvb/adapter(\d+)/frontend(\d+)")

    def testGetScanner(self):
        for dg in self.devgroups:
            for member in dg.get_members():
                match = self.path_regex.search(member)
                self.assertNotEqual(match, None)
                adapter, frontend = match.group(1, 2)
                scanner = self.manager.get_scanner_for_device(adapter,
                    frontend)
                self.assertType(scanner, gnomedvb.DVBScannerClient)
                scanner.destroy()


class TestChannelList(DeviceGroupTestCase):
    
    def setUp(self):
        DeviceGroupTestCase.setUp(self)
        self.chanlists = []
        for dg in self.devgroups:
            self.chanlists.append(dg.get_channel_list())
        self.assertTypeAll(self.chanlists, gnomedvb.DVBChannelListClient)
        self.changroups = [data[0] for data in self.manager.get_channel_groups()]
        
    def testGetChannels(self):
        for cl in self.chanlists:
            ids = cl.get_channels()
            self.assertTypeAll(ids, dbus.UInt32)
            for cid in ids:
                self.assertSuccessAndType(cl.get_channel_name(cid),
                    dbus.String)
                self.assertSuccessAndType(cl.get_channel_network(cid),
                    dbus.String)
                self.assertSuccessAndType(cl.get_channel_url(cid),
                    dbus.String)
                    
    def testGetChannelInfos(self):
        for cl in self.chanlists:
            for cid, name, is_radio in cl.get_channel_infos():
                self.assertType(cid, dbus.UInt32)
                self.assertType(name, dbus.String)
                self.assertType(is_radio, dbus.Boolean)
            
    def testGetTVChannels(self):
        for cl in self.chanlists:
            ids = cl.get_tv_channels()
            self.assertTypeAll(ids, dbus.UInt32)
            for cid in ids:
                data = cl.is_radio_channel(cid)
                self.assertSuccessAndType(data, dbus.Boolean)
                self.assertFalse(data[0])
            
    def testGetRadioChannels(self):
        for cl in self.chanlists:
            ids = cl.get_radio_channels()
            self.assertTypeAll(ids, dbus.UInt32)
            for cid in ids:
                data = cl.is_radio_channel(cid)
                self.assertSuccessAndType(data, dbus.Boolean)
                self.assertTrue(data[0])
                
    def testGetChannelsOfGroup(self):
        for cl in self.chanlists:
            all_channels = set(cl.get_channels())
            for gid in self.changroups:
                data = cl.get_channels_of_group(gid)
                self.assertTrue(data[1])
                self.assertTypeAll(data[0], dbus.UInt32)
                group_chans = set(data[0])
                other_chans = all_channels - group_chans
                for chan in other_chans:
                    self.assertTrue(cl.add_channel_to_group(chan, gid))
                    data = cl.get_channels_of_group(gid)
                    self.assertTrue(chan in data[0])
                    self.assertTrue(cl.remove_channel_from_group(chan, gid))
                
    def testChannelNotExists(self):
        cid = 1000
        for cl in self.chanlists:
            self.assertFalse(cl.get_channel_name(cid)[1])
            self.assertFalse(cl.get_channel_network(cid)[1])
            self.assertFalse(cl.get_channel_url(cid)[1])
            self.assertFalse(cl.is_radio_channel(cid)[1])
            self.assertFalse(cl.add_channel_to_group(cid, 1000))
            self.assertFalse(cl.remove_channel_from_group(cid, 1000))


class TestRecorder(DeviceGroupTestCase):

    DURATION = 2

    def _get_time_now(self):
        nowt = datetime.datetime.now()
        # We don't want (micro)seconds
        now = datetime.datetime(nowt.year, nowt.month,
            nowt.day, nowt.hour, nowt.minute)
        return now

    def setUp(self):
        DeviceGroupTestCase.setUp(self)
        self.recorder = []
        self.channels = []
        for dg in self.devgroups:
            chanlist = dg.get_channel_list()
            self.channels.append(chanlist.get_tv_channels()[0])
            self.recorder.append(dg.get_recorder())
        self.assertTypeAll(self.recorder, gnomedvb.DVBRecorderClient)

    def _assert_time_equals(self, expected, actual):
        self.assertTypeAll(actual, dbus.UInt32)
        self.assertEqual(len(actual), 5)
        self.assertEqual(expected.year, actual[0])
        self.assertEqual(expected.month, actual[1])
        self.assertEqual(expected.day, actual[2])
        self.assertEqual(expected.hour, actual[3])
        self.assertEqual(expected.minute, actual[4])
 
    def testAddTimer(self):
        for i, rec in enumerate(self.recorder):
            now = self._get_time_now()
            delay = datetime.timedelta(hours=2)
            delayed = now + delay
            chan = self.channels[i]

            data = rec.add_timer(chan, delayed.year, delayed.month,
                delayed.day, delayed.hour, delayed.minute, self.DURATION * 2)
            self.assertSuccessAndType(data, dbus.UInt32)
            rec_id = data[0]

            data = rec.get_start_time(rec_id)
            self.assertSuccessAndType(data, dbus.Array)
            start = data[0]
            self._assert_time_equals(delayed, start)
        
            data = rec.get_duration(rec_id)
            self.assertSuccessAndType(data, dbus.UInt32)
            self.assertEqual(data[0], self.DURATION * 2)
                
            self.assertTrue(rec.set_start_time(rec_id, now.year, now.month,
                now.day, now.hour, now.minute))
            
            data = rec.get_start_time(rec_id)
            self.assertSuccessAndType(data, dbus.Array)
            start = data[0]
            self._assert_time_equals(now, start)

            self.assertTrue(rec.set_duration(rec_id, self.DURATION))
            
            data = rec.get_duration(rec_id)
            self.assertSuccessAndType(data, dbus.UInt32)
            self.assertEqual(data[0], self.DURATION)
            
            time.sleep(10)
            
            self.assert_(rec_id in rec.get_active_timers())
            self.assertTrue(rec.is_timer_active(rec_id))
            self.assertTrue(rec.has_timer(now.year, now.month, now.day,
                now.hour, now.minute, self.DURATION))
            
            data = rec.get_end_time(rec_id)
            self.assertSuccessAndType(data, dbus.Array)
            end = data[0]
            self.assertTypeAll(end, dbus.UInt32)
            self.assertEqual(len(end), 5)
            endt = datetime.datetime(*end)
            self.assertEqual(endt - now,
                datetime.timedelta(minutes=self.DURATION))
            
            self.assertSuccessAndType(rec.get_channel_name(rec_id),
                dbus.String)
            self.assertSuccessAndType(rec.get_title(rec_id), dbus.String)
            
            data = rec.get_all_informations(rec_id)
            self.assertSuccessAndType(data, dbus.Struct)
            rid, duration, active, channel, title = data[0]
            self.assertEqual(rid, rec_id)
            self.assertEqual(duration, self.DURATION)
            self.assertTrue(active)
            self.assertType(channel, dbus.String)
            self.assertType(title, dbus.String)

            self.assertFalse(rec.set_start_time(rec_id, delayed.year,
                delayed.month, delayed.day, delayed.hour, delayed.minute))
            
            time.sleep(20)
            self.assertTrue(rec.delete_timer(rec_id))
            self.assertFalse(rec.has_timer(now.year, now.month, now.day,
                now.hour, now.minute, self.DURATION))
            
    def testTimerNotExists(self):
        rec_id = 1000
        for rec in self.recorder:
            self.assertFalse(rec.delete_timer(rec_id))
            self.assertFalse(rec.get_start_time(rec_id)[1])
            self.assertFalse(rec.get_end_time(rec_id)[1])
            self.assertFalse(rec.get_duration(rec_id)[1])
            self.assertFalse(rec.get_channel_name(rec_id)[1])
            self.assertFalse(rec.get_title(rec_id)[1])
            self.assertFalse(rec.is_timer_active(rec_id))
            self.assertFalse(rec.get_all_informations(rec_id)[1])
            self.assertFalse(rec.set_start_time(rec_id, 2010, 1, 5, 15, 0))

    
class TestSchedule(DeviceGroupTestCase):

    def setUp(self):
        DeviceGroupTestCase.setUp(self)
        self.schedules = []
        for dg in self.devgroups:
            chanlist = dg.get_channel_list()
            for chan in chanlist.get_channels():
                self.schedules.append(dg.get_schedule(chan))
        self.assertTypeAll(self.schedules, gnomedvb.DVBScheduleClient)
        
    def testGetAllEvents(self):
        for sched in self.schedules:
            for eid in sched.get_all_events():
                self._get_event_details(sched, eid)
            
    def _get_event_details(self, sched, eid):
        self.assertSuccessAndType(sched.get_name(eid), dbus.String)
        self.assertSuccessAndType(sched.get_short_description(eid),
            dbus.String)
        self.assertSuccessAndType(sched.get_extended_description(eid),
            dbus.String)
        self.assertSuccessAndType(sched.get_duration(eid), dbus.UInt32)
        data = sched.get_local_start_time(eid)
        self.assertSuccessAndType(data, dbus.Array)
        self.assertTypeAll(data[0], dbus.UInt32)
        self.assertSuccessAndType(sched.get_local_start_timestamp(eid),
            dbus.Int64)
        self.assertSuccessAndType(sched.is_running(eid), dbus.Boolean)
        self.assertSuccessAndType(sched.is_scrambled(eid), dbus.Boolean)
        
        data = sched.get_informations(eid)
        self.assertSuccessAndType(data, dbus.Struct)
        eeid, next, name, duration, desc = data[0]
        self.assertEqual(eeid, eid)
        self.assertType(next, dbus.UInt32)
        self.assertType(name, dbus.String)
        self.assertType(duration, dbus.UInt32)
        self.assertType(desc, dbus.String)
                
    def testNowPlaying(self):
        for sched in self.schedules:
            eid = sched.now_playing()
            self.assertType(eid, dbus.UInt32)
            if eid != 0:
                self._get_event_details(sched, eid)
                
    def testNext(self):
        for sched in self.schedules:
            eid = sched.now_playing()
            while eid != 0:
                eid = sched.next(eid)
                self.assertType(eid, dbus.UInt32)
                
    def testEventNotExists(self):
        eid = 1
        for sched in self.schedules:
            self.assertFalse(sched.get_name(eid)[1])
            self.assertFalse(sched.get_short_description(eid)[1])
            self.assertFalse(sched.get_extended_description(eid)[1])
            self.assertFalse(sched.get_duration(eid)[1])
            self.assertFalse(sched.get_local_start_time(eid)[1])
            self.assertFalse(sched.get_local_start_timestamp(eid)[1])
            self.assertFalse(sched.is_running(eid)[1])
            self.assertFalse(sched.is_scrambled(eid)[1])
            self.assertFalse(sched.get_informations(eid)[1])


class TestRecordingsStore(DVBTestCase):

    def setUp(self):
        self.recstore = gnomedvb.DVBRecordingsStoreClient()
        
    def testGetRecordings(self):
        rec_ids = self.recstore.get_recordings()
        for rid in rec_ids:
            self.assertSuccessAndType(self.recstore.get_channel_name(rid),
                dbus.String)
            self.assertSuccessAndType(self.recstore.get_location(rid),
                dbus.String)
            start_data = self.recstore.get_start_time(rid)
            self.assertSuccessAndType(start_data, dbus.Array)
            start = start_data[0]
            self.assertEqual(len(start), 5)
            self.assertTypeAll(start, dbus.UInt32)
            self.assertSuccessAndType(self.recstore.get_start_timestamp(rid),
                dbus.Int64)
            self.assertSuccessAndType(self.recstore.get_length(rid),
                dbus.Int64)
            self.assertSuccessAndType(self.recstore.get_name (rid),
                dbus.String)
            self.assertSuccessAndType(self.recstore.get_description(rid),
                dbus.String)
            
    def testGetRecordingsNotExists(self):
        rid = 1000
        self.assertFalse(self.recstore.get_channel_name(rid)[1])
        self.assertFalse(self.recstore.get_location(rid)[1])
        self.assertFalse(self.recstore.get_start_time(rid)[1])
        self.assertFalse(self.recstore.get_start_timestamp(rid)[1])
        self.assertFalse(self.recstore.get_length(rid)[1])
        self.assertFalse(self.recstore.get_name (rid)[1])
        self.assertFalse(self.recstore.get_description(rid)[1])
        
    def testGetAllInformations(self):
        rec_ids = self.recstore.get_recordings()
        for rid in rec_ids:
            data = self.recstore.get_all_informations(rid)
            self.assertType(data[1], dbus.Boolean)
            self.assertTrue(data[1])
            self.assertType(data[0], dbus.Struct)
            rrid, name, desc, length, ts, chan, loc = data[0]
            self.assertType(rrid, dbus.UInt32)
            self.assertEqual(rrid, rid)
            self.assertType(name, dbus.String)
            self.assertType(desc, dbus.String)
            self.assertType(length, dbus.Int64)
            self.assertType(ts, dbus.Int64)
            self.assertType(chan, dbus.String)
            self.assertType(loc, dbus.String)
            
    def testGetAllInformationsNotExists(self):
        rid = 1000
        data = self.recstore.get_all_informations(rid)
        self.assertType(data[1], dbus.Boolean)
        self.assertFalse(data[1])


if __name__ == '__main__':
    loop = gobject.MainLoop()
    
    unittest.main()
    loop.run()

