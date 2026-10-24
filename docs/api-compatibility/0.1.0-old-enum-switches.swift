// Expected failure: these switches cover every case present in Petrel 0.1.0.
// Baseline tag 0.1.0 resolves to 02de350792158ffc9f2ad9902ac61f101ea84bca.
// This file probes actual exhaustiveness failures in the current built module.
import Petrel

func oldCARReaderSwitch(_ error: Petrel.CARReaderError) -> Int {
    switch error {
    case .invalidHeader, .invalidVarint, .unexpectedEOF,
         .invalidCID, .blockNotFound, .decodingFailed: return 0
    }
}

func oldDAGCBORSwitch(_ error: Petrel.DAGCBORError) -> Int {
    switch error {
    case .encodingFailed, .decodingFailed, .unsupportedType,
         .invalidCIDEncoding, .invalidMapKey, .floatingPointNotAllowed: return 0
    }
}

func oldNetworkErrorSwitch(_ error: Petrel.NetworkError) -> Int {
    switch error {
    case .invalidURL, .requestFailed, .responseError, .noData,
         .decodingError, .unknownError, .expiredToken, .authenticationRequired,
         .retryRequest, .invalidRequest, .oauthManagerNotSet,
         .maxRetryAttemptsReached, .invalidContentType, .authenticationFailed,
         .badRequest, .serverError, .invalidResponse, .unauthorized,
         .securityViolation: return 0
    }
}

func oldAuthErrorSwitch(_ error: Petrel.AuthError) -> Int {
    switch error {
    case .noActiveAccount, .invalidCredentials, .invalidHandle, .handleNotFound,
         .serverUnavailable, .invalidOAuthConfiguration, .tokenRefreshFailed,
         .authorizationFailed, .invalidCallbackURL, .dpopKeyError, .networkError,
         .invalidResponse, .cancelled, .timeout, .rateLimited, .serverError,
         .serviceMaintenance: return 0
    }
}

func oldAuthEventSwitch(_ event: Petrel.AuthEvent) -> Int {
    switch event {
    case .startupInconsistentState, .startupMissingSession, .startupMissingDPoPKey,
         .startupStateHealthy, .accountAutoSwitched, .currentAccountChanged,
         .sessionMissing, .refreshTokenInvalid, .invalidClientMetadata,
         .invalidClient, .dpopNonceMismatch, .logoutStarted, .logoutAutoSwitched,
         .logoutNoAutoSwitch, .logoutClearedCurrentAccount, .autoLogoutTriggered,
         .accountNotFound, .setCurrentAccountNoSession, .storageFailure,
         .inconsistentStateMissingSession, .inconsistentStateMissingAccount: return 0
    }
}
