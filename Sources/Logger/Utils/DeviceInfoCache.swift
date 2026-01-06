//
//  DeviceInfoCache.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 29/12/24.
//

import Foundation
import Network
#if canImport(UIKit)
@preconcurrency import UIKit
import CoreTelephony
#endif

struct DeviceInfoCache: @unchecked Sendable {
    let model: String
    let deviceName: String
    let osName: String
    let osVersion: String
    let osBuild: String
    let architecture: String
    let appVersion: String
    let appBuild: String
    let networkConnectionType: String
    let cellularTechnology: String?

    #if canImport(UIKit)
    private nonisolated(unsafe) static func getDeviceModel() -> String {
        if Thread.isMainThread {
            return UIDevice.current.model
        } else {
            return DispatchQueue.main.sync { UIDevice.current.model }
        }
    }

    private nonisolated(unsafe) static func getDeviceName() -> String {
        if Thread.isMainThread {
            return UIDevice.current.name
        } else {
            return DispatchQueue.main.sync { UIDevice.current.name }
        }
    }

    private nonisolated(unsafe) static func getOSName() -> String {
        if Thread.isMainThread {
            return UIDevice.current.systemName
        } else {
            return DispatchQueue.main.sync { UIDevice.current.systemName }
        }
    }

    private nonisolated(unsafe) static func getOSVersion() -> String {
        if Thread.isMainThread {
            return UIDevice.current.systemVersion
        } else {
            return DispatchQueue.main.sync { UIDevice.current.systemVersion }
        }
    }

    private static func getOSBuild() -> String {
        var size = 0
        sysctlbyname("kern.osversion", nil, &size, nil, 0)
        var build = [UInt8](repeating: 0, count: size)
        sysctlbyname("kern.osversion", &build, &size, nil, 0)
        return String(decoding: build.prefix(while: { $0 != 0 }), as: UTF8.self)
    }

    private static func getArchitecture() -> String {
        #if arch(arm64e)
        return "arm64e"
        #elseif arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }

    private static func getNetworkConnectionType() -> String {
        #if targetEnvironment(simulator)
        return "unknown"
        #else
        final class ConnectionTypeHolder: @unchecked Sendable {
            var value: String = "unknown"
        }

        let pathMonitor = NWPathMonitor()
        let semaphore = DispatchSemaphore(value: 0)
        let holder = ConnectionTypeHolder()

        pathMonitor.pathUpdateHandler = { path in
            if path.usesInterfaceType(.wifi) {
                holder.value = "wifi"
            } else if path.usesInterfaceType(.cellular) {
                holder.value = "cellular"
            } else if path.usesInterfaceType(.wiredEthernet) {
                holder.value = "ethernet"
            } else if path.status == .satisfied {
                holder.value = "other"
            } else {
                holder.value = "none"
            }
            semaphore.signal()
        }

        let queue = DispatchQueue(label: "com.crossmint.network-monitor")
        pathMonitor.start(queue: queue)
        let result = semaphore.wait(timeout: .now() + 0.1)
        pathMonitor.cancel()

        return result == .success ? holder.value : "unknown"
        #endif
    }

    private static func getCellularTechnology() -> String? {
        let networkInfo = CTTelephonyNetworkInfo()
        guard let currentRadio = networkInfo.serviceCurrentRadioAccessTechnology?.values.first else {
            return nil
        }

        switch currentRadio {
        case CTRadioAccessTechnologyGPRS, CTRadioAccessTechnologyEdge:
            return "2G"
        case CTRadioAccessTechnologyWCDMA,
             CTRadioAccessTechnologyHSDPA,
             CTRadioAccessTechnologyHSUPA,
             CTRadioAccessTechnologyCDMA1x,
             CTRadioAccessTechnologyCDMAEVDORev0,
             CTRadioAccessTechnologyCDMAEVDORevA,
             CTRadioAccessTechnologyCDMAEVDORevB,
             CTRadioAccessTechnologyeHRPD:
            return "3G"
        case CTRadioAccessTechnologyLTE:
            return "4G"
        case CTRadioAccessTechnologyNRNSA, CTRadioAccessTechnologyNR:
            return "5G"
        default:
            return nil
        }
    }

    static func capture() -> DeviceInfoCache {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let appBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        let networkType = getNetworkConnectionType()

        return DeviceInfoCache(
            model: getDeviceModel(),
            deviceName: getDeviceName(),
            osName: getOSName(),
            osVersion: getOSVersion(),
            osBuild: getOSBuild(),
            architecture: getArchitecture(),
            appVersion: appVersion,
            appBuild: appBuild,
            networkConnectionType: networkType,
            cellularTechnology: networkType == "cellular" ? getCellularTechnology() : nil
        )
    }
    #else

    static func capture() -> DeviceInfoCache {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let appBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"

        return DeviceInfoCache(
            model: "macOS",
            deviceName: ProcessInfo.processInfo.hostName,
            osName: "macOS",
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            osBuild: "unknown",
            architecture: "unknown",
            appVersion: appVersion,
            appBuild: appBuild
        )
    }
    #endif
}
