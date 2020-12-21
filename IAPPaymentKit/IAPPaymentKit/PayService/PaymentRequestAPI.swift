//
//  PaymentRequestAPI.swift
//  FPVGreat
//
//  Created by youzu on 2020/12/7.
//
import UIKit
import Moya
import RxSwift
import HandyJSON

let PaymentRequestProvider = MoyaProvider<PaymentRequestAPI>(session: AlamofireManager.sharedManager, plugins: [NetworkLoggerPlugin(configuration: .init(logOptions: .verbose))])


public enum PaymentRequestAPI {

    case uploadtransaction(order_id: String, transaction_id: String, transaction: String, user_id: String, product_id: String, amount: String)
}

extension PaymentRequestAPI: PaymentCustomRequestTarget {
    
    var pageSize: Int {
        return 20
    }
    // The path to be appended to `baseURL` to form the full `URL`.
    public var path: String {
        
        switch self {
//        case .paymentpay:
//            return "/payment/pay"
      
        case .uploadtransaction:
            return "/pay/apple"
       
        }
    }
    public var method: Moya.Method {
        return .post
    }
    /// The parameters to be incoded in the request.
    public var parameters: [String: Any]? {
        
        switch self {
        case .uploadtransaction(order_id: let order_id, transaction_id: let tranction_id, transaction: let transaction, user_id: let user_id, product_id: let product_id, amount: let amount):
//        case .uploadtransaction(order_id: let order_id, transaction_id: let tranction_id, transaction: let transaction):
            var param: [String: Any] = [:]
            let payInfo = IAPManager.share.cofig
            let appId = payInfo?.pay_app_id ?? "ONAJnG2L"
            let appKey = payInfo?.pay_app_key ?? "g6d1Bzs90Te8"
            let count = amount
            let originStr = "amount=\(count)&app_id=\(appId)&out_order_id=\(order_id)&product_id=\(product_id)&transaction_id=\(tranction_id)&user_id=\(user_id)\(appKey)"
            print(originStr)
            let sign = originStr.md5()
            print(transaction)
            param["sign"] = sign
            param["app_id"] = appId
            param["out_order_id"] = order_id
            param["user_id"] = user_id
            param["amount"] = count
            param["transaction_id"] = tranction_id
            param["transaction"] = transaction
            param["product_id"] = product_id

            return param
        }
    }
}

//struct LoginRequestManager {
//
//
//    func startRequest<T: HandyJSON>(with: PaymentRequestAPI, dispose: DisposeBag, mapModel: T, completion: ((BaseModel<T>) -> Void)? = nil, onError: ((Error) -> Void)? = nil) {
//        LoginRxRequestProvider.tryUserIsOffline(token:.signBefore).asObservable().mapBaseModel(T.self).subscribe(onNext: { (model) in
//            completion?(model)
//        }, onError: { (error) in
//            onError?(error)
//        }, onCompleted: nil, onDisposed: nil).disposed(by: dispose)
//
//    }
//
//}


