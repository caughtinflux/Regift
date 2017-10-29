//
//  AVAssetImageGeneratorTimePoints.swift
//  Vivify
//
//  Created by Aditya KD on 26/07/15.
//  Copyright (c) 2015 Giffage. All rights reserved.
//

import AVFoundation

public extension AVAssetImageGenerator {
    public func generateCGImagesAsynchronouslyForTimePoints(_ timePoints: [TimePoint], completionHandler: @escaping AVAssetImageGeneratorCompletionHandler) {
        let times = timePoints.map { NSValue(time: $0) }
        self.generateCGImagesAsynchronously(forTimes: times, completionHandler: completionHandler)
    }
}
