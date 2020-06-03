//
//  ResponseTableViewController.swift
//  Restor
//
//  Created by jsloop on 04/05/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit
import WebKit
import Highlightr
import SwiftRichString
import Sourceful

//open class MyXMLDynamicAttributesResolver: XMLDynamicAttributesResolver {
//    public func applyDynamicAttributes(to attributedString: inout AttributedString, xmlStyle: XMLDynamicStyle, fromStyle: StyleXML) {
//        let finalStyleToApply = Style()
//        xmlStyle.enumerateAttributes { key, value  in
//            switch key {
//                case "color": // color support
//                    finalStyleToApply.color = Color(hexString: value)
//                default:
//                    break
//            }
//        }
//
//        attributedString.add(style: finalStyleToApply)
//    }
//
//    public func styleForUnknownXMLTag(_ tag: String, to attributedString: inout AttributedString, attributes: [String : String]?, fromStyle: StyleXML) {
//        if tag == "rainbow" {
//            let colors = UIColor.randomColors(attributedString.length)
//            for i in 0..<attributedString.length {
//                attributedString.add(style: Style({
//                    $0.color = colors[i]
//                }), range: NSMakeRange(i, 1))
//            }
//        }
//    }
//}


public class MyXMLDynamicAttributesResolver: StandardXMLAttributesResolver {
    
    public override func styleForUnknownXMLTag(_ tag: String, to attributedString: inout AttributedString, attributes: [String : String]?, fromStyle forStyle: StyleXML) {
        super.styleForUnknownXMLTag(tag, to: &attributedString, attributes: attributes, fromStyle: forStyle)
        
        if tag == "rainbow" {
            let colors = UIColor.randomColors(attributedString.length)
            for i in 0..<attributedString.length {
                attributedString.add(style: Style({
                    $0.color = colors[i]
                }), range: NSMakeRange(i, 1))
            }
        }
        
    }
    
}

extension UIColor {
    public static func randomColors(_ count: Int) -> [UIColor] {
        return (0..<count).map { _ -> UIColor in
            randomColor()
        }
    }
    
    public static func randomColor() -> UIColor {
        let redValue = CGFloat.random(in: 0...1)
        let greenValue = CGFloat.random(in: 0...1)
        let blueValue = CGFloat.random(in: 0...1)
        
        let randomColor = UIColor(red: redValue, green: greenValue, blue: blueValue, alpha: 1.0)
        return randomColor
    }
}

final class ResponseRawViewCell: UITableViewCell {
    @IBOutlet weak var rawTextView: UITextView!
    @IBOutlet weak var textView: SyntaxTextView!
    var data: ResponseData?
    let sh = Highlightr()
    var rendered: NSAttributedString?
    private let nc = NotificationCenter.default
    var isDirty = true
    
