use std::{
    collections::HashMap,
    fs,
    path::{Path, PathBuf},
    time::{Duration, Instant},
};

use nvml_wrapper::{Nvml, enum_wrappers::device::TemperatureSensor};
use rustix::fs::statvfs;

use crate::model::{DiskSnapshot, NetworkSnapshot, PerformanceSnapshot, ProcessSnapshot};

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct CpuTicks {
    pub total: u64,
    pub idle: u64,
}

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct MemoryInfo {
    pub memory_total: u64,
    pub memory_available: u64,
    pub swap_total: u64,
    pub swap_free: u64,
}

#[derive(Default)]
pub struct Activity {
    pub screen_recording: bool,
    pub camera_in_use: bool,
}

pub struct Collector {
    previous_cpu: Option<CpuTicks>,
    previous_process_ticks: HashMap<u32, u64>,
    previous_network: Option<(String, u64, u64, Instant)>,
    nvml: Option<Nvml>,
    camera_in_use: bool,
    camera_scan_countdown: u8,
}

impl Collector {
    pub fn new() -> Self {
        Self {
            previous_cpu: None,
            previous_process_ticks: HashMap::new(),
            previous_network: None,
            nvml: Nvml::init().ok(),
            camera_in_use: false,
            camera_scan_countdown: 0,
        }
    }

    pub fn collect(&mut self) -> (PerformanceSnapshot, Activity) {
        let proc_stat = fs::read_to_string("/proc/stat").unwrap_or_default();
        let cpu_ticks = parse_proc_stat(&proc_stat).unwrap_or_default();
        let cpu_count = proc_stat
            .lines()
            .skip(1)
            .take_while(|line| line.starts_with("cpu"))
            .count()
            .max(1);
        let cpu = cpu_percent(self.previous_cpu, cpu_ticks);
        let cpu_delta = self
            .previous_cpu
            .map_or(0, |previous| cpu_ticks.total.saturating_sub(previous.total));
        self.previous_cpu = Some(cpu_ticks);

        let memory = fs::read_to_string("/proc/meminfo")
            .ok()
            .map(|text| parse_meminfo(&text))
            .unwrap_or_default();
        let memory_used = memory.memory_total.saturating_sub(memory.memory_available);
        let swap_used = memory.swap_total.saturating_sub(memory.swap_free);
        let scan_camera = self.camera_scan_countdown == 0;
        let (processes, mut activity) =
            self.collect_processes(memory.memory_total, cpu_delta, cpu_count, scan_camera);
        if scan_camera {
            self.camera_in_use = activity.camera_in_use;
            self.camera_scan_countdown = 4;
        } else {
            activity.camera_in_use = self.camera_in_use;
            self.camera_scan_countdown -= 1;
        }
        let (gpu, gpu_temp, gpu_memory_used, gpu_memory_total) = collect_gpu(self.nvml.as_ref());

        let performance = PerformanceSnapshot {
            cpu,
            gpu,
            memory: percent(memory_used, memory.memory_total),
            swap: percent(swap_used, memory.swap_total),
            cpu_temp: collect_cpu_temp(),
            gpu_temp,
            memory_used,
            memory_total: memory.memory_total,
            swap_used,
            swap_total: memory.swap_total,
            gpu_memory_used,
            gpu_memory_total,
            disk: collect_disk(),
            network: self.collect_network(),
            processes,
        };
        (performance, activity)
    }

