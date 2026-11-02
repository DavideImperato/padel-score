import AVFoundation
import Flutter
import MediaPlayer
import UIKit

/// Controllo volume nativo associato alla UIWindowScene attiva.
/// Non intercetta direttamente eventi dei pulsanti hardware.
public final class PadelVolumeDiagnosticPlugin: NSObject, FlutterPlugin {
    private var volumeView: MPVolumeView?
    private weak var volumeWindow: UIWindow?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "padel_volume_diagnostic",
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(PadelVolumeDiagnosticPlugin(), channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Le chiamate method-channel standard arrivano sul thread principale;
        // garantiamo comunque che UIKit venga usato esclusivamente sul main.
        if Thread.isMainThread {
            handleOnMain(call, result: result)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.handleOnMain(call, result: result)
            }
        }
    }

    private func handleOnMain(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "read":
            result(Double(AVAudioSession.sharedInstance().outputVolume))
        case "write":
            guard
                let args = call.arguments as? [String: Any],
                let number = args["volume"] as? NSNumber
            else {
                result(FlutterError(code: "bad_args", message: "Parametro volume mancante", details: nil))
                return
            }
            let target = number.floatValue
            guard target.isFinite && target >= 0.0 && target <= 1.0 else {
                result(FlutterError(code: "bad_volume", message: "Volume fuori intervallo", details: nil))
                return
            }
            writeVolume(target, result: result)
        case "release":
            volumeView?.removeFromSuperview()
            volumeView = nil
            volumeWindow = nil
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func foregroundWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .sorted {
                ($0.activationState == .foregroundActive ? 0 : 1) <
                ($1.activationState == .foregroundActive ? 0 : 1)
            }
        for scene in scenes {
            if let window = scene.windows.first(where: { $0.isKeyWindow }) {
                return window
            }
            if let window = scene.windows.first(where: { !$0.isHidden }) {
                return window
            }
        }
        return nil
    }

    private func attachedSlider() -> UISlider? {
        guard let window = foregroundWindow() else { return nil }
        if volumeView == nil || volumeWindow !== window {
            volumeView?.removeFromSuperview()
            // Controllo tecnico di 2x2 punti: la regolazione visibile
            // e' nel pannello Flutter Audio e telecomando.
            // Mantenerlo associato a UIWindowScene per la scrittura Debug.
            let view = MPVolumeView(frame: CGRect(x: 0, y: 0, width: 2, height: 2))
            view.showsRouteButton = false
            view.showsVolumeSlider = true
            view.alpha = 0.05
            view.isUserInteractionEnabled = true
            window.addSubview(view)
            volumeView = view
            volumeWindow = window
        }
        guard let view = volumeView else { return nil }
        view.setNeedsLayout()
        view.layoutIfNeeded()
        let slider = view.subviews.compactMap { $0 as? UISlider }.first
        print("[PadelVolumeNative] Slider presente=\(slider != nil); subviews=\(view.subviews.count); category=\(AVAudioSession.sharedInstance().category.rawValue)")
        return slider
    }

    private func writeVolume(_ target: Float, result: @escaping FlutterResult) {
        let before = AVAudioSession.sharedInstance().outputVolume
        print("[PadelVolumeNative] WRITE prima=\(before); richiesto=\(target)")
        guard let slider = attachedSlider() else {
            result(FlutterError(code: "slider_unavailable", message: "MPVolumeView non associato alla UIWindowScene attiva", details: nil))
            return
        }

        slider.setValue(target, animated: false)
        slider.sendActions(for: .valueChanged)

        func check(_ finalAttempt: Bool) {
            let observed = AVAudioSession.sharedInstance().outputVolume
            print("[PadelVolumeNative] CHECK letto=\(observed); slider=\(slider.value); confermato=\(abs(observed - target) <= 0.025)")
            if abs(observed - target) <= 0.025 || finalAttempt {
                result([
                    "requested": Double(target),
                    "before": Double(before),
                    "observed": Double(observed),
                    "confirmed": abs(observed - target) <= 0.025,
                    "sliderValue": Double(slider.value)
                ])
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(400)) {
                    check(true)
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(180)) {
            check(false)
        }
    }
}
