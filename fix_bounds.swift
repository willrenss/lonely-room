import Foundation
let p = "lonely-room/ViewModels/KostViewModel.swift"
var c = try! String(contentsOfFile: p)
c = c.replacingOccurrences(of: "SCNVector3(repeating: Float.greatestFiniteMagnitude)", with: "SCNVector3(Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude)")
c = c.replacingOccurrences(of: "SCNVector3(repeating: -Float.greatestFiniteMagnitude)", with: "SCNVector3(-Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude)")
try! c.write(toFile: p, atomically: true, encoding: .utf8)
