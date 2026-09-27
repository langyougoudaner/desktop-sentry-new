import CoreGraphics
import Foundation

enum V5TaskDropPayload {
    private static let prefix = "desktopsentry-task:"

    static func encode(_ taskID: UUID) -> String {
        prefix + taskID.uuidString.lowercased()
    }

    static func decode(_ value: String) -> UUID? {
        guard value.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(value.dropFirst(prefix.count)))
    }
}

enum V5DropEchoPhase: Equatable {
    case seed
    case outline
    case marker
}

struct V5DropEchoValue: Equatable {
    let center: CGPoint
    let size: CGSize
    let cornerRadius: CGFloat
}

enum V5DropEchoGeometry {
    static func value(for phase: V5DropEchoPhase,
                      releasePoint: CGPoint,
                      isToday: Bool) -> V5DropEchoValue {
        switch phase {
        case .seed:
            return V5DropEchoValue(center: releasePoint,
                                   size: CGSize(width: 14, height: 14),
                                   cornerRadius: 7)
        case .outline:
            let size = CGSize(width: isToday ? 78 : 82, height: 78)
            return V5DropEchoValue(center: CGPoint(x: 41, y: 39),
                                   size: size,
                                   cornerRadius: isToday ? 39 : 16)
        case .marker:
            return V5DropEchoValue(center: CGPoint(x: 41, y: 71.5),
                                   size: CGSize(width: 7, height: 7),
                                   cornerRadius: 3.5)
        }
    }
}
