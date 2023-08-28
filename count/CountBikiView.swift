import SceneKit
import SwiftUI

@MainActor struct CountBikiView: View {
    @MainActor struct SceneState {
        let scene: SCNScene
        let idlePlayer: SCNAnimationPlayer
        let correctPlayer: SCNAnimationPlayer
        let incorrectPlayer: SCNAnimationPlayer

        init() {
            let catalogName = "CountBiki.scnassets"
            scene = .init(named: "\(catalogName)/count_biki_rig.scn")!
            idlePlayer = Self.playerForAnimation(scene: scene, resourceName: "\(catalogName)/count_biki_anim_idle", isLooped: true)
            correctPlayer = Self.playerForAnimation(scene: scene, resourceName: "\(catalogName)/count_biki_anim_correct", isLooped: false)
            incorrectPlayer = Self.playerForAnimation(scene: scene, resourceName: "\(catalogName)/count_biki_anim_incorrect", isLooped: false)
        }

        static func playerForAnimation(scene: SCNScene, resourceName: String, isLooped: Bool = false) -> SCNAnimationPlayer {
            guard let sceneURL = Bundle.main.url(forResource: resourceName, withExtension: "dae") else {
                assertionFailure("\(resourceName).dae file not found")
                return SCNAnimationPlayer()
            }
            guard let sceneSource = SCNSceneSource(url: sceneURL, options: nil) else {
                assertionFailure("Scene for \(sceneURL) could not be loaded")
                return SCNAnimationPlayer()
            }

            guard let animationKey = sceneSource.identifiersOfEntries(withClass: CAAnimation.self).first,
                  let animationGroup = sceneSource.entryWithIdentifier(animationKey, withClass: CAAnimation.self),
                  animationGroup.isKind(of: CAAnimationGroup.self)
            else {
                assertionFailure("Animation not found in \(resourceName)")
                return SCNAnimationPlayer()
            }

            guard let targetNode = scene.rootNode.childNode(withName: "Armature", recursively: true) else {
                assertionFailure("Armature node not found in scene")
                return SCNAnimationPlayer()
            }

            animationGroup.repeatCount = isLooped ? .infinity : 1
            animationGroup.fadeInDuration = 0.5
            animationGroup.fadeOutDuration = 0.5

            let player = SCNAnimationPlayer(animation: SCNAnimation(caAnimation: animationGroup))
            targetNode.addAnimationPlayer(player, forKey: resourceName)
            return player
        }
    }
    
    let sceneState: SceneState = .init()
    var bikiAnimation: BikiAnimation?

    var body: some View {
        SceneView(
            scene: sceneState.scene,
            pointOfView: nil,
            options: [],
            preferredFramesPerSecond: 24,
            antialiasingMode: .multisampling4X,
            delegate: nil,
            technique: nil
        )
        .clipShape(Circle())
        .aspectRatio(contentMode: .fit)
        .onAppear {
            sceneState.idlePlayer.play()
        }
    }
}

#Preview {
    CountBikiView()
}
