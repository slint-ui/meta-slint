// SPDX-License-Identifier: MIT

//! Returns to the Slint demo launcher with a four-finger swipe down from the
//! top edge of the screen.
//!
//! On LinuxKMS the launcher exec()s into the demo it starts, so the demo
//! becomes the main process of slint-launcher.service. This daemon watches the
//! touchscreens through its own libinput context (which doesn't grab them, so
//! the demo keeps receiving their events) and, after four fingers swipe down
//! from the top edge, restarts the service unless the launcher is already
//! showing. libinput applies the touchscreen's calibration matrix, so the top
//! edge and "down" are on screen, matching the coordinates Slint gets from
//! libinput.
//!
//! Starting at the edge keeps the gesture apart from using a demo with several
//! fingers, such as scrolling. Touch controllers can lose all contacts for a
//! moment while the fingers move fast, and report new ones further along. So a
//! gesture runs until no finger has been down for [`GESTURE_GAP_USEC`], and the
//! way the fingers moved down adds up how far the fingers that stay down move,
//! plus how far the fingers jump across such dropouts.

use input::event::touch::{TouchEventPosition, TouchEventSlot, TouchEventTrait};
use input::event::{DeviceEvent, EventTrait, TouchEvent};
use input::{DeviceCapability, Event, Libinput, LibinputInterface, SendEventsMode};
use std::collections::HashMap;
use std::fs::OpenOptions;
use std::os::fd::{AsRawFd, OwnedFd};
use std::os::unix::fs::OpenOptionsExt;
use std::path::Path;
use std::process::{Command, Stdio};

const LAUNCHER_UNIT: &str = "slint-launcher.service";
/// The ExecStart= of LAUNCHER_UNIT.
const LAUNCHER_EXE: &str = "/usr/bin/slint-demo-launcher";

const FINGERS: usize = 4;
/// A gesture ends once no finger has been down for this long, in
/// microseconds.
const GESTURE_GAP_USEC: u64 = 100_000;
/// Touch controllers time-stamp a frame some milliseconds before it can be
/// read. When the clock ends a gesture, it waits this much longer than
/// GESTURE_GAP_USEC, so that fingers coming back just within the gap still
/// count, in microseconds.
const READ_DELAY_USEC: u64 = 20_000;
/// How the fingers move, and where they are, is taken from the frames with at
/// least this many fingers down: a finger or two on their own are doing
/// something else, such as scrolling.
const MIN_MEASURED_FINGERS: usize = 3;
// Vertical positions are fractions of the screen height, from the top. The
// first finger has to touch down above TOP_EDGE, the fingers have to end up
// below MIN_END, and they have to have moved down by at least MIN_TRAVEL; a
// hand put down with one finger near the top doesn't count.
const TOP_EDGE: f64 = 0.1;
const MIN_END: f64 = 1. / 3.;
const MIN_TRAVEL: f64 = 0.1;
/// From the first finger touching down to the last frame with
/// MIN_MEASURED_FINGERS down, a swipe takes at most this long, in
/// microseconds. Swipes take a few tenths of a second; without a limit, a demo
/// used with several fingers and no pause could add up to one over time.
const MAX_SWIPE_USEC: u64 = 1_500_000;

#[derive(Default)]
struct Gesture {
    /// Where the first finger touched down (the highest, if several touched
    /// down in the same frame), and when.
    first_y: f64,
    first_usec: u64,
    max_fingers: usize,
    /// How far the fingers moved down, summed over the frames with at least
    /// MIN_MEASURED_FINGERS down.
    travel: f64,
    /// Where the fingers were, on average, in the latest such frame, and when.
    end: Option<(f64, u64)>,
    /// When all fingers lifted after that frame: a contact dropout, if they
    /// are measured again within GESTURE_GAP_USEC.
    lifted_usec: Option<u64>,
    /// When the gesture ends unless a finger touches down before, as a
    /// libinput event time: GESTURE_GAP_USEC after the last finger lifted.
    ends_at_usec: Option<u64>,
}

/// A finger that is down.
struct Touch {
    y: f64,
    /// Where it was in the latest frame with MIN_MEASURED_FINGERS down,
    /// unless it touched down since.
    previous_y: Option<f64>,
}

#[derive(Default)]
struct Watcher {
    /// The fingers that are down, by seat slot.
    touches: HashMap<u32, Touch>,
    gesture: Option<Gesture>,
}

impl Watcher {
    fn ends_at_usec(&self) -> Option<u64> {
        self.gesture.as_ref()?.ends_at_usec
    }