    let baseFontSize: CGFloat = 14
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.rawTextView.font = App.Font.monospace14
    }
    
    func updateUI() {
        guard let data = self.data, let respData = data.responseData, var text = String(data: respData, encoding: .utf8)?.trim() else { return }
        //self.textView.text = "Hello world"
    }

    func updateUI1() {
//        if self.rendered != nil {
//            self.rawTextView.attributedText = self.rendered!
//        } else {
            guard let data = self.data, let respData = data.responseData, var text = String(data: respData, encoding: .utf8)?.trim() else { return }
            //self.rawTextView.text = text
            //if !isDirty { return }
            

            // Apply a custom xml attribute resolver
            //styleGroup.xmlAttributesResolver = MyXMLDynamicAttributesResolver()
            let style = Style {
                $0.font = SystemFonts.AmericanTypewriter.font(size: 15) // just pass a string, one of the SystemFonts or an UIFont
                $0.color = "#0433FF" // you can use UIColor or HEX string!
                $0.underline = (.patternDot, UIColor.red)
                $0.alignment = .center
            }
            // Render
        
        let normal = Style {
            $0.font = SystemFonts.HelveticaNeue.font(size: 15)
            $0.color = UIColor.gray
        }
                
        let bold = Style {
            $0.font = SystemFonts.Helvetica_Bold.font(size: 20)
            $0.color = UIColor.red
            $0.backColor = UIColor.yellow
        }
                
        let italic = normal.byAdding {
            $0.traitVariants = .italic
        }
        let div  = normal.byAdding {
            $0.color = UIColor.green
        }
    
        let kwd = Style {
            $0.font = SystemFonts.AmericanTypewriter.font(size: 14)
            $0.color = "#0433FF"
        }
        
        let html = StyleRegEx(base: normal, pattern: "html", options: .caseInsensitive) {
            $0.color = UIColor.red
        }
        //let myGroup = StyleXML(base: normal, ["html": kwd, "script": kwd, "bold": bold, "italic": italic])
        //text = "&lt;html&gt;Hello &lt;bold&gt;Daniele!&lt;/bold&gt;. You're ready to &lt;italic&gt;play with us!&lt;/italic&gt;&lt;head&gt;&lt;script&gt;foobar&lt;/script&gt;&lt;/head&gt;&lt;/html&gt;"
        //self.rawTextView.attributedText = text.toHtml().set(style: html)
        self.textView.text = text
            
            self.isDirty = false
//            DispatchQueue.global().async {
//                self.rendered = self.sh?.highlight(text)
//                self.isDirty = false
//                self.nc.post(name: .responseTableViewShouldReload, object: self, userInfo: ["id": "raw-cell"])
//            }
//        }
    }
}


extension String {
    func toHtml() -> AttributedString {
        guard let data = data(using: .utf8) else { return AttributedString() }
        
        if let attributedString = try? AttributedString(data: data, options: [.documentType: AttributedString.DocumentType.html,
        .characterEncoding: String.Encoding.utf8.rawValue], documentAttributes: nil) {
            return attributedString
        } else {
            return AttributedString()
        }
    }
}

// MARK: - ResponseWebViewCell

