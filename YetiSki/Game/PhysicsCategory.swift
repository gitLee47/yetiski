import Foundation

/// Bitmasks used for SpriteKit physics contact testing.
enum PhysicsCategory {
    static let none: UInt32 = 0
    static let skier: UInt32 = 0x1 << 0
    static let obstacle: UInt32 = 0x1 << 1
    static let yeti: UInt32 = 0x1 << 2
    static let boundary: UInt32 = 0x1 << 3
    static let ramp: UInt32 = 0x1 << 4
    static let pickup: UInt32 = 0x1 << 5
    static let bullet: UInt32 = 0x1 << 6
}
