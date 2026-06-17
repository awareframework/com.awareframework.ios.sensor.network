import XCTest
import GRDB
@testable import com_awareframework_ios_sensor_network

final class NetworkSensorTests: XCTestCase {
    func testNetworkDataDictionaryContainsStatus() {
        var data = NetworkData()
        data.timestamp = 123
        data.networkType = NetworkSensor.NETWORK_TYPE_WIFI
        data.networkSubtype = "WIFI"
        data.networkState = NetworkSensor.NETWORK_STATE_ON

        let dictionary = data.toDictionary()

        XCTAssertEqual(dictionary["timestamp"] as? Int64, 123)
        XCTAssertEqual(dictionary["networkType"] as? Int, NetworkSensor.NETWORK_TYPE_WIFI)
        XCTAssertEqual(dictionary["networkSubtype"] as? String, "WIFI")
        XCTAssertEqual(dictionary["networkState"] as? Int, NetworkSensor.NETWORK_STATE_ON)
    }

    func testNetworkTrafficDataDictionaryContainsCounters() {
        var data = NetworkTrafficData()
        data.timestamp = 456
        data.networkType = NetworkSensor.TRAFFIC_TYPE_WIFI
        data.networkSubtype = "WIFI"
        data.interfaceName = "en0"
        data.receivedBytes = 100
        data.sentBytes = 40
        data.receivedBytesDelta = 10
        data.sentBytesDelta = 5
        data.totalBytesDelta = 15

        let dictionary = data.toDictionary()

        XCTAssertEqual(dictionary["timestamp"] as? Int64, 456)
        XCTAssertEqual(dictionary["networkType"] as? Int, NetworkSensor.TRAFFIC_TYPE_WIFI)
        XCTAssertEqual(dictionary["interfaceName"] as? String, "en0")
        XCTAssertEqual(dictionary["receivedBytes"] as? Double, 100)
        XCTAssertEqual(dictionary["totalBytesDelta"] as? Double, 15)
    }

    func testCreateTables() throws {
        let queue = try DatabaseQueue()
        try NetworkData.createTable(queue: queue)
        try NetworkTrafficData.createTable(queue: queue)

        let tablesExist = try queue.read { db in
            try db.tableExists(NetworkData.databaseTableName)
                && db.tableExists(NetworkTrafficData.databaseTableName)
        }
        XCTAssertTrue(tablesExist)
    }

    func testInterfaceClassification() {
        XCTAssertEqual(NetworkSensor.interfaceType(for: "en0")?.subtype, "WIFI")
        XCTAssertEqual(NetworkSensor.interfaceType(for: "pdp_ip0")?.subtype, "MOBILE")
        XCTAssertNil(NetworkSensor.interfaceType(for: "awdl0"))
    }
}