final class ResponseWebViewCell: UITableViewCell, WKNavigationDelegate, WKUIDelegate {
    @IBOutlet weak var webView: WKWebView!
    var data: ResponseData? {
        didSet {
            if self.responseCache == nil {
                let reqId = self.data!.requestId
                if let cache = AppState.getResponseCache(reqId) {
                    self.responseCache = cache
                } else {
                    self.responseCache = ResponseCache()
                    AppState.setResponseCache(self.responseCache, for: reqId)
                }
            }
        }
    }
    var doneLoading = false
    let nc = NotificationCenter.default
    var height: CGFloat = 44
    var template = ""
    var responseCache: ResponseCache!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.webView.navigationDelegate = self
        self.webView.uiDelegate = self
        self.loadTemplate()
        self.initUI()
    }
    
    func loadTemplate() {
        guard self.template.isEmpty else { return }
        if let templateURL = Bundle.main.url(forResource: "raw-view", withExtension: "html") {
            let fm = EAFileManager.init(url: templateURL)
            fm.openFile(for: .read)
            fm.readToEOF { result in
                switch result {
                case .success(let data):
                    if let template = String(data: data, encoding: .utf8), !template.isEmpty {
                        self.template = template
                    }
                case .failure(let err):
                    Log.error("Error loading template: \(err)")
                }
            }
        }
    }
    
    func initUI() {
        self.webView.scrollView.isScrollEnabled = true
        self.webView.backgroundColor = UIColor(named: "table-view-cell-bg")
    }
    
    func getHtmlSource(_ data: Data) -> String {
        //if let url = self.responseCache.getURL(data) { return url }
        guard var html = String(data: data, encoding: .utf8)?.trim() else { return "" }
        html = html.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;").replacingOccurrences(of: "'", with: "&#039;")//.replacingOccurrences(of: "\n", with: "<br>")
        return self.template.replacingOccurrences(of: "#_restor-extrapolate-texts", with: html)
        //let hash = self.responseCache.addData(renderedHtml)
        //return self.responseCache.getURL(hash)
    }
    
    func getHtmlSource(_ html: String) -> String {
        let html = html.trim().replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;").replacingOccurrences(of: "'", with: "&#039;").replacingOccurrences(of: "\n", with: "<br>")
        return """
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <link href="themes/prism.css" rel="stylesheet" />
            <style>
            :root {
                color-scheme: light dark;
            }
            @font-face { font-family: "Source Code Pro"; src: url("SourceCodePro-Regular.ttf"); }
            html, body {
                font-family: "Source Code Pro";
                font-size: 16;
            }
            @media (prefers-color-scheme: dark) {
                body {
                    background-color: rgb(26, 28, 30) !important;
                    color: white !important;
                }
            }
            </style>
        </head>
        <body>
        \(html)
        </body>
        </html>
        """
    }

    func updateUI() {
        guard !self.template.isEmpty, let data = self.data, let respData = data.responseData else { return }
        self.doneLoading = false
        var str = ""
        if let json = try? JSONSerialization.jsonObject(with: respData, options: .allowFragments) {
            str = String(describing: json)
            self.webView.loadHTMLString(self.getHtmlSource(str), baseURL: nil)
            return
        }
//        if let text = String(data: respData, encoding: .utf8) {
//            self.webView.loadHTMLString(self.getHtmlSource(text), baseURL: Bundle.main.bundleURL)
//        }
        self.webView.loadHTMLString(self.getHtmlSource(respData), baseURL: Bundle.main.bundleURL)
        
//        if let url = self.getHtmlSource(respData) {
//            //self.webView.loadFileURL(url, allowingReadAccessTo: url)
//            var req = URLRequest(url: url)
//            do {
//                self.webView.load(req)
//                //self.webView.load(try Data(contentsOf: url), mimeType: "text/html", characterEncodingName: "UTF8", baseURL: url)
//            } catch let error {
//                Log.error("Error: \(error)")
//            }
//        }
    }
    
    func updateHeight() {
        self.webView.evaluateJavaScript("document.readyState", completionHandler: { complete, error in
            if complete != nil {
                self.webView.evaluateJavaScript("document.body.scrollHeight", completionHandler: { height, error in
                    if let h = height as? CGFloat {
                        self.height = h
                        Log.debug("web view content height: \(h)")
                        DispatchQueue.main.async {
                            self.nc.post(name: .responseTableViewShouldReload, object: self)
                        }
                    }
                })
            }
        })
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Log.debug("web view did finish load")
    }
}

// MARK: - ResponseInfoCell

