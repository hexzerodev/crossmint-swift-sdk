//
//  UnsafeSendableAttributes.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 26/12/25.
//

struct UnsafeSendableAttributes: @unchecked Sendable {
    let value: [String: Encodable]?
}
