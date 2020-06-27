//
//  EAHTTPCookie.swift
//  Restor
//
//  Created by jsloop on 27/05/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation

struct EAHTTPCookie: Codable, CustomStringConvertible {
    var name: String
    var value: String
    var expires: Date?
    var session: Bool
    var domain: String
    var path: String
    var secure: Bool
    var httpOnly: Bool
    var sameSite: String = ""
    
    enum SameSite: String {
        case lax = "Lax"
        case strict = "Strict"
    }
    
    init(with cookie: HTTPCookie) {
        self.name = cookie.name
        self.value = cookie.value
        self.expires = cookie.expiresDate
        self.session = cookie.isSessionOnly
        self.domain = cookie.domain
        self.path = cookie.path
        self.secure = cookie.isSecure
        self.httpOnly = cookie.isHTTPOnly
        if #available(iOS 13.0, *) {
            if let policy = cookie.sameSitePolicy { self.sameSite = SameSite(rawValue: policy.rawValue)?.rawValue ?? "" }
        }
    }
    
    static func from(headers: [String: String], for url: URL) -> [EAHTTPCookie] {
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: headers, for: url)
        return cookies.map { cookie in EAHTTPCookie(with: cookie) }
    }
    
    func toHTTPCookie() -> HTTPCookie? {
        let hm: [HTTPCookiePropertyKey: Any] = [
            .name: self.name,
            .value: self.value,
            .expires: self.expires as Any,
            .discard: self.session,
            .domain: self.domain,
            .path: self.path,
            .secure: self.secure
        ]
        return HTTPCookie(properties: hm)
    }
    
    var description: String {
        return """
               \(type(of: self)):
               name: \(self.name)
               value: \(self.value)
               expires: \(String(describing: self.expires))
               session: \(self.session)
               domain: \(self.domain)
               path: \(self.path)
               secure: \(self.secure)
               httpOnly: \(self.httpOnly)
               """
    }
}