final class ResponseInfoCell: UITableViewCell {
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var urlLabel: UILabel!
    @IBOutlet weak var statusCodeView: UIView!
    @IBOutlet weak var statusCodeLabel: UILabel!
    @IBOutlet weak var statusMessageLabel: UILabel!
    @IBOutlet weak var statusSizeLabel: UILabel!
    @IBOutlet weak var infoView: UIView!
    var mode: ResponseMode = .preview
    var data: ResponseData?
    private lazy var app = { App.shared }()
    private lazy var utils = { EAUtils.shared }()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.updateUI()
    }
    
    func updateUI() {
        guard let data = self.data, let req = data.request else { return }
        self.nameLabel.text = req.name
        self.urlLabel.text = "\(data.method) \(data.url)"
        
        //self.nameLabel.text = "Get the list of all users filtered by active sorted by first name grouped by location joined by demographics segemented by geolocation"
        //self.urlLabel.text = "https://piperway.com/rest/list/user/sort/filter/group?param=search&name=first"
        //self.nameLabel.text = "Get list of all users"
        //self.urlLabel.text = "https://piperway.com/test/list/user"
        
        var color: UIColor!
        if data.statusCode > 0 {
            self.statusCodeLabel.text = "\(data.statusCode)"
            self.statusMessageLabel.text = HTTPStatusCode(rawValue: data.statusCode)?.toString() ?? ""
            if data.statusCode == 200 {
                self.statusMessageLabel.textAlignment = .center
            } else {
                self.statusMessageLabel.textAlignment = .right
            }
            var is200 = false
            if (200..<299) ~= data.statusCode {
                color = UIColor(named: "http-status-200")
                is200 = true
            } else if (300..<399) ~= data.statusCode {
                color = UIColor(named: "http-status-300")
            } else if (400..<500) ~= data.statusCode {
                color = UIColor(named: "http-status-400")
            } else if (500..<600) ~= data.statusCode {
                color = UIColor(named: "http-status-500")
            }
            self.statusCodeView.backgroundColor = color
            self.statusMessageLabel.textColor = is200 ? UIColor(named: "http-status-text-200") : color
        } else if data.statusCode <= -1 {  // error
            self.statusCodeView.backgroundColor = UIColor(named: "http-status-error")
            self.statusMessageLabel.textColor = UIColor(named: "http-status-error")
            self.statusCodeLabel.text = "Error"
            if data.statusCode <= -2 {
                self.statusMessageLabel.text = ResponseData.ErrorCode(rawValue: data.statusCode)?.toString() ?? ""
            } else {
                self.statusMessageLabel.text = ""
            }
        } else {
            self.statusCodeView.backgroundColor = UIColor(named: "http-status-none")
            self.statusMessageLabel.textColor = UIColor(named: "help-text-fg")
        }
        let ts = data.connectionInfo.elapsed > 0 ? self.utils.millisToReadable(data.connectionInfo.elapsed.toDouble()) : ""
        if data.connectionInfo.responseBodyBytesReceived > 0 {
            self.statusSizeLabel.text = "\(!ts.isEmpty ? "\(ts), " : "")\(self.utils.bytesToReadable(data.connectionInfo.responseBodyBytesReceived))"
        } else {
            self.statusSizeLabel.text = "\(ts)"
        }
    }
    
    func displayNoResponse() {
        UIView.animate(withDuration: 0.3) {
//            self.topBorderView.isHidden = true
//            self.infoView.isHidden = true
//            self.bottomBorderView.isHidden = true
        }
    }
}

enum ResponseKVTableType: String {
    case header = "response-header-table-view"
    case cookies = "response-cookies-table-view"
    case metrics = "response-metrics-table-view"
    case details = "response-details-table-view"
}

// MARK: - ResponseKVCell

