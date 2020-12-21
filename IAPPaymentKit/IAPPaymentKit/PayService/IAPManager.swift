//
//  IAPManager.swift
//  FPVGreat
//
//  Created by youzu on 2020/12/9.
//

import UIKit
import SwiftyStoreKit
import RxSwift
import StoreKit
import Alamofire

class IAPManager: NSObject {
    
    class PayInfoConfig: NSObject {
        var pay_app_id: String!
        var pay_app_key: String!
    }

    static let share = IAPManager()
    
    let disposeBag = DisposeBag()
    
    var cofig: PayInfoConfig?
        
    var dispatchQueueConcurrent = DispatchQueue.init(label: "cache_operation", qos: .default, attributes: .concurrent)
    
    var group = DispatchGroup()
    
    private override init() {
        super.init()
        SwiftyStoreKit.shouldAddStorePaymentHandler = {
            (payment, product) in
            return true
        }
    }
    
    deinit {
        
    }


    //获取购买商品信息
    func retrieveProductsInfo(product_id: String, finish: ((SKProduct?) -> ())?) {
        dispatchQueueConcurrent.async(flags: .barrier) {
//            guard let `self` = self else {
//                finish?(nil)
//                return
//            }
            SwiftyStoreKit.retrieveProductsInfo([product_id]) { result in
                if result.retrievedProducts.count > 0 {
                    let product = result.retrievedProducts.first(where: { (product) -> Bool in
                        product.productIdentifier.isEqualTo(str: product_id)
                    })
                    guard let skproduct = product else {
                        finish?(nil)
                        return
                    }
                    finish?(skproduct)
//                    self.purchaseProduct(product_id: product_id, skProduct: skproduct, quantity: 1, orderId: orderId)
                }else if let invalidProductId = result.invalidProductIDs.first {
                    print("Invalid product identifier: \(invalidProductId)")
//                    self.showErrorMsg(str: "内购商品信息出错")
                    finish?(nil)
                }else {
                    print("Error: \(String(describing: result.error))")
//                    self.showErrorMsg(str: nil)
                    finish?(nil)

                }
            }
        }
    }
    //购买商品
    func purchaseProduct(product_id: String, skProduct: SKProduct, quantity: String, orderId: String, finish: ((Bool) -> ())?) {
        
        func realPruchase(product_id: String, skProduct: SKProduct, quantity: String, orderId: String, finishHandler: ((Bool) -> ())?) {
            SwiftyStoreKit.purchaseProduct(skProduct, quantity: 1, atomically: false) { result in
                switch result {
                case .success(let purchase):
                    print("Purchase Success: \(purchase.productId)")
                    
                    var orderTranctionModel = OrderTranctionModel()
                    orderTranctionModel.order_id = orderId
                    orderTranctionModel.transaction_id = purchase.transaction.transactionIdentifier
                    orderTranctionModel.product_id = purchase.productId
                    orderTranctionModel.amount = quantity
                    IAPTranctionCacheManager.share.saveHistory(for: orderTranctionModel, userId: userId)
//                    print(IAPTranctionCacheManager.share.testList())
                    self.uploadTransitionToServer(userId: userId, orderId: orderId, product_id: purchase.productId, tranction_id: purchase.transaction.transactionIdentifier ?? "", amount: quantity) { (finish) in
                        if finish {
                            SwiftyStoreKit.finishTransaction(purchase.transaction)
                        }
                        HUDHelper.hideProgress(onView: nil)
                        finishHandler?(finish)
                    }
                case .error(let error):
                    switch error.code {
                    case .unknown: print("Unknown error. Please contact support")
                    case .clientInvalid: print("Not allowed to make the payment")
                    case .paymentCancelled: break
                    case .paymentInvalid: print("The purchase identifier was invalid")
                    case .paymentNotAllowed: print("The device is not allowed to make the payment")
                    case .storeProductNotAvailable: print("The product is not available in the current storefront")
                    case .cloudServicePermissionDenied: print("Access to cloud service information is not allowed")
                    case .cloudServiceNetworkConnectionFailed: print("Could not connect to the network")
                    case .cloudServiceRevoked: print("User has revoked permission to use this cloud service")
                    default: print((error as NSError).localizedDescription)
                    }
                    finishHandler?(false)
                }
            }
        }
        let userId = SSaiLoginUser.share.user_id ?? ""
        realPruchase(product_id: product_id, skProduct: skProduct, quantity: quantity, orderId: orderId) { (succ) in
            finish?(succ)
        }
//        self.completeIAPTransactions(userId: userId) {
//            realPruchase(product_id: product_id, skProduct: skProduct, quantity: quantity, orderId: orderId) { (succ) in
//                finish?(succ)
//            }
//        }
       
    }
    
