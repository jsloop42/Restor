//
//  EACrypto.swift
//  Restor
//
//  Created by jsloop on 16/05/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation

public class PKCS12 {
    var label: String?
    var keyID: Data?
    var trust: SecTrust?
    var certChain: [SecTrust]?
    var identity: SecIdentity?
    
    public init(data: Data, password: String) {
        let opts: NSDictionary = [kSecImportExportPassphrase as NSString: password]
        var items: CFArray?
        let status: OSStatus = SecPKCS12Import(data as CFData, opts, &items)
        guard status == errSecSuccess else {
            if status == errSecAuthFailed { Log.error("Authentication failed.") }
            return
        }
        guard let itemsCFArr = items else { return }
        let itemsNSArr: NSArray = itemsCFArr as NSArray
        guard let hmxs = itemsNSArr as? [[String: AnyObject]] else { return }
           
        func f<T>(_ k: CFString) -> T? {
            for hm in hmxs {
                if let v = hm[k as String] as? T { return v }
            }
            return nil
        }

        self.label = f(kSecImportItemLabel)
        self.keyID = f(kSecImportItemKeyID)
        self.trust = f(kSecImportItemTrust)
        self.certChain = f(kSecImportItemCertChain)
        self.identity = f(kSecImportItemIdentity)
    }
}

extension URLCredential {
    convenience init?(pkcs12: PKCS12) {
        if let identity = pkcs12.identity {
            self.init(identity: identity, certificates: pkcs12.certChain, persistence: .none)
        } else { return nil }
    }
}

/// An enum reflecting the tsl_cuphersuite_t enum from Security module.
public enum EATLSCipherSuite: Int {
    case rsa_with_3des_ede_cbc_sha = 10
    case rsa_with_aes128_cbc_sha = 47
    case rsa_with_aes256_cbc_sha = 53
    case rsa_with_aes128_gcm_sha256 = 156
    case rsa_with_aes256_gcm_sha384 = 157
    case rsa_with_aes128_cbc_sha256 = 60
    case rsa_with_aes256_cbc_sha256 = 61
    case ecdhe_ecdsa_with_3des_ede_cbc_sha = 49160
    case ecdhe_ecdsa_with_aes128_cbc_sha = 49161
    case ecdhe_ecdsa_with_aes256_cbc_sha = 49162
    case ecdhe_rsa_with_3des_ede_cbc_sha = 49170
    case ecdhe_rsa_with_aes128_cbc_sha = 49171
    case ecdhe_rsa_with_aes256_cbc_sha = 49172
    case ecdhe_ecdsa_with_aes128_cbc_sha256 = 49187
    case ecdhe_ecdsa_with_aes256_cbc_sha384 = 49188
    case ecdhe_rsa_with_aes128_cbc_sha256 = 49191
    case ecdhe_rsa_with_aes256_cbc_sha384 = 49192
    case ecdhe_ecdsa_with_aes128_gcm_sha256 = 49195
    case ecdhe_ecdsa_with_aes256_gcm_sha384 = 49196
    case ecdhe_rsa_with_aes128_gcm_sha256 = 49199
    case ecdhe_rsa_with_aes256_gcm_sha384 = 49200
    case ecdhe_rsa_with_chacha20_poly1305_sha256 = 52392
    case ecdhe_ecdsa_with_chacha20_poly1305_sha256 = 52393
    case aes128_gcm_sha256 = 4865
    case aes256_gcm_sha384 = 4866
    case chacha20_poly1305_sha256 = 4867
    
    public init?(_ t: UInt16) {
        self.init(rawValue: Int(t))
    }
    
    func toString() -> String {
        switch self {
        case .aes128_gcm_sha256: return "AES128 GCM SHA256"
        case .aes256_gcm_sha384: return "AES256 GCM SHA384"
        case .chacha20_poly1305_sha256: return "ChaCha20 Poly1305 SHA256"
        case .ecdhe_ecdsa_with_3des_ede_cbc_sha: return "ECDHE-ECDSA with 3DES EDE CBC SHA"
        case .ecdhe_ecdsa_with_aes128_cbc_sha: return "ECDHE-ECDSA with AES128 CBC SHA"
        case .ecdhe_ecdsa_with_aes256_cbc_sha: return "ECDHE-ECDSA with AES256 CBC SHA"
        case .ecdhe_ecdsa_with_aes128_cbc_sha256: return "ECDHE-ECDSA with AES128 CBC SHA256"
        case .ecdhe_ecdsa_with_aes256_cbc_sha384: return "ECDHE-ECDSA with AES256 CBC SHA384"
        case .ecdhe_rsa_with_3des_ede_cbc_sha: return "ECDHE RSA with 3DES EDE CBC SHA"
        case .ecdhe_rsa_with_aes128_cbc_sha: return "ECDHE RSA with AES128 CBC SHA"
        case .ecdhe_rsa_with_aes256_cbc_sha: return "ECDHE RSA with AES256 CBC SHA"
        case .ecdhe_rsa_with_aes128_cbc_sha256: return "ECDHE RSA with AES128 CBC SHA256"
        case .ecdhe_rsa_with_aes256_cbc_sha384: return "ECDHE RSA with AES256 CBC SHA384"
        case .ecdhe_ecdsa_with_aes128_gcm_sha256: return "ECDHE-ECDSA with AES128 GCM SHA256"
        case .ecdhe_ecdsa_with_aes256_gcm_sha384: return "ECDHE-ECDSA with AES256 GCM SHA384"
        case .ecdhe_rsa_with_aes128_gcm_sha256: return "ECDHE RSA with AES128 GCM SHA256"
        case .ecdhe_rsa_with_aes256_gcm_sha384: return "ECDHE RSA with AES256 GCM SHA384"
        case .ecdhe_rsa_with_chacha20_poly1305_sha256: return "ECDHE RSA with ChaCha20 Poly1305 SHA256"
        case .ecdhe_ecdsa_with_chacha20_poly1305_sha256: return "ECDHE-ECDSA with ChaCha20 Poly1305 SHA256"
        case .rsa_with_3des_ede_cbc_sha: return "RSA with 3DES EDE CBC SHA"
        case .rsa_with_aes128_cbc_sha: return "RSA with AES128 CBC SHA"
        case .rsa_with_aes256_cbc_sha: return "RSA with AES256 CBC SHA"
        case .rsa_with_aes128_gcm_sha256: return "RSA with AES128 GCM SHA256"
        case .rsa_with_aes256_gcm_sha384: return "RSA with AES256 GCM SHA384"
        case .rsa_with_aes128_cbc_sha256: return "RSA with AES128 CBC SHA256"
        case .rsa_with_aes256_cbc_sha256: return "RSA with AES256 CBC SHA256"
        }
    }
}

/// An enum reflecting the tls_protocol_version_t enum from Security module.
public enum EATLSProtocolVersion: Int {
    case tls10 = 769
    case tls11 = 770
    case tls12 = 771
    case tls13 = 772
    case dtls10 = 65279
    case dtls12 = 65277
    
    public init?(_ t: UInt16) {
        self.init(rawValue: Int(t))
    }
    
    func toString() -> String {
        switch self {
        case .tls10: return "TLS v1.0"
        case .tls11: return "TLS v1.1"
        case .tls12: return "TLS v1.2"
        case .tls13: return "TLS v1.3"
        case .dtls10: return "DTLS v1.0"
        case .dtls12: return "DTLS v1.2"
        }
    }
}
