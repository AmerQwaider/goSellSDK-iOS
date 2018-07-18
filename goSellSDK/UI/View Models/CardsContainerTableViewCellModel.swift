//
//  CardsContainerTableViewCellModel.swift
//  goSellSDK
//
//  Copyright © 2018 Tap Payments. All rights reserved.
//

internal class CardsContainerTableViewCellModel: TableViewCellViewModel {
    
    // MARK: - Internal -
    // MARK: Properties
    
    internal weak var cell: CardsContainerTableViewCell?
    
    internal var collectionViewCellModels: [CardCollectionViewCellModel]
    
    internal lazy var cardsCollectionViewHandler: CardsContainerTableViewCellModelCollectionViewHandler = CardsContainerTableViewCellModelCollectionViewHandler(model: self)
    
    // MARK: Methods
    
    internal init(indexPath: IndexPath, cards: [SavedCard]) {
        
        self.cards = cards
        self.collectionViewCellModels = type(of: self).generateCollectionViewCellModels(with: cards)
        super.init(indexPath: indexPath)
    }
    
    // MARK: - Private -
    // MARK: Properties
    
    private let cards: [SavedCard]
}

// MARK: - SingleCellModel
extension CardsContainerTableViewCellModel: SingleCellModel {}