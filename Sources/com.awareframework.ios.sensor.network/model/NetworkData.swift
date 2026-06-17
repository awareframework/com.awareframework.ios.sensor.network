import Foundation
import GRDB
import com_awareframework_ios_core

public struct NetworkData: BaseDbModelSQLite {
    public var id: Int64?
    public var timestamp: Int64 = 0
    public var deviceId: String = AwareUtils.getCommonDeviceId()
    public var label: String = ""
    public var timezone: Int = AwareUtils.getTimeZone()
    public var os: String = "iOS"
    public var jsonVersion: Int = 1
    public static let databaseTableName = "ios_network"
    public static let TABLE_NAME = databaseTableName

    public var networkType: Int = 0
    public var networkSubtype: String = ""
    public var networkState: Int = 0

    public init() {}

    public init(_ dict: Dictionary<String, Any>) {
        timestamp = dict["timestamp"] as? Int64 ?? 0
        label = dict["label"] as? String ?? ""
        deviceId = dict["deviceId"] as? String ?? AwareUtils.getCommonDeviceId()
        networkType = dict["networkType"] as? Int ?? 0
        networkSubtype = dict["networkSubtype"] as? String ?? ""
        networkState = dict["networkState"] as? Int ?? 0
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
                t.column("networkState", .integer).notNull()
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
            "networkState": networkState,
        ]
    }
}
