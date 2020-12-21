//
//  PaymentCustomRequestTarget.swift
//  FPVGreat
//
//  Created by youzu on 2020/12/17.
//

import UIKit
import Foundation
import Moya

public protocol PaymentCustomRequestTarget: TargetType{
    var parameters: [String: Any]?{ get }
}

public extension PaymentCustomRequestTarget {
    
    var baseURL: URL {
        return URL(string: "https://payment-h5.youzu.com/api/v1")!
    }
    
    var headers: [String: String]? {
        return ["Content-Type": "application/x-www-form-urlencoded"]
    }
    var method: Moya.Method {
        return .post
    }
    
    var task: Task {
//        print(self.parameters)
        switch method {
        case .get:
            return .requestParameters(parameters: parameters ?? [:], encoding: URLEncoding.default)
        default:
            var multipartData = [MultipartFormData]()
            let para = parameters ?? [:]
            for (key, value) in para {
                if let strV = value as? String, let oriData = strV.data(using: .utf8){
                    let formData = MultipartFormData(provider: .data(oriData), name: key)
                    multipartData.append(formData)
                }
            }
            return .uploadMultipart(multipartData)
        }
    }
    
    var sampleData: Data {
        return "{\"code\"ok\",\"data\": {}}".data(using: .utf8)!
    }
}


