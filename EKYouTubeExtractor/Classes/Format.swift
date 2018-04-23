//
//  Format.swift
//
//  Created by elviskuocy@gmail.com on 04/23/2018.
//  Copyright (c) 2018 elviskuocy@gmail.com. All rights reserved.
//

class Format {
    enum VCodec {
        case H263, H264, MPEG4, VP8, VP9, NONE
    }
    
    enum ACodec {
        case MP3, AAC, VORBIS, OPUS, NONE
    }
    
    private var itag: String
    private var ext: String
    private var height: Int?
    private var fps: Int
    private var audioBitrate: Int
    private var isDashContainer: Bool
    private var isHlsContent: Bool
    
    init(itag: String, ext: String, height: Int, vCodec:VCodec, aCodec:ACodec, audioBitrate: Int, isDashContainer: Bool) {
        self.itag = itag
        self.ext  = ext
        self.height = height
        self.fps = 30
        self.audioBitrate = audioBitrate
        self.isDashContainer = isDashContainer
        self.isHlsContent = false
    }
    
    init(itag: String, ext: String, height: Int, vCodec:VCodec, aCodec:ACodec, isDashContainer: Bool) {
        self.itag = itag
        self.ext  = ext
        self.height = height
        self.fps = 30
        self.audioBitrate = -1
        self.isDashContainer = isDashContainer
        self.isHlsContent = false
    }
    
    init(itag: String, ext: String, vCodec:VCodec, aCodec:ACodec, audioBitrate: Int, isDashContainer: Bool) {
        self.itag = itag
        self.ext  = ext
        self.fps = 30
        self.audioBitrate = audioBitrate
        self.isDashContainer = isDashContainer
        self.isHlsContent = false
    }
}
