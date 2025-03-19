//
//  LogManager.swift
//  Petrel
//
//  Created by Josh LaCalamito on 4/21/24.
//

import Foundation
import os.log

class LogManager {
  private static let logger = os.Logger(
    subsystem: "com.joshlacalamito.Petrel", category: "Network"
  )

  static func logInfo(_ message: String) {
    logger.info("\(message, privacy: .public)")
  }

  static func logDebug(_ message: String) {
    #if DEBUG
      logger.debug("\(message, privacy: .public)")
    #endif
  }

  static func logError(_ message: String) {
    logger.error("\(message, privacy: .public)")
  }

  static func logRequest(_ request: URLRequest) {
    #if DEBUG
      var debugMessage = "Request URL: \(request.url?.absoluteString ?? "N/A")\n"
      debugMessage += "Method: \(request.httpMethod ?? "N/A")\n"
      debugMessage += "Headers: \(request.allHTTPHeaderFields ?? [:])"

      if let bodyData = request.httpBody, let bodyString = String(data: bodyData, encoding: .utf8) {
        debugMessage += "\nBody: \(bodyString)"
      }

      logDebug(debugMessage)
    #endif
  }

  static func logResponse(_ response: HTTPURLResponse, data: Data) {
    #if DEBUG
      var debugMessage = "Response URL: \(response.url?.absoluteString ?? "N/A")\n"
      debugMessage += "Status Code: \(response.statusCode)\n"
      debugMessage += "Headers: \(response.allHeaderFields)"

      if let responseString = String(data: data, encoding: .utf8) {
        debugMessage += "\nBody: \(responseString)"
      }

      logDebug(debugMessage)
    #endif
  }

  static func logError(_ error: Error) {
    logError("Error: \(error.localizedDescription)")
  }
}