    //获取付款的凭证
    func getReceiptFor(useId: String?, orderId: String, product_id: String, receiptHandler: @escaping (String?) -> ()) {
        SwiftyStoreKit.fetchReceipt(forceRefresh: true) { result in
            switch result {
            case .success(let receiptData):
                let encryptedReceipt = receiptData.base64EncodedString(options: [])
//                print("Fetch receipt success:\n\(encryptedReceipt)")
                receiptHandler(encryptedReceipt)
            case .error(let error):
                print("Fetch receipt failed: \(error)")
                receiptHandler(nil)
            }
        }
    }

}

extension IAPManager {
    
    //购买的时候调用，并缓存
    func uploadTransitionToServer(userId: String, orderId: String, product_id: String, tranction_id: String, amount: String, finish: @escaping (Bool) -> ()) {
//        let cacheManager = IAPTracCacheManager.share
        self.getReceiptFor(useId: userId, orderId: orderId, product_id: product_id) { [weak self](receipt) in
            guard  let recei = receipt else { return }
            //删除订单和交易号缓存
            IAPTranctionCacheManager.share.deleteHistorys(for: tranction_id, userId: userId)
//            print(IAPTranctionCacheManager.share.testList())

            //本地缓存
            var tranctionModel = OrderTranctionModel()
            tranctionModel.order_id = orderId
            tranctionModel.transaction_id = tranction_id
            tranctionModel.product_id = product_id
            tranctionModel.receipt = recei
            tranctionModel.amount = amount
            IAPTracCacheManager.share.saveHistory(for: tranctionModel, userId: userId)
//            print(IAPTracCacheManager.share.testList())

            self?.deliverReciptToServer(receipe: recei, orderId: orderId, userId: userId, product_id: product_id, trannction_id: tranction_id, amount: amount) { (success) in
                finish(success)
            }
//            cacheManager.getOrderIdFromTranction(with: recei, userId: userId) {
//                [weak self](orderId) in
//                guard let `self` = self, let `orderId` = orderId else {
//                    return
//                }
//                self.deliverReciptToServer(receipe: recei, orderId: orderId, userId: userId, product_id: product_id, trannction_id: tranction) { (success) in
//                    finish(success)
//                }
//
//            }
        }
    }
    
    //上传凭证到服务器，服务器去验证
    func deliverReciptToServer(receipe: String, orderId: String, userId: String, product_id: String, trannction_id: String, amount: String, finish: @escaping (Bool) -> ()) {
        PaymentRequestProvider.tryUserIsOffline(token:.uploadtransaction(order_id: orderId, transaction_id: trannction_id, transaction: receipe, user_id: userId, product_id: product_id, amount: amount))
            .asObservable()
            .mapBaseModel(AnyModel.self)
            .subscribe(onNext: { (model) in
                IAPTracCacheManager.share.deleteHistorys(for: trannction_id, userId: userId)
//                print(IAPTracCacheManager.share.testList())
                finish(true)
            }, onError: { (error) in
                if NetworkReachabilityManager()?.isReachable == true {
                    finish(true)
                }else{
                    finish(false)
                }
            }, onCompleted: nil, onDisposed: nil).disposed(by: self.disposeBag)
    }
    
}

