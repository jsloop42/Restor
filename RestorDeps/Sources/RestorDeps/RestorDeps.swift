import IQKeyboardManagerSwift

public struct RestorDeps {
    private static let keyboardManager = IQKeyboardManager.shared
    
    public static func enableIQKeyboardManager() {
        self.keyboardManager.enable = true
        self.keyboardManager.enableAutoToolbar = false        
    }
}
