//
//  AMANPositionRole.swift
//  
//
//  Created by Axel Péju on 09/02/2022.
//

import Foundation

enum AMANPositionRole: String, Codable {
    case seq
    case coorini
    case coorinin
    case coorinis
    case ini
    case inin
    case inis
    case itm
    case itmn
    case itms
    case itmba
    case coordep
    case coordeps
    case coordepn
    case dep
    case deps
    case depn
    
    var name: String {
        switch self {
        case .seq:
            return "SEQ"
        case .coorini:
            return "COOR_INI"
        case .coorinin:
            return "COOR_INI_N"
        case .coorinis:
            return "COOR_INI_S"
        case .ini:
            return "INI"
        case .inin:
            return "INI_N"
        case .inis:
            return "INI_S"
        case .itm:
            return "ITM"
        case .itmn:
            return "ITM_N"
        case .itms:
            return "ITM_S"
        case .itmba:
            return "ITM_BA"
        case .dep:
            return "DEP"
        case .deps:
            return "DEP_S"
        case .depn:
            return "DEP_N"
        case .coordep:
            return "COOR_DEP"
        case .coordepn:
            return "COOR_DEP_N"
        case .coordeps:
            return "COOR_DEP_S"
        }
    }
}
