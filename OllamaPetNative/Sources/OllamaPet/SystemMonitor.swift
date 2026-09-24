import Foundation
import AppKit
import IOKit.ps
import ServiceManagement

// MARK: - Production System Monitor with Efficient Decoupled Intervals

@MainActor
public class SystemMonitor: ObservableObject {
    public static let shared = SystemMonitor()

    // 1. Static Hardware & OS Info (Cached, loaded once)
    @Published public var macModel: String = "Mac"
    @Published public var architecture: String = "Apple Silicon"
    @Published public var cpuCores: Int = 8
    @Published public var macOSVersion: String = "macOS"
    @Published public var appVersion: String = "1.0.0"
    @Published public var appInstallationPath: String = ""

    // 2. Live Performance Metrics (1-2s interval)
    @Published public var cpuPercent: Double = 0.0
    @Published public var memoryUsedGB: Double = 0.0
    @Published public var memoryTotalGB: Double = 0.0
    @Published public var memoryPercent: Double = 0.0

    // 3. Power & Battery (10-30s interval)
    @Published public var batteryPercent: Int = 100
    @Published public var isCharging: Bool = false
    @Published public var hasBattery: Bool = true
    @Published public var uptimeString: String = "0h 0m"
    @Published public var isPowerSavingMode: Bool = false

    // 4. Storage & Disk (30-60s interval)
    @Published public var diskAvailableGB: Double = 0.0
    @Published public var diskTotalGB: Double = 0.0
    @Published public var diskUsedGB: Double = 0.0
    @Published public var diskPercent: Double = 0.0

    // 5. Live App & Process Info
    @Published public var frontmostApp: String = "Finder"
    @Published public var runningAppsCount: Int = 0
    @Published public var foregroundApps: [String] = []

    // Decoupled Timer Management
    private var cpuTimer: Timer?
    private var batteryTimer: Timer?
    private var diskTimer: Timer?
    private var previousCpuInfo: processor_info_array_t?
    private var previousCpuInfoCount: mach_msg_type_number_t = 0

    public init() {
        loadStaticSystemInfo()
        DispatchQueue.main.async { [weak self] in
            self?.startMonitoring()
        }
    }

    // MARK: - Static System Info (Loaded Once)

    public func loadStaticSystemInfo() {
        // Mac Model Identifier
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        if size > 0 {
            var model = [CChar](repeating: 0, count: size)
            sysctlbyname("hw.model", &model, &size, nil, 0)
            self.macModel = String(cString: model)
        } else {
            self.macModel = "Mac"
        }

        // CPU Architecture
        #if arch(arm64)
        self.architecture = "Apple Silicon (ARM64)"
        #elseif arch(x86_64)
        self.architecture = "Intel (x86_64)"
        #else
        self.architecture = "Unknown"
        #endif

        // Core count
        self.cpuCores = ProcessInfo.processInfo.activeProcessorCount

        // macOS Version
        let os = ProcessInfo.processInfo.operatingSystemVersion
        self.macOSVersion = "macOS \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"

        // App Version
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"

        // App installation path
        self.appInstallationPath = Bundle.main.bundleURL.path

        // Initial fetch of physical RAM
        let totalBytes = ProcessInfo.processInfo.physicalMemory
        self.memoryTotalGB = Double(totalBytes) / 1_073_741_824.0
    }

    // MARK: - Monitoring Intervals & Lifecycle

    public func startMonitoring() {
        updateCpu()
        updateMemory()
        updateBattery()
        updateUptime()
        updateDisk()
        updateProcessInfo()

        rescheduleTimers()
    }

    public func rescheduleTimers() {
        cpuTimer?.invalidate()
        batteryTimer?.invalidate()
        diskTimer?.invalidate()

        let isSafe = PerformanceManager.shared.isSafeMode || isPowerSavingMode

        // 1. Fast live CPU: 1.5s (or 4.0s in safe mode)
        let cpuInterval: TimeInterval = isSafe ? 4.0 : 1.5
        cpuTimer = Timer.scheduledTimer(withTimeInterval: cpuInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateCpu()
                self?.updateMemory()
            }
        }

