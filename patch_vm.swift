import Foundation
let p = "lonely-room/ViewModels/KostViewModel.swift"
var c = try! String(contentsOfFile: p)

c = c.replacingOccurrences(of: "case .custom3D:", with: "case .custom3D, .aiGenerated:")
c = c.replacingOccurrences(of: "if type == .custom3D, let path = pendingCustom3DPath {", with: "if (type == .custom3D || type == .aiGenerated), let path = pendingCustom3DPath {")
c = c.replacingOccurrences(of: "if type == .custom3D, let path = data.custom3DPath {", with: "if (type == .custom3D || type == .aiGenerated), let path = data.custom3DPath {")

try! c.write(toFile: p, atomically: true, encoding: .utf8)
