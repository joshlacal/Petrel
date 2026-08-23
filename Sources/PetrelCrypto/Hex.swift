import Foundation

public enum Hex {
    public static func encode(_ data: some Sequence<UInt8>) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    public static func decode(_ string: String) -> Data? {
        guard string.utf8.count % 2 == 0 else { return nil }
        var bytes = Data()
        bytes.reserveCapacity(string.utf8.count / 2)
        var index = string.utf8.startIndex
        while index < string.utf8.endIndex {
            let nextIndex = string.utf8.index(after: index)
            guard let high = nibble(string.utf8[index]),
                  let low = nibble(string.utf8[nextIndex]) else {
                return nil
            }
            bytes.append((high << 4) | low)
            index = string.utf8.index(after: nextIndex)
        }
        return bytes
    }

    private static func nibble(_ byte: UInt8) -> UInt8? {
        switch byte {
        case 48 ... 57: return byte - 48
        case 97 ... 102: return byte - 97 + 10
        case 65 ... 70: return byte - 65 + 10
        default: return nil
        }
    }
}