final class ResponseKVCell: UITableViewCell, UITableViewDataSource, UITableViewDelegate {
    @IBOutlet weak var tableView: EADynamicSizeTableView!
    @IBOutlet weak var tvView: UIView!
    //var tableView: EADynamicSizeTableView!
    var isInit = false
    var data: ResponseData? {
        didSet { self.updateData() }
    }
    let cellId = "twoColumnCell"
    var tableType: ResponseKVTableType = .header
    var headers: [String: String] = [:]
    var headerKeys: [String] = []
    var heightMap: [Int: CGFloat] = [:] // [Row: Height]
    var metrics: [String: String]  = [:]
    var metricsKeys: [String] = []
    var details: [String: String] = [:]
    var detailsKeys: [String] = []
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.bootstrap()
    }
    
    func bootstrap() {
        if !self.isInit {
            UIView.animate(withDuration: 0.3) { self.initUI() }
            self.isInit = true
        }
    }
    
    func initUI() {
        self.tableView.tableViewId = self.tableType.rawValue
        self.tableView.drawBorders = false
        self.tableView.separatorStyle = .none
        self.tableView.separatorColor = .clear
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.estimatedRowHeight = 44
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.tableFooterView = UIView()
    }
    
    func updateUI() {
        self.tableView.resetMeta()  // so that for a new request, the height for the previous index gets removed.
        self.updateData()
        self.tableView.reloadData()
    }
    
    func updateData() {
        guard let data = self.data else { return }
        self.headers = data.getResponseHeaders()
        self.headerKeys = data.getResponseHeaderKeys()
        self.metrics = data.getMetricsMap()
        self.metricsKeys = data.getMetricsKeys()
        self.details = data.getDetailsMap()
        self.detailsKeys = data.getDetailsKeys()
        self.tableView.reloadData()
    }

    // MARK: - Table view
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch self.tableType {
        case .header:
            return self.headerKeys.count
        case .cookies:
            return self.data?.cookies.count ?? 0
        case .metrics:
            return self.metrics.count
        case .details:
            return self.details.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "kvCell", for: indexPath) as! KVCell
        let row = indexPath.row
        if self.tableType == .header {
            let key = self.headerKeys[row]
            cell.keyLabel.text = key
            //cell.keyLabel.text = "A machine is only as good as the man who programs it. A machine is only as good as the man who programs it"
            cell.valueLabel.text = self.headers[key]
            if row == self.headers.count - 1 {
                cell.hideBorder()
            } else {
                cell.showBorder()
            }
        } else if self.tableType == .cookies {
            if let data = self.data {
                let cookie = data.cookies[row]
                cell.keyLabel.text = cookie.name
                cell.valueLabel.text = cookie.value
                if row == data.cookies.count - 1 {
                    cell.hideBorder()
                } else {
                    cell.showBorder()
                }
            } else {
                cell.hideBorder()
            }
        } else if self.tableType == .metrics {
            let key = self.metricsKeys[row]
            if let val = self.metrics[key] {
                cell.keyLabel.text = key
                cell.valueLabel.text = val
                if row == self.metrics.count - 1 {
                    cell.hideBorder()
                } else {
                    cell.showBorder()
                }
            } else {
                cell.hideBorder()
            }
        } else if self.tableType == .details {
            let key = self.detailsKeys[row]
            if let val = self.details[key] {
                cell.keyLabel.text = key
                cell.valueLabel.text = val
            }
            if row == self.detailsKeys.count - 1 {
                cell.hideBorder()
            } else {
                cell.showBorder()
            }
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let row = indexPath.row
        var key = ""
        var val = ""
        if self.tableType == .header {
            key = self.headerKeys[row]
            val = self.headers[key] ?? ""
        } else if self.tableType == .cookies {
            if let cookie = self.data?.cookies[row] {
                key = cookie.name
                val = cookie.value
            }
        } else if self.tableType == .metrics {
            let _key = self.metricsKeys[row]
            if let _val = self.metrics[_key] {
                key = _key
                val = _val
            }
        } else if self.tableType == .details {
            let _key = self.detailsKeys[row]
            if let _val = self.details[_key] {
                key = _key
                val = _val
            }
        }
        //key = "A machine is only as good as the man who programs it. A machine is only as good as the man who programs it"
        let text = val.count >= key.count ? val : key
        Log.debug("text: \(text)")
        let width = tableView.frame.width / 2 - 32
        let h = max(UI.getTextHeight(text, width: width, font: UIFont.systemFont(ofSize: 14)) + 28, 55)  // For texts greater than the default 55, 28 padding is required for the cell
        Log.debug("header cell height h: \(h)")
        self.tableView.setHeight(h, forRowAt: indexPath)
        return h
    }
}

enum ResponseMode: Int {
    case info
    case raw
    case preview
    
    static var allCases = ["Info", "Raw", "Preview"]
}

// MARK: - ResponseTableViewController

extension Notification.Name {
    static let responseTableViewShouldReload = Notification.Name("response-table-view-should-reload")
}

