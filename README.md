# AWARE Network Sensor

This package implements the iOS network sensor for AWARE-compatible clients.

It records Wi-Fi/mobile connectivity state in `ios_network` and interface traffic counters in
`ios_network_traffic` under the `aware_network.sqlite` database.

## Installation

Add the package to your Swift package dependencies:

```swift
.package(url: "https://github.com/awareframework/com.awareframework.ios.sensor.network.git", from: "1.0.0")
```

Then add the product to your target:

```swift
.product(name: "com.awareframework.ios.sensor.network", package: "com.awareframework.ios.sensor.network")
```

## Usage

```swift
import com_awareframework_ios_sensor_network

let sensor = NetworkSensor(NetworkSensor.Config().apply { config in
    config.dbType = .sqlite
    config.dbPath = "aware_network"
    config.dbTableName = NetworkData.databaseTableName
    config.interval = 60
    config.statusEventsEnabled = true
    config.trafficEnabled = true
})

sensor.start()
```

`NetworkSensor.Config` extends the common AWARE `SensorConfig`.

| Property | Type | Default | Description |
| --- | --- | --- | --- |
| `interval` | `Int` | `60` | Traffic sampling interval in seconds. |
| `statusEventsEnabled` | `Bool` | `true` | Enables Wi-Fi/mobile/internet availability events. |
| `trafficEnabled` | `Bool` | `true` | Enables interface traffic sampling. |
| `includeLoopback` | `Bool` | `false` | Includes loopback interfaces when sampling. |
| `sensorObserver` | `NetworkObserver?` | `nil` | Callback for live status and traffic samples. |
| `dbPath` | `String?` | `aware_network` | SQLite database path. |
| `dbTableName` | `String?` | `ios_network` in AwareClient | Active status table name. |

## Data

`NetworkData` stores connectivity state:

| Field | Type | Description |
| --- | --- | --- |
| `networkType` | `Int` | AWARE type. `1` Wi-Fi, `4` mobile. |
| `networkSubtype` | `String` | `WIFI` or `MOBILE`. |
| `networkState` | `Int` | `1` on, `0` off. |

`NetworkTrafficData` stores interface counters:

| Field | Type | Description |
| --- | --- | --- |
| `networkType` | `Int` | Traffic type. `1` mobile, `2` Wi-Fi. |
| `networkSubtype` | `String` | `WIFI` or `MOBILE`. |
| `interfaceName` | `String` | Interface name, for example `en0` or `pdp_ip0`. |
| `receivedBytes` / `sentBytes` | `Double` | Cumulative byte counters from the OS. |
| `receivedPackets` / `sentPackets` | `Double` | Cumulative packet counters from the OS. |
| `receivedBytesDelta` / `sentBytesDelta` | `Double` | Difference from the previous sample. |
| `receivedPacketsDelta` / `sentPacketsDelta` | `Double` | Packet difference from the previous sample. |
| `totalBytesDelta` | `Double` | Received plus sent byte delta. |

The first traffic sample has zero deltas because there is no previous counter snapshot.

## Notifications

| Notification | Description |
| --- | --- |
| `actionAwareNetworkStart` | Posted when the sensor starts. |
| `actionAwareNetworkStop` | Posted when the sensor stops. |
| `actionAwareNetwork` | Posted after each connectivity state record. |
| `actionAwareNetworkWifiOn` / `actionAwareNetworkWifiOff` | Posted when Wi-Fi state changes. |
| `actionAwareNetworkMobileOn` / `actionAwareNetworkMobileOff` | Posted when mobile state changes. |
| `actionAwareInternetAvailable` / `actionAwareInternetUnavailable` | Posted when internet availability changes. |
| `actionAwareNetworkTraffic` | Posted after each traffic sample. |
| `actionAwareNetworkSync` | Posted when sync starts. |
| `actionAwareNetworkSyncCompletion` | Posted when a table sync completes. |
| `actionAwareNetworkSetLabel` | Posted when the label changes. |

## Observer

```swift
final class Observer: NetworkObserver {
    func onNetworkChanged(data: NetworkData) {}
    func onTrafficChanged(data: [NetworkTrafficData]) {}
    func onInternetAvailable(access: Int) {}
    func onInternetUnavailable() {}
}
```

## Notes

The traffic implementation uses iOS/macOS interface counters exposed through `getifaddrs`.
It monitors Wi-Fi as `en0` and cellular interfaces as `pdp_ip*`. iOS does not expose per-app
network byte counts through public APIs, so these values represent interface-level counters.
