import SwiftUI

/// 根界面：在主界面、关卡列表和游戏画面之间切换
struct ContentView: View {
    private enum Screen: Equatable {
        case menu
        case levelSelect
        case game
    }

    @State private var screen: Screen = .menu
    /// 整个 App 共用一个游戏场景，每次进入游戏时重新开局
    @State private var scene = GameScene()

    var body: some View {
        ZStack {
            // 所有界面共用的木桌面背景，游戏场景是透明的，也会露出它
            WoodTableBackground()

            switch screen {
            case .menu:
                MainMenuView(
                    onEndless: { play(.endless) },
                    onLevels: { screen = .levelSelect }
                )
            case .levelSelect:
                LevelSelectView(
                    onSelect: { play(.level($0)) },
                    onBack: { screen = .menu }
                )
            case .game:
                GameView(
                    scene: scene,
                    onExit: exitGame,
                    onPlay: play
                )
            }
        }
        .animation(.easeInOut(duration: 0.2), value: screen)
    }

    private func play(_ mode: GameMode) {
        scene.start(mode)
        screen = .game
    }

    /// 无尽模式回主界面，闯关模式回关卡列表
    private func exitGame() {
        scene.stop()
        screen = scene.mode == .endless ? .menu : .levelSelect
    }
}

#Preview {
    ContentView()
}
