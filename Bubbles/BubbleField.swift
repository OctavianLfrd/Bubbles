//
//  BubbleField.swift
//  Bubbles
//
//  Created by Alfred Lapkovsky on 21/04/2022.
//

import Foundation


class BubbleField {
    
    let dimensions: Dimensions
    let colorCount: ColorCount
    
    private(set) var bubbleRows: [BubbleRow] = []
    private(set) var connectedBubbleSets: [Set<UUID>] = []
    private var isSetup: Bool = false
    
    var isEmpty: Bool {
        bubbleRows.isEmpty
    }
    
    init(_ dimensions: Dimensions, colorCount: ColorCount) {
        self.dimensions = dimensions
        self.colorCount = colorCount
    }
    
    convenience init(_ bubbleField: BubbleField) {
        self.init(bubbleField.dimensions, colorCount: bubbleField.colorCount)
        self.bubbleRows = bubbleField.bubbleRows
        self.connectedBubbleSets = bubbleField.connectedBubbleSets
        self.isSetup = bubbleField.isSetup
    }
    
    func setup() {
        guard !isSetup else {
            return
        }
        
        isSetup = true
        
        generateBubbles()
        generateConnectedBubbleSets()
    }
    
    @discardableResult
    func killBubbles(by bubbleId: UUID) -> Set<UUID>? {
        guard let setIndex = connectedBubbleSets.firstIndex(where: { $0.contains(bubbleId) }) else {
            return nil
        }
        
        let set = connectedBubbleSets.remove(at: setIndex)
        
        removeBubblesAndNormalizeRows(removedIds: set)
        generateConnectedBubbleSets()
        
        return set
    }
    
    private func generateBubbles() {
        for row in 0..<dimensions.vertical {
            let odd = (row & 1) == 1
            let bubbleCount = odd ? dimensions.horizontal - 1 : dimensions.horizontal
            
            var bubbles: [Bubble] = []
            
            for _ in 0..<bubbleCount {
                let colorType = Int.random(in: Bubble.ColorType.color1.rawValue...min(Bubble.ColorType.color6.rawValue, colorCount.rawValue))
                
                bubbles.append(Bubble(colorType: .init(rawValue: colorType)!))
            }
            
            bubbleRows.append(BubbleRow(bubbles: bubbles))
        }
    }
    
    private func generateConnectedBubbleSets() {
        var sets: [Set<UUID>] = []
        
        for r in bubbleRows.indices {
            for b in bubbleRows[r].bubbles.indices {
                
                let current = bubbleRows[r].bubbles[b]
                
                if current.colorType == .invisible {
                    continue
                }
                
                var nearestBubbles = [
                    bubbleRows[r].bubbles[safe: b - 1],
                    bubbleRows[r].bubbles[safe: b + 1],
                    bubbleRows[safe: r - 1]?.bubbles[safe: b],
                    bubbleRows[safe: r + 1]?.bubbles[safe: b]
                ]
                
                let odd = (r & 1) == 1
                
                if odd {
                    nearestBubbles.append(bubbleRows[safe: r - 1]?.bubbles[safe: b + 1])
                    nearestBubbles.append(bubbleRows[safe: r + 1]?.bubbles[safe: b + 1])
                } else {
                    nearestBubbles.append(bubbleRows[safe: r - 1]?.bubbles[safe: b - 1])
                    nearestBubbles.append(bubbleRows[safe: r + 1]?.bubbles[safe: b - 1])
                }
                
                let matchedBubbleIds: [UUID] = nearestBubbles.compactMap { bubble in
                    if let bubble = bubble, bubble.colorType == current.colorType {
                        return bubble.id
                    }
                    
                    return nil
                }
                
                var set = Set(matchedBubbleIds)
                set.insert(current.id)
                
                sets.append(set)
            }
        }
        
        var mergedSets: [Set<UUID>] = []
        
        var accumulatedSet = !sets.isEmpty ? sets.removeFirst() : nil
        mainLoop: while accumulatedSet != nil {
            
            for i in sets.indices.reversed() {
                if !sets[i].intersection(accumulatedSet!).isEmpty {
                    accumulatedSet!.formUnion(sets[i])
                    sets.remove(at: i)
                    continue mainLoop
                }
            }
            
            if !accumulatedSet!.isEmpty {
                mergedSets.append(accumulatedSet!)
            }
            
            accumulatedSet = !sets.isEmpty ? sets.removeFirst() : nil
        }
        
        connectedBubbleSets = mergedSets
    }
    
    private func removeBubblesAndNormalizeRows(removedIds: Set<UUID>) {
        let bubbleVector = bubbleRows.reduce(into: []) { partialResult, bubbles in
            partialResult.append(contentsOf: bubbles.bubbles.filter { !removedIds.contains($0.id) && $0.colorType != .invisible })
        }
        
        var newBubbleRows = [BubbleRow]()
        
        let rowPairSize = 2 * dimensions.horizontal - 1
        let fullRowPairCount = bubbleVector.count / rowPairSize
        let remainingBubbles = bubbleVector.count % rowPairSize
        let extraRows = remainingBubbles == 0 ? 0 : (remainingBubbles > dimensions.horizontal ? 2 : 1)
        
        let rowCount = fullRowPairCount * 2 + extraRows
        
        var startIndex = 0
        for r in 0..<rowCount {
            let odd = (r & 1) == 1
            let bubbleCount = odd ? dimensions.horizontal - 1 : dimensions.horizontal
            
            let endIndex = min(startIndex + bubbleCount, bubbleVector.endIndex)
            
            var bubbles = Array(bubbleVector[startIndex..<endIndex])
            
            if (startIndex + bubbleCount) > bubbleVector.endIndex {
                bubbles.append(contentsOf: (0..<((startIndex + bubbleCount) - bubbleVector.endIndex)).map { _ in Bubble(colorType: .invisible) })
            }
            
            newBubbleRows.append(BubbleRow(bubbles: bubbles))
            
            startIndex += bubbleCount
        }
        
        bubbleRows = newBubbleRows
    }
    
    enum ColorCount : Int {
        case four = 4
        case five = 5
        case six = 6
    }
    
    struct Dimensions {
        let vertical: Int
        let horizontal: Int
        
        init(vertical: Int, horizontal: Int) {
            precondition(vertical > 0 && horizontal > 0)
            
            self.vertical = vertical
            self.horizontal = horizontal
        }
        
        static let presetExtraTiny = Dimensions(vertical: 6, horizontal: 4)
        static let presetTiny = Dimensions(vertical: 5, horizontal: 5)
        static let presetSmall = Dimensions(vertical: 8, horizontal: 7)
        static let presetMedium = Dimensions(vertical: 9, horizontal: 7)
        static let presetLarge = Dimensions(vertical: 10, horizontal: 8)
    }
}

private extension Array {
    
    subscript(safe index: Int) -> Element? {
        index >= 0 && index < count ? self[index] : nil
    }
}
