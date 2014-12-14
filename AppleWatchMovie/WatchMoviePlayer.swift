//
//  WatchMoviePlayer.swift
//  AppleWatchMovie
//
//  Copyright (c) 2014 saiten. All rights reserved.
//

import WatchKit
import Foundation
import AVFoundation
import CoreMedia


class WatchMoviePlayer {
    
    var imageView: WKInterfaceImage?
    var movieFilePath: String? {
        willSet(newMovieFilePath) {
            if self.movieFilePath != newMovieFilePath {
                if self.assetReader != nil {
                    self.assetReader?.cancelReading()
                    self.assetReader = nil;
                }
            }
        }
    }
    var framePerSecond: Int32 = 5
    private(set) var playing: Bool = false
    
    private var assetReader: AVAssetReader?
    private var trackOutput: AVAssetReaderTrackOutput?
    
    private var previousSampleTime: CMTime!
    private var nextRenderingTime: CMTime!
    private var previousActualTime: CFAbsoluteTime!
    
    init(imageView: WKInterfaceImage?) {
        self.imageView = imageView;
    }
    
    func prepareToPlay() {
        if self.movieFilePath == nil {
            return
        }
        
        let asset = AVURLAsset(URL: NSURL(fileURLWithPath: self.movieFilePath!), options:[ AVURLAssetPreferPreciseDurationAndTimingKey: true ])
        asset.loadValuesAsynchronouslyForKeys(["tracks"]) {
            let tracks = asset.tracksWithMediaType(AVMediaTypeVideo)
            
            let outputSetting = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            self.trackOutput = AVAssetReaderTrackOutput(track: tracks[0] as AVAssetTrack, outputSettings: outputSetting)
            
            var error: NSError?
            self.assetReader = AVAssetReader(asset: asset, error: &error)
            if error != nil {
                NSLog("failed open movie file. : %@", error!.localizedDescription)
                return
            }
            
            if self.assetReader!.canAddOutput(self.trackOutput) {
                self.assetReader!.addOutput(self.trackOutput)
                self.assetReader!.startReading()
            }
            
            self.previousSampleTime = kCMTimeZero
            self.nextRenderingTime = kCMTimeZero
        }
    }
    
    func play() {
        if self.assetReader == nil {
            return
        }
        
        self.playing = true
        self.previousActualTime = CFAbsoluteTimeGetCurrent()
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            while self.assetReader?.status == AVAssetReaderStatus.Reading && self.playing {
                self.readNextVideoFrame()
            }
            
            if self.assetReader?.status == AVAssetReaderStatus.Completed {
                self.assetReader?.cancelReading()
                self.assetReader = nil
            }
            
            self.playing = false
        }
    }
    
    func pause() {
        self.playing = false
    }
    
    private func readNextVideoFrame() {
        if let sampleBufferRef = self.trackOutput?.copyNextSampleBuffer() {
            // 速度調整
            let currentSampleTime = CMSampleBufferGetOutputPresentationTimeStamp(sampleBufferRef)
            let diffSampleTimeFromLastFrame = CMTimeSubtract(currentSampleTime, self.previousSampleTime)
            
            let sampleTimeDiff = CMTimeGetSeconds(diffSampleTimeFromLastFrame) as Double
            
            let currentActualTime = CFAbsoluteTimeGetCurrent()
            let actualTimeDiff = (currentActualTime - self.previousActualTime) as Double;
            
            if sampleTimeDiff > actualTimeDiff {
                let waitTime = UInt32((sampleTimeDiff - actualTimeDiff) * 1000000.0)
                usleep(waitTime)
            }
            
            self.previousSampleTime = currentSampleTime
            self.previousActualTime = currentActualTime
            
            if CMTimeCompare(currentSampleTime, self.nextRenderingTime) < 0 {
                return
            }
            
            self.nextRenderingTime = CMTimeAdd(currentSampleTime, CMTimeMake(1, self.framePerSecond))
            
            // samplebuffer to image
            if let imageBufferRef = CMSampleBufferGetImageBuffer(sampleBufferRef) {
                CVPixelBufferLockBaseAddress(imageBufferRef, 0);
                
                let baseAddress = CVPixelBufferGetBaseAddress(imageBufferRef)
                let bytePerRow = CVPixelBufferGetBytesPerRow(imageBufferRef)
                let width = CVPixelBufferGetWidth(imageBufferRef)
                let height = CVPixelBufferGetHeight(imageBufferRef)
                
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                
                let context = CGBitmapContextCreate(baseAddress, width, height, 8, bytePerRow, colorSpace, .ByteOrder32Little | CGBitmapInfo(CGImageAlphaInfo.PremultipliedFirst.rawValue))
                
                let cgImageRef = CGBitmapContextCreateImage(context)
                let image = UIImage(CGImage: cgImageRef)
                
                CVPixelBufferUnlockBaseAddress(imageBufferRef, 0);
                
                dispatch_async(dispatch_get_main_queue()) {
                    self.imageView?.setImage(image)
                    return
                }
            }
        }
    }
}