from pathlib import Path
import subprocess, tempfile
root=Path(__file__).resolve().parents[2]
out=Path(tempfile.mkdtemp(prefix='SentryCompletionRender-',dir='/private/tmp'))
s=(root/'Sources/Views/CalendarWorkbenchV5View.swift').read_text()
parts=[]
for start,end in [('private struct V5TaskCompletionFlightSession:', 'private struct V5PendingTaskCompletion:'),('private struct V5TaskCompletionFlightView:', 'private struct V5TaskLandingOutline:')]:
 parts.append(s[s.index(start):s.index(end)])
sidebar=(root/'Sources/Views/CalendarWorkbenchV5Sidebar.swift').read_text()
if 'private struct V5TaskCompletionSourceModifier:' in sidebar:
 parts.append(sidebar[sidebar.index('private struct V5TaskCompletionSourceModifier:'):sidebar.index('private struct V5TaskDragModifier:')])
main=r'''
@main struct RenderCheck {
 @MainActor static func main() {
  let session = V5TaskCompletionFlightSession(id: UUID(), taskID: UUID(), title: "Fixture", dateText: "9月8日", sourceFrame: CGRect(x:700,y:250,width:360,height:52), sourceRingPoint: CGPoint(x:722,y:276), targetPoint: CGPoint(x:180,y:140), targetDate: Date(), accent: .overdue, phase: .card)
  let renderer = ImageRenderer(content: V5TaskCompletionFlightView(session: session).frame(width:1060,height:660))
  guard let image=renderer.cgImage else { fatalError("render unavailable") }
  var bytes=[UInt8](repeating:0,count:1060*660*4)
  let context=CGContext(data:&bytes,width:1060,height:660,bitsPerComponent:8,bytesPerRow:1060*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
  context.draw(image,in:CGRect(x:0,y:0,width:1060,height:660))
  let visible=stride(from:3,to:bytes.count,by:4).filter {bytes[$0]>10}.count
  print("flight-layer-visible-pixels-at-card-phase=\(visible)")
  if visible>0 { print("FAIL: flight layer duplicates source card before ring handoff"); exit(1) }
  for phase in [V5TaskCompletionFlightPhase.orb, .arrived] {
   let source = ImageRenderer(content: RoundedRectangle(cornerRadius:11).fill(Color.blue).frame(width:360,height:52).modifier(V5TaskCompletionSourceModifier(phase:phase, reduceMotion:false)))
   guard let sourceImage=source.cgImage else {fatalError("source render unavailable")}
   var sourceBytes=[UInt8](repeating:0,count:360*52*4)
   let sourceContext=CGContext(data:&sourceBytes,width:360,height:52,bitsPerComponent:8,bytesPerRow:360*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
   sourceContext.draw(sourceImage,in:CGRect(x:0,y:0,width:360,height:52))
   let sourceVisible=stride(from:3,to:sourceBytes.count,by:4).filter {sourceBytes[$0]>10}.count
   precondition(sourceVisible == 0, "source card must remain hidden during flight and departure")
  }
  print("completion-render=passed")
 }
}
'''
(out/'main.swift').write_text('import SwiftUI\nimport AppKit\n'+'\n'.join(parts)+main)
subprocess.run(['swiftc','-parse-as-library','-sdk','/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk','-module-cache-path','/private/tmp/DesktopSentryManagedCache',*[str(root/'Sources/Models'/p) for p in ['V5WorkbenchPresentation.swift','CalendarWorkbenchV5Model.swift','TaskItem.swift','V5TaskReminderPlanner.swift']],str(out/'main.swift'),'-o',str(out/'check')],check=True)
raise SystemExit(subprocess.run([str(out/'check')]).returncode)
