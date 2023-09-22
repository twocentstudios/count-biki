import Dependencies
import IdentifiedCollections
import UIKit.UIImage

struct AppIconClient {
    var allIcons: @Sendable () -> IdentifiedArrayOf<AppIcon>
    var appIcon: @MainActor @Sendable () -> AppIcon
    var setAppIcon: @Sendable (AppIcon) async throws -> Void
}

extension AppIconClient: DependencyKey {
    static var liveValue: Self {
        Self(
            allIcons: { IdentifiedArray(uniqueElements: AppIcon.allCases) },
            appIcon: { @MainActor in
                if let iconName = UIApplication.shared.alternateIconName,
                   let appIcon = AppIcon(rawValue: iconName)
                {
                    return appIcon
                } else {
                    return AppIcon.primary
                }
            },
            setAppIcon: { newIcon in
                guard await UIApplication.shared.alternateIconName != newIcon.iconName else { return }
                try await UIApplication.shared.setAlternateIconName(newIcon.iconName)
            }
        )
    }
}
extension DependencyValues {
    var appIconClient: AppIconClient {
        get { self[AppIconClient.self] }
        set { self[AppIconClient.self] = newValue }
    }
}

/// Ref: https://www.avanderlee.com/swift/alternate-app-icon-configuration-in-xcode/
enum AppIcon: String, CaseIterable, Identifiable {
    case primary = "AppIcon"
    case icon01 = "AppIcon-01"
    case icon02 = "AppIcon-02"
    case icon03 = "AppIcon-03"
    case icon04 = "AppIcon-04"
    case icon05 = "AppIcon-05"

    var id: String { rawValue }
    var iconName: String? {
        switch self {
        case .primary:
            /// `nil` is used to reset the app icon back to its primary icon.
            return nil
        default:
            return rawValue
        }
    }
}
