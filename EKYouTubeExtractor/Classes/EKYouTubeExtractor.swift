//
//  EKYouTubeExtractor.swift
//
//  Created by elviskuocy@gmail.com on 04/23/2018.
//  Copyright (c) 2018 elviskuocy@gmail.com. All rights reserved.
//
//  Reference: https://github.com/HaarigerHarald/android-YouTubeExtractor
//

import Alamofire
import JavaScriptCore

let fileCache = NSCache<AnyObject, AnyObject>()

public class EKYouTubeExtractor {
    
    // MARK: - Properties
    
    let TAG = "EKYouTube"
    let DEBUG = false
    
    var sigEnc = true
    let oriURL  = "https://youtube.com/watch?v="
    let apiURL  = "&eurl=https://youtube.googleapis.com/v/"
    let infoURL = "http://www.youtube.com/get_video_info?video_id="
    
    let decipherFunctUrl = "https://s.ytimg.com/yts/jsbin/"
    let userAgent = "Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/40.0.2214.115 Safari/537.36"
    let streamMapString = "url_encoded_fmt_stream_map"
    
    // Search start: "dashmpd=", end: "&" or "\z"
    let patDashManifest1      = "dashmpd=(.+?)(&|\\z)"
    let patDashManifest2      = "\"dashmpd\":\"(.+?)\""
    let patDashManifestEncSig = "/s/([0-9A-F|.]{10,}?)(/|\\z)"
    
    let patTitle     = "title=(.*?)(&|\\z)"
    let patAuthor    = "author=(.+?)(&|\\z)"
    let patChannelId = "ucid=(.+?)(&|\\z)"
    let patLength    = "length_seconds=(\\d+?)(&|\\z)"
    let patViewCount = "view_count=(\\d+?)(&|\\z)"
    
    let patHlsvp     = "hlsvp=(.+?)(&|\\z)"
    
    let patItag      = "itag=([0-9]+?)([&,])"
    let patEncSig    = "s=([0-9A-F|.]{10,}?)([&,\"])"
    // = %3d, & %26
    let patIsEncSig  = "s%3D([0-9A-F|.]{10,}?)%26"
    let patUrl       = "url=(.+?)([&,])"
    
    let patVariableFunction     = "([{; =])([a-zA-Z$][a-zA-Z0-9$]{0,2})\\.([a-zA-Z$][a-zA-Z0-9$]{0,2})\\("
    let patFunction             = "([{; =])([a-zA-Z$_][a-zA-Z0-9$]{0,2})\\("
    let patDecryptionJsFile     = "jsbin\\\\/(player-(.+?).js)"
    let patSignatureDecFunction = "\"signature\",(.{1,3}?)\\(.{1,10}?\\)"
    
    let group = DispatchGroup()
    let interactiveQueue = DispatchQueue(label: "com.weeview.youtube", qos: .userInteractive, attributes: .concurrent)
    
    var decipheredSignature: String?
    var formatMap = Dictionary<String, Format>()
    var videoMeta: VideoMeta?
    
