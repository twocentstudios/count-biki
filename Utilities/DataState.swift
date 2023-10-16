import Foundation

enum DataState<Value: Equatable & Sendable>: Equatable, Sendable {
    case initialized
    case loading
    case loadingFailed(EquatableError)
    case loaded(Value)
    case reloading(Value)
}

extension DataState {
    var isLoading: Bool {
        switch self {
        case .initialized: true
        case .loading: true
        case .loadingFailed: false
        case .loaded: false
        case .reloading: true
        }
    }

    var isLoaded: Bool {
        switch self {
        case .initialized: false
        case .loading: false
        case .loadingFailed: false
        case .loaded: true
        case .reloading: true
        }
    }

    var isLoadingFirstTime: Bool {
        switch self {
        case .initialized: false
        case .loading: true
        case .reloading: false
        case .loadingFailed: false
        case .loaded: false
        }
    }

    var isReloading: Bool {
        switch self {
        case .initialized: false
        case .loading: false
        case .reloading: true
        case .loadingFailed: false
        case .loaded: false
        }
    }

    var shouldLoad: Bool {
        switch self {
        case .initialized: true
        case .loading: false
        case .reloading: false
        case .loadingFailed: true
        case .loaded: true
        }
    }

    var stateByLoading: Self? {
        switch self {
        case .initialized: .loading
        case .loading: nil
        case .reloading: nil
        case .loadingFailed: .loading
        case let .loaded(value): .reloading(value)
        }
    }

    var reloadDisabled: Bool {
        switch self {
        case .initialized: true
        case .loading: true
        case .reloading: true
        case .loadingFailed: true
        case .loaded: false
        }
    }

    var allowsMutation: Bool {
        switch self {
        case .initialized: false
        case .loading: false
        case .reloading: false
        case .loadingFailed: false
        case .loaded: true
        }
    }

    var value: Value? {
        switch self {
        case .initialized: nil
        case .loading: nil
        case let .reloading(value): value
        case .loadingFailed: nil
        case let .loaded(value): value
        }
    }

    var errorMessage: String? {
        switch self {
        case let .loadingFailed(error):
            error.localizedDescription
        case .initialized,
             .loading,
             .reloading,
             .loaded:
            nil
        }
    }
}
