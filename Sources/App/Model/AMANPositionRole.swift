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
    
    /// Corresponding AMAN name used to link a TX to an AMAN branch
    ///
    /// The name can be arbitrary, but only some positions are allowed
    /// to make some changes:
    /// - SEQ, C_INI_IFR, C_INI_N_IFR, C_INI_S_IFR are able to change the
    /// runway configuration
    /// - arrival positions are able to change the allocated runway of flights
    var name: String {
        switch self {
        case .seq:
            return "SEQ"
        case .coorini:
            return "C_INI_IFR"
        case .coorinin:
            return "C_INI_N_IFR"
        case .coorinis:
            return "C_INI_S_IFR"
        case .ini:
            return "INI_IFR"
        case .inin:
            return "INI_N_IFR"
        case .inis:
            return "INI_S_IFR"
        case .itm:
            return "ITM_IFR"
        case .itmn:
            return "ITM_N_IFR"
        case .itms:
            return "ITM_S_IFR"
        case .itmba:
            return "ITM_BA_IFR"
        case .dep:
            return "DEP_IFR"
        case .deps:
            return "DEP_S_IFR"
        case .depn:
            return "DEP_N_IFR"
        case .coordep:
            return "C_DEP_IFR"
        case .coordepn:
            return "C_DEP_N_IFR"
        case .coordeps:
            return "C_DEP_S_IFR"
        }
    }
}
