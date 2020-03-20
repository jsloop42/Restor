//
//  UI.swift
//  Restor
//
//  Created by jsloop on 05/12/19.
//  Copyright © 2019 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit

class UI {
    private static var toastQueue: Set<String> = Set<String>()
    private static var isToastPresenting = false
    
    static func setGlobalStyle() {
        self.clearBackButtonText()
    }
    
    static func clearBackButtonText() {
        // Clear back button text
        let BarButtonItemAppearance = UIBarButtonItem.appearance()
        BarButtonItemAppearance.setTitleTextAttributes([.foregroundColor: UIColor.clear, .backgroundColor: UIColor.clear], for: .normal)
        BarButtonItemAppearance.setTitleTextAttributes([.foregroundColor: UIColor.clear, .backgroundColor: UIColor.clear], for: .highlighted)
        BarButtonItemAppearance.setTitleTextAttributes([.foregroundColor: UIColor.clear, .backgroundColor: UIColor.clear], for: .selected)
    }
    
    static func roundTopCornersWithBorder(view: UIView, borderColor: UIColor? = nil, name: String) {
        // Round corners with mask
        let path = UIBezierPath(roundedRect: view.bounds, byRoundingCorners:[.topLeft, .topRight], cornerRadii: CGSize(width: 12.0, height: 12.0))
        let layer = CAShapeLayer()
        layer.path = path.cgPath
        view.layer.mask = layer

        // Remove border if present
        if let layers = view.layer.sublayers {
            for layer in layers {
                if layer.name == name {
                    Log.debug("removed border layer")
                    layer.removeFromSuperlayer()
                    break
                }
            }
        }
        
        // Add border
        let borderLayer = CAShapeLayer()
        borderLayer.name = name
        borderLayer.path = layer.path
        borderLayer.fillColor = UIColor.clear.cgColor
        Log.debug("updating top border")
        borderLayer.frame = view.bounds
        view.layer.addSublayer(borderLayer)
    }
    
    /// Return a done button for right navigation bar item. The button is bold than the default cancel button.
    static func getNavbarTopDoneButton() -> UIButton {
        let btn = UIButton(type: .custom)
        btn.setTitle("Done", for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        btn.setTitleColor(btn.tintColor, for: .normal)
        return btn
    }
    
    static func pushScreen(_ navVC: UINavigationController, storyboardId: String) {
        if let storyboard = navVC.storyboard {
            let vc = storyboard.instantiateViewController(withIdentifier: storyboardId)
            navVC.pushViewController(vc, animated: true)
        }
    }
    
    static func isDarkMode() -> Bool {
        if #available(iOS 12.0, *) {
            return UIScreen.main.traitCollection.userInterfaceStyle == .dark
        }
        return false
    }
           
    /// Present the given view controller from the storyboard
    static func presentScreen(_ vc: UIViewController, storyboard: UIStoryboard, storyboardId: String) -> UIViewController {
        let screen = storyboard.instantiateViewController(withIdentifier: storyboardId)
        vc.present(screen, animated: true, completion: nil)
        return screen
    }
   
    /// Push the given view controller from the storyboard
    static func pushScreen(_ vc: UINavigationController, storyboard: UIStoryboard, storyboardId: String) {
        let navVC = storyboard.instantiateViewController(withIdentifier: storyboardId)
        navVC.hidesBottomBarWhenPushed = true
        vc.pushViewController(navVC, animated: true)
    }
   
    static func hideNavigationBar(_ navVC: UINavigationController) {
        navVC.setNavigationBarHidden(true, animated: true)
    }
   
    static func showNavigationBar(_ navVC: UINavigationController) {
        navVC.setNavigationBarHidden(false, animated: true)
    }
   
    /// Remove the text from navigation bar back button. The text depends on the master view. So this has to be called in the `viewWillDisappear`.
    /// - Parameter navItem: The navigationItem as in `self.navigationItem`.
    static func clearNavigationBackButtonText(_ navItem: UINavigationItem) {
        navItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
    }
   
    /// Handler method which queues toast events for display
    static func displayToast(_ msg: String) {
        if self.isToastPresenting {
            self.toastQueue.insert(msg)
        } else {
            if let vc = WorkspaceViewController.shared {
                self.viewToast(msg, vc: vc)
            }
        }
    }
    
