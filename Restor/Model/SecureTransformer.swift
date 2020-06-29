//
//  SecureTransformer.swift
//  Restor
//
//  Created by jsloop on 15/06/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation

fileprivate struct SecureTransformerInfo {
    private static let utils = { EAUtils.shared }()
    private static let _key: [UInt8] = [79, 87, 53, 108, 90, 72, 73, 53, 78, 87, 49, 108, 100, 87, 120, 106, 97, 68, 74, 109, 99, 88, 86, 51, 90, 68, 70, 105,
                                        79, 84, 104, 120, 100, 110, 90, 104, 99, 71, 49, 122, 97, 51, 77, 61]
    private static let _iv: [UInt8] = [78, 84, 82, 120, 90, 106, 70, 108, 100, 84, 70, 104, 100, 87, 69, 52, 97, 109, 100, 51, 101, 65, 61, 61]
    
    static var key: String {
        guard let str = String(data: Data(_key), encoding: .utf8) else { return "" }
        return self.utils.base64Decode(str) ?? ""
    }
    static var iv: String {
        guard let str = String(data: Data(_iv), encoding: .utf8) else { return "" }
        return self.utils.base64Decode(str) ?? ""
    }
}

/// A class that can be used for encrypting and decrypting core data `String` values on the fly.
class SecureTransformerString: ValueTransformer {
    private let aes = AES(key: SecureTransformerInfo.key, iv: SecureTransformerInfo.iv)
    
    override class func allowsReverseTransformation() -> Bool {
        return true
    }
    
    /// Encrypt the value.
    override func transformedValue(_ value: Any?) -> Any? {
        guard let text = value as? String else { return nil }
        return self.aes?.encrypt(string: text)
    }
    
    /// Decrypt the value.
    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else { return nil }
        if let res = self.aes?.decrypt(data: data) {
            return String(data: res, encoding: .utf8)
        }
        return nil
    }
}

/// A class that can be used for encrypting and decrypting core data `Data` values on the fly.
class SecureTransformerData: ValueTransformer {
    private let aes = AES(key: SecureTransformerInfo.key, iv: SecureTransformerInfo.iv)
    
    override class func allowsReverseTransformation() -> Bool {
        return true
    }
    
    /// Decrypt the value.
    /// - Parameter value: A data value
    /// - Returns: Encrypted binary data
    override func transformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else { return nil }
        return self.aes?.encrypt(data: data)
    }
    
    /// Decrypt the value.
    /// - Parameter value: A transformed data value
    /// - Returns: Decrypted binary data
    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else { return nil }
        return self.aes?.decrypt(data: data)  // returns Data
    }
}
