//
//  DataDogConfig.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 2/12/25.
//

import Foundation

public enum DataDogConfig {
    static let clientToken = "pub946d87ea0c2cc02431c15e9446f776fc"

    private(set) nonisolated(unsafe) static var environment: String = "production"

    public static func configure(environment: String) {
        self.environment = environment
    }
}
