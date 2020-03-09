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
    private var inpStream: InputStream?
    private var outStream: OutputStream?
    public typealias EAFileManagerCallback = ((Result<Data, Error>) -> Void)
    private var callback: EAFileManagerCallback?
    private var buffSize: Int = 1024
    private var data: Data!
    private let fm = FileManager.default
    private static let fm = FileManager.default
    private var fileHandle: FileHandle?
    private let nc = NotificationCenter.default

    deinit {
        self.nc.removeObserver(self)
    }
    
    init(url: URL) {
        self.url = url
        self.data = Data()
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
    }
    
    public func read(completion: EAFileManagerCallback? = nil) {
        self.nc.addObserver(self, selector: #selector(self.readToEOFDidComplete(_:)), name: .NSFileHandleReadToEndOfFileCompletion, object: nil)
        self.fileHandle?.readToEndOfFileInBackgroundAndNotify()
    }

    @objc private func readToEOFDidComplete(_ notif: Notification) {
        Log.debug("read to EOF did complete")
        if let info = notif.userInfo as? [String: Any], let data = info[NSFileHandleNotificationDataItem] as? Data {
            self.data = data
            // TODO: test
        }
    }
}
