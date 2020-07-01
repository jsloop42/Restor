//
//  RequestTabBarViewController.swift
//  Restor
//
//  Created by jsloop on 04/05/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit

extension Notification.Name {
    static let requestVCShouldPresent = Notification.Name("request-vc-should-present")
    static let responseSegmentDidChange = Notification.Name("response-segment-did-change")
    static let editRequestDidTap = Notification.Name("edit-request-did-tap")
    static let viewRequestHistoryDidTap = Notification.Name("view-request-history-did-tap")
}

class RequestTabBarController: UITabBarController, UITabBarControllerDelegate {
    var request: ERequest?
    var responseData: ResponseData?
    var segView: UISegmentedControl!
    private let ck = EACloudKit.shared
    private let nc = NotificationCenter.default
    private var selectedTab: Tab = .request
    private var barBtn: UIButton!
    var isHideHistory = false
    
    enum Tab: Int {
        case request
        case response
    }
    
    deinit {
        self.nc.removeObserver(self)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        _ = self.segmentControl()
    }
       
    override func viewDidLoad() {
        Log.debug("request tab bar controller")
        self.initEvents()
        self.addNavigationBarEditButton()
        self.delegate = self
        self.selectedIndex = 0
        self.viewNavbarSegment()
    }
    
    func initEvents() {
        self.nc.addObserver(self, selector: #selector(self.responseDidReceive(_:)), name: .responseDidReceive, object: nil)
    }
    
    @objc func responseDidReceive(_ notif: Notification) {
        DispatchQueue.main.async {
            guard let info = notif.userInfo as? [String: Any], let data = info["data"] as? ResponseData else { return }
            self.responseData = data
            self.selectedIndex = 1
            self.selectedTab = .response
            if let vc = self.viewControllers?.last as? ResponseTableViewController { vc.data = data }
            self.viewNavbarSegment()
            self.updateBarButtonText()
        }
    }
    
    /// Display Edit button in navigation bar
    func addNavigationBarEditButton() {
        self.barBtn = UIButton(type: .custom)
        self.barBtn.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        self.barBtn.setTitleColor(self.barBtn.tintColor, for: .normal)
        self.barBtn.addTarget(self, action: #selector(self.rightBarButtonDidTap(_:)), for: .touchUpInside)
        self.updateBarButtonText()
    }
    
    func updateBarButtonText() {
        if self.isHideHistory {
            self.navigationItem.rightBarButtonItem = nil
            return
        }
        self.barBtn.setTitle(self.selectedTab == .request ? "Edit" : "History", for: .normal)
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: self.barBtn)
    }
    
    func hideHistoryButton() {
        self.isHideHistory = true
    }
    
    func displayHistoryButton() {
        self.isHideHistory = false
    }
    
    @objc func rightBarButtonDidTap(_ sender: Any) {
        Log.debug("req-resp right button did tap")
        guard let req = self.request else { return }
        if self.selectedTab == .request {
            self.nc.post(name: .editRequestDidTap, object: self, userInfo: ["request": req])
        } else if self.selectedTab == .response {
            if let vc = self.storyboard?.instantiateViewController(withIdentifier: StoryboardId.historyVC.rawValue) as? HistoryViewController {
                vc.request = req
                self.navigationController?.pushViewController(vc, animated: true)
            }
        }
    }
    
    func segmentControl() -> UISegmentedControl {
        if self.segView != nil { return self.segView }
        self.segView = UISegmentedControl(items: ResponseMode.allCases)
        self.segView.selectedSegmentIndex = self.ck.getValue(key: Const.responseSegmentIndexKey) as? Int ?? ResponseMode.info.rawValue
        self.segView.sizeToFit()
        self.segView.addTarget(self, action: #selector(self.segmentDidChange(_:)), for: .valueChanged)
        return self.segView!
    }
    
    func viewNavbarSegment() {
        self.segView.selectedSegmentIndex = self.ck.getValue(key: Const.responseSegmentIndexKey) as? Int ?? ResponseMode.info.rawValue
        if self.selectedTab == .response {
            self.navigationItem.titleView = self.segView
        }
    }
    
    func hideNavbarSegment() {
        self.navigationItem.titleView = nil
    }
    
    @objc func segmentDidChange(_ sender: Any) {
        Log.debug("segment did change")
        self.nc.post(name: .responseSegmentDidChange, object: self, userInfo: ["index": self.segView!.selectedSegmentIndex])
    }
    
    /// Display the view change with an animation effect.
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        if (self.selectedTab == .request && self.viewControllers?.first == viewController) ||
            (self.selectedTab == .response && self.viewControllers?.last == viewController) { return false }
        guard let fromView = self.selectedViewController?.view, let toView = viewController.view else { return false }
        UIView.transition(from: fromView, to: toView, duration: 0.3, options: [.transitionCrossDissolve], completion: nil)
        return true
    }
    
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        self.selectedTab = Tab(rawValue: tabBarController.selectedIndex) ?? .request
        self.viewNavbarSegment()
        self.updateBarButtonText()
    }
}