    let sessionManager: SessionManager = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        
        return SessionManager(configuration: configuration)
    }()
    
    public static let shared: EKYouTubeExtractor = {
        let instance = EKYouTubeExtractor()
        // Setup
        return instance
    }()
    
    // MARK: init
    
    init() {
        // http://en.wikipedia.org/wiki/YouTube#Quality_and_formats
        
        // Video and Audio
        let format17 = Format(itag: "17", ext: "3gp", height: 144, vCodec: Format.VCodec.MPEG4, aCodec: Format.ACodec.AAC, audioBitrate: 24, isDashContainer: false)
        let format18 = Format(itag: "18", ext: "mp4", height: 360, vCodec: Format.VCodec.H264, aCodec: Format.ACodec.AAC, audioBitrate: 96, isDashContainer: false)
        let format22 = Format(itag: "22", ext: "mp4", height: 720, vCodec: Format.VCodec.H264, aCodec: Format.ACodec.AAC, audioBitrate: 192, isDashContainer: false)
        
        // Dash Video
        let format137 = Format(itag: "137", ext: "mp4", height: 1080, vCodec: Format.VCodec.H264, aCodec: Format.ACodec.AAC, isDashContainer: true)
        let format264 = Format(itag: "264", ext: "mp4", height: 1440, vCodec: Format.VCodec.H264, aCodec: Format.ACodec.AAC, isDashContainer: true)
        let format266 = Format(itag: "266", ext: "mp4", height: 2160, vCodec: Format.VCodec.H264, aCodec: Format.ACodec.AAC, isDashContainer: true)
        
        // Dash Audio
        let format140 = Format(itag: "140", ext: "m4a", vCodec: Format.VCodec.NONE, aCodec: Format.ACodec.AAC, audioBitrate: 128, isDashContainer: true)
        let format141 = Format(itag: "141", ext: "m4a", vCodec: Format.VCodec.NONE, aCodec: Format.ACodec.AAC, audioBitrate: 256, isDashContainer: true)
        //let format171 = Format(itag: "171", ext: "webm", vCodec: Format.VCodec.NONE, aCodec: Format.ACodec.VORBIS, audioBitrate: 128, isDashContainer: true)
        //let format250 = Format(itag: "250", ext: "webm", vCodec: Format.VCodec.NONE, aCodec: Format.ACodec.OPUS, audioBitrate: 64, isDashContainer: true)
        //let format251 = Format(itag: "251", ext: "webm", vCodec: Format.VCodec.NONE, aCodec: Format.ACodec.OPUS, audioBitrate: 160, isDashContainer: true)
        
        // Initial youtube format
        
        formatMap["17"]  = format17
        formatMap["18"]  = format18
        formatMap["22"]  = format22
        formatMap["137"] = format137
        formatMap["264"] = format264
        formatMap["266"] = format266
        formatMap["140"] = format140
        formatMap["141"] = format141
        //formatMap["171"] = format171
        //formatMap["250"] = format250
        //formatMap["251"] = format251
        
        //print("formatMap: \(formatMap)")
    }
    
    /**
     Method for retrieving the youtube ID from a youtube URL
     
     @param youtubeURL the the complete youtube video url, either youtu.be or youtube.com
     @return string with desired youtube id
     */
    private func youtubeIdFromYouTubeURL(_ youtubeURL: URL) -> String? {
        guard let youtubeHost = youtubeURL.host else {
            return nil
        }
        
        let youtubePathComponents = youtubeURL.pathComponents
        let youtubeAbsoluteString = youtubeURL.absoluteString
        if youtubeHost == "youtu.be" as String? {
            return youtubePathComponents[1]
        } else if youtubeAbsoluteString.range(of: "www.youtube.com/embed") != nil {
            return youtubePathComponents[2]
        } else if youtubeHost == "youtube.googleapis.com" ||
            youtubeURL.pathComponents.first == "www.youtube.com" as String? {
            return youtubePathComponents[2]
        } else if let queryString = youtubeURL.dictionaryForQueryString(), let searchParam = queryString["v"] as? String {
            return searchParam
        }
        
        return nil
    }
    
    /**
     Method for retreiving a iOS supported video link
     
     @param youtubeURL the the complete youtube video url
     @return dictionary with the available formats for the selected video
     
     */
    private func h264videosWithYouTubeId(_ youtubeId: String) -> [String: Any]? {
        //stopAllSessions()
        
        guard let parts = loadVideoInfos(youtubeId: youtubeId), parts.count > 0 else {
            print("parts nil")
            return nil
        }
        var data = [String: Any]()
        
        //data["title"] = parts["title"] as? String
        //data["length_seconds"] = parts["length_seconds"] as? String
        //data["isStream"] = false as Any?
        
        if let infos = decipherVideoInfos(youtubeId: youtubeId) {
            for (key, value) in infos {
                data[key] = value
                //printLog("decipherVideoInfos: \(key) \(String(describing: data[key]))")
            }
            //printLog("data \(data.count)")
        }
        
        // DecipherVideoInfos nil
        if data.count == 0 {
            // Live Stream
            if parts["live_playback"] != nil {
                if let hlsvp = parts["hlsvp"] as? String {
                    return [
                        "url": "\(hlsvp)" as Any,
                        "title": parts["title"] as Any,
                        "image": parts["iurl"] as Any,
                        "isStream": true as Any
                    ]
                }
            } else { //url_encoded_fmt_stream_map || adaptive_fmts
                if let fmts = parts["adaptive_fmts"] as? String {
                    let fmtsArray = fmts.components(separatedBy: ",")
                    //printLog("fmtsArray ")
                    
                    for videoEncodedString in fmtsArray {
                        var videoComponents = videoEncodedString.dictionaryFromQueryStringComponents()
                        
                        if let signature = videoComponents["s"]{
                            if let type = videoComponents["type"] as? String, type.range(of: "mp4") != nil {
                                if let url = videoComponents["url"] as? String, let itag = videoComponents["itag"] as? String {
                                    let urlString = url.stringByDecodingURLFormat()+"&signature=\(signature)"
                                    data[itag] = urlString
                                }
                            }
                            
                            if let type = videoComponents["type"] as? String, type.range(of: "mp4a") != nil {
                                if let url = videoComponents["url"] as? String {
                                    let urlString = url.stringByDecodingURLFormat()+"&signature=\(signature)"
                                    data["audio"] = urlString
                                }
                            }
                        }
                    }
                }
                
                if let fmtStreamMap = parts[streamMapString] as? String  {
                    let fmtStreamMapArray = fmtStreamMap.components(separatedBy: ",")
                    
                    for videoEncodedString in fmtStreamMapArray {
                        var videoComponents = videoEncodedString.dictionaryFromQueryStringComponents()
                        
                        if let signature = videoComponents["itag"]{
                            if let type = videoComponents["type"] as? String, type.range(of: "mp4") != nil {
                                if let url = videoComponents["url"] as? String, let itag = videoComponents["itag"] as? String {
                                    let urlString = url.stringByDecodingURLFormat()+"&signature=\(signature)"
                                    data[itag] = urlString
                                }
                            }
                        }
                    }
                }
                return data
            }
        }
        return data
    }
    
    private func loadVideoInfos(youtubeId: String) -> [String: Any]? {
        let group = DispatchGroup()
        
        var result: [String: Any]?
        let urlString = String(format: "%@%@%@%@", infoURL, youtubeId , apiURL, youtubeId)
        
        group.enter()
        sessionManager.request(urlString).response(queue: interactiveQueue) { response in
            if let data = response.data, let streamMap = String(data: data, encoding: .utf8) {
                self.printLog("loadVideoInfos response: \(urlString)")
                result = streamMap.dictionaryFromQueryStringComponents()
                
                var isLive = false;
                if let mat = streamMap.matcher(withRegex: self.patHlsvp) {
                    self.printLog("isLive: true \(mat.count)")
                    isLive = true
                }
                
                if let title = result?["title"], let author = result?["author"], let channelId = result?["ucid"], let videoLength = result?["length_seconds"], let viewCount = result?["view_count"] {
                    
                    self.videoMeta = VideoMeta(videoId: youtubeId,
                                               title: title as! String,
                                               author: author as! String,
                                               channelId: channelId as! String,
                                               videoLength: videoLength as! String,
                                               viewCount: viewCount as! String,
                                               isLive: isLive)
                } else {
                    self.videoMeta = nil
                }
                
                self.sigEnc = true
                if streamMap.contains(s: self.streamMapString) {
                    if let range = streamMap.range(of: self.streamMapString) {
                        let streamMapSubTmp = streamMap[range.lowerBound...]
                        let stringMapSub = String(streamMapSubTmp)
                        if let mat = stringMapSub.matcher(withRegex: self.patIsEncSig) {
                            self.printLog("sigEnc matcher: \(mat[1])")
                        } else {
                            self.sigEnc = false
                        }
                    }
                }
            }
            group.leave()
        }
        _ = group.wait(timeout: .distantFuture)
        
        return result
    }
    
    private func parseVideoMeta(videoId: String, getVideoInfo: String) {
        printLog("parseVideoMeta")
        
        //printLog("getVideoInfo: \(getVideoInfo)")
        var isLive = false;
        var title = "", author = "", channelId = ""
        var viewCount = "", length = ""
        
        if let mat = getVideoInfo.matcher(withRegex: patTitle) {
            //printLog("title1: \(mat[1])")
            title = mat[1]
        }
        if let _ = getVideoInfo.matcher(withRegex: patHlsvp) {
            //printLog("isLive: true \(mat.count)")
            isLive = true
        }
        if let mat = getVideoInfo.matcher(withRegex: patAuthor) {
            //printLog("author: \(mat[1])")
            author = mat[1]
        }
        if let mat = getVideoInfo.matcher(withRegex: patChannelId) {
            //printLog("channelId: \(mat[1])")
            channelId = mat[1]
        }
        if let mat = getVideoInfo.matcher(withRegex: patLength) {
            //printLog("length: \(mat[1])")
            length = mat[1]
        }
        if let mat = getVideoInfo.matcher(withRegex: patViewCount) {
            //printLog("viewCount: \(mat[1])")
            viewCount = mat[1]
        }
        
        videoMeta = VideoMeta(videoId: videoId, title: title, author: author, channelId: channelId, videoLength: length, viewCount: viewCount, isLive: isLive)
    }
    
    private func decipherVideoInfos(youtubeId: String) -> [String: Any]? {
        let urlString = String(format: "%@%@", oriURL, youtubeId)
        var result = [String: Any]()
        
        group.enter()
        sessionManager.request(urlString).response(queue: interactiveQueue) { response in
            if let data = response.data, let streamMap = String(data: data, encoding: .utf8) {
                result.removeAll(keepingCapacity: false)
                
                var itag: String?
                var dashMpdUrl: String?
                var decipherFunctionName: String?
                var decipherFunctions: String?
                var decipherJsFileName: String?
                
                //decipherFunctionName == nill || decipherFunctions == nil
                
                if let cacheURL = fileCache.object(forKey: urlString as AnyObject) {
                    result = cacheURL as! [String : Any]
                } else {
                    var encSignatures = [Dictionary<String, String>]()
                    
                    if let mat = streamMap.matcher(withRegex: self.patDecryptionJsFile) {
                        let decryptionJsFile = mat[1]
                        let curJsFileName = decryptionJsFile.replacingOccurrences(of: "\\/", with: "/")
                        decipherJsFileName = curJsFileName
                    } else {
                        self.printLog("patDecryptionJsFile not found")
                    }
                    
                    if let mat = streamMap.matcher(withRegex: self.patDashManifest2) {
                        let dashManifest2 = mat[1]
                        dashMpdUrl = dashManifest2.replacingOccurrences(of: "\\/", with: "/")
                        
                        if let mat = dashMpdUrl?.matcher(withRegex: self.patDashManifestEncSig) {
                            encSignatures.append(["0": mat[1]])
                        } else {
                            dashMpdUrl = nil
                        }
                    }
                    
                    //url_encoded_fmt_stream_map|&adaptive_fmts=
                    var ytFiles = Dictionary<String, YTFile>()
                    let semicolonStreamMap = streamMap.components(separatedBy: ";")
                    //self.printLog("semicolonStreamMap: \(semicolonStreamMap)")
                    for semicolonStreams in semicolonStreamMap {
                        if semicolonStreams.contains(self.streamMapString) || semicolonStreams.contains("adaptive_fmts") {
                            let commaStreams = semicolonStreams.components(separatedBy: ",")
                            
                            for streams in commaStreams {
                                let stream = streams.replacingOccurrences(of: "\\u0026", with: "&") + ","
                                
                                if let mat = stream.matcher(withRegex: self.patItag) {
                                    itag = mat[1]
                                    //printLog("itag: \(String(describing: itag!))")
                                } else {
                                    continue
                                }
                                //printLog("stream: \(stream)")
                                if let mat = stream.matcher(withRegex: self.patEncSig), let tag = itag {
                                    encSignatures.append([tag: mat[1]])
                                    //printLog("mat: \(mat)")
                                }
                                
                                if let mat = stream.matcher(withRegex: self.patUrl) {
                                    //print("url: \(String(describing: url))")
                                    if let url = mat[1].removingPercentEncoding, let tag = itag {
                                        if let format = self.formatMap[tag] {
                                            let newVideo = YTFile(format, url)
                                            ytFiles[tag] = newVideo
                                        }
                                    }
                                }
                            }
                            //self.printLog("encSignatures")
                        }
                    }
                    
                    // From loadVideoInfos() result
                    if self.sigEnc , let decipherJs = decipherJsFileName {
                         self.group.enter()
                        self.sessionManager.request( self.decipherFunctUrl + decipherJs ).response(queue: self.interactiveQueue) { response in
                            //self.printLog("decipherFunctUrl response2: \(self.decipherFunctUrl + decipherJs)")
                            //self.printLog("Error   : \(String(describing: response.error))")
                            //self.printLog("Request : \(String(describing: response.request))")
                            //self.printLog("Response: \(String(describing: response.response))")
                            
                            if let data = response.data, let javascriptFile = String(data: data, encoding: .utf8) {
                                var mainDecipherFunct: String?
                                
                                //self.printLog("javascriptFile \(javascriptFile)")
                                //self.printLog("patSignatureDecFunction matcher before")
                                if let tmpMat = javascriptFile.range(of: self.patSignatureDecFunction, options: .regularExpression),
                                    let mat = String(javascriptFile[tmpMat]).matcher(withRegex: self.patSignatureDecFunction) {
                                    //self.printLog("patSignatureDecFunction matcher enter")
                                    
                                    decipherFunctionName = mat[1]
                                    //self.printLog("decipherFunctionName: \(String(describing: decipherFunctionName!))")
                                    
                                    let patMainVariable = "(var |\\s|,|;)" + decipherFunctionName!.replacingOccurrences(of: "$", with: "\\$") + "(=function\\((.{1,3})\\)\\{)"
                                    
                                    var funcName: String?
                                    if let mat = javascriptFile.range(of: patMainVariable, options: .regularExpression) {
                                        let result = String(javascriptFile[mat]).trim()
                                            mainDecipherFunct = "var " + result
                                            funcName = result
                                    } else {
                                        let patMainFunction = "function " + decipherFunctionName!.replacingOccurrences(of: "$", with: "\\$") + "(=function\\((.{1,3})\\)\\{)"
                                        
                                        if let mat = javascriptFile.matcher(withRegex: patMainFunction) {
                                            mainDecipherFunct = "function " + decipherFunctionName! + mat[2]
                                            funcName = mat[2]
                                        } else {
                                            return
                                        }
                                    }
                                    
                                    /*
                                        if let mat = javascriptFile.matcher(withRegex: patMainVariable) {
                                            mainDecipherFunct = "var " + decipherFunctionName! + mat[2]
                                            funcName = mat[2]
                                        } else {
                                            let patMainFunction = "function " + decipherFunctionName!.replacingOccurrences(of: "$", with: "\\$") + "(=function\\((.{1,3})\\)\\{)"
                                     
                                            if let mat = javascriptFile.matcher(withRegex: patMainFunction) {
                                                 mainDecipherFunct = "function " + decipherFunctionName! + mat[2]
                                                 funcName = mat[2]
                                            } else {
                                                return
                                            }
                                        }
                                     */
                                    
                                    var start: String.Index
                                    if let jsRange = javascriptFile.range(of: funcName!) {
                                        start = jsRange.upperBound
                                    } else {
                                        start = javascriptFile.startIndex
                                    }
                                    
                                    // Find DecipherFunction
                                    let subJSF = javascriptFile[start...].components(separatedBy: ";")
                                    //self.printLog("subJSF \(subJSF)")
                                    
                                    for line in subJSF {
                                        mainDecipherFunct = mainDecipherFunct! + line + ";"
                                        //self.printLog("mainDecipherFunct \(String(describing: mainDecipherFunct))")
                                        if line.contains("}") {
                                            break
                                        }
                                    }
                                    
                                    decipherFunctions = mainDecipherFunct!
                                    
                                    var tmpDecipherFunctions = ""
                                    if let mat = mainDecipherFunct?.matcher(withRegex: self.patVariableFunction) {
                                        //self.printLog("patVariableFunction matcher enter")

                                        for _ in 0..<mat.count {
                                            let variableDef = "var " + mat[2] + "={";
                                            //self.printLog("variableDef \(variableDef)")
                                            if decipherFunctions!.contains(variableDef) {
                                                continue;
                                            }
                                            //self.printLog("patVariableFunction contain exit")

                                            //print("variableDef: \(String(describing: variableDef))")
                                            
                                            if let jsFile = javascriptFile.range(of: variableDef) {
                                                //self.printLog("patVariableFunction range enter")

                                                let subJS = javascriptFile[jsFile.upperBound...].components(separatedBy: ";")
                                                
                                                var braces = 1
                                                for line in subJS {
                                                    tmpDecipherFunctions = tmpDecipherFunctions + line + ";"
                                                    
                                                    if line.contains("{") {
                                                        braces += (line.components(separatedBy: "{").count-1)
                                                    }
                                                    
                                                    if line.contains("}") {
                                                        braces -= (line.components(separatedBy: "}").count-1)
                                                    }
                                                    
                                                    if braces == 0 {
                                                        decipherFunctions = decipherFunctions! + variableDef + tmpDecipherFunctions
                                                        break
                                                    }
                                                }
                                                //self.printLog("patVariableFunction End")
                                            }
                                        }
                                    } else {
                                        self.printLog("patVariableFunction not found")
                                    }
                                    
                                    
                                    tmpDecipherFunctions = ""
                                    if let mat = mainDecipherFunct?.matcher(withRegex: self.patFunction) {
                                        //self.printLog("patFunction matcher enter")
                                        for _ in 0..<mat.count {
                                            let functionDef = "var " + mat[2] + "={";
                                            if decipherFunctions!.contains(functionDef) {
                                                continue;
                                            }
                                            
                                            let endIndex = javascriptFile.index(javascriptFile.startIndex, offsetBy: javascriptFile.length)
                                            
                                            if let jsFile = javascriptFile.range(of: functionDef) {
                                                let startIndex = jsFile.lowerBound
                                                let searchRange = startIndex..<endIndex
                                                
                                                // find DecipherFunction
                                                let subJSF = javascriptFile[searchRange].components(separatedBy: ";")
                                                
                                                var braces = 1
                                                for line in subJSF {
                                                    tmpDecipherFunctions = tmpDecipherFunctions + line + ";"
                                                    
                                                    if line.contains("{") {
                                                        braces += (line.components(separatedBy: "{").count-1)
                                                    }
                                                    
                                                    if line.contains("}") {
                                                        braces -= (line.components(separatedBy: "}").count-1)
                                                    }
                                                    
                                                    if braces == 0 {
                                                        decipherFunctions = decipherFunctions! + functionDef + tmpDecipherFunctions
                                                        break
                                                    }
                                                }
                                                //self.printLog("patFunction End")
                                            }
                                        }
                                    } else {
                                        self.printLog("patFunction not found")
                                    }
                                    
                                    // JavaScript Execute
                                    self.printLog("jsFile Execute")
                                    let context = JSContext()!
                                    var jsFile = decipherFunctions! + " function decipher(){return "
                                    for i in 0..<encSignatures.count {
                                        for (_, value) in encSignatures[i] {
                                            if (i < encSignatures.count - 1){
                                                jsFile.append(decipherFunctionName! + "('" + value + "')+\"\\n\"+");
                                            } else {
                                                jsFile.append(decipherFunctionName! + "('" + value + "')");
                                            }
                                        }
                                    }
                                    jsFile.append("};decipher();");
                                    //self.printLog("jsFile Execute End")
                                    
                                    let jsResult = context.evaluateScript(jsFile).toString()

                                    if jsResult != "undefined" {
                                        //self.printLog("signature")
                                        let sigs = jsResult!.components(separatedBy: "\n")
                                        
                                        for i in 0...sigs.count where i < encSignatures.count {
                                            for (key, _) in encSignatures[i] {
                                                if key == "0" {
                                                    dashMpdUrl = dashMpdUrl?.replacingOccurrences(of: "/s/" + encSignatures[i][key]!, with: "/signature/" + sigs[i])
                                                    //self.printLog("dashMpdUrl: \(String(describing: dashMpdUrl))")
                                                } else {
                                                    if let url = ytFiles[key]?.getUrl(), let format = self.formatMap[key] {
                                                        let finalUrl = url + "&signature=" + sigs[i]
                                                        //self.printLog("signature finalUrl: \(String(describing: finalUrl))")
                                                        let newFile = YTFile(format, finalUrl)
                                                        ytFiles[key] = newFile
                                                        
                                                        // return
                                                        result[key] = finalUrl
                                                    }
                                                }
                                            }
                                        }
                                    } else {
                                        //self.printLog("no signature")
                                        
                                        for (key, value) in ytFiles {
                                            // return
                                            //self.printLog("no signature finalUrl: \(String(describing: value.getUrl()))")
                                            result[key] = value.getUrl()
                                        }
                                    }
                                    
                                    fileCache.setObject(result as AnyObject, forKey: urlString as AnyObject)
                                } else {
                                    self.printLog("patSignatureDecFunction matcher nil")
                                    result.removeAll()
                                }
                            }
                            self.group.leave()
                        }// End Alamofire.request
                    } else { // sigEnc FALSE
                        for (key, value) in ytFiles {
                            // return
                            //self.printLog("no signature finalUrl: \(String(describing: value.getUrl()))")
                            result[key] = value.getUrl()
                        }
                    }
                }// End FileCache
            }
            self.group.leave()
        }// End Alamofire.request
        _ = self.group.wait(timeout: .distantFuture)
        
        return result
    }
    
    /**
     Block based method for retreiving a iOS supported video link
     
     @param youtubeURL the the complete youtube video url
     @param completeBlock the block which is called on completion
     
     */
    public func h264videosWithYoutubeURL(_ youtubeURL: URL, completion: ((_ videoInfo: [String: Any]?, _ videoMeta: VideoMeta?,_ error: NSError?) -> Void)?) {
        
        interactiveQueue.async {
            if let youtubeId = self.youtubeIdFromYouTubeURL(youtubeURL), let videoInformation = self.h264videosWithYouTubeId(youtubeId) {
                DispatchQueue.main.async {
                    self.printLog("videoMeta completion")
                    //self.printLog("videoInformation \(videoInformation)")
                    completion?(videoInformation, self.videoMeta, nil)
                }
            }else{
                DispatchQueue.main.async {
                    completion?(nil, nil, NSError(domain: "com.player.YouTube.backgroundqueue", code: 1001, userInfo: ["error": "Invalid YouTube URL"]))
                }
            }
        }
    }
    
    func stopAllSessions() {
        printLog("stopSessions")
        
        sessionManager.session.getAllTasks { tasks in
            self.printLog("tasks: \(tasks.count)")
            tasks.forEach {
                $0.cancel()
            }
        }
    }
    
    // MARK: Convenience
    
    private func printLog(_ log: Any?) {
        if DEBUG, let msg = log {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS "
            print(formatter.string(from: Date()), TAG, ":", msg)
            //print(formatter.string(from: Date()), terminator: "")
            //print(TAG , ":", msg)
        }
    }
}

