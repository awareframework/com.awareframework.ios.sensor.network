//
//  NetworkSensor.swift
//  com.awareframework.ios.sensor.network
//

import Darwin
import Foundation
import Network
import com_awareframework_ios_core

extension Notification.Name {
    public static let actionAwareNetwork = Notification.Name(NetworkSensor.ACTION_AWARE_NETWORK)
    public static let actionAwareNetworkStart = Notification.Name(NetworkSensor.ACTION_AWARE_NETWORK_START)
    public static let actionAwareNetworkStop = Notification.Name(NetworkSensor.ACTION_AWARE_NETWORK_STOP)
    public static let actionAwareNetworkSync = Notification.Name(NetworkSensor.ACTION_AWARE_NETWORK_SYNC)
    public static let actionAwareNetworkSetLabel = Notification.Name(NetworkSensor.ACTION_AWARE_NETWORK_SET_LABEL)
    public static let actionAwareNetworkSyncCompletion = Notification.Name(NetworkSensor.ACTION_AWARE_NETWORK_SYNC_COMPLETION)
    public static let actionAwareNetworkWifiOn = Notification.Name(NetworkSensor.ACTION_AWARE_NETWORK_WIFI_ON)
    public static let actionAwareNetworkWifiOff = Notification.Name(NetworkSensor.ACTION_AWARE_NETWORK_WIFI_OFF)
    public static let actionAwareNetworkMobileOn = Notification.Name(NetworkSensor.ACTION_AWARE_NETWORK_MOBILE_ON)
    public static let actionAwareNetworkMobileOff = Notification.Name(NetworkSensor.ACTION_AWARE_NETWORK_MOBILE_OFF)
    public static let actionAwareInternetAvailable = Notification.Name(NetworkSensor.ACTION_AWARE_INTERNET_AVAILABLE)
    public static let actionAwareInternetUnavailable = Notification.Name(NetworkSensor.ACTION_AWARE_INTERNET_UNAVAILABLE)
    public static let actionAwareNetworkTraffic = Notification.Name(NetworkSensor.ACTION_AWARE_NETWORK_TRAFFIC)
}

public protocol NetworkObserver {
    func onNetworkChanged(data: NetworkData)
    func onTrafficChanged(data: [NetworkTrafficData])
    func onInternetAvailable(access: Int)
    func onInternetUnavailable()
}

extension NetworkSensor {
    public static let TAG = "AWARE::Network"
    public static let ACTION_AWARE_NETWORK = "com.awareframework.ios.sensor.network"
    public static let ACTION_AWARE_NETWORK_START = "com.awareframework.ios.sensor.network.SENSOR_START"
    public static let ACTION_AWARE_NETWORK_STOP = "com.awareframework.ios.sensor.network.SENSOR_STOP"
    public static let ACTION_AWARE_NETWORK_SET_LABEL = "com.awareframework.ios.sensor.network.SET_LABEL"
    public static let ACTION_AWARE_NETWORK_SYNC = "com.awareframework.ios.sensor.network.SENSOR_SYNC"
    public static let ACTION_AWARE_NETWORK_SYNC_COMPLETION =
        "com.awareframework.ios.sensor.network.SENSOR_SYNC_COMPLETION"
    public static let ACTION_AWARE_NETWORK_WIFI_ON = "com.awareframework.ios.sensor.network.WIFI_ON"
    public static let ACTION_AWARE_NETWORK_WIFI_OFF = "com.awareframework.ios.sensor.network.WIFI_OFF"
    public static let ACTION_AWARE_NETWORK_MOBILE_ON = "com.awareframework.ios.sensor.network.MOBILE_ON"
    public static let ACTION_AWARE_NETWORK_MOBILE_OFF = "com.awareframework.ios.sensor.network.MOBILE_OFF"
    public static let ACTION_AWARE_INTERNET_AVAILABLE =
        "com.awareframework.ios.sensor.network.INTERNET_AVAILABLE"
    public static let ACTION_AWARE_INTERNET_UNAVAILABLE =
        "com.awareframework.ios.sensor.network.INTERNET_UNAVAILABLE"
    public static let ACTION_AWARE_NETWORK_TRAFFIC =
        "com.awareframework.ios.sensor.network.TRAFFIC"

    public static let EXTRA_DATA = "data"
    public static let EXTRA_LABEL = "label"
    public static let EXTRA_STATUS = "status"
    public static let EXTRA_ERROR = "error"
    public static let EXTRA_TABLE_NAME = "tableName"

