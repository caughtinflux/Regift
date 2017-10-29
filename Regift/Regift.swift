//
//  Regift.swift
//  Regift
//
//  Created by Matthew Palmer on 27/12/2014.
//  Copyright (c) 2014 Matthew Palmer. All rights reserved.
//

import UIKit
import ImageIO
import MobileCoreServices
import AVFoundation
import Dispatch

public typealias TimePoint = CMTime
public typealias ProgressCallback = ((CGImage, Double) -> Void)

open class Regift: NSObject {
    struct Constants {
        static let FileName = "regift.gif"
        static let TimeInterval: Int32 = 600
        static let Tolerance = 0.01
    }
    
    /**
    Convert the video at the given URL to a GIF, and return the GIF's URL if it was created.
    
    - parameter URL: The URL at which the video to be converted to GIF exists
    - parameter frameCount: Number of frames to extract from the video for use in the GIF. The frames are evenly spaced out and all have the same duration
    - parameter delayTime: The amount of time for each frame in the GIF.
    - parameter loopCount: The number of times the GIF will repeat. Defaults to 0, which means repeat infinitely.
    */
    open class func createGIFFromURL(_ URL: Foundation.URL, withFrameCount frameCount: Int, delayTime: Float, loopCount: Int = 0) -> Foundation.URL? {
        var gifURL: Foundation.URL? = nil
        
        let group = DispatchGroup()
        group.enter()
        createGIFAsynchronouslyFromURL(URL, withFrameCount: frameCount, delayTime: delayTime, loopCount: loopCount, progressHandler: nil, completionHandler: {finalURL in
            gifURL = finalURL
            group.leave();
        })
        _ = group.wait(timeout: DispatchTime.distantFuture)
        
        return gifURL
    }
    
    /**
    Ascynchronously convert the video at the given URL to a GIF, and return the GIF's URL if it was created.
    
    - parameter URL: The URL at which the video to be converted to GIF exists
    - parameter frameCount: Number of frames to extract from the video for use in the GIF. The frames are evenly spaced out and all have the same duration
    - parameter delayTime: The amount of time for each frame in the GIF.
    - parameter loopCount: The number of times the GIF will repeat. Defaults to 0, which means repeat infinitely.
    - parameter progressHandler: The closure to be called with the progress of the conversion. It is called with an argument from 0.0 -> 1.0
    - parameter completionHandler: The closure to be called on completion of the process. If the conversion was successful, an NSURL to the location of the GIF on disk is passed in.
    */
    open class func createGIFAsynchronouslyFromURL(_ URL: Foundation.URL, withFrameCount frameCount: Int, delayTime: Float, loopCount: Int = 0, maxImageSize: CGSize = CGSize.zero, progressHandler: ProgressCallback?, completionHandler: ((Foundation.URL?) -> Void)?) {
        let fileProperties = [
            kCGImagePropertyGIFDictionary as String :
                [kCGImagePropertyGIFLoopCount as String: loopCount]
        ]
        
        let frameProperties = [
            kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFDelayTime as String: delayTime]
        ]
        
        let asset = AVURLAsset(url: URL, options: [AVURLAssetPreferPreciseDurationAndTimingKey: NSNumber(value: true as Bool)])
        
        // The total length of the movie, in seconds.
        let movieLength = Float(asset.duration.value) / Float(asset.duration.timescale)
        
        // How far along the video track we want to move, in seconds.
        let increment = Float(movieLength) / Float(frameCount)
        
        // Add each of the frames to the buffer
        var timePoints: [TimePoint] = []
        
        for frameNumber in 0 ..< frameCount {
            let seconds: Float64 = Float64(increment) * Float64(frameNumber)
            
            let time = CMTimeMakeWithSeconds(seconds, Constants.TimeInterval)
            
            timePoints.append(time)
        }
        Regift.createGIFAsynchronouslyForTimePoints(timePoints, fromURL: URL, fileProperties: fileProperties as [String : AnyObject], frameProperties: frameProperties as [String : AnyObject], maxImageSize: maxImageSize, frameCount: frameCount, progressHandler: progressHandler, completionHandler: completionHandler)
        
    }
    
    open class func createGIFForTimePoints(_ timePoints: [TimePoint], fromURL URL: Foundation.URL, fileProperties: [String: AnyObject], frameProperties: [String: AnyObject], frameCount: Int) -> Foundation.URL? {
        
        var fileURL: Foundation.URL? = nil
        
        let group = DispatchGroup()
        group.enter()
        
        createGIFAsynchronouslyForTimePoints(timePoints, fromURL: URL, fileProperties: fileProperties, frameProperties: frameProperties, frameCount: frameCount, progressHandler: nil, completionHandler: {URL in
            fileURL = URL
            group.leave()
        })

        _ = group.wait(timeout: DispatchTime.distantFuture)
        
        return fileURL
    }
    
    open class func createGIFAsynchronouslyForTimePoints(_ timePoints: [TimePoint], fromURL URL: Foundation.URL, fileProperties: [String: AnyObject], frameProperties: [String: AnyObject], maxImageSize: CGSize = CGSize.zero, frameCount: Int, progressHandler: ProgressCallback?, completionHandler: ((Foundation.URL?) -> Void)?) -> Void {
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
            let fileURL = Foundation.URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(Constants.FileName)
            
            let destination = CGImageDestinationCreateWithURL(fileURL as CFURL, kUTTypeGIF, frameCount, NSDictionary())!
            
            CGImageDestinationSetProperties(destination, fileProperties as CFDictionary)
            let asset = AVURLAsset(url: URL)
            let generator = AVAssetImageGenerator(asset: asset)
            
            generator.appliesPreferredTrackTransform = true
            let tolerance = CMTimeMakeWithSeconds(Constants.Tolerance, Constants.TimeInterval)
            generator.requestedTimeToleranceBefore = tolerance
            generator.requestedTimeToleranceAfter = tolerance
            generator.maximumSize = maxImageSize
        
            var generatedImageCount = 0.0
            let generationHandler: AVAssetImageGeneratorCompletionHandler = {(requestedTime: CMTime, image: CGImage?, receivedTime: CMTime, result: AVAssetImageGeneratorResult, err: NSError?) -> Void in
                if let error = err, result != .cancelled {
                    NSLog("Error generating CGImage: \(error.domain)(\(error.code)) - \(String(describing: error.localizedFailureReason ??  nil))")
                    if (CMTimeCompare(requestedTime, timePoints.last!) == 0) {
                        completionHandler?(nil)
                    }
                }
                else if result == .succeeded {
                    CGImageDestinationAddImage(destination, image!, frameProperties as CFDictionary)
                    
                    generatedImageCount += 1.0

                    let progress =  generatedImageCount / Double(timePoints.count)
                    progressHandler?(image!, progress)
                    
                    if (CMTimeCompare(requestedTime, timePoints.last!) == 0) {
                        if CGImageDestinationFinalize(destination) {
                            completionHandler?(fileURL)
                        }
                        else {
                            NSLog("\(self): Unable to finalize CGImageDestination!")
                            completionHandler?(nil)
                        }
                    }
                }
            } as! AVAssetImageGeneratorCompletionHandler
            
            generator.generateCGImagesAsynchronouslyForTimePoints(timePoints, completionHandler: generationHandler)
        }
    }
}
