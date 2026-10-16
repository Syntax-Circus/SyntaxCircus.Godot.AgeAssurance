import Foundation
import UIKit
import DeclaredAgeRange

// Objective-C++ owns the engine interface. UIKit and framework calls stay on MainActor.
@objc(SCAgeAssurance)
public final class SCAgeAssurance: NSObject {
    @objc public static func request(_ minimum: Int, allowPrompt: Bool, completion: @escaping (String) -> Void) {
        Task { @MainActor in
            var wire: [String: Any] = ["status": "unavailable"]
            if #available(iOS 26.0, *) {
                var mandatory = false
                do {
                    if #available(iOS 26.4, *) {
                        let features = try await AgeRangeService.shared.requiredRegulatoryFeatures
                        mandatory = features.contains(.declaredAgeRangeRequired)
                        var requirements: [String] = []
                        if features.contains(.significantAppChangeRequiresParentalConsent) { requirements.append("parental_consent") }
                        if features.contains(.significantAppChangeRequiresAdultNotification) { requirements.append("adult_notification") }
                        wire["requirements"] = requirements
                    } else if #available(iOS 26.2, *) {
                        mandatory = try await AgeRangeService.shared.isEligibleForAgeFeatures
                    }
                    wire["mandatory"] = mandatory
                    // There is no noninteractive request API on Apple. A foreground check reports
                    // unavailable and the game explicitly offers Recheck; never show unsolicited sheets.
                    if !allowPrompt {
                        // No silent range API exists. Reevaluate the session's last bounds against
                        // changed thresholds; refresh the actual Apple range on launch/explicit Recheck.
                        wire["reuse_session"] = true
                    } else {
                        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                        let root = scenes.filter { $0.activationState == .foregroundActive }
                            .flatMap { $0.windows }.first { $0.isKeyWindow }?.rootViewController
                        if let root {
                            var presenter = root
                            while let presented = presenter.presentedViewController { presenter = presented }
                            let response = try await AgeRangeService.shared.requestAgeRange(ageGates: minimum, in: presenter)
                            switch response {
                            case .sharing(let range):
                                wire["status"] = "shared"
                                if let lower = range.lowerBound { wire["lower"] = lower }
                                // Apple's sandbox table documents inclusive upper bounds (12/15/17).
                                // https://developer.apple.com/documentation/storekit/testing-age-assurance-in-sandbox
                                if let upper = range.upperBound { wire["upper_exclusive"] = upper + 1 }
                            case .declinedSharing: wire["status"] = "declined"
                            @unknown default: wire["status"] = "unavailable"
                            }
                        }
                    }
                } catch {
                    wire["status"] = "unavailable"
                    wire["mandatory"] = mandatory
                }
            }
            let data = (try? JSONSerialization.data(withJSONObject: wire)) ?? Data("{}".utf8)
            completion(String(decoding: data, as: UTF8.self))
        }
    }
}