class ResponseTableViewController: RestorTableViewController {
    private let nc = NotificationCenter.default
    private lazy var ck = { EACloudKit.shared }()
    private lazy var localdb = { CoreDataService.shared }()
    private lazy var utils = { EAUtils.shared }()
    private lazy var tabbarController = { self.tabBarController as! RequestTabBarController }()
    var mode: ResponseMode = .info
    @IBOutlet weak var infoCell: ResponseInfoCell!
    @IBOutlet weak var headersViewCell: ResponseKVCell! {
        didSet { self.headersViewCell.tableType = .header }
    }
    @IBOutlet weak var cookiesViewCell: ResponseKVCell! {
        didSet { self.cookiesViewCell.tableType = .cookies }
    }
    @IBOutlet weak var metricsViewCell: ResponseKVCell! {
        didSet { self.metricsViewCell.tableType = .metrics }
    }
    @IBOutlet weak var detailsViewCell: ResponseKVCell! {
        didSet { self.detailsViewCell.tableType = .details }
    }
    @IBOutlet weak var helpCell: ResponseInfoCell!
    @IBOutlet weak var rawCell: ResponseRawViewCell!
    @IBOutlet weak var previewCell: ResponseWebViewCell!
    private var headerCellHeight: CGFloat = 0.0
    private var cookieCellHeight: CGFloat = 0.0
    private var metricsCellHeight: CGFloat = 0.0
    private var detailsCellHeight: CGFloat = 0.0
    private var previousHeaderCellHeight: CGFloat = 0.0
    private var previousCookieCellHeight: CGFloat = 0.0
    private var previousMetricsCellHeight: CGFloat = 0.0
    private var previousDetailsCellHeight: CGFloat = 0.0
    var data: ResponseData?
    
    enum InfoCellId: Int {
        case spacerBeforeInfoCell
        case infoCell
        case headerTitleCell
        case headersViewCell
        case cookiesTitleCell
        case cookiesViewCell
        case metricsTitleCell
        case metricsViewCell
        case detailsTitleCell
        case detailsViewCell
        case spacerAfterDetailsCell
        case helpCell
    }
    
    enum RawCellId: Int {
        case spacerBeforeRawCell
        case rawCell
    }
    
    enum PreviewCellId: Int {
        case spacerBeforePreviewCell
        case previewCell
    }
    
    deinit {
        self.nc.removeObserver(self)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.initData()
        self.updateUI()
        self.tableView.reloadData()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Log.debug("response vc did load")
        self.initUI()
        self.initEvents()
    }
    
    func initData() {
        Log.debug("response vc - initData")
        guard let req = self.tabbarController.request else { return }
        self.data = self.tabbarController.responseData
        if self.data == nil {
            if let history = self.localdb.getLatestHistory(reqId: req.getId(), includeMarkForDelete: nil, ctx: self.localdb.mainMOC) {
                self.data = ResponseData(history: history)
                self.data?.history = history
                self.data?.request = req
            }
        }
        self.data?.updateResponseHeadersMap()
        if self.data != nil, self.data!.cookiesData != nil, self.data!.cookies.isEmpty {
            self.data!.updateCookies()
        }
        self.data?.updateMetricsMap()
        self.data?.updateDetailsMap()
        Log.debug("response data: \(String(describing: self.data))")
        // info cell
        self.infoCell.data = self.data
        // headers cell
        self.headersViewCell.tableType = .header
        self.headersViewCell.data = self.data
        // cookies cell
        self.cookiesViewCell.tableType = .cookies
        self.cookiesViewCell.data = self.data
        // metrics cell
        self.metricsViewCell.tableType = .metrics
        self.metricsViewCell.data = self.data
        self.metricsViewCell.metrics = self.data?.getMetricsMap() ?? [:]
        self.metricsViewCell.metricsKeys = self.data?.getMetricsKeys() ?? []
        // details cell
        self.detailsViewCell.tableType = .details
        self.detailsViewCell.data = self.data
        self.detailsViewCell.details = self.data?.getDetailsMap() ?? [:]
        self.detailsViewCell.detailsKeys = self.data?.getDetailsKeys() ?? []
        // Raw section - cell
        self.rawCell.data = self.data
        self.rawCell.updateUI()
        // preview section - cell
        self.previewCell.data = self.data
        self.previewCell.updateUI()
    }
    
    func initUI() {
        self.mode = ResponseMode(rawValue: self.tabbarController.segView.selectedSegmentIndex) ?? .info
        self.tabbarController.viewNavbarSegment()
    }
    
