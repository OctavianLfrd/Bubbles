//
//  ContentView.swift
//  Bubbles
//
//  Created by Alfred Lapkovsky on 21/04/2022.
//

import SwiftUI


struct ContentView: View {
    
    @StateObject private var gameManager = GameManager()
    @State private var stepCompletion: UserPlayer.StepCompletion?
    @State private var player1Name: String = ""
    @State private var player2Name: String = ""
    
    private let gameNameString = "Bubbles"
    private let newGameString = "Jauna spēle"
    private let whoPlaysFirstString = "Kurš spēlē pirmais?"
    private let userString = "Lietotājs"
    private let computerString = "Dators"
    private let wonString = "Uzvarēja"
    private let drawString = "Neizšķirts"
    private let okString = "OK"
    
    var body: some View {
        switch gameManager.state {
        case .inactive:
            inactiveGameView
        case .setup:
            setupGameView
        case .active:
            activeGameView
        case .finished(let result):
            buildFinishedGameView(result)
        }
    }
    
    private var inactiveGameView: some View {
        VStack(spacing: 0) {
            Text(gameNameString)
                .font(.system(size: 54, weight: .bold, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [.red, .blue], startPoint: UnitPoint(x: 0, y: 0.8), endPoint: UnitPoint(x: 1, y: 0.2)))
                .padding()
            Spacer()
            HStack {
                Circle()
                    .frame(width: 50, height: 50, alignment: .center)
                    .foregroundColor(getColor(Bubble.ColorType.color1))
                Circle()
                    .frame(width: 50, height: 50, alignment: .center)
                    .foregroundColor(getColor(Bubble.ColorType.color2))
            }
            HStack {
                Circle()
                    .frame(width: 50, height: 50, alignment: .center)
                    .foregroundColor(getColor(Bubble.ColorType.color3))
                Circle()
                    .frame(width: 50, height: 50, alignment: .center)
                    .foregroundColor(getColor(Bubble.ColorType.color4))
                Circle()
                    .frame(width: 50, height: 50, alignment: .center)
                    .foregroundColor(getColor(Bubble.ColorType.color5))
            }
            
            Button {
                startGame()
            } label: {
                Text(newGameString)
                    .font(Font.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                    .background(Capsule().foregroundStyle(LinearGradient(colors: [.red, .blue], startPoint: UnitPoint(x: 0, y: 0.8), endPoint: UnitPoint(x: 1, y: 0.2))))
            }
            .buttonStyle(ScalingButtonStyle())
            .padding(EdgeInsets(top: 20, leading: 16, bottom: 20, trailing: 16))
            Spacer()
        }
        .padding()
    }
    
    private var setupGameView: some View {
        VStack {
            Text(whoPlaysFirstString)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .padding()
            
            HStack {
                VStack {
                    Button {
                        startGame(userPlaysFirst: true)
                    } label: {
                        Image(systemName: "brain.head.profile")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 90, height: 90, alignment: .center)
                            .padding(EdgeInsets(top: 24, leading: 24, bottom: 24, trailing: 24))
                            .background(Circle().foregroundColor(.red))
                    }
                    .buttonStyle(ScalingButtonStyle())
                    .padding()
                    
                    Text(userString)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
                VStack {
                    Button {
                        startGame(userPlaysFirst: false)
                    } label: {
                        Image(systemName: "desktopcomputer")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 90, height: 90, alignment: .center)
                            .padding(EdgeInsets(top: 24, leading: 24, bottom: 24, trailing: 24))
                            .background(Circle().foregroundColor(.blue))
                    }
                    .buttonStyle(ScalingButtonStyle())
                    .padding()
                    
                    Text(computerString)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
        }
        .padding()
    }
    
    private var activeGameView: some View {
        GeometryReader { geometry in
            let circleSize = geometry.size.width / CGFloat(gameManager.bubbleFieldDimensions.horizontal)
            
            VStack(alignment: .center, spacing: 0) {
                HStack {
                    let activePlayer1 = gameManager.activePlayerType == .player1
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(player1Name)
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                        Text(String(gameManager.player1Scores))
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                    }
                    .frame(width: 100, height: 50, alignment: .leading)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.red.opacity(activePlayer1 ? 1 : 0.5), style: StrokeStyle(lineWidth: activePlayer1 ? 5 : 3, lineCap: .round, lineJoin: .round))
                            .foregroundColor(.black.opacity(0))
                    )
                    Spacer()
                    Text(String(Int(gameManager.stepRemainingTime)))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Spacer()
                    VStack(alignment: .trailing, spacing: 8) {
                        Text(player2Name)
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                        Text(String(gameManager.player2Scores))
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                    }
                    .frame(width: 100, height: 50, alignment: .trailing)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.blue.opacity(activePlayer1 ? 0.5 : 1), style: StrokeStyle(lineWidth: activePlayer1 ? 3 : 5, lineCap: .round, lineJoin: .round))
                            .foregroundColor(.black.opacity(0))
                    )
                }
                Spacer()
                ForEach(gameManager.bubbleRows) { bubbleRow in
                    HStack(alignment: .center, spacing: 0) {
                        ForEach(bubbleRow.bubbles) { bubble in
                            let dismissed = gameManager.dismissedBubbleIds?.contains(bubble.id) == true
                            
                            Button {
                                if bubble.colorType != .invisible {
                                    stepCompletion?(bubble.id)
                                    stepCompletion = nil
                                }
                            } label: {
                                Circle()
                                    .frame(width: circleSize, height: circleSize, alignment: .center)
                                    .foregroundColor(getColor(bubble.colorType))
                                    .padding(.zero)
                                    .scaleEffect(dismissed ? 0.5 : 1)
                                    .animation(.spring(response: 0.25, dampingFraction: 0.4, blendDuration: 0.2), value: dismissed)
                            }
                            .buttonStyle(ScalingButtonStyle())
                        }
                    }
                }
                Spacer()
            }
        }

        .padding(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
    }
    
    private func buildFinishedGameView(_ result: GameManager.GameResult) -> some View {
        VStack {
            Text(gameNameString)
                .font(.system(size: 54, weight: .bold, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [.red, .blue], startPoint: UnitPoint(x: 0, y: 0.8), endPoint: UnitPoint(x: 1, y: 0.2)))
                .padding()
            Spacer()
            
            if result == .draw {
                Text(drawString)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding()
                HStack {
                    Text("\(player1Name): \(gameManager.player1Scores)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding()
                    Text("\(player2Name): \(gameManager.player2Scores)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding()
                }
            } else {
                switch result {
                case .winner1:
                    Text("\(wonString) \(player1Name)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("\(gameManager.player1Scores)")
                        .font(.system(size: 100, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("\(player2Name): \(gameManager.player2Scores)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding()
                case .winner2:
                    Text("\(wonString) \(player2Name)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("\(gameManager.player2Scores)")
                        .font(.system(size: 100, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("\(player1Name): \(gameManager.player1Scores)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding()
                default:
                    fatalError()
                }
            }
            Spacer()
            Button {
                gameManager.finishGame()
            } label: {
                Text(okString)
                    .font(Font.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(EdgeInsets(top: 16, leading: 50, bottom: 16, trailing: 50))
                    .background(Capsule().foregroundStyle(LinearGradient(colors: [.red, .blue], startPoint: UnitPoint(x: 0, y: 0.8), endPoint: UnitPoint(x: 1, y: 0.2))))
            }
            .buttonStyle(ScalingButtonStyle())
            .padding(EdgeInsets(top: 20, leading: 16, bottom: 48, trailing: 16))
        }
    }
    
    private func startGame() {
        gameManager.setupGame()
    }
    
    private func startGame(userPlaysFirst: Bool) {
        let player1: Player
        let player2: Player
        
        if userPlaysFirst {
            player1 = createUserPlayer()
            player2 = createComputerPlayer()
            player1Name = userString
            player2Name = computerString
        } else {
            player1 = createComputerPlayer()
            player2 = createUserPlayer()
            player1Name = computerString
            player2Name = userString
        }

        gameManager.startGame(player1: player1, player2: player2)
    }
    
    private func createUserPlayer() -> UserPlayer {
        let userPlayer = UserPlayer()
        userPlayer.stepHandler = { completion in
            stepCompletion = completion
        }
        
        return userPlayer
    }
    
    private func createComputerPlayer() -> ComputerPlayer {
        return ComputerPlayer()
    }
    
    private func getColor(_ colorType: Bubble.ColorType) -> Color {
        switch colorType {
        case .invisible: return .black.opacity(0)
        case .color1: return .red
        case .color2: return .blue
        case .color3: return .green
        case .color4: return .yellow
        case .color5: return .teal
        case .color6: return .purple
        }
    }
}

struct ScalingButtonStyle : ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.8 : 1)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