    public static let NETWORK_TYPE_WIFI = 1
    public static let NETWORK_TYPE_BLUETOOTH = 2
    public static let NETWORK_TYPE_GPS = 3
    public static let NETWORK_TYPE_MOBILE = 4
    public static let NETWORK_STATE_OFF = 0
    public static let NETWORK_STATE_ON = 1

    public static let TRAFFIC_TYPE_MOBILE = 1
    public static let TRAFFIC_TYPE_WIFI = 2
}

public class NetworkSensor: AwareSensor {
    public var CONFIG = Config()
    private var monitor: NWPathMonitor?
    private var timer: DispatchSourceTimer?
    private let statusQueue = DispatchQueue(
        label: "com.awareframework.ios.sensor.network.status.queue",
        qos: .utility)
    private let trafficQueue = DispatchQueue(
        label: "com.awareframework.ios.sensor.network.traffic.queue",
        qos: .utility)
    private var previousSnapshots: [String: InterfaceSnapshot] = [:]
    private var previousWifiState: Int?
    private var previousMobileState: Int?
    private var previousInternetAvailable: Bool?

    public class Config: SensorConfig {
        public var sensorObserver: NetworkObserver?
        public var statusEventsEnabled: Bool = true
        public var trafficEnabled: Bool = true
        public var includeLoopback: Bool = false
        public var interval: Int = 60 {
            didSet {
                if interval <= 0 {
                    if debug {
                        print(
                            NetworkSensor.TAG,
                            "The interval parameter must be greater than 0. Keeping \(oldValue).")
                    }
                    interval = oldValue
                }
            }
        }

        public override init() {
            super.init()
            dbPath = "aware_network"
        }

        public convenience init(_ config: Dictionary<String, Any>) {
            self.init()
            set(config: config)
            if let interval = config["interval"] as? Int {
                self.interval = interval
            }
            if let statusEventsEnabled = config["statusEventsEnabled"] as? Bool {
                self.statusEventsEnabled = statusEventsEnabled
            }
            if let trafficEnabled = config["trafficEnabled"] as? Bool {
                self.trafficEnabled = trafficEnabled
            }
            if let includeLoopback = config["includeLoopback"] as? Bool {
                self.includeLoopback = includeLoopback
            }
        }

        public func apply(closure: (_ config: NetworkSensor.Config) -> Void) -> Self {
            closure(self)
            return self
        }
    }

    public override convenience init() {
        self.init(NetworkSensor.Config())
    }

    public init(_ config: NetworkSensor.Config) {
        super.init()
        CONFIG = config
        initializeDbEngine(config: config)
        initializeTables()
        super.syncConfig = DbSyncConfig().apply { config in
            config.dispatchQueue = DispatchQueue(label: "com.awareframework.ios.sensor.network.sync.queue")
        }
    }

    deinit {
        stopMonitor()
        stopTimer()
    }

    public override func start() {
        stopMonitor()
        stopTimer()
        if CONFIG.statusEventsEnabled {
            startMonitor()
        }
        if CONFIG.trafficEnabled {
            trafficQueue.async { [weak self] in
                self?.sampleTraffic()
            }
            let timer = DispatchSource.makeTimerSource(queue: trafficQueue)
            timer.schedule(
                deadline: .now() + .seconds(max(1, CONFIG.interval)),
                repeating: .seconds(max(1, CONFIG.interval)))
            timer.setEventHandler { [weak self] in
                self?.sampleTraffic()
            }
            timer.resume()
            self.timer = timer
        }
        notificationCenter.post(name: .actionAwareNetworkStart, object: self)
    }

    public override func stop() {
        stopMonitor()
        stopTimer()
        notificationCenter.post(name: .actionAwareNetworkStop, object: self)
    }

    public override func sync(force: Bool = false) {
        guard let syncConfig = syncConfig else { return }
        syncConfig.debug = CONFIG.debug
        syncTable(NetworkData.databaseTableName, syncConfig: syncConfig)
        syncTable(NetworkTrafficData.databaseTableName, syncConfig: syncConfig)
        notificationCenter.post(name: .actionAwareNetworkSync, object: self)
    }

    public override func set(label: String) {
        CONFIG.label = label
        notificationCenter.post(
            name: .actionAwareNetworkSetLabel,
            object: self,
            userInfo: [NetworkSensor.EXTRA_LABEL: label])
    }

