import Foundation

/// 使用 FNV-1a (64-bit) 生成跨平台、跨设备稳定的字符串标识。
///
/// 不使用 CryptoKit 等 Apple 专属框架，保证 Windows / Linux 上结果一致。
public enum StableIdentifier {

    public static func make(_ parts: [String]) -> String {
        make(parts.joined(separator: "|"))
    }

    public static func make(_ string: String) -> String {
        // FNV-1a 64-bit
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        let prime: UInt64 = 0x0000_0100_0000_01b3
        for byte in Array(string.utf8) {
            hash ^= UInt64(byte)
            hash = hash &* prime
        }
        return String(format: "%016llx", hash)
    }
}
