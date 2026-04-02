import Foundation

let path = "lonely-room/ContentView.swift"
var c = try! String(contentsOfFile: path)

c = c.replacingOccurrences(of: "FurnitureCatalogView(vm: vm, onDismiss: {\n                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {\n                            showCatalog = false\n                            vm.pendingType = nil\n                            vm.selectFurniture(nil)\n                        }\n                    }, onOpenScanner: {\n                        showCatalog = false\n                        showScanner = true\n                    })", with: "FurnitureCatalogView(vm: vm, onDismiss: {\n                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {\n                            showCatalog = false\n                            vm.pendingType = nil\n                            vm.selectFurniture(nil)\n                        }\n                    }, onOpenScanner: {\n                        showCatalog = false\n                        showScanner = true\n                    })")

try! c.write(toFile: path, atomically: true, encoding: .utf8)