    fn handle_event(&mut self, event: Event) {
        match event {
            Event::Device(DeviceEvent::Added(event)) => {
                let device = event.device();
                if device.has_capability(DeviceCapability::Touch) {
                    eprintln!(
                        "Watching touchscreen {} ({})",
                        device.sysname(),
                        device.name()
                    );
                } else {
                    // Closes the device, sparing the wakeups for its events.
                    let _ = device.config_send_events_set_mode(SendEventsMode::DISABLED);
                }
            }
            Event::Touch(TouchEvent::Down(event)) => {
                // Judged by the event times, so that a late wakeup doesn't
                // merge a new touch into a gesture that has already ended.
                let time_usec = event.time_usec();
                if self
                    .ends_at_usec()
                    .is_some_and(|ends_at| time_usec >= ends_at)
                    && self.end_gesture()
                {
                    // Returning now would bring the launcher up under this
                    // finger, which it would take for a tap on an entry.
                    eprintln!(
                        "Not returning to the launcher: a finger touched down right after the swipe"
                    );
                }
                let y = event.y_transformed(1);
                self.touches.insert(
                    event.seat_slot(),
                    Touch {
                        y,
                        previous_y: None,
                    },
                );
                self.gesture.get_or_insert_with(|| Gesture {
                    first_usec: time_usec,
                    ..Default::default()
                });
            }
            Event::Touch(TouchEvent::Motion(event)) => {
                if let Some(touch) = self.touches.get_mut(&event.seat_slot()) {
                    touch.y = event.y_transformed(1);
                }
            }
            Event::Touch(TouchEvent::Up(event)) => {
                self.touches.remove(&event.seat_slot());
            }
            Event::Touch(TouchEvent::Cancel(event)) => {
                self.touches.remove(&event.seat_slot());
            }
            Event::Touch(TouchEvent::Frame(event)) => self.handle_frame(event.time_usec()),
            _ => {}
        }
    }

    fn handle_frame(&mut self, time_usec: u64) {
        let Some(gesture) = &mut self.gesture else {
            return;
        };
        let fingers = self.touches.len();
        if fingers == 0 {
            if gesture.end.is_some() {
                gesture.lifted_usec.get_or_insert(time_usec);
            }
            gesture
                .ends_at_usec
                .get_or_insert(time_usec + GESTURE_GAP_USEC);
            return;
        }
        gesture.ends_at_usec = None;
        if gesture.max_fingers == 0 {
            // The gesture's first frame: the highest of the fingers that
            // landed in it.
            gesture.first_y = self
                .touches
                .values()
                .map(|touch| touch.y)
                .fold(f64::INFINITY, f64::min);
        }
        gesture.max_fingers = gesture.max_fingers.max(fingers);
        if fingers < MIN_MEASURED_FINGERS {
            return;
        }

        // How far the fingers that stayed down since the previous measured
        // frame moved, on average; fingers landing or lifting don't count as
        // movement.
        let (mut moved, mut moved_fingers, mut y) = (0., 0, 0.);
        for touch in self.touches.values_mut() {
            if let Some(previous_y) = touch.previous_y.replace(touch.y) {
                moved += touch.y - previous_y;
                moved_fingers += 1;
            }
            y += touch.y;
        }
        if moved_fingers > 0 {
            gesture.travel += moved / moved_fingers as f64;
        }
        let y = y / fingers as f64;
        if let Some(lifted_usec) = gesture.lifted_usec.take()
            && time_usec.saturating_sub(lifted_usec) <= GESTURE_GAP_USEC
            && let Some((end_y, _)) = gesture.end
        {
            // The contacts dropped out and came back further along. Measured
            // as the average position of the fingers in the measured frames
            // before and after, which needn't be the same fingers.
            gesture.travel += y - end_y;
        }
        gesture.end = Some((y, time_usec));
    }

    /// Judges the gesture once the fingers have been off the screen for
    /// GESTURE_GAP_USEC, so that moving them back up (with at least
    /// MIN_MEASURED_FINGERS) before lifting cancels the swipe. Returns whether
    /// it was a swipe.
    fn end_gesture(&mut self) -> bool {
        let Some(gesture) = self.gesture.take() else {
            return false;
        };
        let Some((end_y, end_usec)) = gesture.end else {
            return false;
        };
        if gesture.max_fingers < FINGERS {
            return false;
        }
        let duration_usec = end_usec.saturating_sub(gesture.first_usec);
        let swiped = gesture.first_y < TOP_EDGE
            && end_y > MIN_END
            && gesture.travel > MIN_TRAVEL
            && duration_usec <= MAX_SWIPE_USEC;
        if !swiped {
            // To help tell why a swipe didn't count.
            eprintln!(
                "{}-finger touch with the first finger at {:.2}, moving down by {:.2} to {end_y:.2} of the screen height in {:.2} s, wasn't a swipe down from the top edge",
                gesture.max_fingers,
                gesture.first_y,
                gesture.travel,
                duration_usec as f64 / 1e6
            );
        }
        swiped
    }
}