    fn collect_network(&mut self) -> NetworkSnapshot {
        let interface = fs::read_to_string("/proc/net/route")
            .ok()
            .and_then(|text| parse_default_route(&text))
            .unwrap_or_default();
        if interface.is_empty() {
            self.previous_network = None;
            return NetworkSnapshot::default();
        }
        let base = Path::new("/sys/class/net")
            .join(&interface)
            .join("statistics");
        let rx = read_u64(base.join("rx_bytes")).unwrap_or(0);
        let tx = read_u64(base.join("tx_bytes")).unwrap_or(0);
        let now = Instant::now();
        let (rx_rate, tx_rate) = self.previous_network.as_ref().map_or(
            (0, 0),
            |(old_interface, old_rx, old_tx, old_time)| {
                if old_interface == &interface {
                    network_rates(*old_rx, *old_tx, rx, tx, now.duration_since(*old_time))
                } else {
                    (0, 0)
                }
            },
        );
        self.previous_network = Some((interface.clone(), rx, tx, now));
        NetworkSnapshot {
            interface,
            rx_bytes_per_second: rx_rate,
            tx_bytes_per_second: tx_rate,
            rx_bytes_total: rx,
            tx_bytes_total: tx,
        }
    }

    fn collect_processes(
        &mut self,
        memory_total: u64,
        cpu_delta: u64,
        cpu_count: usize,
        scan_camera: bool,
    ) -> (Vec<ProcessSnapshot>, Activity) {
        let mut snapshots = Vec::new();
        let mut next_ticks = HashMap::new();
        let mut activity = Activity::default();
        let Ok(entries) = fs::read_dir("/proc") else {
            return (snapshots, activity);
        };
        for entry in entries.flatten() {
            let Some(pid) = entry
                .file_name()
                .to_str()
                .and_then(|name| name.parse::<u32>().ok())
            else {
                continue;
            };
            let path = entry.path();
            let Some((name, ticks, rss_bytes)) = read_process_stat(&path) else {
                continue;
            };
            let cmdline = fs::read(path.join("cmdline")).unwrap_or_default();
            activity.screen_recording |=
                name == "gpu-screen-recorder" || contains_bytes(&cmdline, b"gpu-screen-recorder");
            if scan_camera {
                activity.camera_in_use |= process_uses_camera(&path);
            }
            let previous = self
                .previous_process_ticks
                .get(&pid)
                .copied()
                .unwrap_or(ticks);
            let cpu_percent = if cpu_delta == 0 {
                0.0
            } else {
                ticks.saturating_sub(previous) as f64 * 100.0 * cpu_count as f64 / cpu_delta as f64
            };
            next_ticks.insert(pid, ticks);
            snapshots.push(ProcessSnapshot {
                pid,
                name,
                cpu_percent,
                memory_percent: percent(rss_bytes, memory_total),
                rss_bytes,
            });
        }
        self.previous_process_ticks = next_ticks;
        snapshots.sort_by(|left, right| right.cpu_percent.total_cmp(&left.cpu_percent));
        snapshots.truncate(5);
        (snapshots, activity)
    }
}

pub fn parse_proc_stat(text: &str) -> Option<CpuTicks> {
    let mut fields = text.lines().next()?.split_whitespace();
    if fields.next()? != "cpu" {
        return None;
    }
    let values: Vec<u64> = fields
        .take(8)
        .map(str::parse)
        .collect::<Result<_, _>>()
        .ok()?;
    if values.len() < 4 {
        return None;
    }
    Some(CpuTicks {
        total: values.iter().sum(),
        idle: values[3] + values.get(4).copied().unwrap_or(0),
    })
}

pub fn parse_meminfo(text: &str) -> MemoryInfo {
    let mut result = MemoryInfo::default();
    for line in text.lines() {
        let mut fields = line.split_whitespace();
        let key = fields.next().unwrap_or_default();
        let bytes = fields
            .next()
            .and_then(|value| value.parse::<u64>().ok())
            .unwrap_or(0)
            .saturating_mul(1024);
        match key {
            "MemTotal:" => result.memory_total = bytes,
            "MemAvailable:" => result.memory_available = bytes,
            "SwapTotal:" => result.swap_total = bytes,
            "SwapFree:" => result.swap_free = bytes,
            _ => {}
        }
    }
    result
}

