import Foundation
let p = "lonely-room/ContentView.swift"
var c = try! String(contentsOfFile: p)

c = c.replacingOccurrences(of: "@State private var showScanner      = false", with: "@State private var showScanner      = false\n    @State private var showAIGenerator  = false")

c = c.replacingOccurrences(of: "                WardrobeCustomizerView(vm: vm) {\n                    withAnimation { showWardrobe = false }\n                }\n                .transition(.move(edge: .bottom).combined(with: .opacity))\n            }\n        }", with: "                WardrobeCustomizerView(vm: vm) {\n                    withAnimation { showWardrobe = false }\n                }\n                .transition(.move(edge: .bottom).combined(with: .opacity))\n            }\n            if showAIGenerator {\n                Color.black.opacity(0.3).ignoresSafeArea().onTapGesture { withAnimation { showAIGenerator = false } }\n                AIGeneratorView(vm: vm, onDismiss: { withAnimation { showAIGenerator = false } })\n            }\n        }")

try! c.write(toFile: p, atomically: true, encoding: .utf8)
