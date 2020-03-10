//
//  EAFileManager.swift
//  Restor
//
//  Created by jsloop on 10/03/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation

/// File open mode
public enum FileIOMode {
    case read
    case write
    case append
}

public class EAFileManager: NSObject {
    private let url: URL!
    private var callback: EADataResultCallback?
    private var data: Data?
    private let fm = FileManager.default
    private static let fm = FileManager.default
    private var fileHandle: FileHandle?
    private let queue = DispatchQueue(label: "com.estoapps.ios.restor8", qos: .userInitiated, attributes: .concurrent, autoreleaseFrequency: .workItem, target: nil)
    var isFileOpened = false

    deinit {
        Log.debug("EAFileManager deinit")
    }
    
    init(url: URL) {
        self.url = url
        super.init()
    }
    
    /// Checks if the file exists at the given URL.
    public static func isFileExists(at url: URL) -> Bool {
        return self.fm.fileExists(atPath: url.path)
    }
    
    /// Checks if the directory exists at the given URL.
    public static func isDirectoryExists(at url: URL) -> Bool {
        var isDir: ObjCBool = false
        if self.fm.fileExists(atPath: url.path, isDirectory: &isDir) {
            return isDir.boolValue
        }
        return false
    }
    
    /// Create directory at the given path including intermediate directories as well.
    public static func createDirectory(at url: URL) -> Bool {
        do {
            try self.fm.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
            return true
        } catch let err {
            print("Error creating directory: \(err)")
            return false
        }
    }
    
    /// Create a file at the given file url irrespective of whether the file exists or not. If the file exists at the file url, this will clear its contents.
    public static func createFile(_ url: URL) {
        self.fm.createFile(atPath: url.path, contents: nil, attributes: nil)
    }
    
    /// Creates a file at the given file URL if it does not exists already.
    public static func createFileIfNotExists(_ url: URL) {
        if !self.isFileExists(at: url) {
            let dirURL = url.deletingLastPathComponent()
            if !self.isDirectoryExists(at: dirURL) { _ = self.createDirectory(at: dirURL) }
            self.createFile(url)
        }
    }
    
    /// Open an existing file with the given mode, which can be for reading, writing or for appending.
    public func openFile(for mode: FileIOMode) {
        switch mode {
        case .read:
            self.fileHandle = FileHandle(forReadingAtPath: self.url.path)
        case .write:
            self.fileHandle = FileHandle(forWritingAtPath: self.url.path)
        case .append:
            self.fileHandle = FileHandle(forUpdatingAtPath: self.url.path)
        }
        self.isFileOpened = true
    }
    
    /// Reads the entire file and return the data object
    public func readToEOF(completion: EADataResultCallback? = nil) {
        self.queue.async {
            do {
                self.data = try Data(contentsOf: self.url)
                if let x = self.data, let cb = completion { cb(.success(x)) }
            } catch let error {
                Log.error("Error reading file: \(error)")
                if let cb = completion { cb(.failure(AppError.fileRead)) }
            }
        }
    }
}
