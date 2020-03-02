//
//  Utils.swift
//  Restor
//
//  Created by jsloop on 03/12/19.
//  Copyright © 2019 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit
import CommonCrypto

class Utils {
    static let shared: Utils = Utils()
    private let userDefaults = UserDefaults.standard
    
    // MARK: - UserDefaults
    
    func getValue(_ key: String) -> Any? {
        return self.userDefaults.value(forKey: key)
    }
    
    func setValue(key: String, value: Any) {
        self.userDefaults.set(value, forKey: key)
    }
    
    func removeValue(_ key: String) {
        self.userDefaults.removeObject(forKey: key)
    }

    // MARK: - Misc
    
    /// Generate a random number between the given range [begin, end).
    func genRandom(_ begin: Int, _ end: Int) -> Int {
        return Int.random(in: begin..<end)
    }
    
    /// Check if the given string contains only numbers.
    func isNumber(_ text: String) -> Bool {
        return CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: text))
    }
    
    /// Returns only the digits from the given string.
    func digits(_ text: String) -> String {
        return text.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
    }
    
    /// XOR encrypt plain text with a key.
    /// - Parameters:
    ///     - plainText: A plain text for encryption.
    ///     - withKey: Encryption key.
    /// - Returns: An array containing encrypted bytes
    func xorEncrypt(_ plainText: String, withKey: String) -> [UInt8] {
        var encrypted: [UInt8] = []
        if plainText.isEmpty {
            return []
        }
        let text: [UInt8] = Array(plainText.utf8)
        let key: [UInt8] = Array(withKey.utf8)
        let len = key.count
        text.enumerated().forEach { idx, elem in
            encrypted.append(elem ^ key[idx % len])
        }
        return encrypted
    }
    
    /// XOR decrypt cipher text with a key.
    /// - Parameters:
    ///     - cipherText: A cipher text for decryption.
    ///     - withKey: Decryption key.
    /// - Returns: The decrypted string.
    func xorDecrypt(_ cipherText: [UInt8], withKey: String) -> String {
        var decrypted: [UInt8] = []
        if cipherText.count == 0 {
            return ""
        }
        let key: [UInt8] = Array(withKey.utf8)
        let len = key.count
        cipherText.enumerated().forEach { idx, elem in
            decrypted.append(elem ^ key[idx % len])
        }
        return String(bytes: decrypted, encoding: .utf8)!
    }
    
    /// Returns a random string of length 20.
    func genRandomString() -> String {
        var xs = UUID.init().uuidString.lowercased().components(separatedBy: "-")
        xs.removeLast()
        return xs.joined()
    }
    
    func base64Encode(_ str: String) -> String {
        return Data(str.utf8).base64EncodedString()
    }
    
    func base64Decode(_ str: String) -> String? {
        guard let data = Data(base64Encoded: str) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    /// Capitalise the first character in the given text
    func capitalizeText(_ txt: String) -> String {
        if txt.count >= 2, let c = txt.first {
            let f = String(c).uppercased()
            return "\(f)\(txt[1..<txt.count])"
        }
        return txt
    }
    
    /// Converts the first character of the text to smaller case.
    func lowerCaseText(_ txt: String) -> String {
        if txt.count >= 2, let c = txt.first {
            let f = String(c).lowercased()
            return "\(f)\(txt[1..<txt.count])"
        }
        return txt
    }
    
    /// Generates the MD5 hash corresponding to the given text.
    func md5(_ txt: String) -> String {
        let context = UnsafeMutablePointer<CC_MD5_CTX>.allocate(capacity: 1)
        var digest = Array<UInt8>(repeating:0, count:Int(CC_MD5_DIGEST_LENGTH))
        CC_MD5_Init(context)
        CC_MD5_Update(context, txt, CC_LONG(txt.lengthOfBytes(using: String.Encoding.utf8)))
        CC_MD5_Final(&digest, context)
        context.deallocate()
        var hex = ""
        for byte in digest {
            hex += String(format:"%02x", byte)
        }
        return hex
    }
}

class Log {
    static func debug(_ msg: Any) {
        #if DEBUG
        print("[DEBUG] \(msg)")
        #endif
    }
    
    static func error(_ msg: Any) {
        print("[ERR] \(msg)")
    }
    
    static func info(_ msg: Any) {
        print("[INFO] \(msg)")
    }
}
