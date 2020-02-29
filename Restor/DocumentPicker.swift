//
//  DocumentPicker.swift
//  Restor
//
//  Created by jsloop on 24/02/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit
import MobileCoreServices
import AVFoundation
import Photos

class DocumentPicker: NSObject {
    static let shared = DocumentPicker()
    let docTypes = ["com.apple.iwork.pages.pages", "com.apple.iwork.numbers.numbers",
                    "com.apple.iwork.keynote.key", "public.image", "com.apple.application", "public.item",
                    "public.content", "public.audiovisual-content", "public.movie",
                    "public.audiovisual-content", "public.video", "public.audio", "public.text", "public.data",
                    "public.zip-archive", "com.pkware.zip-archive", "public.composite-content"]
    var navVC: UINavigationController?
    /// The delegate need to be set from a view controller instance
    lazy var photoPicker: UIImagePickerController = {
        let picker = UIImagePickerController()
        return picker
    }()
    /// The delegate need to be set from a view controller instance
    lazy var docPicker: UIDocumentPickerViewController = {
        let picker = UIDocumentPickerViewController(documentTypes: self.docTypes, in: .import)
        picker.allowsMultipleSelection = true
        if #available(iOS 13.0, *) {
            picker.shouldShowFileExtensions = true
        }
        picker.modalPresentationStyle = .formSheet
        return picker
    }()
    private let photoAccessMessage = "Restor does not have access to your photos or videos. To enable access, tap Settings and turn on Photos."
    private let cameraAccessMessage = "Restor does not have access to your camera. To enable access, tap Settings and turn on Camera."
    private let nc = NotificationCenter.default
    
    func requestCameraAuthorization(completion: ((Bool) -> Void)? = nil) {
        AVCaptureDevice.requestAccess(for: AVMediaType.video) { response in
            completion?(response)
        }
    }
    
    func requestPhotoLibraryAuthorization(completion: ((Bool) -> Void)? = nil) {
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                Log.debug("photo access granted")
                completion?(true)
            } else {
                Log.debug("photo access denied")
                completion?(false)
            }
        }
    }
    
    func presentDocumentPicker(navVC: UINavigationController? = nil, vc: UIDocumentPickerDelegate? = nil, completion: (() -> Void)? = nil) {
        if navVC != nil { self.navVC = navVC }
        guard let aVC = self.navVC else { return }
        self.docPicker.delegate = vc
        aVC.present(self.docPicker, animated: true, completion: completion)
    }
    
    func presentPhotoPicker(navVC: UINavigationController? = nil, isCamera: Bool, vc: (UIImagePickerControllerDelegate & UINavigationControllerDelegate)? = nil, completion: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            if navVC != nil { self.navVC = navVC }
            guard let navVC = self.navVC else { return }
            self.photoPicker.sourceType =  isCamera ? .camera : .photoLibrary
            self.photoPicker.delegate = vc
            navVC.present(self.photoPicker, animated: true, completion: nil)
        }
    }
    
    func presentAccessRequiredAlert(title: String?, message: String?) {
        guard let vc = self.navVC else { return }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Settings", style: .default, handler: { action in
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
        }))
        alert.popoverPresentationController?.sourceView = vc.view
        vc.present(alert, animated: true)
    }
    
    func presentDocumentMenu(navVC: UINavigationController? = nil,
                             imagePickerDelegate: (UIImagePickerControllerDelegate & UINavigationControllerDelegate)? = nil,
                             documentPickerDelegate: UIDocumentPickerDelegate? = nil) {
        if navVC != nil { self.navVC = navVC }
        guard let aVC = self.navVC else { return }
        let alert = UIAlertController()
        alert.popoverPresentationController?.sourceView = aVC.view
        let docAction = UIAlertAction(title: "Document", style: .default) { action in
            self.presentDocumentPicker(navVC: navVC, vc: documentPickerDelegate, completion: nil)
        }
        let cameraAction = UIAlertAction(title: "Camera", style: .default) { action in
            DocumentPickerState.isCameraMode = true
            if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
                self.requestCameraAuthorization { status in
                    if status {
                        Log.debug("camera access granted")
                        self.presentPhotoPicker(isCamera: true, vc: imagePickerDelegate)
                    } else {
                        Log.debug("camera access denied")
                    }
                }
            }
            if AVCaptureDevice.authorizationStatus(for: .video) == .authorized {
                self.presentPhotoPicker(isCamera: true, vc: imagePickerDelegate)
            }
        }
        let photoAction = UIAlertAction(title: "Photo", style: .default) { action in
            DocumentPickerState.isCameraMode = false
            let authStatus = PHPhotoLibrary.authorizationStatus()
            if authStatus == .notDetermined {
                self.requestPhotoLibraryAuthorization(completion: { status in
                    if status {
                        Log.debug("photo access granted")
                        self.presentPhotoPicker(isCamera: false, vc: imagePickerDelegate)
                        return
                    } else {
                        Log.debug("photo access denied")
                    }
                })
            }
            if authStatus == .denied {
                self.presentAccessRequiredAlert(title: self.photoAccessMessage, message: nil)
            } else if authStatus == .authorized {
                self.presentPhotoPicker(isCamera: false, vc: imagePickerDelegate)
            }
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { action in
            
        }
        alert.addAction(docAction)
        alert.addAction(cameraAction)
        alert.addAction(photoAction)
        alert.addAction(cancelAction)
        aVC.present(alert, animated: true, completion: nil)
    }
        
    // MARK: - Document Picker
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        Log.debug("urls: \(urls)")
        DocumentPickerState.docs = urls
        self.nc.post(Notification(name: NotificationKey.documentPickerFileIsAvailable))
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        Log.debug("document picker cancelled")
        DocumentPickerState.docs = []
    }
    
    // MARK: - Photo Picker
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        Log.debug("image picker did finish - info: \(info)")
        if let image = info[.originalImage] as? UIImage {
            DocumentPickerState.image = image
            Log.debug("image obtained")
            self.nc.post(Notification(name: NotificationKey.documentPickerImageIsAvailable))
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        Log.debug("image picker did cancel")
        DocumentPickerState.image = nil
    }
}
