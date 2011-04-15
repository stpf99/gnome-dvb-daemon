import gnomedvb
import gobject
import unittest
import sys
import random
import datetime
import time
import re
from gi.repository import GLib

class DVBTestCase(unittest.TestCase):

    def assertSuccessAndType(self, data, objtype):
        self.assertType(data[1], bool)
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
        self.assertType(data, list)
        for cid, name in data:
            self.assertType(cid, int)
            self.assertType(name, str)
            
    def testAddDeleteChannelGroup(self):
        name = "Test Group %f" % random.random()
        data = self.manager.add_channel_group(name)
        self.assertSuccessAndType(data, int)
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
            self.assertType(dtype, str)
            self.assert_(dtype in ("DVB-C", "DVB-S", "DVB-T"))
            name_before = dg.get_name()
            self.assertType(name_before, str)
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
            self.assertType(dg.get_recordings_directory(), str)

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
                scanner = self.manager.get_scanner_for_device(int(adapter),
                    int(frontend))
                self.assertType(scanner, gnomedvb.DVBScannerClient)

                data = {"frequency": GLib.Variant('u', 738000000),
                    "hierarchy": GLib.Variant('u', 0), # NONE
                    "bandwidth": GLib.Variant('u', 8), # 8MHz
                    "transmission-mode": GLib.Variant('s', "8k"),
                    "code-rate-hp": GLib.Variant('s', "2/3"),
                    "code-rate-lp": GLib.Variant('s', "NONE"),
                    "constellation": GLib.Variant('s', "QAM16"),
                    "guard-interval": GLib.Variant('u', 4),} # 1/4
                success = scanner.add_scanning_data(data)
                self.assertTrue(success)
                self.assertType(success, bool)
                scanner.run()

                time.sleep(15)

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
            self.assertTypeAll(ids, long)
            for cid in ids:
                self.assertSuccessAndType(cl.get_channel_name(cid),
                    str)
                self.assertSuccessAndType(cl.get_channel_network(cid),
                    str)
                self.assertSuccessAndType(cl.get_channel_url(cid),
                    str)
                    
    def testGetChannelInfos(self):
        for cl in self.chanlists:
            for cid, name, is_radio in cl.get_channel_infos():
                self.assertType(cid, long)
                self.assertType(name, str)
                self.assertType(is_radio, bool)
            
    def testGetTVChannels(self):
        for cl in self.chanlists:
            ids = cl.get_tv_channels()
            self.assertTypeAll(ids, long)
            for cid in ids:
                data = cl.is_radio_channel(cid)
                self.assertSuccessAndType(data, bool)
                self.assertFalse(data[0])
            
    def testGetRadioChannels(self):
        for cl in self.chanlists:
            ids = cl.get_radio_channels()
            self.assertTypeAll(ids, long)
            for cid in ids:
                data = cl.is_radio_channel(cid)
                self.assertSuccessAndType(data, bool)
                self.assertTrue(data[0])
                
    def testGetChannelsOfGroup(self):
        for cl in self.chanlists:
            all_channels = set(cl.get_channels())
            for gid in self.changroups:
                data = cl.get_channels_of_group(gid)
                self.assertTrue(data[1])
                self.assertTypeAll(data[0], long)
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
        self.assertTypeAll(actual, long)
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
            self.assertSuccessAndType(data, long)
            rec_id = data[0]

            data = rec.get_start_time(rec_id)
            self.assertSuccessAndType(data, list)
            start = data[0]
            self._assert_time_equals(delayed, start)
        
            data = rec.get_duration(rec_id)
            self.assertSuccessAndType(data, long)
            self.assertEqual(data[0], self.DURATION * 2)
                
            self.assertTrue(rec.set_start_time(rec_id, now.year, now.month,
                now.day, now.hour, now.minute))
            
            data = rec.get_start_time(rec_id)
            self.assertSuccessAndType(data, list)
            start = data[0]
            self._assert_time_equals(now, start)

            self.assertTrue(rec.set_duration(rec_id, self.DURATION))
            
            data = rec.get_duration(rec_id)
            self.assertSuccessAndType(data, long)
            self.assertEqual(data[0], self.DURATION)
            
            time.sleep(10)
            
            self.assert_(rec_id in rec.get_active_timers())
            self.assertTrue(rec.is_timer_active(rec_id))
            self.assertTrue(rec.has_timer(now.year, now.month, now.day,
                now.hour, now.minute, self.DURATION))
            
            data = rec.get_end_time(rec_id)
            self.assertSuccessAndType(data, list)
            end = data[0]
            self.assertTypeAll(end, long)
            self.assertEqual(len(end), 5)
            endt = datetime.datetime(*end)
            self.assertEqual(endt - now,
                datetime.timedelta(minutes=self.DURATION))
            
            self.assertSuccessAndType(rec.get_channel_name(rec_id),
                str)
            self.assertSuccessAndType(rec.get_title(rec_id), str)
            
            data = rec.get_all_informations(rec_id)
            self.assertSuccessAndType(data, tuple)
            rid, duration, active, channel, title = data[0]
            self.assertEqual(rid, rec_id)
            self.assertEqual(duration, self.DURATION)
            self.assertTrue(active)
            self.assertType(channel, str)
            self.assertType(title, str)

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
        self.assertSuccessAndType(sched.get_name(eid), str)
        self.assertSuccessAndType(sched.get_short_description(eid),
            str)
        self.assertSuccessAndType(sched.get_extended_description(eid),
            str)
        self.assertSuccessAndType(sched.get_duration(eid), long)
        data = sched.get_local_start_time(eid)
        self.assertSuccessAndType(data, list)
        self.assertTypeAll(data[0], long)
        self.assertSuccessAndType(sched.get_local_start_timestamp(eid),
            long)
        self.assertSuccessAndType(sched.is_running(eid), bool)
        self.assertSuccessAndType(sched.is_scrambled(eid), bool)
        
        data = sched.get_informations(eid)
        self.assertSuccessAndType(data, tuple)
        eeid, next, name, duration, desc = data[0]
        self.assertEqual(eeid, eid)
        self.assertType(next, long)
        self.assertType(name, str)
        self.assertType(duration, long)
        self.assertType(desc, str)
                
    def testNowPlaying(self):
        for sched in self.schedules:
            eid = sched.now_playing()
            self.assertType(eid, long)
            if eid != 0:
                self._get_event_details(sched, eid)
                
    def testNext(self):
        for sched in self.schedules:
            eid = sched.now_playing()
            while eid != 0:
                eid = sched.next(eid)
                self.assertType(eid, long)
                
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
                str)
            self.assertSuccessAndType(self.recstore.get_location(rid),
                str)
            start_data = self.recstore.get_start_time(rid)
            self.assertSuccessAndType(start_data, list)
            start = start_data[0]
            self.assertEqual(len(start), 5)
            self.assertTypeAll(start, long)
            self.assertSuccessAndType(self.recstore.get_start_timestamp(rid),
                long)
            self.assertSuccessAndType(self.recstore.get_length(rid),
                long)
            self.assertSuccessAndType(self.recstore.get_name (rid),
                str)
            self.assertSuccessAndType(self.recstore.get_description(rid),
                str)
            
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
            self.assertType(data[1], bool)
            self.assertTrue(data[1])
            self.assertType(data[0], tuple)
            rrid, name, desc, length, ts, chan, loc = data[0]
            self.assertType(rrid, long)
            self.assertEqual(rrid, rid)
            self.assertType(name, str)
            self.assertType(desc, str)
            self.assertType(length, long)
            self.assertType(ts, long)
            self.assertType(chan, str)
            self.assertType(loc, str)
            
    def testGetAllInformationsNotExists(self):
        rid = 1000
        data = self.recstore.get_all_informations(rid)
        self.assertType(data[1], bool)
        self.assertFalse(data[1])


if __name__ == '__main__':
    loop = gobject.MainLoop()
    
    unittest.main()
    loop.run()

