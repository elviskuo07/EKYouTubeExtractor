//
//  YTFile.swift
//
//  Created by elviskuocy@gmail.com on 04/23/2018.
//  Copyright (c) 2018 elviskuocy@gmail.com. All rights reserved.
//

class YTFile {
    let format: Format?
    let url: String?
    
    init(_ format: Format,_ url: String ) {
        self.format = format
        self.url = url
    }
    
    public func getUrl() -> String? {
        return self.url
    }
    
    public func getFormat() -> Format? {
        return self.format
    }
    
}