        // 2. Battery & Uptime: 15.0s (or 30.0s in safe mode)
        let batteryInterval: TimeInterval = isSafe ? 30.0 : 15.0
        batteryTimer = Timer.scheduledTimer(withTimeInterval: batteryInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateBattery()
                self?.updateUptime()
                self?.updateProcessInfo()
            }
        }

        // 3. Disk & Storage: 60.0s
        let diskInterval: TimeInterval = 60.0
        diskTimer = Timer.scheduledTimer(withTimeInterval: diskInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateDisk()
            }
        }
    }

    public func manualRefreshAll() {
        loadStaticSystemInfo()
        updateCpu()
        updateMemory()
        updateBattery()
        updateUptime()
        updateDisk()
        updateProcessInfo()
    }

    // MARK: - Metric Updaters

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

            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prev), vm_size_t(previousCpuInfoCount * UInt32(MemoryLayout<integer_t>.size)))
        }

        previousCpuInfo = cpuInfo
        previousCpuInfoCount = cpuInfoCount
    }

    private func updateMemory() {
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var vmStat = vm_statistics64_data_t()

        let ret = withUnsafeMutablePointer(to: &vmStat) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        if ret == KERN_SUCCESS {
            let pageSize = vm_kernel_page_size
            let active = Double(vmStat.active_count) * Double(pageSize)
            let wired = Double(vmStat.wire_count) * Double(pageSize)
            let compressed = Double(vmStat.compressor_page_count) * Double(pageSize)

            let usedBytes = active + wired + compressed
            let usedGB = usedBytes / 1_073_741_824.0

            self.memoryUsedGB = (usedGB * 10).rounded() / 10
            if memoryTotalGB > 0 {
                self.memoryPercent = min(100.0, max(0.0, (usedGB / memoryTotalGB) * 100.0))
            }
        }
    }

    private func updateBattery() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            self.hasBattery = false
            return
        }

        if sources.isEmpty {
            self.hasBattery = false
            self.batteryPercent = 100
            self.isCharging = true
            return
        }

        self.hasBattery = true
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
        self.isPowerSavingMode = (!self.isCharging && self.batteryPercent <= 20)
        if wasLowPower != self.isPowerSavingMode {
            self.rescheduleTimers()
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

    private func updateDisk() {
        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: "/")
            if let free = attrs[.systemFreeSize] as? NSNumber,
               let total = attrs[.systemSize] as? NSNumber {
                let freeGB = free.doubleValue / 1_073_741_824.0
                let totalGB = total.doubleValue / 1_073_741_824.0
                let usedGB = max(0, totalGB - freeGB)

                self.diskAvailableGB = (freeGB * 10).rounded() / 10
                self.diskTotalGB = (totalGB * 10).rounded() / 10
                self.diskUsedGB = (usedGB * 10).rounded() / 10

                if totalGB > 0 {
                    self.diskPercent = min(100.0, max(0.0, (usedGB / totalGB) * 100.0))
                }
            }
        } catch {
            // Keep existing values or defaults
        }
    }

    private func updateProcessInfo() {
        let front = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unavailable"
        self.frontmostApp = front

        let running = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && !($0.localizedName?.isEmpty ?? true) }
            .compactMap { $0.localizedName }

        let unique = Array(Set(running)).sorted()
        self.runningAppsCount = unique.count
        self.foregroundApps = unique
    }

    deinit {
        cpuTimer?.invalidate()
        batteryTimer?.invalidate()
        diskTimer?.invalidate()
        if let prev = previousCpuInfo {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prev), vm_size_t(previousCpuInfoCount * UInt32(MemoryLayout<integer_t>.size)))
        }
    }
}
