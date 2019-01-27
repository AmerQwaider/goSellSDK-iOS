//
//  PayButtonInternalImplementation.swift
//  goSellSDK
//
//  Copyright © 2019 Tap Payments. All rights reserved.
//

internal protocol PayButtonInternalImplementation: PayButtonProtocol, SessionProtocol {
	
	var session:	InternalSession			{ get }
    var uiElement:	TapButton?				{ get }
	var handler:	WrappedAndTypeErased?	{ get set }
    
    func updateDisplayedState()
}

internal extension PayButtonInternalImplementation {
    
    // MARK: - Internal -
    // MARK: Methods
	
	internal func updateAppearance() {
		
		if self.updateHandlerIfRequired() {
			
			if let payHandler: PayButtonHandler = self.handler?.unwrapped() {
				
				payHandler.buttonStyle = self.requiredButtonType
				payHandler.updateButtonState()
			}
			else if let saveHandler: SaveButtonHandler = self.handler?.unwrapped() {
				
				saveHandler.buttonStyle = self.requiredButtonType
				saveHandler.updateButtonState()
			}
		}
	}
	
	// MARK: - Private -
	
	private typealias PayButtonHandler	= Process.TapButtonHandler<PaymentClass>
	private typealias SaveButtonHandler	= Process.TapButtonHandler<CardSavingClass>
	
	// MARK: Properties
	
	private var transactionMode: TransactionMode {
		
		let mode = self.session.dataSource?.mode ?? .default
		
		return mode
	}
	
	private var requiredButtonType: TapButtonStyle.ButtonType {
		
		let mode = self.transactionMode
		let type: TapButtonStyle.ButtonType = mode == .cardSaving ? .save : .pay
		
		return type
	}
	
	private var amount: AmountedCurrency? {
		
		let mode = self.transactionMode
		
		guard mode == .purchase || mode == .authorizeCapture else { return nil }
		
		var amountedCurrency: AmountedCurrency?
		
		if
			let amount				= self.session.calculateDisplayedAmount(),
			let optionalCurrency	= self.session.dataSource?.currency,
			let currency			= optionalCurrency {
			
			amountedCurrency = AmountedCurrency(currency, amount.decimalValue)
		}
		else {
			
			amountedCurrency = nil
		}
		
		return amountedCurrency
	}
	
	private var canSave: Bool {
		
		return Process.Validation.canStart(using: self.session)
	}
	
	// MARK: Methods
	
	private func updateHandlerIfRequired() -> Bool {
		
		let type = self.requiredButtonType
		
		switch type {
			
		case .pay:
			
			if let existing: PayButtonHandler = self.handler?.unwrapped() {
				
				existing.amount = self.amount
				return true
			}
			else {
				
				let payHandler = PayButtonHandler()
				payHandler.clickCallback = { self.session.start() }
				payHandler.amount = self.amount
				payHandler.setButton(self.uiElement)
				payHandler.buttonStyle = type
				
				self.handler = WrappedAndTypeErased(payHandler)
				
				return false
			}
			
		case .save, .draewilSave:
			
			if let existing: SaveButtonHandler = self.handler?.unwrapped() {
				
				existing.makeButtonEnabled(self.canSave)
				return true
			}
			else {
				
				let saveHandler = SaveButtonHandler()
				saveHandler.clickCallback = { self.session.start() }
				saveHandler.setButton(self.uiElement)
				saveHandler.buttonStyle = type
				
				self.handler = WrappedAndTypeErased(saveHandler)
				
				return false
			}
			
		case .confirmOTP:
			
			fatalError("Impossible case here.")
		}
	}
}
