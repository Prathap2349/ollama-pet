import Foundation
import AppKit
import IOKit.ps

@MainActor
public class SystemMonitor: ObservableObject {
    public static let shared = SystemMonitor()

    @Published public var cpuPercent: Double = 0.0
    @Published public var batteryPercent: Int = 100
    @Published public var isCharging: Bool = false
    @Published public var uptimeString: String = "0h 0m"
    @Published public var foregroundApps: [String] = []

    @Published public var isPowerSavingMode: Bool = false

    private var previousCpuInfo: processor_info_array_t?
    private var previousCpuInfoCount: mach_msg_type_number_t = 0
    private var timer: Timer?

    public init() {
        startMonitoring()
    }

    public func startMonitoring() {
        updateAllStats()
        rescheduleTimer()
    }

    private func rescheduleTimer() {
        timer?.invalidate()
        let interval: TimeInterval = isPowerSavingMode ? 5.0 : 2.0
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateAllStats()
            }
        }
    }

    public func updateAllStats() {
        updateCpu()
        updateBattery()
        updateUptime()
        updateForegroundApps()
    }

    private func updateCpu() {
        var numProcessors: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var cpuInfoCount: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numProcessors,
            &cpuInfo,
            &cpuInfoCount
        )

        guard result == KERN_SUCCESS, let cpuInfo = cpuInfo else { return }

        if let prev = previousCpuInfo {
            var inUse: Int64 = 0
            var total: Int64 = 0

            for i in 0..<Int(numProcessors) {
                let offset = Int(CPU_STATE_MAX) * i
                let user = Int64(cpuInfo[offset + Int(CPU_STATE_USER)] - prev[offset + Int(CPU_STATE_USER)])
                let system = Int64(cpuInfo[offset + Int(CPU_STATE_SYSTEM)] - prev[offset + Int(CPU_STATE_SYSTEM)])
                let nice = Int64(cpuInfo[offset + Int(CPU_STATE_NICE)] - prev[offset + Int(CPU_STATE_NICE)])
                let idle = Int64(cpuInfo[offset + Int(CPU_STATE_IDLE)] - prev[offset + Int(CPU_STATE_IDLE)])

                inUse += (user + system + nice)
                total += (user + system + nice + idle)
            }

            if total > 0 {
                let load = Double(inUse) / Double(total) * 100.0
                self.cpuPercent = min(100.0, max(0.0, load))
            }

            // Deallocate previous info
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prev), vm_size_t(previousCpuInfoCount * UInt32(MemoryLayout<integer_t>.size)))
        }

        previousCpuInfo = cpuInfo
        previousCpuInfoCount = cpuInfoCount
    }

    private func updateBattery() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return
        }

        for ps in sources {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, ps)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            if let cur = desc[kIOPSCurrentCapacityKey] as? Int,
               let max = desc[kIOPSMaxCapacityKey] as? Int, max > 0 {
                self.batteryPercent = Int((Double(cur) / Double(max)) * 100.0)
            }
            if let state = desc[kIOPSPowerSourceStateKey] as? String {
                self.isCharging = (state == kIOPSACPowerValue)
            }
        }

        let wasLowPower = self.isPowerSavingMode
        self.isPowerSavingMode = (!self.isCharging && self.batteryPercent <= 25)
        if wasLowPower != self.isPowerSavingMode {
            self.rescheduleTimer()
        }
    }

    private func updateUptime() {
        var boottime = timeval()
        var size = MemoryLayout<timeval>.size
        var mib = [CTL_KERN, KERN_BOOTTIME]
        if sysctl(&mib, 2, &boottime, &size, nil, 0) == 0 {
            let now = Date().timeIntervalSince1970
            let uptime = now - Double(boottime.tv_sec)
            let hours = Int(uptime / 3600)
            let mins = Int((uptime.truncatingRemainder(dividingBy: 3600)) / 60)
            self.uptimeString = "\(hours)h \(mins)m"
        }
    }

    private func updateForegroundApps() {
        let running = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && !($0.localizedName?.isEmpty ?? true) }
            .compactMap { $0.localizedName }
        self.foregroundApps = Array(Set(running)).sorted()
    }

    deinit {
        timer?.invalidate()
        if let prev = previousCpuInfo {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prev), vm_size_t(previousCpuInfoCount * UInt32(MemoryLayout<integer_t>.size)))
        }
    }
}
