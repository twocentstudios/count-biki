import SceneKit
import SwiftUI

struct CountBikiView: View {
    struct SceneState {
        let scene: SCNScene
        let catalogName = "CountBiki.scnassets"

        init() {
            scene = .init(named: "\(catalogName)/count_biki_rig.scn")!
        }

        @MainActor func playIdle() {
            Self.playAnimation(scene: scene, resourceName: "\(catalogName)/count_biki_anim_idle", isLooped: true)
        }

        @MainActor func playCorrect() {
            Self.playAnimation(scene: scene, resourceName: "\(catalogName)/count_biki_anim_correct", isLooped: false)
        }

        @MainActor func playIncorrect() {
            Self.playAnimation(scene: scene, resourceName: "\(catalogName)/count_biki_anim_incorrect", isLooped: false)
        }

        @MainActor static func playAnimation(scene: SCNScene, resourceName: String, isLooped: Bool = false) {
            guard let sceneURL = Bundle.main.url(forResource: resourceName, withExtension: "dae") else {
                assertionFailure("\(resourceName).dae file not found")
                return
            }
            guard let sceneSource = SCNSceneSource(url: sceneURL, options: nil) else {
                assertionFailure("Scene for \(sceneURL) could not be loaded")
                return
            }

            guard let animationKey = sceneSource.identifiersOfEntries(withClass: CAAnimation.self).first,
                  let animationGroup = sceneSource.entryWithIdentifier(animationKey, withClass: CAAnimation.self),
                  animationGroup.isKind(of: CAAnimationGroup.self)
            else {
                assertionFailure("Animation not found in \(resourceName)")
                return
            }

            guard let targetNode = scene.rootNode.childNode(withName: "Armature", recursively: true) else {
                assertionFailure("Armature node not found in scene")
                return
            }

            animationGroup.repeatCount = isLooped ? .greatestFiniteMagnitude : 1
            animationGroup.fadeInDuration = 0.5
            animationGroup.fadeOutDuration = 0.5
            animationGroup.isRemovedOnCompletion = true

            targetNode.addAnimation(animationGroup, forKey: resourceName)
        }
    }

    @State var sceneState: SceneState = .init()
    var bikiAnimation: BikiAnimation?
    @Environment(\.colorScheme) var colorScheme: ColorScheme

    var body: some View {
        SceneView(
            scene: sceneState.scene,
            pointOfView: nil,
            options: [],
            preferredFramesPerSecond: 48,
            antialiasingMode: .multisampling4X,
            delegate: nil,
            technique: nil
        )
        .clipShape(Circle())
        .padding(2)
        .background { Circle().fill(Color(.secondarySystemBackground)) }
        .aspectRatio(contentMode: .fit)
        .onAppear {
            updateSceneBackground(colorScheme)
            sceneState.playIdle()
        }
        .onChange(of: colorScheme) { _, newValue in
            updateSceneBackground(newValue)
        }
        .onChange(of: bikiAnimation) { _, newValue in
            switch newValue?.kind {
            case .correct:
                sceneState.playCorrect()
            case .incorrect:
                sceneState.playIncorrect()
            case nil:
                break
            }
        }
    }

    private func updateSceneBackground(_ colorScheme: ColorScheme) {
        sceneState.scene.background.contents = colorScheme == .dark ? UIColor.black : UIColor.white
    }
}

#Preview {
    CountBikiView()
}