pub fn parse_default_route(text: &str) -> Option<String> {
    text.lines()
        .skip(1)
        .filter_map(|line| {
            let fields: Vec<&str> = line.split_whitespace().collect();
            if fields.len() < 8 || fields[1] != "00000000" {
                return None;
            }
            let flags = u16::from_str_radix(fields[3], 16).ok()?;
            if flags & 1 == 0 {
                return None;
            }
            let metric = fields[6].parse::<u64>().ok()?;
            Some((metric, fields[0].to_owned()))
        })
        .min_by_key(|(metric, _)| *metric)
        .map(|(_, interface)| interface)
}

pub fn network_rates(
    previous_rx: u64,
    previous_tx: u64,
    rx: u64,
    tx: u64,
    elapsed: Duration,
) -> (u64, u64) {
    let seconds = elapsed.as_secs_f64();
    if seconds <= 0.0 {
        return (0, 0);
    }
    (
        (rx.saturating_sub(previous_rx) as f64 / seconds) as u64,
        (tx.saturating_sub(previous_tx) as f64 / seconds) as u64,
    )
}

fn cpu_percent(previous: Option<CpuTicks>, current: CpuTicks) -> f64 {
    let Some(previous) = previous else {
        return percent(current.total.saturating_sub(current.idle), current.total);
    };
    let total = current.total.saturating_sub(previous.total);
    let idle = current.idle.saturating_sub(previous.idle);
    percent(total.saturating_sub(idle), total)
}

fn percent(used: u64, total: u64) -> f64 {
    if total == 0 {
        0.0
    } else {
        used as f64 * 100.0 / total as f64
    }
}

fn read_u64(path: PathBuf) -> Option<u64> {
    fs::read_to_string(path).ok()?.trim().parse().ok()
}

fn read_process_stat(path: &Path) -> Option<(String, u64, u64)> {
    let stat = fs::read_to_string(path.join("stat")).ok()?;
    let name_start = stat.find('(')? + 1;
    let name_end = stat.rfind(')')?;
    let name = stat[name_start..name_end].to_owned();
    let fields: Vec<&str> = stat[name_end + 1..].split_whitespace().collect();
    let ticks = fields.get(11)?.parse::<u64>().ok()? + fields.get(12)?.parse::<u64>().ok()?;
    let pages = fields.get(21)?.parse::<u64>().ok()?;
    Some((name, ticks, pages.saturating_mul(4096)))
}

fn process_uses_camera(path: &Path) -> bool {
    fs::read_dir(path.join("fd")).is_ok_and(|entries| {
        entries.flatten().any(|fd| {
            fs::read_link(fd.path())
                .ok()
                .is_some_and(|target| target.to_string_lossy().starts_with("/dev/video"))
        })
    })
}

fn contains_bytes(haystack: &[u8], needle: &[u8]) -> bool {
    haystack
        .windows(needle.len())
        .any(|window| window == needle)
}

fn collect_disk() -> DiskSnapshot {
    let Ok(info) = statvfs("/") else {
        return DiskSnapshot::default();
    };
    let block_size = info.f_frsize;
    let total = info.f_blocks.saturating_mul(block_size);
    let available = info.f_bavail.saturating_mul(block_size);
    let free = info.f_bfree.saturating_mul(block_size);
    let used = total.saturating_sub(free);
    DiskSnapshot {
        device: root_device(),
        total_bytes: total,
        used_bytes: used,
        available_bytes: available,
        used_percent: percent(used, total),
    }
}

fn root_device() -> String {
    fs::read_to_string("/proc/self/mountinfo")
        .ok()
        .and_then(|text| {
            text.lines().find_map(|line| {
                let (mount, filesystem) = line.split_once(" - ")?;
                (mount.split_whitespace().nth(4)? == "/").then(|| {
                    filesystem
                        .split_whitespace()
                        .nth(1)
                        .unwrap_or_default()
                        .to_owned()
                })
            })
        })
        .unwrap_or_default()
}

