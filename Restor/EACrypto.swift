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
