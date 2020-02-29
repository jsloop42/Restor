//
//  Request.swift
//  Restor
//
//  Created by jsloop on 05/12/19.
//  Copyright © 2019 EstoApps. All rights reserved.
//

import Foundation
import UIKit

class Request {
    var created: Int64
    var name: String = ""
    var desc: String = ""
    var tags: [String] = []
    var url: String = ""
    var selectedMethodIndex = 0
    /// The request methods which can also contain custom data. With Core Data, only custom methods are saved.
    var methods: [RequestMethodData] = []
    var modified: Int64
    var headers: [RequestData] = []
    var params: [RequestData] = []
    var body: RequestBodyData?
    weak var project: Project?
    var version: Int64
    // Method names are case sensitive RFC 7230, 7231
    private let reqMethods = ["GET", "POST", "PUT", "OPTION", "DELETE"]
    
    init() {
        for i in self.reqMethods {
            self.methods.append(RequestMethodData(name: i, isCustom: false, project: self.project))
        }
        self.created = Date().currentTimeMillis()
        self.modified = self.created
        self.version = 0
    }
}

protocol RequestDataProtocol {
    func getKey() -> String
    func getValue() -> String
    func getFieldType() -> RequestBodyFormFieldType
    func setFieldType(_ type: RequestBodyFormFieldType)
    func getImage() -> UIImage?
    func getFiles() -> [URL]
}

class RequestData: RequestDataProtocol {
    var created: Int64
    var modified: Int64
    var key: String
    var value: String
    var type: RequestBodyFormFieldType = .text
    var isEditing: Bool = false
    var image: UIImage?
    /// If the image was taken from the camera directly for from the photo library
    var isCameraMode: Bool = false
    var files: [URL] = []
    var version: Int64
    
    convenience init() {
        self.init(key: "", value: "")
    }
    
    init(key: String, value: String) {
        self.key = key
        self.value = value
        self.created = Date().currentTimeMillis()
        self.modified = self.created
        self.version = 0
    }
    
    func getKey() -> String {
        return key
    }
    
    func getValue() -> String {
        return value
    }
    
    func getFieldType() -> RequestBodyFormFieldType {
        return self.type
    }
    
    func setFieldType(_ type: RequestBodyFormFieldType) {
        self.type = type
    }
    
    func getImage() -> UIImage? {
        return self.image
    }
    
    func getFiles() -> [URL] {
        return self.files
    }
}

class RequestBodyData {
    var json: String?
    var xml: String?
    var raw: String?
    var form: [RequestData] = []
    var multipart: [RequestData] = []
    var binary: Data?
    var selected: Int = RequestBodyType.json.rawValue
}

enum RequestBodyType: Int {
    case json
    case xml
    case raw
    case form
    case multipart
    case binary
}

/// Form fields under request body
enum RequestBodyFormFieldType: Int {
    case text
    case file

    static var allCases: [String] {
        return ["Text", "File"]
    }
}

struct RequestMethodData {
    var created: Int64
    var modified: Int64
    var name: String
    var isCustom = false
    weak var project: Project?
    var version: Int64
    
    init(name: String, isCustom: Bool, project: Project?) {
        self.name = name
        self.isCustom = isCustom
        self.project = project
        self.created = Date().currentTimeMillis()
        self.modified = self.created
        self.version = 0
    }
    
    init(name: String, project: Project?) {
        self.init(name: name, isCustom: false, project: project)
    }
}
