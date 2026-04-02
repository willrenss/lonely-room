import Foundation
let p = "lonely-room/Views/FurnitureCatalogView.swift"
var c = try! String(contentsOfFile: p)

c = c.replacingOccurrences(of: "                            } else if ft == .custom3D {", with: "                            } else if ft == .custom3D {\n                                onOpenScanner?()\n                            } else if ft == .aiGenerated {\n                                onOpenAIGenerator?()")
c = c.replacingOccurrences(of: "                            } else if ft == .custom3D {\n                                onOpenScanner?()\n                            } else if ft == .aiGenerated {\n                                onOpenAIGenerator?()\n                                onOpenScanner?()\n", with: "                            } else if ft == .custom3D {\n                                onOpenScanner?()\n                            } else if ft == .aiGenerated {\n                                onOpenAIGenerator?()\n")
c = c.replacingOccurrences(of: "    var onOpenScanner: (() -> Void)? = nil", with: "    var onOpenScanner: (() -> Void)? = nil\n    var onOpenAIGenerator: (() -> Void)? = nil")
try! c.write(toFile: p, atomically: true, encoding: .utf8)
