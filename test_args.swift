import Foundation

let path = "lonely-room/ContentView.swift"
var c = try! String(contentsOfFile: path)
if c.contains("FurnitureCatalogView(vm: vm, onDismiss: {") {
    print("Found exact initialiser")
}
