import UIKit
import Capacitor

/// The app's web view controller. Registers Khione's in-app native plugins.
class KhioneViewController: CAPBridgeViewController {
    override open func capacitorDidLoad() {
        bridge?.registerPluginInstance(KhioneHapticsPlugin())
    }
}

/// Taptic feedback for the game: `Capacitor.nativePromise('KhioneHaptics', 'impact', { style, intensity })`,
/// `'notify'` with `{ type: 'success' | 'warning' | 'error' }`, and `'selection'`.
@objc(KhioneHapticsPlugin)
public class KhioneHapticsPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "KhioneHapticsPlugin"
    public let jsName = "KhioneHaptics"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "impact", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "notify", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "selection", returnType: CAPPluginReturnPromise)
    ]

    @objc func impact(_ call: CAPPluginCall) {
        let style: UIImpactFeedbackGenerator.FeedbackStyle
        switch call.getString("style") ?? "light" {
        case "medium": style = .medium
        case "heavy": style = .heavy
        case "rigid": style = .rigid
        case "soft": style = .soft
        default: style = .light
        }
        let intensity = CGFloat(min(max(call.getDouble("intensity") ?? 1.0, 0.0), 1.0))
        DispatchQueue.main.async {
            UIImpactFeedbackGenerator(style: style).impactOccurred(intensity: intensity)
            call.resolve()
        }
    }

    @objc func notify(_ call: CAPPluginCall) {
        let type: UINotificationFeedbackGenerator.FeedbackType
        switch call.getString("type") ?? "success" {
        case "warning": type = .warning
        case "error": type = .error
        default: type = .success
        }
        DispatchQueue.main.async {
            UINotificationFeedbackGenerator().notificationOccurred(type)
            call.resolve()
        }
    }

    @objc func selection(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            UISelectionFeedbackGenerator().selectionChanged()
            call.resolve()
        }
    }
}
