import RealityKit
import Foundation
@available(iOS 17.0, *)
func test() {
    let session = ObjectCaptureSession()
    let url = URL(fileURLWithPath: "/tmp")
    var config = ObjectCaptureSession.Configuration()
    session.start(imagesDirectory: url, configuration: config)
    
    let pSession = try! PhotogrammetrySession(input: url)
    try! pSession.process(requests: [
        PhotogrammetrySession.Request.modelFile(url: url, detail: .reduced)
    ])
}