extension IAPManager {
    //启动的时候上传 或者退出登录的时候上传
    func uploadReceiptComplete(userId: String, finish: (() -> ())? = nil) {
        //缓存凭证上传
        func uploadReceiptAction(userId: String, finishHandler: (() -> ())? = nil) {
            
            IAPTracCacheManager.share.fetchHistoryList(userId: userId) { [weak self](receiptList) in
                guard let `self` = self, let recps = receiptList, recps.count > 0 else {
                    finishHandler?()
                    return
                }
                for recpModel in recps {
                    self.dispatchQueueConcurrent.async(group: self.group, execute: DispatchWorkItem.init(block: {
                        self.deliverReciptToServer(receipe: recpModel.receipt, orderId: recpModel.order_id, userId: userId, product_id: recpModel.product_id, trannction_id: recpModel.transaction_id, amount: recpModel.amount) { (finish) in
                        }
                    }))
                }
                self.group.notify(queue: self.dispatchQueueConcurrent, work: DispatchWorkItem.init(block: {
                    IAPTracCacheManager.share.fetchHistoryList(userId: userId) { (list) in
                        if let li = list, li.count > 0 {
                            finishHandler?()
                            return
                        }
                        SwiftyStoreKit.completeTransactions(atomically: true) { (purchase) in
                            finishHandler?()
                        }
                    }
                }))
            }
        }
        //上传未完的交易
        completeIAPTransactions(userId: userId) {
            uploadReceiptAction(userId: userId) {
                finish?()
            }
        }
       
    }
    //完成购买流程，有些购买没有成功
    func completeIAPTransactions(userId: String, finishBlock: @escaping () -> ()) {
      
        SwiftyStoreKit.completeTransactions(atomically: true) { purchases in
            
            if purchases.count > 0 {
                
                for purchase in purchases {
                    switch purchase.transaction.transactionState {
                    case .purchased, .restored:
                        if purchase.needsFinishTransaction {
                            // Deliver content from server, then:
                            IAPTranctionCacheManager.share.fetchHistoryList(userId: userId) { (models) in
                                guard let list = models, list.count  > 0 else{
                                    finishBlock()
                                    SwiftyStoreKit.finishTransaction(purchase.transaction)
                                    return
                                }
                                let orderModel = list.first { (tranModel) -> Bool in
                                    return tranModel.transaction_id.isEqualTo(str: purchase.transaction.transactionIdentifier ?? "")
                                }
                                guard let realModel = orderModel else{
                                    finishBlock()
                                    SwiftyStoreKit.finishTransaction(purchase.transaction)
                                    return
                                }
                                
                                self.uploadTransitionToServer(userId: userId, orderId: realModel.order_id, product_id: purchase.productId, tranction_id: purchase.transaction.transactionIdentifier ?? "", amount: realModel.amount) { (finish) in
                                    if finish {
                                        SwiftyStoreKit.finishTransaction(purchase.transaction)
                                    }
                                    finishBlock()
                                }
                                
                            }
                            
                        }
                        print("\(purchase.transaction.transactionState.debugDescription): \(purchase.productId)")
                    case .failed, .deferred:
                        SwiftyStoreKit.finishTransaction(purchase.transaction)
                        finishBlock()
                        break // do nothing
                    case .purchasing:
                        finishBlock()
                        break
                    @unknown default:
                        finishBlock()
                        break // do nothing
                    }
                }
                
            }else{
                finishBlock()
            }
        }
    }
    
}

extension IAPManager {
    func updatePayInfo(with app_id: String?, app_key: String?) {
        let config = IAPManager.PayInfoConfig()
        config.pay_app_id = app_id
        config.pay_app_key = app_key
        self.cofig = config
    }
}
//extension IAPManager {
//    func requestProducts() {
//        if !SKPaymentQueue.canMakePayments() {
//           assert(true,"手机没有打开程序内付费")
//            return
//        }
//
//    }
//}
//extension IAPManager: SKPaymentTransactionObserver {
//
//    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
//
//    }
//
//
//
//}
