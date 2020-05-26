//
//  EAUtils.swift
//  Restor
//
//  Created by jsloop on 03/12/19.
//  Copyright © 2019 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit
import CommonCrypto

class EAUtils {
    static let shared: EAUtils = EAUtils()
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
        if cipherText.isEmpty { return "" }
        let key: [UInt8] = Array(withKey.utf8)
        let len = key.count
        cipherText.enumerated().forEach { idx, elem in
            decrypted.append(elem ^ key[idx % len])
        }
        return String(bytes: decrypted, encoding: .utf8)!
    }
    
    /// Returns a random string of length 22 by compressing the UUID.
    func genRandomString() -> String {
        return self.compress(uuid: UUID()) ?? ""
    }
    
    /// Generates a uuid with the given identifier and compresses it to return a 22 bytes string.
    func compress(id: String) -> String? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        print("uuid: \(uuid)")
        return self.compress(uuid: uuid)
    }
    
    /// Compresses the given UUID to a 22 bytes string.
    func compress(uuid: UUID) -> String? {
        print("uuid: \(uuid)")
        let padding = "="
        let base64 = uuid.data.base64EncodedString(options: Data.Base64EncodingOptions())
        return base64.replacingOccurrences(of: padding, with: "")
    }

    /// Decompresses a compressed UUID string back to its full form returning a 36 bytes string.
    func decompress(shortId: String?) -> String? {
        guard let id = shortId else { return nil }
        let padding = "="
        let idPadded = "\(id)\(padding)\(padding)"
        if let data = Data(base64Encoded: idPadded) {
            return UUID.fromBytes(data.toBytes()).uuidString
        }
        return nil
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
    func md5(txt: String) -> String {
        let context = UnsafeMutablePointer<CC_MD5_CTX>.allocate(capacity: 1)
        var digest = Array<UInt8>(repeating:0, count:Int(CC_MD5_DIGEST_LENGTH))
        CC_MD5_Init(context)
        CC_MD5_Update(context, txt, CC_LONG(txt.lengthOfBytes(using: String.Encoding.utf8)))
        CC_MD5_Final(&digest, context)
        context.deallocate()
        return self.toHex(digest)
    }
    
    /// Generates the MD5 hash corresponding to the given data.
    func md5(data: Data) -> String {
        var digest = Array<UInt8>(repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        var hex = ""
        _ = data.withUnsafeBytes { bytes in
            let buff: UnsafePointer<UInt8> = bytes.baseAddress!.assumingMemoryBound(to: UInt8.self)
            CC_MD5(buff, CC_LONG(data.count), &digest)
            hex = self.toHex(digest)
        }
        return hex
    }
    
    /// Get hex string from the given array.
    func toHex(_ xs: [UInt8]) -> String {
        var hex = ""
        for byte in xs {
            hex += String(format: "%02x", byte)
        }
        return hex
    }
    
    /// Returns elements in the first list that are not in the second list.
    func subtract<T: Hashable>(lxs: [T], rxs: [T]) -> [T] {
        var lset = Set<T>(lxs)
        let rset = Set<T>(rxs)
        lset.subtract(rset)
        return lset.toArray()
    }
    
    /// Get address of any value type.
    func address(o: UnsafeRawPointer) -> Int {
        return Int(bitPattern: o)
    }

    /// Get address of any reference type.
    func addressHeap<T: AnyObject>(o: T) -> Int {
        return unsafeBitCast(o, to: Int.self)
    }
    
    /// Returns the given bytes in a readable format string
    func bytesToReadable(_ bytes: Int64) -> String {
        let bcf = ByteCountFormatter()
        bcf.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        bcf.countStyle = .binary
        return bcf.string(fromByteCount: bytes)
    }
}

class Log {
    static func debug(_ msg: Any) {
        #if DEBUG
        print("[DEBUG] \(msg)")
        #endif
    }
    
    static func error(_ msg: Any) {
        print("[ERROR] \(msg)")
    }
    
    static func info(_ msg: Any) {
        print("[INFO] \(msg)")
    }
}
