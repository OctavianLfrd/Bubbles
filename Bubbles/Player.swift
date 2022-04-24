//
//  Player.swift
//  Bubbles
//
//  Created by Alfred Lapkovsky on 21/04/2022.
//

import Foundation


protocol Player {
    
    func makeStep(_ stepInfo: GameManager.StepInfo) async -> UUID?
}
