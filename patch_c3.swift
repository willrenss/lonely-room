import Foundation
let p = "lonely-room/ContentView.swift"
var c = try! String(contentsOfFile: p)

c = c.replacingOccurrences(of: "                        showScanner = true\n                    })", with: "                        showScanner = true\n                    }, onOpenAIGenerator: {\n                        showCatalog = false\n                        showAIGenerator = true\n                    })")
try! c.write(toFile: p, atomically: true, encoding: .utf8)
