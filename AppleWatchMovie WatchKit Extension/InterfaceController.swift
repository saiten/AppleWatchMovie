//
//  InterfaceController.swift
//  AppleWatchMovie WatchKit Extension
//
//  Created by saiten on 12/13/14.
//  Copyright (c) 2014 saiten. All rights reserved.
//

import WatchKit
import Foundation


class InterfaceController: WKInterfaceController {
    
    @IBOutlet var imageView: WKInterfaceImage!
    @IBOutlet var playPauseButton: WKInterfaceButton!
    var watchMoviePlayer: WatchMoviePlayer!;

    override init(context: AnyObject?) {
        super.init(context: context)
        NSLog("%@ init", self)
    }

    override func willActivate() {
        super.willActivate()
        NSLog("%@ will activate", self)
        
        let moviePath = NSBundle.mainBundle().pathForResource("video", ofType: "mp4")
        self.watchMoviePlayer = WatchMoviePlayer(imageView: self.imageView);
        self.watchMoviePlayer.movieFilePath = moviePath
        self.watchMoviePlayer.prepareToPlay()
    }

    override func didDeactivate() {
        NSLog("%@ did deactivate", self)
        super.didDeactivate()
    }

    @IBAction func playPauseButtonTapped(AnyObject) {
        if(self.watchMoviePlayer.playing) {
            self.watchMoviePlayer.pause()
            self.playPauseButton.setTitle("Play")
        } else {
            self.watchMoviePlayer.play()
            self.playPauseButton.setTitle("Pause")
        }
    }
}
