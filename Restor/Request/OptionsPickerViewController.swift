//
//  OptionsPickerViewController.swift
//  Restor
//
//  Created by jsloop on 08/02/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit

protocol OptionsPickerViewDelegate: class {
    func optionDidSelect(_ row: Int)
    func reloadOptionsData()
}

class OptionsPickerViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var cancelBtn: UIButton!
    @IBOutlet weak var titleLabel: UILabel!
    weak var optionsDelegate: OptionsPickerViewDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Log.debug("options picker vc view did load")
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.reloadData()
        initUI()
    }
    
    func initUI() {
        self.titleLabel.text = OptionsPickerState.title
    }
    
    @IBAction func cancelButtonDidTap() {
        Log.debug("cancel button did tap")
        self.close()
    }
    
    func close() {
        self.optionsDelegate?.reloadOptionsData()
        self.dismiss(animated: true, completion: nil)
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return OptionsPickerState.data.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "optionsCell", for: indexPath) as! OptionsTableViewCell
        let row = indexPath.row
        if OptionsPickerState.data.count > row {
            cell.titleLabel.text = OptionsPickerState.data[row]
            if row == OptionsPickerState.selected {
                cell.selectCell()
            } else {
                cell.deselectCell()
            }
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = indexPath.row
        OptionsPickerState.selected = row
        self.optionsDelegate?.optionDidSelect(row)
        self.close()
    }
}

class OptionsTableViewCell: UITableViewCell {
    @IBOutlet weak var titleLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    func selectCell() {
        self.accessoryType = .checkmark
    }
    
    func deselectCell() {
        self.accessoryType = .none
    }
}
