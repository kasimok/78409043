//
//  ContentView.swift
//  AssetWriter
//
//  Created by 0x67 on 2024-05-09.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    
    let targetUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("output.mp4")
    let size = CGSize(width: 4096, height: 2160)
    var body: some View {
        Button(action: {
            if FileManager.default.fileExists(atPath: targetUrl.path) {
                try? FileManager.default.removeItem(at: targetUrl)
            }
            Task {
                do {
                    try await writeAssets()
                } catch {
                    print("Error writing assets: \(error)")
                }
            }
        }
        ) {
            Text("Write Assets")
        }
    }
    
    private func writeAssets() async throws {
        // Initial AVAssetWriter
        // Write mp4 file
        let assetWriter = try AVAssetWriter(outputURL: targetUrl, fileType: .mp4)
        // set options for written video
        let videoSettings: [String : Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: size.width,
            AVVideoHeightKey: size.height
        ]
        guard assetWriter.canApply(outputSettings: videoSettings, forMediaType: AVMediaType.video) else {
            fatalError("Error applying output settings")
        }
        // Initial AVAssetWriterInput
        let assetWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        
        // set arritbutes
        let sourcePixelBufferAttributes: [String : Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: size.width,
            kCVPixelBufferHeightKey as String: size.height
        ]
        
        // Initial AVAssetWriterInputPixelBufferAdaptor
        let inputPixelBufferAdaptor =
        AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: assetWriterInput,
                                             sourcePixelBufferAttributes: sourcePixelBufferAttributes)
        if assetWriter.canAdd(assetWriterInput) == true {
            assetWriter.add(assetWriterInput)
            assetWriter.startWriting()
            assetWriter.startSession(atSourceTime: .zero)
        } else {
            print("Cannot add asset writer input.")
        }
        
        if let error = assetWriter.error {
            throw error
        }
        
        var images: [UIImage] = [UIImage]()
        images.append(UIImage(named: "IMG1")!)
        images.append(UIImage(named: "IMG2")!)
        
        var frameCount = 0
        let frameDuration = CMTime(value: 5, timescale: 1) // 5 second per frame
        for image in images {
            guard let pixelBuffer = self.pixelBuffer(from: image, size: size) else { continue }
            while !assetWriterInput.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 1_000_000_000)
            }
            inputPixelBufferAdaptor.append(pixelBuffer, withPresentationTime: CMTimeMultiply(frameDuration, multiplier: Int32(frameCount)))
            frameCount += 1
        }
        assetWriterInput.markAsFinished()
        assetWriter.finishWriting {
            if let error = assetWriter.error {
                print("Error finishing asset writing: \(error)")
            }else {
                print("job done!")
            }
            
        }
        
    }
    
    // Convert UIImage to CVPixelBuffer
    func pixelBuffer(from image: UIImage, size: CGSize) -> CVPixelBuffer? {
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
        guard status == kCVReturnSuccess else { return nil }
        
        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)
        
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: pixelData, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else { return nil }
        
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        
        UIGraphicsPushContext(context)
        image.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        UIGraphicsPopContext()
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        return pixelBuffer
    }
}

#Preview {
    ContentView()
}