/// The main process of LAUNCHER_UNIT, if the unit is active; not, for example,
/// already restarting after an earlier swipe.
fn launcher_main_pid() -> Option<u32> {
    let output = match Command::new("systemctl")
        .args(["show", "--property=ActiveState,MainPID", LAUNCHER_UNIT])
        .stderr(Stdio::inherit())
        .output()
    {
        Ok(output) if output.status.success() => output,
        Ok(_) => {
            eprintln!("Cannot query {LAUNCHER_UNIT}");
            return None;
        }
        Err(err) => {
            eprintln!("Cannot run systemctl: {err}");
            return None;
        }
    };
    let output = String::from_utf8_lossy(&output.stdout);
    let state = property(&output, "ActiveState");
    let main_pid = property(&output, "MainPID");
    match (state, main_pid.and_then(|pid| pid.parse().ok())) {
        (Some("active"), Some(pid)) if pid != 0 => Some(pid),
        _ => {
            eprintln!(
                "{LAUNCHER_UNIT} is {} with main PID {}",
                state.unwrap_or("unknown"),
                main_pid.unwrap_or("unknown")
            );
            None
        }
    }
}

/// The value of `name` in `systemctl show` output.
fn property<'a>(output: &'a str, name: &str) -> Option<&'a str> {
    output
        .lines()
        .find_map(|line| line.strip_prefix(name)?.strip_prefix('='))
}

fn return_to_launcher() {
    let Some(pid) = launcher_main_pid() else {
        return;
    };
    let exe = match std::fs::read_link(format!("/proc/{pid}/exe")) {
        Ok(exe) => exe,
        Err(err) => {
            eprintln!("Cannot read /proc/{pid}/exe: {err}");
            return;
        }
    };
    let exe = exe.to_string_lossy();
    // The launcher binary may have been replaced since it started.
    if exe.strip_suffix(" (deleted)").unwrap_or(&exe) == LAUNCHER_EXE {
        return; // the launcher is already showing
    }

    eprintln!("Stopping {exe} (pid {pid}) to return to the launcher");
    match Command::new("systemctl")
        .args(["try-restart", "--no-block", LAUNCHER_UNIT])
        .status()
    {
        Ok(status) if status.success() => {}
        _ => eprintln!("Cannot restart {LAUNCHER_UNIT}"),
    }
}

struct Interface;

impl LibinputInterface for Interface {
    fn open_restricted(&mut self, path: &Path, flags: i32) -> Result<OwnedFd, i32> {
        let access = flags & libc::O_ACCMODE;
        OpenOptions::new()
            .custom_flags(flags)
            .read(access != libc::O_WRONLY)
            .write(access != libc::O_RDONLY)
            .open(path)
            .map(OwnedFd::from)
            .map_err(|err| err.raw_os_error().unwrap_or(libc::EIO))
    }

    fn close_restricted(&mut self, fd: OwnedFd) {
        drop(fd);
    }
}

/// The current time on the clock of libinput's event times.
fn now_usec() -> u64 {
    let mut now = libc::timespec {
        tv_sec: 0,
        tv_nsec: 0,
    };
    unsafe { libc::clock_gettime(libc::CLOCK_MONOTONIC, &mut now) };
    now.tv_sec as u64 * 1_000_000 + now.tv_nsec as u64 / 1000
}

fn main() {
    let mut libinput = Libinput::new_with_udev(Interface);
    if libinput.udev_assign_seat("seat0").is_err() {
        eprintln!("Cannot set up libinput");
        std::process::exit(1);
    }

    let mut watcher = Watcher::default();
    loop {
        if let Err(err) = libinput.dispatch() {
            eprintln!("Cannot read input events: {err}");
            std::process::exit(1);
        }
        for event in &mut libinput {
            watcher.handle_event(event);
        }

        let mut timeout = -1;
        if let Some(ends_at) = watcher.ends_at_usec() {
            let ends_at = ends_at + READ_DELAY_USEC;
            let now = now_usec();
            if ends_at <= now {
                // The screen is clear, so the launcher can come up.
                if watcher.end_gesture() {
                    return_to_launcher();
                }
            } else {
                // Rounded up, so as not to wake up just before the gesture ends.
                timeout = (ends_at - now).div_ceil(1000) as i32;
            }
        }
        let mut fds = libc::pollfd {
            fd: libinput.as_raw_fd(),
            events: libc::POLLIN,
            revents: 0,
        };
        if unsafe { libc::poll(&mut fds, 1, timeout) } < 0 {
            let err = std::io::Error::last_os_error();
            if err.kind() != std::io::ErrorKind::Interrupted {
                eprintln!("poll: {err}");
                std::process::exit(1);
            }
        }
    }
}
