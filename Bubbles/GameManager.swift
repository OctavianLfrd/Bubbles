//
//  GameManager.swift
//  Bubbles
//
//  Created by Alfred Lapkovsky on 21/04/2022.
//

import Foundation
import SwiftUI


@MainActor
class GameManager : ObservableObject {
    
    @Published private(set) var state: State = .inactive
    @Published private(set) var bubbleRows: [BubbleRow] = []
    @Published private(set) var stepRemainingTime: TimeInterval = -1
    @Published private(set) var activePlayerType: PlayerType = .none
    @Published private(set) var player1Scores: Int = 0
    @Published private(set) var player2Scores: Int = 0
    @Published private(set) var dismissedBubbleIds: Set<UUID>?
    
    let bubbleFieldDimensions: BubbleField.Dimensions = .presetTiny
    let bubbleFieldColorCount: BubbleField.ColorCount = .six
    
    private static let stepRecommendedTime: TimeInterval = 25
    private static let stepTimeLimit: TimeInterval = 30
    
    private var player1: Player!
    private var player2: Player!
    private var bubbleField: BubbleField!
    
    init() {
    }
    
    func setupGame() {
        guard state == .inactive else {
            return
        }
        
        state = .setup
    }
    
    func startGame(player1: Player, player2: Player) {
        guard state == .setup else {
            return
        }
        
        self.player1 = player1
        self.player2 = player2
        
        bubbleField = BubbleField(bubbleFieldDimensions, colorCount: bubbleFieldColorCount)
        player1Scores = 0
        player2Scores = 0
        stepRemainingTime = -1
        activePlayerType = .player1
        state = .active
        
        bubbleField.setup()
        
        loopGame()
    }
    
    func finishGame() {
        guard state.isFinished else {
            return
        }
        
        state = .inactive
    }
    
    private func loopGame() {
        Task {
            var activePlayer = player1
            var idlePlayer = player2
            
            while state == .active {
                do {
                    let player = activePlayer
                    let stepInfo = getCurrentStepInfo()
                    
                    bubbleRows = bubbleField.bubbleRows
                    
                    let id: UUID = try await withThrowingTaskGroup(of: UUID.self) { group in
                        
                        group.addTask {
                            var timeLeft = await self.updateTimeLimitAndGet(Self.stepTimeLimit)
                            
                            while timeLeft > 0 {
                                try await Task.sleep(nanoseconds: 1_000_000_000)
                                timeLeft = await self.updateTimeLimitAndGet(timeLeft - 1)
                            }
                            
                            throw CancellationError()
                        }
                        
                        group.addTask {
                            if let id = await player?.makeStep(stepInfo) {
                                return id
                            }
                            
                            throw CancellationError()
                        }
                        
                        do {
                            if let id = try await group.next() {
                                group.cancelAll()
                                return id
                            }
                        } catch {
                            print(error)
                        }
                        
                        group.cancelAll()
                        throw CancellationError()
                    }

                    if let killedBubbleIds = bubbleField.killBubbles(by: id) {
                        
                        self.dismissedBubbleIds = killedBubbleIds
                        try? await Task.sleep(nanoseconds: 250_000_000)
                        self.dismissedBubbleIds = nil
                        
                        let playerScores = killedBubbleIds.count
                        
                        print("Player \(player) kills id \(id) and gets \(playerScores) scores")
                        addScoresToCurrentPlayer(playerScores)
                    }
                    else {
                        print("Player \(player) did not kill anything")
                    }
                } catch {
                    print("An error occurred")
                }
                
                if bubbleField.isEmpty {
                    declareResults()
                } else {
                    (activePlayer, idlePlayer) = (idlePlayer, activePlayer)
                    
                    activePlayerType.next()
                }
            }
            
            activePlayerType = .none
        }
    }
    
    private func declareResults() {
        if player1Scores > player2Scores {
            state = .finished(result: .winner1)
        } else if player2Scores > player1Scores {
            state = .finished(result: .winner2)
        } else {
            state = .finished(result: .draw)
        }
    }
    
    private func getCurrentStepInfo() -> StepInfo {
        let ownScores: Int
        let opponentScores: Int
        
        switch activePlayerType {
        case .none:
            fatalError()
        case .player1:
            ownScores = player1Scores
            opponentScores = player2Scores
        case .player2:
            ownScores = player2Scores
            opponentScores = player1Scores
        }
        
        return StepInfo(playerType: activePlayerType,
                        stepRecommendedTime: Self.stepRecommendedTime,
                        stepTimeLimit: Self.stepTimeLimit,
                        ownScores: ownScores,
                        opponentScores: opponentScores,
                        fieldCopy: BubbleField(bubbleField))
    }
    
    private func addScoresToCurrentPlayer(_ scores: Int) {
        switch activePlayerType {
        case .none:
            fatalError()
        case .player1:
            player1Scores += scores
        case .player2:
            player2Scores += scores
        }
    }
    
    private func updateTimeLimitAndGet(_ timeLimit: TimeInterval) -> TimeInterval {
        stepRemainingTime = timeLimit
        return stepRemainingTime
    }
    
    enum State : Equatable {
        case inactive
        case setup
        case active
        case finished(result: GameResult)
        
        var isFinished: Bool {
            if case .finished(_) = self {
                return true
            }
            
            return false
        }
    }
    
    enum PlayerType : Equatable {
        case none
        case player1
        case player2
        
        mutating func next() {
            switch self {
            case .none:
                self = .none
            case .player1:
                self = .player2
            case .player2:
                self = .player1
            }
        }
    }
    
    enum GameResult {
        case winner1
        case winner2
        case draw
    }
    
    struct StepInfo {
        let playerType: PlayerType
        let stepRecommendedTime: TimeInterval
        let stepTimeLimit: TimeInterval
        let ownScores: Int
        let opponentScores: Int
        let fieldCopy: BubbleField
    }
}
