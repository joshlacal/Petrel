//
//  OAuthCallbackBuffer.swift
//  Petrel
//
//  Caches incoming OAuth callback URLs that may arrive before the client
//  or authentication service is fully initialized. Stored in UserDefaults
//  so it survives brief process bounces during the browser round-trip.
//

import Foundation

enum OAuthCallbackBuffer {
  private static let key = "petrel.pending.oauth.callback.url"

  /// Save a pending OAuth callback URL for later processing.
  static func save(_ url: URL) {
    UserDefaults.standard.set(url.absoluteString, forKey: key)
  }

  /// Take and clear the pending OAuth callback URL, if any.
  static func take() -> URL? {
    guard let s = UserDefaults.standard.string(forKey: key), let url = URL(string: s) else {
      return nil
    }
    UserDefaults.standard.removeObject(forKey: key)
    return url
  }
}
