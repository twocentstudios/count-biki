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
                let iconName = UIApplication.shared.alternateIconName
                let appIcon = AppIcon(uikitName: iconName)
                return appIcon
            },
            setAppIcon: { newIcon in
                guard await UIApplication.shared.alternateIconName != newIcon.uikitName else { return }
                try await UIApplication.shared.setAlternateIconName(newIcon.uikitName)
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
enum AppIcon: String, CaseIterable, Identifiable, Equatable {
    case primary = "AppIcon"
    case icon01 = "AppIcon-01"
    case icon02 = "AppIcon-02"
    case icon03 = "AppIcon-03"
    case icon04 = "AppIcon-04"
    case icon05 = "AppIcon-05"

    var id: String { rawValue }
    var iconName: String { rawValue }
    var uikitName: String? {
        if self == .primary {
            nil
        } else {
            rawValue
        }
    }
}

extension AppIcon {
    init(uikitName: String?) {
        if let uikitName,
           let alternate = Self(rawValue: uikitName)
        {
            self = alternate
        } else {
            self = .primary
        }
    }
}
