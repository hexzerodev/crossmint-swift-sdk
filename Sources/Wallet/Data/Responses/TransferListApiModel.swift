//
//  TransferListApiModel.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 21/01/26.
//

import CrossmintCommonTypes
import Foundation

struct TransferListApiModel: Decodable {
    let data: [TransferApiModel]
}

struct TransferApiModel: Decodable {
    let type: String
    let sender: TransferParticipantApiModel
    let recipient: TransferParticipantApiModel
    let token: TransferTokenApiModel
    let status: String
    let onChain: TransferOnChainApiModel?
    let completedAt: String
    let error: TransferErrorApiModel?
}

struct TransferParticipantApiModel: Decodable {
    let address: String
    let chain: String
    let locator: String
    let owner: String?
}

struct TransferTokenApiModel: Decodable {
    let type: String
    let chain: String
    let locator: String
    let amount: String
    let symbol: String
    let decimals: Int
}

struct TransferOnChainApiModel: Decodable {
    let txId: String
    let explorerLink: String?
}

struct TransferErrorApiModel: Decodable {
    let code: String
    let message: String
}
