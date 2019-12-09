//
//  Utils.swift
//  Restor
//
//  Created by jsloop on 03/12/19.
//  Copyright © 2019 EstoApps. All rights reserved.
//

import Foundation
import UIKit

class Utils {
    static let shared: Utils = Utils()
    
    func addSettingsBarButton() -> UIBarButtonItem {
        return UIBarButtonItem(image: UIImage(systemName: "gear"), style: .plain, target: self, action: #selector(self.settingsBtnDidTap(_:)))
    }
    
    @objc func settingsBtnDidTap(_ sender: Any) {
        Log.debug("settings btn did tap")
    }
}


struct Log {
    static func debug(_ msg: @autoclosure () -> Any) {
        #if DEBUG
        print("[DEBUG] \(msg())")
        #endif
    }
}
