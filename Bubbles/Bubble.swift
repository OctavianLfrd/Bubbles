//
//  Bubble.swift
//  Bubbles
//
//  Created by Alfred Lapkovsky on 21/04/2022.
//

import Foundation


struct Bubble : Hashable, Equatable, Identifiable {
    let id = UUID()
    let colorType: ColorType
    
    enum ColorType : Int {
        case invisible = 0
        case color1 = 1
        case color2 = 2
        case color3 = 3
        case color4 = 4
        case color5 = 5
        case color6 = 6
    }
}
