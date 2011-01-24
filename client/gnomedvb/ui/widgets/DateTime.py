# -*- coding: utf-8 -*-
# Copyright (C) 2010 Sebastian Pölsterl
#
# This file is part of GNOME DVB Daemon.
#
# GNOME DVB Daemon is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# GNOME DVB Daemon is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with GNOME DVB Daemon.  If not, see <http://www.gnu.org/licenses/>.

from gettext import gettext as _
import gobject
from gi.repository import Gdk
from gi.repository import Gtk
import datetime

class CalendarPopup(Gtk.Window):

    __gsignals__ = {
        "closed":  (gobject.SIGNAL_RUN_LAST, gobject.TYPE_NONE, []),
        "changed": (gobject.SIGNAL_RUN_LAST, gobject.TYPE_NONE, [int, int, int, int, int]),
    }

    def __init__(self, dt=None):
        gobject.GObject.__init__(self, type=Gtk.WindowType.POPUP)
        self.set_border_width(5)
        self.vbox = Gtk.VBox(spacing=12)
        self.add(self.vbox)
        
        self.connect("key-press-event", self._on_key_press_event)
        self.connect("button-press-event", self._on_button_press_event)
        
        self.cal = Gtk.Calendar()
        self.cal.connect("day-selected", self._emit_changed)
        self.cal.connect("day-selected-double-click", lambda w: self.popdown())
        self.vbox.pack_start(self.cal, True, True, 0)
        
        self.time_box = Gtk.HBox(spacing=12)
        self.vbox.pack_start(self.time_box, False, True, 0)

        time_label = Gtk.Label()
        time_label.set_markup_with_mnemonic(_("_Time:"))
        self.time_box.pack_start(time_label, False, True, 0)

        spinners_box = Gtk.HBox(spacing=6)
        self.time_box.pack_start(spinners_box, True, True, 0)

        self.hour = Gtk.SpinButton()
        self.hour.connect("changed", self._emit_changed)
        self.hour.set_range(0, 23)
        self.hour.set_increments(1, 3)
        self.hour.set_wrap(True)
        self.hour.set_width_chars(2)
        spinners_box.pack_start(self.hour, True, True, 0)
        time_label.set_mnemonic_widget(self.hour)
        
        self.minute = Gtk.SpinButton()
        self.minute.connect("changed", self._emit_changed)
        self.minute.set_range(0, 59)
        self.minute.set_increments(1, 15)
        self.minute.set_wrap(True)
        self.minute.set_width_chars(2)
        spinners_box.pack_start(self.minute, True, True, 0)

        if dt == None:
            dt = datetime.datetime.now()
        self.set_date_and_time(dt.year, dt.month, dt.day,
            dt.hour, dt.minute)

    def get_calendar(self):
        return self.cal
  
    def popup(self, widget):
        if (self.get_mapped()):
            return
        if not (widget.get_mapped()):
            return
        if not (widget.get_realized()):
            return

        x, y = widget.get_window().get_position()
        rec = widget.get_allocation()
        x += rec.x
        y += rec.y + rec.height

        self.move(x, y)

        self.show_all()

        # For grabbing to work we need the view realized
        if not (self.get_realized()):
            self.realize ()

        self._add_grab()

    def popdown(self):
        self._remove_grab()
        self.emit("closed")
        self.hide()

    def set_date_and_time(self, year, month, day, hour, minute):
        self.cal.select_month(month-1, year)
        self.cal.select_day(day)
        self.hour.set_value(hour)
        self.minute.set_value(minute)

    def get_date_and_time(self):        
        year, mon, day = self.cal.get_date()
        hour = self.hour.get_value_as_int()
        minute = self.minute.get_value_as_int()
        return year, mon+1, day, hour, minute

    def _on_key_press_event(self, widget, event):
        if event.keyval == Gdk.KEY_Escape:
            self.popdown()

    def _on_button_press_event(self, widget, event):
        x, y = self.get_window().get_position()
        alloc = widget.get_allocation()
        # Check if pointer is within the popup
        if not (event.x_root >= x and event.x_root < x + alloc.width \
            and event.y_root >= y and event.y_root < y + alloc.height):
            self.popdown()

    def _add_grab(self):
        window = self.get_window()

        dev = Gtk.get_current_event_device()
        grab_val = dev.grab(window, Gdk.GrabOwnership.WINDOW, True,
            Gdk.EventMask.BUTTON_PRESS_MASK | Gdk.EventMask.BUTTON_RELEASE_MASK,
            None, Gtk.get_current_event_time())
        if grab_val == Gdk.GrabStatus.SUCCESS:
            Gtk.grab_add(self)

    def _remove_grab(self):
        Gtk.grab_remove(self)
        dev = Gtk.get_current_event_device()
        dev.ungrab(Gtk.get_current_event_time())

    def _emit_changed(self, *args):
        year, mon, day, hour, minute = self.get_date_and_time()
        self.emit("changed", year, mon, day, hour, minute)


class DateTimeBox(Gtk.Bin):

    __gsignals__ = {
        "changed": (gobject.SIGNAL_RUN_LAST, gobject.TYPE_NONE, [int, int, int, int, int]),
    }

    def __init__(self, dt=None):
        gobject.GObject.__init__(self)

        self.hbox = Gtk.HBox()

        self.entry = Gtk.Entry()
        self.entry.set_editable(False)

        self.button = Gtk.ToggleButton()
        self.button.connect("toggled", self._on_button_toggled)
        arrow = Gtk.Arrow.new(Gtk.ArrowType.DOWN, Gtk.ShadowType.NONE)
        self.button.add(arrow)

        if dt == None:
            dt = datetime.datetime.now()

        self.popup_win = CalendarPopup(dt)        
        self.popup_win.connect("changed", self._on_datetime_changed)
        self.popup_win.connect("closed", lambda w: self.button.set_active(False))
        
        self.hbox.pack_start(self.entry, True, True, 0)
        self.hbox.pack_start(self.button, False, True, 0)

        self.add(self.hbox)
        self.get_child().show_all()

    def do_size_allocate(self, alloc):
        self.set_allocation(alloc)
        self.get_child().size_allocate(alloc)

    def do_get_preferred_height(self):
        val = self.get_child().get_preferred_height()
        return val

    def do_get_preferred_width(self):
        val = self.get_child().get_preferred_width()
        return val

    def do_get_preferred_height_for_width(self, width):
        return self.get_child().get_preferred_height_for_width(width)

    def do_get_preferred_width_for_height(self, height):
        return self.get_child().get_preferred_width_for_height(height)

    def do_mnemonic_activate(self, group_cycling):
        self.button.grab_focus()
        return True

    def mark_valid(self, val):
        sc = self.get_style_context()        
        # XXX
        #if val:
        #    color = self.style.text[Gtk.StateType.NORMAL]
        #else:
        #    color = self.style.text[Gtk.StateType.INSENSITIVE]
        #self.entry.modify_text(Gtk.StateType.NORMAL, color)

    def get_date_and_time(self):
        return self.popup_win.get_date_and_time()

    def set_date_and_time(self, year, month, day, hour, minute):
        self.popup_win.set_date_and_time(year, month, day, hour, minute)

    def set_editable(self, val):
        self.button.set_sensitive(val)

    def _on_button_toggled(self, button):
        if button.get_active():
            self.popup_win.popup(self)
        else:
            self.popup_win.popdown()

    def _on_datetime_changed(self, calwin, year, mon, day, hour, minute):
        dt = datetime.datetime(year, mon, day, hour, minute)
        self.entry.set_text(dt.strftime("%c"))
        self.emit("changed", year, mon, day, hour, minute)


