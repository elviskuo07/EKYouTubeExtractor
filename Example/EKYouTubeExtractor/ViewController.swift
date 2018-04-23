//
//  ViewController.swift
//  EKYouTubeExtractor
//
//  Created by elviskuocy@gmail.com on 04/23/2018.
//  Copyright (c) 2018 elviskuocy@gmail.com. All rights reserved.
//

import UIKit
import EKYouTubeExtractor

class ViewController: UIViewController {
    var ytFormat = [String: Any]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        let url = URL(string: "https://www.youtube.com/watch?v=W-H6v6b1hu4")!
        
        EKYouTubeExtractor.shared.h264videosWithYoutubeURL(url) { (videoInfo, videoMeta, error) in
            // EKYouTubeExtractor() -> init() have Video and Audio format list
            // 360p
            if let videoUrl = videoInfo?["18"] as? String {
                self.ytFormat["18"] = videoUrl
                print("360p: \(videoUrl)")
            }
            
            // 720p
            if let videoUrl = videoInfo?["22"] as? String {
                self.ytFormat["22"] = videoUrl
                print("720p: \(videoUrl)")
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

