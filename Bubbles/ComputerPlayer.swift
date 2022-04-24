//
//  ComputerPlayer.swift
//  Bubbles
//
//  Created by Alfred Lapkovsky on 22/04/2022.
//

import Foundation


actor ComputerPlayer : Player {
    
    private var task: Task<UUID?, Never>?
    private var cancellationTask: Task<Void, Never>?
    
    private static let maxChildNodeCount = 100_000
    
    func makeStep(_ stepInfo: GameManager.StepInfo) async -> UUID? {
        guard task == nil else {
            return nil
        }
        
        task = Task(priority: .high) {
            return await computeBestStep(stepInfo)
        }
        
        cancellationTask = Task(priority: .high) {
            try? await Task.sleep(nanoseconds: UInt64(stepInfo.stepRecommendedTime) * 1_000_000_000)
            task?.cancel()
        }
        
        let result = await task?.value
        
        cancellationTask?.cancel()
        task?.cancel()
        
        cancellationTask = nil
        task = nil
        
        return result
    }
    
    private func computeBestStep(_ stepInfo: GameManager.StepInfo) async -> UUID? {
        return await computeBestStep(stepInfo.fieldCopy, ownScores: stepInfo.ownScores, opponentScores: stepInfo.opponentScores)
    }

    private func computeBestStep(_ bubbleField: BubbleField, ownScores: Int, opponentScores: Int) async -> UUID? {
        let topLevel = Level.max
        
        let initialNodes: [Node] = bubbleField.connectedBubbleSets.indices.compactMap { setIndex in
            let newField = BubbleField(bubbleField)
            
            if let bubbleId = newField.connectedBubbleSets[setIndex].first {
                if let scores = newField.killBubbles(by: bubbleId)?.count {
                    
                    let ownScores = topLevel == .max ? ownScores + scores : ownScores
                    let opponentScores = topLevel == .min ? opponentScores + scores : opponentScores
                    
                    return Node(parent: nil,
                                bubbleField: newField,
                                setIndex: setIndex,
                                level: topLevel.next,
                                ownScores: ownScores,
                                opponentScores: opponentScores)
                }
            }
            
            return nil
        }
        
        print("Level size: \(initialNodes.count) nodes")
        
        var currentLevel = topLevel.next
        var currentNodes = initialNodes
        
        while !currentNodes.isEmpty && currentNodes.count < Self.maxChildNodeCount {
            guard !Task.isCancelled else {
                break
            }
            
            let prevNodes = currentNodes
            currentNodes = await withThrowingTaskGroup(of: [Node].self) { group in
                let prevLevel = currentLevel
                
                let prevNodeChunks = prevNodes.chunks(ProcessInfo.processInfo.processorCount)
                
                for prevNodeChunk in prevNodeChunks {
                    group.addTask {
                        var childNodes: [Node] = []
                        
                        for prevNode in prevNodeChunk {
                            for setIndex in prevNode.bubbleField.connectedBubbleSets.indices {
                                try Task.checkCancellation()
                                
                                let newField = BubbleField(prevNode.bubbleField)
                                
                                if let bubbleId = newField.connectedBubbleSets[setIndex].first {
                                    if let scores = newField.killBubbles(by: bubbleId) {
                                        
                                        let ownScores = prevLevel == .max ? prevNode.ownScores + scores.count : prevNode.ownScores
                                        let opponentScores = prevLevel == .min ? prevNode.opponentScores + scores.count : prevNode.opponentScores
                                        
                                        let node = Node(parent: prevNode,
                                                        bubbleField: newField,
                                                        setIndex: setIndex,
                                                        level: prevLevel.next,
                                                        ownScores: ownScores,
                                                        opponentScores: opponentScores)

                                        childNodes.append(node)
                                    }
                                }
                            }

                            try? await Task.sleep(nanoseconds: 20_000_000)
                        }
                        
                        return childNodes
                    }
                }
                
                do {
                    var nodes: [Node] = []
                    
                    for try await singleNodeChildren in group {
                        nodes.append(contentsOf: singleNodeChildren)
                    }
                    
                    return nodes
                } catch {
                    return []
                }
            }
            
            for node in currentNodes {
                node.parent?.updateWithChild(node.id, scores: Node.ChildScores(ownScores: node.ownScores, opponentScores: node.opponentScores))
                await Task.yield()
            }

            currentLevel = currentLevel.next
            
            if Task.isCancelled {
                break
            }
            
            await Task.yield()
            
            print(initialNodes.reduce(into: "", { partialResult, node in
                partialResult += "Node[h=\(node.heurisitcValue); own=\(node.ownScores); op=\(node.opponentScores); setSize=\(bubbleField.connectedBubbleSets[node.setIndex].count)];"
            }))
            print("Level size: \(currentNodes.count) nodes")
            print("_______________________________________________________________________________________")
        }
        
        if let setIndex = initialNodes.max(by: { $0.heurisitcValue < $1.heurisitcValue })?.setIndex {
            return bubbleField.connectedBubbleSets[setIndex].first
        }
        
        return nil
    }
    
    private class Node {
        let id: UUID = UUID()
        let parent: Node?
        let bubbleField: BubbleField
        let setIndex: Int
        let level: Level
        
        private(set) var ownScores: Int
        private(set) var opponentScores: Int
        
        private var childScores: Dictionary<UUID, ChildScores> = [:]
        
        var heurisitcValue: Int {
            getHeuristicValue(ownScores: ownScores, opponentScores: opponentScores)
        }
        
        init(parent: Node?, bubbleField: BubbleField, setIndex: Int, level: Level, ownScores: Int, opponentScores: Int) {
            self.parent = parent
            self.bubbleField = bubbleField
            self.setIndex = setIndex
            self.level = level
            self.ownScores = ownScores
            self.opponentScores = opponentScores
        }
        
        func updateWithChild(_ id: UUID, scores: ChildScores) {
            childScores[id] = scores
            
            let relevantScores: ChildScores
            
            switch level {
            case .min:
                relevantScores = childScores.values.min(by: {
                    let firstHeuristicValue = getHeuristicValue(ownScores: $0.ownScores, opponentScores: $0.opponentScores)
                    let secondHeuristicValue = getHeuristicValue(ownScores: $1.ownScores, opponentScores: $1.opponentScores)
                    
                    return firstHeuristicValue < secondHeuristicValue
                })!
            case .max:
                relevantScores = childScores.values.max(by: {
                    let firstHeuristicValue = getHeuristicValue(ownScores: $0.ownScores, opponentScores: $0.opponentScores)
                    let secondHeuristicValue = getHeuristicValue(ownScores: $1.ownScores, opponentScores: $1.opponentScores)
                    
                    return firstHeuristicValue < secondHeuristicValue
                })!
            }

            ownScores = relevantScores.ownScores
            opponentScores = relevantScores.opponentScores
            
            parent?.updateWithChild(self.id, scores: ChildScores(ownScores: ownScores, opponentScores: opponentScores))
        }
        
        private func getHeuristicValue(ownScores: Int, opponentScores: Int) -> Int {
            return ownScores - opponentScores
        }
        
        struct ChildScores {
            let ownScores: Int
            let opponentScores: Int
        }
    }
    
    private enum Level {
        case min
        case max
        
        var next: Level {
            switch self {
            case .min:
                return .max
            case .max:
                return .min
            }
        }
    }
}


private extension Array {
    
    func chunks(_ chunkCount: Int) -> [Array<Element>] {
        guard chunkCount > 0 else {
            fatalError()
        }
        
        var chunks: [[Element]] = []
        
        let chunkSize = count / chunkCount
        
        var extraElements = count % chunkCount
        var i = 0
        while i < count {
            let startIndex = i
            var endIndex = i + chunkSize
            
            if extraElements > 0 {
                endIndex += 1
                extraElements -= 1
                i += 1
            }
            
            chunks.append(Array(self[startIndex..<endIndex]))
            
            i += chunkSize
        }
        
        return chunks
    }
}
