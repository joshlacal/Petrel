# Structured Error Handling in Petrel

This document describes how structured error handling works in Petrel and how to use it in your code.

## Overview

Petrel now properly supports structured errors as defined in ATProto Lexicons. When an API endpoint returns an error (4xx/5xx status code), Petrel will:

1. Parse the error response to extract the error code and message
2. Match it to the lexicon-defined error type
3. Throw a strongly-typed `ATProtoError` containing both the error type and message
4. Fall back to returning the status code if error parsing fails (backward compatibility)

## How It Works

### Error Response Format

ATProto endpoints return errors as JSON:

```json
{
  "error": "NotFound",
  "message": "Record not found"
}
```

### Generated Error Types

For each endpoint with defined errors in its lexicon, Petrel generates an `Error` enum that conforms to `ATProtoErrorType`:

```swift
public enum Error: String, Swift.Error, ATProtoErrorType, CustomStringConvertible {
    case notFound = "NotFound."

    public var description: String {
        return self.rawValue
    }
}
```

### Error Wrapper

Errors are wrapped in `ATProtoError<ErrorType>` which provides:

- `error`: The strongly-typed error enum case
- `message`: The human-readable error message from the server
- `statusCode`: The HTTP status code

## Usage Examples

### Basic Error Handling

```swift
do {
    let (statusCode, thread) = try await client.app.bsky.feed.getPostThread(
        input: AppBskyFeedGetPostThread.Parameters(uri: postURI)
    )

    // Success case - process the thread
    if let thread = thread {
        // Handle successful response
    }
} catch let error as ATProtoError<AppBskyFeedGetPostThread.Error> {
    // Handle structured error
    switch error.error {
    case .notFound:
        print("Post not found: \(error.message ?? "")")
    }
} catch {
    // Handle other errors (network errors, etc.)
    print("Request failed: \(error)")
}
```

### Extracting Error Information

```swift
catch let error as ATProtoError<AppBskyFeedGetPostThread.Error> {
    print("Error code: \(error.error.errorName)")
    print("HTTP status: \(error.statusCode)")
    print("Message: \(error.message ?? "No message")")
    print("Description: \(error.errorDescription ?? "")")
}
```

### Handling Multiple Error Types

For endpoints with multiple possible errors:

```swift
catch let error as ATProtoError<SomeEndpoint.Error> {
    switch error.error {
    case .notFound:
        // Handle not found
        showNotFoundUI()
    case .unauthorized:
        // Handle unauthorized
        promptLogin()
    case .rateLimitExceeded:
        // Handle rate limit
        showRateLimitMessage()
    }
}
```

## Backward Compatibility

The error handling maintains backward compatibility:

1. **Success responses** still return `(responseCode: Int, data: OutputType?)`
2. **Endpoints without defined errors** continue to return status codes without throwing
3. **Unparseable errors** fall back to returning `(statusCode, nil)` instead of throwing
4. **Existing error handling code** continues to work without modification

## Implementation Details

### Key Components

1. **`ATProtoErrorResponse`**: Codable struct for parsing error responses
2. **`ATProtoErrorType` protocol**: Marks error enums and provides error name extraction
3. **`ATProtoError<ErrorType>`**: Generic wrapper combining error type, message, and status code
4. **`ATProtoErrorParser`**: Helper for parsing and matching error responses

### Generated Code

For each query/procedure with errors, the generator:

1. Creates an `Error` enum conforming to `ATProtoErrorType`
2. Adds error parsing logic in the error response path
3. Throws `ATProtoError` when a structured error is detected
4. Falls back to returning status code if parsing fails

### Template Changes

- `errorsEnum.jinja`: Added `ATProtoErrorType` conformance
- `query.jinja`: Added error parsing in error response path
- `procedure.jinja`: Added error parsing in error response path

## Adding New Lexicons

When adding new lexicons with errors:

1. Define errors in the lexicon JSON:
   ```json
   {
     "errors": [
       {
         "name": "NotFound",
         "description": "Resource was not found"
       }
     ]
   }
   ```

2. Regenerate code:
   ```bash
   python run.py Generator/lexicons Sources/Petrel/Generated
   ```

3. The error handling will be automatically generated

## Testing

To test error handling:

```swift
// Trigger a not-found error
do {
    let result = try await client.app.bsky.feed.getPostThread(
        input: .init(uri: "at://invalid/post")
    )
} catch let error as ATProtoError<AppBskyFeedGetPostThread.Error> {
    XCTAssertEqual(error.error, .notFound)
    XCTAssertEqual(error.statusCode, 404)
    XCTAssertNotNil(error.message)
}
```

## Future Enhancements

Potential improvements:

1. Add retry logic for specific error types
2. Add error metrics/logging
3. Add error recovery suggestions
4. Support for custom error handlers per endpoint