    public func sampleTraffic() {
        let snapshots = Self.interfaceSnapshots(includeLoopback: CONFIG.includeLoopback)
        guard !snapshots.isEmpty else { return }

        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        var data: [NetworkTrafficData] = []
        for snapshot in snapshots {
            let previous = previousSnapshots[snapshot.interfaceName]
            var row = NetworkTrafficData()
            row.timestamp = timestamp
            row.label = CONFIG.label
            row.networkType = snapshot.trafficType
            row.networkSubtype = snapshot.subtype
            row.interfaceName = snapshot.interfaceName
            row.receivedBytes = Double(snapshot.receivedBytes)
            row.sentBytes = Double(snapshot.sentBytes)
            row.receivedPackets = Double(snapshot.receivedPackets)
            row.sentPackets = Double(snapshot.sentPackets)
            if let previous {
                row.receivedBytesDelta = Double(Self.delta(snapshot.receivedBytes, previous.receivedBytes))
                row.sentBytesDelta = Double(Self.delta(snapshot.sentBytes, previous.sentBytes))
                row.receivedPacketsDelta = Double(Self.delta(snapshot.receivedPackets, previous.receivedPackets))
                row.sentPacketsDelta = Double(Self.delta(snapshot.sentPackets, previous.sentPackets))
                row.totalBytesDelta = row.receivedBytesDelta + row.sentBytesDelta
            }
            data.append(row)
        }

        previousSnapshots = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.interfaceName, $0) })
        dbEngine?.save(data)
        CONFIG.sensorObserver?.onTrafficChanged(data: data)
        notificationCenter.post(
            name: .actionAwareNetworkTraffic,
            object: self,
            userInfo: [NetworkSensor.EXTRA_DATA: data])
    }

    private func startMonitor() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            self?.handle(path: path)
        }
        monitor.start(queue: statusQueue)
        self.monitor = monitor
    }

    private func stopMonitor() {
        monitor?.cancel()
        monitor = nil
    }

    private func stopTimer() {
        timer?.setEventHandler {}
        timer?.cancel()
        timer = nil
    }

    private func handle(path: NWPath) {
        let internetAvailable = path.status == .satisfied
        let wifiState =
            internetAvailable && path.usesInterfaceType(.wifi)
            ? NetworkSensor.NETWORK_STATE_ON : NetworkSensor.NETWORK_STATE_OFF
        let mobileState =
            internetAvailable && path.usesInterfaceType(.cellular)
            ? NetworkSensor.NETWORK_STATE_ON : NetworkSensor.NETWORK_STATE_OFF

        if previousInternetAvailable != internetAvailable {
            previousInternetAvailable = internetAvailable
            if internetAvailable {
                CONFIG.sensorObserver?.onInternetAvailable(access: preferredAccessType(path: path))
                notificationCenter.post(
                    name: .actionAwareInternetAvailable,
                    object: self,
                    userInfo: [NetworkSensor.EXTRA_DATA: preferredAccessType(path: path)])
            } else {
                CONFIG.sensorObserver?.onInternetUnavailable()
                notificationCenter.post(name: .actionAwareInternetUnavailable, object: self)
            }
        }

        if previousWifiState != wifiState {
            previousWifiState = wifiState
            saveNetworkState(
                type: NetworkSensor.NETWORK_TYPE_WIFI,
                subtype: "WIFI",
                state: wifiState,
                notification: wifiState == NetworkSensor.NETWORK_STATE_ON
                    ? .actionAwareNetworkWifiOn : .actionAwareNetworkWifiOff)
        }

        if previousMobileState != mobileState {
            previousMobileState = mobileState
            saveNetworkState(
                type: NetworkSensor.NETWORK_TYPE_MOBILE,
                subtype: "MOBILE",
                state: mobileState,
                notification: mobileState == NetworkSensor.NETWORK_STATE_ON
                    ? .actionAwareNetworkMobileOn : .actionAwareNetworkMobileOff)
        }
    }

    private func saveNetworkState(
        type: Int,
        subtype: String,
        state: Int,
        notification: Notification.Name
    ) {
        var data = NetworkData()
        data.timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        data.label = CONFIG.label
        data.networkType = type
        data.networkSubtype = subtype
        data.networkState = state

        dbEngine?.save([data])
        CONFIG.sensorObserver?.onNetworkChanged(data: data)
        notificationCenter.post(
            name: .actionAwareNetwork,
            object: self,
            userInfo: [NetworkSensor.EXTRA_DATA: data])
        notificationCenter.post(
            name: notification,
            object: self,
            userInfo: [NetworkSensor.EXTRA_DATA: data])
    }

    private func preferredAccessType(path: NWPath) -> Int {
        if path.usesInterfaceType(.wifi) {
            return NetworkSensor.NETWORK_TYPE_WIFI
        }
        if path.usesInterfaceType(.cellular) {
            return NetworkSensor.NETWORK_TYPE_MOBILE
        }
        return 0
    }

    private func initializeTables() {
        guard CONFIG.dbType == .sqlite,
            let queue = (dbEngine as? SQLiteEngine)?.getSQLiteInstance()
        else { return }
        try? NetworkData.createTable(queue: queue)
        try? NetworkTrafficData.createTable(queue: queue)
    }

    private func syncTable(_ tableName: String, syncConfig: DbSyncConfig) {
        guard let baseEngine = dbEngine else { return }
        let tableSyncConfig = Self.copy(syncConfig)
        let engine =
            tableName == CONFIG.dbTableName
            ? baseEngine
            : Engine.Builder()
                .setType(baseEngine.config.type)
                .setPath(baseEngine.config.path)
                .setHost(baseEngine.config.host)
                .setEncryptionKey(baseEngine.config.encryptionKey)
                .setTableName(tableName)
                .build()

        tableSyncConfig.completionHandler = { status, error in
            var userInfo: Dictionary<String, Any> = [
                NetworkSensor.EXTRA_STATUS: status,
                NetworkSensor.EXTRA_TABLE_NAME: tableName,
            ]
            if let error {
                userInfo[NetworkSensor.EXTRA_ERROR] = error
            }
            self.notificationCenter.post(
                name: .actionAwareNetworkSyncCompletion,
                object: self,
                userInfo: userInfo)
        }
        engine.startSync(tableSyncConfig)
    }

    private static func copy(_ config: DbSyncConfig) -> DbSyncConfig {
        let clone = DbSyncConfig()
        clone.removeAfterSync = config.removeAfterSync
        clone.batchSize = config.batchSize
        clone.markAsSynced = config.markAsSynced
        clone.skipSyncedData = config.skipSyncedData
        clone.keepLastData = config.keepLastData
        clone.deviceId = config.deviceId
        clone.debug = config.debug
        clone.debugLevel = config.debugLevel
        clone.progressHandler = config.progressHandler
        clone.dispatchQueue = config.dispatchQueue
        clone.backgroundSession = config.backgroundSession
        clone.compactDataFormat = config.compactDataFormat
        clone.serverType = config.serverType
        clone.studyNumber = config.studyNumber
        clone.studyKey = config.studyKey
        clone.test = config.test
        return clone
    }

    static func interfaceType(for interfaceName: String) -> (networkType: Int, trafficType: Int, subtype: String)? {
        if interfaceName == "en0" {
            return (
                NetworkSensor.NETWORK_TYPE_WIFI,
                NetworkSensor.TRAFFIC_TYPE_WIFI,
                "WIFI"
            )
        }
        if interfaceName.hasPrefix("pdp_ip") {
            return (
                NetworkSensor.NETWORK_TYPE_MOBILE,
                NetworkSensor.TRAFFIC_TYPE_MOBILE,
                "MOBILE"
            )
        }
        return nil
    }

    static func interfaceSnapshots(includeLoopback: Bool) -> [InterfaceSnapshot] {
        var address: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&address) == 0, let firstAddress = address else {
            return []
        }
        defer { freeifaddrs(address) }

        var snapshots: [InterfaceSnapshot] = []
        var pointer: UnsafeMutablePointer<ifaddrs>? = firstAddress
        while let current = pointer {
            defer { pointer = current.pointee.ifa_next }
            let interface = current.pointee
            guard let ifaAddress = interface.ifa_addr,
                ifaAddress.pointee.sa_family == UInt8(AF_LINK),
                let ifaData = interface.ifa_data
            else { continue }

            let flags = interface.ifa_flags
            guard flags & UInt32(IFF_UP) != 0 else { continue }
            if !includeLoopback, flags & UInt32(IFF_LOOPBACK) != 0 {
                continue
            }

            let interfaceName = String(cString: interface.ifa_name)
            guard let type = interfaceType(for: interfaceName) else { continue }

            let data = ifaData.assumingMemoryBound(to: if_data.self).pointee
            snapshots.append(
                InterfaceSnapshot(
                    interfaceName: interfaceName,
                    networkType: type.networkType,
                    trafficType: type.trafficType,
                    subtype: type.subtype,
                    receivedBytes: UInt64(data.ifi_ibytes),
                    sentBytes: UInt64(data.ifi_obytes),
                    receivedPackets: UInt64(data.ifi_ipackets),
                    sentPackets: UInt64(data.ifi_opackets)))
        }

        return snapshots
    }

    private static func delta(_ current: UInt64, _ previous: UInt64) -> UInt64 {
        current >= previous ? current - previous : 0
    }
}

struct InterfaceSnapshot {
    let interfaceName: String
    let networkType: Int
    let trafficType: Int
    let subtype: String
    let receivedBytes: UInt64
    let sentBytes: UInt64
    let receivedPackets: UInt64
    let sentPackets: UInt64
}
