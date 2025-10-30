# Build & Test Commands

- Build the iOS app for the simulator:
  ```bash
  xcodebuild -scheme count -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
  ```

- Run the unit tests:
  ```bash
  xcodebuild -scheme count -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
  ```

These are the commands I’ve been using to validate changes locally.

# Reference Documentation

- Swift Dependencies docc catalog  
  `DerivedData/count/SourcePackages/checkouts/swift-dependencies/Sources/Dependencies/Documentation.docc`

- Swift Composable Architecture docc catalog  
  `DerivedData/count/SourcePackages/checkouts/swift-composable-architecture/Sources/ComposableArchitecture/Documentation.docc`

