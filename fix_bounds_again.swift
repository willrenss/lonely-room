import Foundation
import SceneKit

let p = "lonely-room/ViewModels/KostViewModel.swift"
var c = try! String(contentsOfFile: p)

let oldCode = """
        // Deteksi Bounding Box berdasar Geometri Saja (Abaikan elemen tak terlihat/cahaya Tripo yang bikin boundingbox raksasa)
        var minVec: SCNVector3 = SCNVector3(Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude)
        var maxVec: SCNVector3 = SCNVector3(-Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude)
        
        importedNode.enumerateChildNodes { child, _ in
            if child.geometry != nil {
                let (cMin, cMax) = child.boundingBox
                let worldMin = child.convertPosition(cMin, to: importedNode)
                let worldMax = child.convertPosition(cMax, to: importedNode)
                
                minVec.x = min(minVec.x, min(worldMin.x, worldMax.x))
                minVec.y = min(minVec.y, min(worldMin.y, worldMax.y))
                minVec.z = min(minVec.z, min(worldMin.z, worldMax.z))
                maxVec.x = max(maxVec.x, max(worldMin.x, worldMax.x))
                maxVec.y = max(maxVec.y, max(worldMin.y, worldMax.y))
                maxVec.z = max(maxVec.z, max(worldMin.z, worldMax.z))
            }
        }
"""

let newCode = """
        var minVec = SCNVector3(Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude)
        var maxVec = SCNVector3(-Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude)
        
        var nodesToCheck = [importedNode]
        importedNode.enumerateChildNodes { child, _ in nodesToCheck.append(child) }
        
        for n in nodesToCheck {
            if n.geometry != nil {
                let (cMin, cMax) = n.boundingBox
                let corners = [
                    SCNVector3(cMin.x, cMin.y, cMin.z), SCNVector3(cMin.x, cMin.y, cMax.z),
                    SCNVector3(cMin.x, cMax.y, cMin.z), SCNVector3(cMin.x, cMax.y, cMax.z),
                    SCNVector3(cMax.x, cMin.y, cMin.z), SCNVector3(cMax.x, cMin.y, cMax.z),
                    SCNVector3(cMax.x, cMax.y, cMin.z), SCNVector3(cMax.x, cMax.y, cMax.z)
                ]
                for corner in corners {
                    let worldP = n.convertPosition(corner, to: importedNode)
                    minVec.x = min(minVec.x, worldP.x)
                    minVec.y = min(minVec.y, worldP.y)
                    minVec.z = min(minVec.z, worldP.z)
                    maxVec.x = max(maxVec.x, worldP.x)
                    maxVec.y = max(maxVec.y, worldP.y)
                    maxVec.z = max(maxVec.z, worldP.z)
                }
            }
        }
"""

if c.contains("var nodesToCheck = [importedNode]") {
    print("Already updated")
} else if c.contains("var minVec: SCNVector3 = SCNVector3(Float.greatestFiniteMagnitude") {
    c = c.replacingOccurrences(of: oldCode, with: newCode)
    try! c.write(toFile: p, atomically: true, encoding: .utf8)
    print("Updated successfully")
} else {
    print("Could not find the block to replace")
}
