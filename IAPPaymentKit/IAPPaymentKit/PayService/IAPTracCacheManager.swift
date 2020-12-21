//
//  IAPTracCacheManager.swift
//  FPVGreat
//
//  Created by youzu on 2020/12/10.
//

import UIKit
import SwiftyUserDefaults

struct OrderTranctionModel: Codable, DefaultsSerializable {
    var order_id: String!
    var transaction_id: String!
    var product_id: String!
    var receipt: String!
    var amount: String!
    init() {}
}

class IAPTracCacheManager: NSObject {
    
    static let share = IAPTracCacheManager()
    
    var dispatchQueueConcurrent = DispatchQueue.init(label: "cache_operation", qos: .default, attributes: .concurrent)
    
    private override init() { }
    
    
    func getUserId(user_id: String? = SSaiLoginUser.share.user_id) -> String {
        if let cuUser = user_id {
            return cuUser
        }else {
            var user_id =  "none"
            let isLogin = SSaiLoginManager.isUserLogin
            if isLogin {
                user_id = SSaiLoginUser.share.user_id ?? ""
            }
            return user_id
        }
    }
    

    //获取所有的历史记录
    func fetchHistoryList(userId: String? = nil, finishHandler: @escaping ([OrderTranctionModel]?) -> ()) {
        dispatchQueueConcurrent.async { [weak self] in
            guard let `self` = self else {
                return
            }
            let user_id = self.getUserId(user_id: userId)
            let historyModelsKey = ("orderTransaction_\(String.init(user_id))")
            let defaultHistoryKey = DefaultsKey<[OrderTranctionModel]?>(historyModelsKey)
            let searchHistoryList = Defaults[key: defaultHistoryKey]
            finishHandler(searchHistoryList)
        }
       
    }
    
    func saveHistory(for orderTranctionModel: OrderTranctionModel?, userId: String? = nil) {
        
        guard let tranctionModel = orderTranctionModel else {
            return
        }
        dispatchQueueConcurrent.async(flags: .barrier) { [weak self] in
            guard let `self` = self else { return }
            let user_id = self.getUserId(user_id: userId)
            let historyModelsKey = ("orderTransaction_\(String.init(user_id))")
            let defaultHistoryKey = DefaultsKey<[OrderTranctionModel]?>(historyModelsKey)
            self.fetchHistoryList(userId: userId) { (hisLists) in
                guard let hisList = hisLists, hisList.count > 0 else {
                    Defaults[key: defaultHistoryKey] = [tranctionModel]
                    return
                }
                var results = hisList.filter{ $0.transaction_id.caseInsensitiveCompare(tranctionModel.transaction_id) != .orderedSame}
                results.append(tranctionModel)
                Defaults[key: defaultHistoryKey] = results
            }
           
        }
    }
    
    func deleteHistorys(for tranction: String, userId: String? = nil) {
        dispatchQueueConcurrent.async(flags: .barrier) { [weak self] in
            guard let `self` = self else { return }
            let user_id = self.getUserId(user_id: userId)
            let historyModelsKey = ("orderTransaction_\(String.init(user_id))")
            let defaultHistoryKey = DefaultsKey<[OrderTranctionModel]?>(historyModelsKey)
            var localList = Defaults[key: defaultHistoryKey]
            localList = localList?.filter({ (model) -> Bool in
                return model.transaction_id != tranction
            })
            Defaults[key: defaultHistoryKey] = localList
        }
    }
    
    func testList(userId: String? = SSaiLoginUser.share.user_id) -> [OrderTranctionModel]?{
        let user_id = self.getUserId(user_id: userId)
        let historyModelsKey = ("orderTransaction_\(String.init(user_id))")
        let defaultHistoryKey = DefaultsKey<[OrderTranctionModel]?>(historyModelsKey)
        let searchHistoryList = Defaults[key: defaultHistoryKey]
        return searchHistoryList
    }
}
extension IAPTracCacheManager {
    func getOrderIdFromTranction(with: String, userId: String? = nil,finishHandler: @escaping (String?) -> ()){
        fetchHistoryList(userId: userId) { (cacheList) in
            guard let localList = cacheList else { return }
            let model = localList.filter { $0.transaction_id == with }.first
            if let order_id = model?.order_id{
                finishHandler(order_id)
                return
            }
            finishHandler(nil)
        }
    }
}
