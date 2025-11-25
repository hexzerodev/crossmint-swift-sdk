//
//  CrossmintAuthManager.swift
//  SmartWalletsDemo
//
//  Created by Austin Feight on 11/24/25.
//

import Auth
import CrossmintClient

let crossmintApiKey = "ck_staging_YOUR_API_KEY"
let crossmintAuthManager = try! CrossmintAuthManager(apiKey: crossmintApiKey)
