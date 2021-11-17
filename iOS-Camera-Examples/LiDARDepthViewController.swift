import UIKit
import AVFoundation

class LiDARDepthViewController: UIViewController {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var dispalitySwitch: UISwitch!
    
    private let captureSession = AVCaptureSession()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let depthDataOutput = AVCaptureDepthDataOutput()
    private var videoDevice: AVCaptureDevice!
    private var videoConnection: AVCaptureConnection!
    private var depthConnection: AVCaptureConnection!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        captureSession.beginConfiguration()
        captureSession.sessionPreset = AVCaptureSession.Preset.photo
        
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInDualCamera], mediaType: AVMediaType.video, position: .back)
        videoDevice = deviceDiscoverySession.devices.first
        
        // discovery available to contain depth format
        let availableFormats = videoDevice.formats.filter { format in
            return format.supportedDepthDataFormats.filter{ depthFormat in
                return CMFormatDescriptionGetMediaSubType(depthFormat.formatDescription) == kCVPixelFormatType_DepthFloat32
            }.count > 0
        }
        
        // select max size video format
        guard let selectedFormat = availableFormats.max(by: {
            CMVideoFormatDescriptionGetDimensions($0.formatDescription).width
                < CMVideoFormatDescriptionGetDimensions($1.formatDescription).width
        }) else {
            fatalError()
        }

        // discovery 32bit float depth format
        let depth32Formats = selectedFormat.supportedDepthDataFormats.filter {
            CMFormatDescriptionGetMediaSubType($0.formatDescription) == kCVPixelFormatType_DepthFloat32
        }
        guard !depth32Formats.isEmpty else { fatalError() }
        
        // select max size depth format
        let selectedDepthFormat = depth32Formats.max(by: {
            CMVideoFormatDescriptionGetDimensions($0.formatDescription).width
                < CMVideoFormatDescriptionGetDimensions($1.formatDescription).width
        })!
        
        // device configuration
        try! videoDevice.lockForConfiguration()
        videoDevice.activeFormat = selectedFormat
        videoDevice.activeDepthDataFormat = selectedDepthFormat
        videoDevice.unlockForConfiguration()

        print("selected format: \(selectedFormat), depth format: \(selectedDepthFormat)")
        
        // video input
        let videoDeviceInput = try! AVCaptureDeviceInput(device: videoDevice)
        guard captureSession.canAddInput(videoDeviceInput) else { fatalError() }
        captureSession.addInput(videoDeviceInput)

        // depth output
        guard captureSession.canAddOutput(depthDataOutput) else { fatalError() }
        captureSession.addOutput(depthDataOutput)
        depthDataOutput.setDelegate(self, callbackQueue: DispatchQueue(label: "depth queue"))
        depthDataOutput.isFilteringEnabled = false
        guard let connection = depthDataOutput.connection(with: .depthData) else { fatalError() }
        depthConnection = connection
        depthConnection.isEnabled = true

        // session configuration
        captureSession.commitConfiguration()
        
        // session start
        captureSession.startRunning()
    }
}

extension LiDARDepthViewController: AVCaptureDepthDataOutputDelegate {
    func depthDataOutput(_ output: AVCaptureDepthDataOutput, didOutput depthData: AVDepthData, timestamp: CMTime, connection: AVCaptureConnection) {

        DispatchQueue.main.async {
            let pixelBuffer = self.dispalitySwitch.isOn ?
                depthData.converting(toDepthDataType: kCVPixelFormatType_DisparityFloat32).depthDataMap :
                depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32).depthDataMap
            let image = CIImage(cvPixelBuffer: pixelBuffer, options: [:])
            self.imageView.image = UIImage(ciImage: image.oriented(.right))
        }
    }
}

