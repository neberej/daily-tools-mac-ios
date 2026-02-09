//
//  RequestMethod.swift
//  APIClient
//

import Foundation

enum RequestMethod: String, CaseIterable, Codable {
    case GET
    case POST
    case PUT
    case PATCH
    case DELETE
    case HEAD
    case OPTIONS
}
