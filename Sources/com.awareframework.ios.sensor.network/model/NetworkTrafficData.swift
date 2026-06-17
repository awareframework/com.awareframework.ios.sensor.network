import Foundation
import GRDB
import com_awareframework_ios_core

public struct NetworkTrafficData: BaseDbModelSQLite {
    public var id: Int64?
    public var timestamp: Int64 = 0
    public var deviceId: String = AwareUtils.getCommonDeviceId()
    public var label: String = ""
    public var timezone: Int = AwareUtils.getTimeZone()
    public var os: String = "iOS"
    public var jsonVersion: Int = 1
    public static let databaseTableName = "ios_network_traffic"
    public static let TABLE_NAME = databaseTableName

    public var networkType: Int = 0
    public var networkSubtype: String = ""
    public var interfaceName: String = ""
    public var receivedBytes: Double = 0
    public var sentBytes: Double = 0
    public var receivedPackets: Double = 0
    public var sentPackets: Double = 0
    public var receivedBytesDelta: Double = 0
    public var sentBytesDelta: Double = 0
    public var receivedPacketsDelta: Double = 0
    public var sentPacketsDelta: Double = 0
    public var totalBytesDelta: Double = 0

    public init() {}

    public init(_ dict: Dictionary<String, Any>) {
        timestamp = dict["timestamp"] as? Int64 ?? 0
        label = dict["label"] as? String ?? ""
        deviceId = dict["deviceId"] as? String ?? AwareUtils.getCommonDeviceId()
        networkType = dict["networkType"] as? Int ?? 0
        networkSubtype = dict["networkSubtype"] as? String ?? ""
        interfaceName = dict["interfaceName"] as? String ?? ""
        receivedBytes = dict["receivedBytes"] as? Double ?? 0
        sentBytes = dict["sentBytes"] as? Double ?? 0
        receivedPackets = dict["receivedPackets"] as? Double ?? 0
        sentPackets = dict["sentPackets"] as? Double ?? 0
        receivedBytesDelta = dict["receivedBytesDelta"] as? Double ?? 0
        sentBytesDelta = dict["sentBytesDelta"] as? Double ?? 0
        receivedPacketsDelta = dict["receivedPacketsDelta"] as? Double ?? 0
        sentPacketsDelta = dict["sentPacketsDelta"] as? Double ?? 0
        totalBytesDelta = dict["totalBytesDelta"] as? Double ?? 0
    }

    public static func createTable(queue: DatabaseQueue) throws {
        try queue.write { db in
            try db.create(table: databaseTableName, ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("deviceId", .text).notNull()
                t.column("timestamp", .integer).notNull()
                t.column("label", .text).notNull()
                t.column("timezone", .integer).notNull()
                t.column("os", .text).notNull()
                t.column("jsonVersion", .integer).notNull()
                t.column("networkType", .integer).notNull()
                t.column("networkSubtype", .text).notNull()
                t.column("interfaceName", .text).notNull()
                t.column("receivedBytes", .double).notNull()
                t.column("sentBytes", .double).notNull()
                t.column("receivedPackets", .double).notNull()
                t.column("sentPackets", .double).notNull()
                t.column("receivedBytesDelta", .double).notNull()
                t.column("sentBytesDelta", .double).notNull()
                t.column("receivedPacketsDelta", .double).notNull()
                t.column("sentPacketsDelta", .double).notNull()
                t.column("totalBytesDelta", .double).notNull()
            }
        }
    }

    public func toDictionary() -> Dictionary<String, Any> {
        [
            "id": id ?? -1,
            "timestamp": timestamp,
            "deviceId": deviceId,
            "label": label,
            "timezone": timezone,
            "os": os,
            "jsonVersion": jsonVersion,
            "networkType": networkType,
            "networkSubtype": networkSubtype,
            "interfaceName": interfaceName,
            "receivedBytes": receivedBytes,
            "sentBytes": sentBytes,
            "receivedPackets": receivedPackets,
            "sentPackets": sentPackets,
            "receivedBytesDelta": receivedBytesDelta,
            "sentBytesDelta": sentBytesDelta,
            "receivedPacketsDelta": receivedPacketsDelta,
            "sentPacketsDelta": sentPacketsDelta,
            "totalBytesDelta": totalBytesDelta,
        ]
    }
}