    /// Display an action sheet.
    /// - Parameters:
    ///     - vc: Any view controller object.
    ///     - title: An optional title string.
    ///     - message: An optional message string.
    ///     - cancelText: Cancel button text.
    ///     - otherButtonText: Other button text.
    ///     - cancelStyle: The alert style for cancel.
    ///     - otherStyle: The alert style for the other option.
    ///     - cancelCallback: Callback function on cancel.
    ///     - otherCallback: Callback function when other button is tapped.
    static func viewActionSheet(vc: UIResponder, title: String? = nil, message: String? = nil,
                                cancelText: String, otherButtonText: String,
                                cancelStyle: UIAlertAction.Style, otherStyle: UIAlertAction.Style,
                                cancelCallback: (() -> Void)? = nil, otherCallback: (() -> Void)? = nil) {
        guard let aVC = vc as? UIViewController else { return }
        let alertVC = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        alertVC.addAction(UIAlertAction(title: cancelText, style: cancelStyle, handler: { _ in
            if let cb = cancelCallback { cb() }
        }))
        alertVC.addAction(UIAlertAction(title: otherButtonText, style: otherStyle, handler: {_ in
            if let cb = otherCallback { cb() }
        }))
        alertVC.modalPresentationStyle = .popover
        if let popoverPresentationController = alertVC.popoverPresentationController {
            popoverPresentationController.sourceView = aVC.view
            popoverPresentationController.sourceRect = aVC.view.bounds
            popoverPresentationController.permittedArrowDirections = []
        }
        DispatchQueue.main.async { aVC.present(alertVC, animated: true, completion: nil) }
    }
    
