//
//  Const.swift
//  Restor
//
//  Created by jsloop on 09/12/19.
//  Copyright © 2019 EstoApps. All rights reserved.
//

import Foundation

struct Const {
}

enum TableCellId: String {
    case workspaceCell
    case projectCell
    case requestCell
}

enum StoryboardId: String {
    case workspaceVC
    case projectVC
    case requestListVC
    case requestVC
}

/// The request option elements
enum RequestHeaderInfo: Int {
    case description = 0
    case headers
    case urlParams
    case body
    case auth
    case options
}
