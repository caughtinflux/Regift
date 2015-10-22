//
//  AVAssetImageGeneratorTimePoints.swift
//  Vivify
//
//  Created by Aditya KD on 26/07/15.
//  Copyright (c) 2015 Giffage. All rights reserved.
//

import AVFoundation

public extension AVAssetImageGenerator {
    public func generateCGImagesAsynchronouslyForTimePoints(timePoints: [TimePoint], completionHandler: AVAssetImageGeneratorCompletionHandler) {
        let times = timePoints.map { NSValue(CMTime: $0) }
        self.generateCGImagesAsynchronouslyForTimes(times, completionHandler: completionHandler)
    }
}
