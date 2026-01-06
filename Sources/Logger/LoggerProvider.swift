//
//  LoggerProvider.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 2/12/25.
//

import Foundation

protocol LoggerProvider: Sendable {
    nonisolated func debug(_ message: String, attributes: [String: Encodable]?)
    nonisolated func error(_ message: String, attributes: [String: Encodable]?)
    nonisolated func info(_ message: String, attributes: [String: Encodable]?)
    nonisolated func warn(_ message: String, attributes: [String: Encodable]?)
    nonisolated func flush() async
}

extension LoggerProvider {
    nonisolated func flush() { }
}
