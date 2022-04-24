//
//  UserPlayer.swift
//  Bubbles
//
//  Created by Alfred Lapkovsky on 22/04/2022.
//

import Foundation


@MainActor
class UserPlayer : Player {
    
    typealias StepCompletion = @Sendable (_ bubbleId: UUID?) -> Void
    typealias StepHandler = (@escaping StepCompletion) -> Void
    
    var stepHandler: StepHandler?
    
    private var stepContinuation: UnsafeContinuation<UUID?, Never>?
    
    init() {
    }
    
    func makeStep(_ stepInfo: GameManager.StepInfo) async -> UUID? {
        guard stepContinuation == nil else {
            return nil
        }
        
        return await withTaskCancellationHandler(handler: {
            Task { @MainActor [weak self] in
                self?.completeTask(with: nil)
            }
        }, operation: {
            return await withUnsafeContinuation { continuation in
                stepContinuation = continuation
                
                stepHandler?({ bubbleId in
                    Task { @MainActor [weak self] in
                        self?.completeTask(with: bubbleId)
                    }
                })
            }
        })
    }
    
    private func completeTask(with bubbleId: UUID?) {
        stepContinuation?.resume(returning: bubbleId)
        stepContinuation = nil
    }
}
