import CoreGraphics
import Foundation

@main
struct V5NativeDropSmoke {
    static func main() {
        let taskID = UUID(uuidString: "00000000-0000-0000-0000-000000000042")!
        let encoded = V5TaskDropPayload.encode(taskID)
        precondition(V5TaskDropPayload.decode(encoded) == taskID,
                     "a native drag must carry exactly one existing task identity")
        precondition(V5TaskDropPayload.decode(taskID.uuidString) == nil,
                     "plain UUID text from another app must not be accepted as a task drag")

        let release = CGPoint(x: 63, y: 22)
        let seed = V5DropEchoGeometry.value(for: .seed,
                                           releasePoint: release,
                                           isToday: false)
        precondition(seed.center == release && seed.size == CGSize(width: 14, height: 14),
                     "the echo must begin at the actual local release point")

        let outline = V5DropEchoGeometry.value(for: .outline,
                                              releasePoint: release,
                                              isToday: false)
        precondition(outline.center == CGPoint(x: 41, y: 39))
        precondition(outline.size == CGSize(width: 82, height: 78))
        precondition(outline.cornerRadius == 16,
                     "a normal target must expand into its rounded selection outline")

        let todayOutline = V5DropEchoGeometry.value(for: .outline,
                                                   releasePoint: release,
                                                   isToday: true)
        precondition(todayOutline.size == CGSize(width: 78, height: 78))
        precondition(todayOutline.cornerRadius == 39,
                     "today must preserve its circular selection language")

        let marker = V5DropEchoGeometry.value(for: .marker,
                                             releasePoint: release,
                                             isToday: false)
        precondition(marker.center == CGPoint(x: 41, y: 71.5))
        precondition(marker.size == CGSize(width: 7, height: 7),
                     "the echo must finish in the date cell's real indicator slot")

        print("v5-native-drop=passed")
    }
}