// MARK: - Extension

public extension URL {
    /**
     Parses a query string of an NSURL
     
     @return key value dictionary with each parameter as an array
     */
    func dictionaryForQueryString() -> [String: Any]? {
        if let query = self.query {
            return query.dictionaryFromQueryStringComponents()
        }
        
        // Note: find YouTube ID in m.youtube.com "https://m.youtube.com/#/watch?v=1hZ98an9wjo"
        let result = absoluteString.components(separatedBy: "?")
        if result.count > 1 {
            return result.last?.dictionaryFromQueryStringComponents()
        }
        return nil
    }
}

public extension String {
    func trim() -> String {
        return self.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
    
    /**
     Convenient method for decoding a html encoded string
     */
    func stringByDecodingURLFormat() -> String {
        let result = self.replacingOccurrences(of: "+", with:" ")
        return result.removingPercentEncoding!
    }
    
    /**
     Parses a query string
     
     @return key value dictionary with each parameter as an array
     */
    func dictionaryFromQueryStringComponents() -> [String: Any] {
        var parameters = [String: Any]()
        for keyValue in components(separatedBy: "&") {
            let keyValueArray = keyValue.components(separatedBy: "=")
            if keyValueArray.count < 2 {
                continue
            }
            let key = keyValueArray[0].stringByDecodingURLFormat()
            let value = keyValueArray[1].stringByDecodingURLFormat()
            parameters[key] = value as Any?
        }
        return parameters
    }
    
    var length:Int {
        return self.count
    }
    
    func indexOf(target: String) -> Int? {
        
        let range = (self as NSString).range(of: target)
        
        guard Range.init(range) != nil else {
            return nil
        }
        
        return range.location
    }
    
    func lastIndexOf(target: String) -> Int? {
        
        let range = (self as NSString).range(of: target, options: NSString.CompareOptions.backwards)
        
        guard Range.init(range) != nil else {
            return nil
        }
        
        return self.length - range.location - 1
    }
    
    func contains(s: String) -> Bool {
        return (self.range(of: s) != nil) ? true : false
    }
    
    func matcher(withRegex pattern: String) -> [String]? {
        var regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: pattern, options: [])
        } catch let error {
            print("\(error.localizedDescription)")
            return nil
        }
        
        //print("count: \(self.characters.count)")
        let matches = regex.matches(in: self, options: [], range: NSRange(location: 0, length: self.count))
        guard let match = matches.first else {
            return nil
        }
        
        let lastRangeIndex = match.numberOfRanges - 1
        guard lastRangeIndex >= 1 else {
            return nil
        }
        
        var results = [String]()
        for i in 0...lastRangeIndex {
            let capturedGroupIndex = match.range(at: i)
            if capturedGroupIndex.location != NSNotFound {
                let matchedString = (self as NSString).substring(with: capturedGroupIndex)
                results.append(matchedString)
            }
        }
        
        return results
    }
}
