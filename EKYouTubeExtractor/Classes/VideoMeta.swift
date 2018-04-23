//
//  VideoMeta.swift
//
//  Created by elviskuocy@gmail.com on 04/23/2018.
//  Copyright (c) 2018 elviskuocy@gmail.com. All rights reserved.
//

public class VideoMeta {
    let IMAGE_BASE_URL = "http://i.ytimg.com/vi/"
    
    let title  : String?
    let author : String?
    let videoId: String?
    let channelId: String?
    let videoLength: String?
    let viewCount: String?
    let isLive: Bool?
    
    init(videoId: String, title: String, author: String, channelId: String, videoLength: String, viewCount: String, isLive: Bool) {
    
        self.videoId = videoId
        self.title = title
        self.author = author
        self.channelId = channelId
        self.videoLength = videoLength
        self.viewCount = viewCount
        self.isLive = isLive
    }
    
    // 120 x 90
    public func getThumbUrl() -> String? {
        if let id = videoId {
            return IMAGE_BASE_URL + id + "/default.jpg"
        } else {
            return nil
        }
    }
    
    // 320 x 180
    public func getMqImageUrl() -> String? {
        if let id = videoId {
            return IMAGE_BASE_URL + id + "/mqdefault.jpg"
        } else {
            return nil
        }
    }
    
    // 480 x 360
    public func getHqImageUrl() -> String? {
        if let id = videoId {
            return IMAGE_BASE_URL + id + "/hqdefault.jpg"
        } else {
            return nil
        }
    }
    
    // 640 x 480
    public func getSdImageUrl() -> String? {
        if let id = videoId {
            return IMAGE_BASE_URL + id + "/sddefault.jpg"
        } else {
            return nil
        }
    }
    
    // Max Res
    public func getMaxResImageUrl() -> String? {
        if let id = videoId {
            return IMAGE_BASE_URL + id + "/maxresdefault.jpg"
        } else {
            return nil
        }
    }
    
    public func getVideoId() -> String? {
        return self.videoId
    }
    
    public func getTitle() -> String? {
        return self.title;
    }
    
    public func getAuthor() -> String? {
        return self.author;
    }
    
    public func getChannelId() -> String? {
        return self.channelId;
    }
    
    public func isLiveStream() -> Bool? {
        return self.isLive
    }
    
    /**
     * The video length in seconds.
     */
    public func getVideoLength() -> String? {
        return self.videoLength;
    }
    
    public func getViewCount() -> String? {
        return self.viewCount;
    }
}