fn collect_cpu_temp() -> f64 {
    let Ok(hwmons) = fs::read_dir("/sys/class/hwmon") else {
        return 0.0;
    };
    for hwmon in hwmons.flatten() {
        let Ok(entries) = fs::read_dir(hwmon.path()) else {
            continue;
        };
        for label in entries.flatten() {
            let file_name = label.file_name();
            let Some(file_name) = file_name.to_str() else {
                continue;
            };
            if !file_name.starts_with("temp") || !file_name.ends_with("_label") {
                continue;
            }
            let name = fs::read_to_string(label.path())
                .unwrap_or_default()
                .to_lowercase();
            if !(name.contains("package id 0") || name.contains("tctl") || name.contains("tdie")) {
                continue;
            }
            let input = label
                .path()
                .with_file_name(file_name.replace("_label", "_input"));
            if let Some(value) = read_u64(input) {
                return value as f64 / 1000.0;
            }
        }
    }
    0.0
}

fn collect_gpu(nvml: Option<&Nvml>) -> (f64, f64, u64, u64) {
    if let Some(nvml) = nvml
        && let Ok(device) = nvml.device_by_index(0)
    {
        let gpu = device
            .utilization_rates()
            .map_or(0.0, |rates| f64::from(rates.gpu));
        let temperature = device
            .temperature(TemperatureSensor::Gpu)
            .map_or(0.0, f64::from);
        let memory = device.memory_info().ok();
        return (
            gpu,
            temperature,
            memory.as_ref().map_or(0, |info| info.used / 1024 / 1024),
            memory.as_ref().map_or(0, |info| info.total / 1024 / 1024),
        );
    }

    let Ok(cards) = fs::read_dir("/sys/class/drm") else {
        return (0.0, 0.0, 0, 0);
    };
    for card in cards.flatten() {
        let name = card.file_name();
        if !name.to_string_lossy().starts_with("card") || name.to_string_lossy().contains('-') {
            continue;
        }
        let device = card.path().join("device");
        if fs::read_to_string(device.join("vendor"))
            .ok()
            .as_deref()
            .map(str::trim)
            != Some("0x1002")
        {
            continue;
        }
        let gpu = read_u64(device.join("gpu_busy_percent")).unwrap_or(0) as f64;
        let used = read_u64(device.join("mem_info_vram_used")).unwrap_or(0) / 1024 / 1024;
        let total = read_u64(device.join("mem_info_vram_total")).unwrap_or(0) / 1024 / 1024;
        let temperature = fs::read_dir(device.join("hwmon"))
            .ok()
            .and_then(|mut entries| entries.next()?.ok())
            .and_then(|entry| read_u64(entry.path().join("temp1_input")))
            .map_or(0.0, |value| value as f64 / 1000.0);
        return (gpu, temperature, used, total);
    }
    (0.0, 0.0, 0, 0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_proc_stat() {
        assert_eq!(
            parse_proc_stat("cpu  10 2 3 40 5 6 7 8 0 0\ncpu0 1 2 3 4"),
            Some(CpuTicks {
                total: 81,
                idle: 45
            })
        );
        assert_eq!(parse_proc_stat("intr 1 2"), None);
    }

    #[test]
    fn parses_meminfo_as_bytes() {
        let info = parse_meminfo(
            "MemTotal: 1000 kB\nMemAvailable: 250 kB\nSwapTotal: 500 kB\nSwapFree: 100 kB\n",
        );
        assert_eq!(info.memory_total, 1_024_000);
        assert_eq!(info.memory_available, 256_000);
        assert_eq!(info.swap_total, 512_000);
        assert_eq!(info.swap_free, 102_400);
    }

    #[test]
    fn picks_lowest_metric_default_route() {
        let route = "Iface Destination Gateway Flags RefCnt Use Metric Mask\neth0 00000000 01010101 0003 0 0 200 00000000\nwlan0 00000000 01010101 0003 0 0 100 00000000\n";
        assert_eq!(parse_default_route(route).as_deref(), Some("wlan0"));
    }

    #[test]
    fn computes_rates_and_handles_counter_reset() {
        assert_eq!(
            network_rates(100, 200, 500, 300, Duration::from_secs(2)),
            (200, 50)
        );
        assert_eq!(
            network_rates(500, 300, 100, 100, Duration::from_secs(1)),
            (0, 0)
        );
    }
}
