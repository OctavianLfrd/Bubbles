//
//  BubbleRow.swift
//  Bubbles
//
//  Created by Alfred Lapkovsky on 21/04/2022.
//

import Foundation


struct BubbleRow : Hashable, Equatable, Identifiable {
    let id = UUID()
    let bubbles: [Bubble]
}
