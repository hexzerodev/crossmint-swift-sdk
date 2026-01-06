//
//  LogEntry.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 26/12/25.
//

struct LogEntry {
    let level: LogLevel
    let message: String
    let timestamp: String
    let context: [String: Encodable]
}