    /// Display an alert box.
    /// - Parameters:
    ///     - vc: A view controller conforming to `ViewControllerProtocol`.
    ///     - title: An optional title string.
    ///     - message: An optional message string.
    ///     - cancelText: Cancel button text.
    ///     - otherButtonText: Other button text.
    ///     - cancelCallback: Callback function on cancel.
    ///     - otherCallback: Callback function when other button is tapped.
    static func viewAlert(vc: UIResponder, title: String? = nil, message: String? = nil, cancelText: String, otherButtonText: String,
                          cancelStyle: UIAlertAction.Style, otherStyle: UIAlertAction.Style,
                          cancelCallback: (() -> Void)? = nil, otherCallback: (() -> Void)? = nil) {
        guard let aVC = vc as? UIViewController else { return }
        let alertVC = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: cancelText, style: cancelStyle, handler: { _ in
            if let cb = cancelCallback { cb() }
        }))
        alertVC.addAction(UIAlertAction(title: otherButtonText, style: otherStyle, handler: {_ in
            if let cb = otherCallback { cb() }
        }))
        alertVC.modalPresentationStyle = .popover
        if let popoverPresentationController = alertVC.popoverPresentationController {
            popoverPresentationController.sourceView = aVC.view
            popoverPresentationController.sourceRect = aVC.view.bounds
            popoverPresentationController.permittedArrowDirections = []
        }
        DispatchQueue.main.async { aVC.present(alertVC, animated: true, completion: nil) }
    }
   
    /// Display toast using the presented view controller
    static func viewToast(_ message: String, hideSec: Double? = 3, vc: UIViewController) {
        self.isToastPresenting = true
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .actionSheet)
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + (hideSec ?? 3), execute: {
            self.isToastPresenting = false
            alert.dismiss(animated: true, completion: {
                if !self.toastQueue.isEmpty, let msg = self.toastQueue.popFirst() {
                    self.viewToast(msg, hideSec: hideSec, vc: vc)
                }
            })
        })
        alert.modalPresentationStyle = .popover
        if let popoverPresentationController = alert.popoverPresentationController {
            popoverPresentationController.sourceView = vc.view
            popoverPresentationController.sourceRect = vc.view.bounds
            popoverPresentationController.permittedArrowDirections = []
        }
        DispatchQueue.main.async { vc.present(alert, animated: true, completion: nil) }
    }
   
    static func activityIndicator() -> UIActivityIndicatorView {
        let activityIndicator: UIActivityIndicatorView = UIActivityIndicatorView.init(style: UIActivityIndicatorView.Style.gray)
        activityIndicator.alpha = 1.0
        activityIndicator.center = CGPoint(x: UIScreen.main.bounds.size.width / 2, y: UIScreen.main.bounds.size.height / 3)
        activityIndicator.startAnimating()
        return activityIndicator
    }
   
    static func showLoading(_ indicator: UIActivityIndicatorView?) {
        DispatchQueue.main.async {
            guard let indicator = indicator else { return }
            indicator.startAnimating()
            indicator.backgroundColor = UIColor.white
        }
    }

    static func hideLoading(_ indicator: UIActivityIndicatorView?) {
        guard let indicator = indicator else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.0, execute: {
            indicator.stopAnimating()
            indicator.hidesWhenStopped = true
        })
    }

    static func addActivityIndicator(indicator: UIActivityIndicatorView?, view: UIView) {
        guard let indicator = indicator else { return }
        DispatchQueue.main.async {
            indicator.style = UIActivityIndicatorView.Style.gray
            indicator.center = view.center
            view.addSubview(indicator)
        }
    }
   
    static func removeActivityIndicator(indicator: UIActivityIndicatorView?) {
        guard let indicator = indicator else { return }
        DispatchQueue.main.async {
            indicator.removeFromSuperview()
        }
    }
    
    static func getTextHeight(_ text: String, width: CGFloat, font: UIFont) -> CGFloat {
        let frame = NSString(string: text)
                        .boundingRect(with: CGSize(width: width, height: .infinity),
                                      options: [.usesFontLeading, .usesLineFragmentOrigin],
                                      attributes: [.font : font],
                                      context: nil)
        return frame.size.height
    }
    
    /// Returns the height of the navigation bar.
    /// - Parameter navVC: The current navigation controller (optional).
    static func getNavBarHeight(navVC: UINavigationController? = nil) -> CGFloat {
        let vc = navVC != nil ? navVC! : UINavigationController()
        return vc.navigationBar.frame.size.height
    }
    
    static func endEditing() {
        UIApplication.shared.sendAction(#selector(UIApplication.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

extension UIView {
    @IBInspectable
    var cornerRadius: CGFloat {
        get {
            return layer.cornerRadius
        }
        set {
            layer.cornerRadius = newValue
        }
    }

    @IBInspectable
    var borderWidth: CGFloat {
        get {
            return layer.borderWidth
        }
        set {
            layer.borderWidth = newValue
        }
    }

    @IBInspectable
    var borderColor: UIColor? {
        get {
            if let color = layer.borderColor {
                return UIColor(cgColor: color)
            }
            return nil
        }
        set {
            if let color = newValue {
                layer.borderColor = color.cgColor
            } else {
                layer.borderColor = nil
            }
        }
    }

    @IBInspectable
    var shadowRadius: CGFloat {
        get {
            return layer.shadowRadius
        }
        set {
            layer.shadowRadius = newValue
        }
    }

    @IBInspectable
    var shadowOpacity: Float {
        get {
            return layer.shadowOpacity
        }
        set {
            layer.shadowOpacity = newValue
        }
    }

    @IBInspectable
    var shadowOffset: CGSize {
        get {
            return layer.shadowOffset
        }
        set {
            layer.shadowOffset = newValue
        }
    }

    @IBInspectable
    var shadowColor: UIColor? {
        get {
            if let color = layer.shadowColor {
                return UIColor(cgColor: color)
            }
            return nil
        }
        set {
            if let color = newValue {
                layer.shadowColor = color.cgColor
            } else {
                layer.shadowColor = nil
            }
        }
    }
    
    func addTopBorderWithColor(color: UIColor, width: CGFloat) {
        let border = CALayer()
        border.backgroundColor = color.cgColor
        border.frame = CGRect(x: 0, y: 0, width: self.frame.size.width, height: width)
        self.layer.addSublayer(border)
    }

    func addRightBorderWithColor(color: UIColor, width: CGFloat) {
        let border = CALayer()
        border.backgroundColor = color.cgColor
        border.frame = CGRect(x: self.frame.size.width - width, y: 0, width: width, height: self.frame.size.height)
        self.layer.addSublayer(border)
    }

    func addBottomBorderWithColor(color: UIColor, width: CGFloat, name: String) {
        let border = CALayer()
        border.name = name
        border.backgroundColor = color.cgColor
        border.frame = CGRect(x: 0, y: self.frame.size.height - width, width: self.frame.size.width, height: width)
        self.layer.addSublayer(border)
    }
    
    func addLeftBorderWithColor(color: UIColor, width: CGFloat) {
        let border = CALayer()
        border.backgroundColor = color.cgColor
        border.frame = CGRect(x: 0, y: 0, width: width, height: self.frame.size.height)
        self.layer.addSublayer(border)
    }
    
    func removeBottomBorder(name: String) {
        self.layer.sublayers?.forEach({ aLayer in
            if aLayer.name == name {
                aLayer.removeFromSuperlayer()
                return
            }
        })
    }

    func addBorderWithColor(color: UIColor, width: CGFloat) {
        self.layer.cornerRadius = 5
        self.layer.borderWidth = width
        self.layer.borderColor = color.cgColor
    }

    func removeBorder() {
        self.layer.borderColor = UIColor.clear.cgColor
    }
}

extension UILabel {
    func textWidth() -> CGFloat {
        return UILabel.textWidth(label: self)
    }
    
    class func textWidth(label: UILabel) -> CGFloat {
        return textWidth(label: label, text: label.text!)
    }
    
    class func textWidth(label: UILabel, text: String) -> CGFloat {
        return textWidth(font: label.font, text: text)
    }
    
    class func textWidth(font: UIFont, text: String) -> CGFloat {
        let myText = text as NSString
        let rect = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        let labelSize = myText.boundingRect(with: rect, options: .usesLineFragmentOrigin, attributes: [NSAttributedString.Key.font: font], context: nil)
        return ceil(labelSize.width)
    }
}

extension UITableView {
    func reloadData(completion: @escaping () -> ()) {
        UIView.animate(withDuration: 0, animations: { self.reloadData() }, completion: { _ in
            completion()
        })
    }
}