    func initEvents() {
        self.nc.addObserver(self, selector: #selector(self.segmentDidChange(_:)), name: .responseSegmentDidChange, object: nil)
        self.nc.addObserver(self, selector: #selector(self.viewRequestHistoryDidTap(_:)), name: .viewRequestHistoryDidTap, object: nil)
        self.nc.addObserver(self, selector: #selector(self.dynamicSizeTableViewHeightDidChange(_:)), name: .dynamicSizeTableViewHeightDidChange, object: nil)
        self.nc.addObserver(self, selector: #selector(self.responseTableViewShouldReload(_:)), name: .responseTableViewShouldReload, object: nil)
    }
    
    func updateUI() {
        Log.debug("update UI")
        if self.data == nil { return }
        if self.mode == .info {
            self.infoCell.updateUI()
            self.headersViewCell.updateUI()
            self.cookiesViewCell.updateUI()
            self.metricsViewCell.updateUI()
            self.detailsViewCell.updateUI()
        } else if self.mode == .raw {
            self.rawCell.data = self.data
            if self.rawCell.data != self.data { self.rawCell.isDirty = true }
            self.rawCell.updateUI()
        } else if self.mode == .preview {
            self.previewCell.data = self.data
            self.previewCell.updateUI()
        }
    }
    
    /// Get the dynamic height of the inner table view
    func setHeight(_ height: CGFloat, type: ResponseKVTableType) {
        if type == .header {
            self.headerCellHeight = height
            // Once the height changes, reload the outer table view. Also prevents continuous reloading of the table view.
            if self.headerCellHeight != self.previousHeaderCellHeight {
                self.previousHeaderCellHeight = self.headerCellHeight
            }
        } else if type == .cookies {
            self.cookieCellHeight = height
            if self.cookieCellHeight != self.previousCookieCellHeight {
                self.previousCookieCellHeight = self.cookieCellHeight
            }
        } else if type == .metrics {
            self.metricsCellHeight = height
            if self.metricsCellHeight != self.previousMetricsCellHeight {
                self.previousMetricsCellHeight = self.metricsCellHeight
            }
        } else if type == .details {
            self.detailsCellHeight = height
            if self.detailsCellHeight != self.previousDetailsCellHeight {
                self.previousDetailsCellHeight = self.detailsCellHeight
            }
        }
        self.tableView.reloadData()
    }
    
    @objc func dynamicSizeTableViewHeightDidChange(_ notif: Notification) {
        Log.debug("dynamic size table view height did change notification")
        if let info = notif.userInfo as? [String: Any], let tableViewId = info["tableViewId"] as? String, let type = ResponseKVTableType(rawValue: tableViewId),
            let height = info["height"] as? CGFloat {
            switch type {
            case .header:
                self.headerCellHeight = height
                self.headersViewCell.tableView.shouldReload = false
                self.tableView.reloadData()
                self.headersViewCell.tableView.shouldReload = true
                self.headersViewCell.tableView.reloadData()
            case .cookies:
                self.cookieCellHeight = height
                self.cookiesViewCell.tableView.shouldReload = false
                self.tableView.reloadData()
                self.cookiesViewCell.tableView.shouldReload = true
                self.cookiesViewCell.tableView.reloadData()
            case .metrics:
                self.metricsCellHeight = height
                self.metricsViewCell.tableView.shouldReload = false
                self.tableView.reloadData()
                self.metricsViewCell.tableView.shouldReload = true
                self.metricsViewCell.tableView.reloadData()
            case .details:
                self.detailsCellHeight = height
                self.detailsViewCell.tableView.shouldReload = false
                self.tableView.reloadData()
                self.detailsViewCell.tableView.shouldReload = true
                self.detailsViewCell.tableView.reloadData()
            }
        }
    }
    
    @objc func segmentDidChange(_ notif: Notification) {
        Log.debug("segment did change notif")
        if let info = notif.userInfo, let idx = info["index"] as? Int {
            self.ck.saveValue(key: Const.responseSegmentIndexKey, value: idx)
            self.mode = ResponseMode(rawValue: idx) ?? .info
            Log.debug("response mode changed: \(self.mode)")
            self.initData()
            self.updateUI()
            self.tableView.reloadData()
        }
    }
    
    @objc func viewRequestHistoryDidTap(_ notif: Notification) {
        Log.debug("view request history did tap")
        guard let info = notif.userInfo, let req = info["request"] as? ERequest, let data = self.data, req.getId() == data.request?.getId() else { return }
        // TODO: display history page
    }
    
    @objc func responseTableViewShouldReload(_ notif: Notification) {
        Log.debug("response table view should reload receieve")
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
}

// MARK: - ResponseTableViewController TableView Delegate

extension ResponseTableViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.mode == .info && section == 0 { return 12 }
        if self.mode == .raw && section == 1 { return 2 }
        if self.mode == .preview && section == 2 { return 2 }
        return 0
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return CGFloat.leastNormalMagnitude
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return nil
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 0:  // info section
            if self.mode == .info {
                if self.data == nil {  // For requests which has not been sent once
                    if indexPath.row == InfoCellId.helpCell.rawValue { return 44 }
                    return 0
                } else {
                    guard let data = self.data else { return 0 }
                    let cellId = InfoCellId(rawValue: indexPath.row)
                    switch cellId {
                    case .spacerBeforeInfoCell:
                        return 24
                    case .infoCell:
                        return 81
                    case .headerTitleCell:
                        if data.getResponseHeaders().isEmpty { return 0 }
                        return 44
                    case .headersViewCell:
                        if data.getResponseHeaders().isEmpty { return 0 }
                        self.headersViewCell.tableView.invalidateIntrinsicContentSize()
                        self.headersViewCell.invalidateIntrinsicContentSize()
                        self.headersViewCell.tableView.reloadData()
                        return self.headerCellHeight == 0 ? UITableView.automaticDimension : self.headerCellHeight
                    case .cookiesTitleCell:
                        Log.debug("cookies: \(String(describing: self.data?.cookies))")
                        if data.cookies.isEmpty { return 0 }
                        return 44
                    case .cookiesViewCell:
                        if data.cookies.isEmpty { return 0 }
                        self.cookiesViewCell.tableView.invalidateIntrinsicContentSize()
                        self.cookiesViewCell.invalidateIntrinsicContentSize()
                        self.cookiesViewCell.tableView.reloadData()
                        return self.cookieCellHeight == 0 ? UITableView.automaticDimension : self.cookieCellHeight
                    case .metricsTitleCell:
                        return 44
                    case .metricsViewCell:
                        self.metricsViewCell.tableView.invalidateIntrinsicContentSize()
                        self.metricsViewCell.invalidateIntrinsicContentSize()
                        self.metricsViewCell.tableView.reloadData()
                        return self.metricsCellHeight == 0 ? UITableView.automaticDimension : self.metricsCellHeight
                    case .detailsTitleCell:
                        return 44
                    case .detailsViewCell:
                        self.detailsViewCell.tableView.invalidateIntrinsicContentSize()
                        self.detailsViewCell.invalidateIntrinsicContentSize()
                        self.detailsViewCell.tableView.reloadData()
                        return self.detailsCellHeight == 0 ? UITableView.automaticDimension : self.detailsCellHeight
                    case .spacerAfterDetailsCell:
                        return 24
                    default:
                        return 0
                    }
                }
            }
        case 1:  // raw section
            if indexPath.row == RawCellId.spacerBeforeRawCell.rawValue {
                return 24
            }
            let h: CGFloat = UIScreen.main.bounds.height - (48 + self.tabbarController.tabBar.frame.height + self.navigationController!.navigationBar.frame.height +
                UIApplication.shared.keyWindow!.safeAreaInsets.top)
            Log.debug("view height: \(h) - 832?")
            return h
        case 2:  // preview section
            if indexPath.row == PreviewCellId.spacerBeforePreviewCell.rawValue {
                return 24
            }
            let h: CGFloat = UIScreen.main.bounds.height - (48 + self.tabbarController.tabBar.frame.height + self.navigationController!.navigationBar.frame.height +
                UIApplication.shared.keyWindow!.safeAreaInsets.top)
            return h
        default:
            return 0
        }
        return UITableView.automaticDimension
    }
}
