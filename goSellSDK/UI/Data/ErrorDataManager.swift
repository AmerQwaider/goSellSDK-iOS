//
//  ErrorDataManager.swift
//  goSellSDK
//
//  Copyright © 2019 Tap Payments. All rights reserved.
//

import struct TapAdditionsKit.TypeAlias

internal class ErrorDataManager {
    
    // MARK: - Internal -
    // MARK: Methods
    
    internal static func handle(_ error: TapSDKError, retryAction: TypeAlias.ArgumentlessClosure?, alertDismissButtonClickHandler: TypeAlias.ArgumentlessClosure?) {
        
        if let apiError = error as? TapSDKAPIError {
            
            self.handleAPIError(apiError, retryAction: retryAction, alertDismissButtonClickHandler: alertDismissButtonClickHandler)
        }
        else if let knownError = error as? TapSDKKnownError {
            
            self.handleKnownError(knownError, retryAction: retryAction, alertDismissButtonClickHandler: alertDismissButtonClickHandler)
        }
        else if let unknownError = error as? TapSDKUnknownError {
            
            self.handleUnknownError(unknownError, retryAction: retryAction, alertDismissButtonClickHandler: alertDismissButtonClickHandler)
        }
    }
    
    // MARK: - Private -
    // MARK: Methods
    
    private static func handleAPIError(_ error: TapSDKAPIError, retryAction: TypeAlias.ArgumentlessClosure?, alertDismissButtonClickHandler: TypeAlias.ArgumentlessClosure?) {
        
        guard let firstError = error.error.details.first else { return }
        self.handleErrorDetails(error.error.details, in: error, current: firstError, retryAction: retryAction, alertDismissButtonClickHandler: alertDismissButtonClickHandler)
    }
    
    private static func handleErrorDetails(_ errorDetails: [ErrorDetail], in error: TapSDKError, current: ErrorDetail, retryAction: TypeAlias.ArgumentlessClosure?, alertDismissButtonClickHandler: TypeAlias.ArgumentlessClosure?) {
        
        self.handleErrorDetail(current, in: error, retryAction: retryAction, alertDismissButtonClickHandler: alertDismissButtonClickHandler) { (retryUsed) in
            
            guard !retryUsed else { return }
            
            guard let index = errorDetails.index(of: current), index < errorDetails.count - 1 else { return }
            
            let nextIndex = errorDetails.index(after: index)
            self.handleErrorDetails(errorDetails, in: error, current: errorDetails[nextIndex], retryAction: retryAction, alertDismissButtonClickHandler: alertDismissButtonClickHandler)
        }
    }
    
    private static func handleKnownError(_ error: TapSDKKnownError, retryAction: TypeAlias.ArgumentlessClosure?, alertDismissButtonClickHandler: TypeAlias.ArgumentlessClosure?) {
        
        switch error.type {
            
        case .internal:
            
            guard let nsError = error.error as NSError? else { return }
            
            guard let internalErrorCode = InternalError(rawValue: nsError.code) else { return }
            let errorCode = self.errorCode(from: internalErrorCode)
            
            let errorDetail = ErrorDetail(code: errorCode)
            self.handleErrorDetail(errorDetail, in: error, retryAction: retryAction, alertDismissButtonClickHandler: alertDismissButtonClickHandler)
            
        case .serialization:
            
            let errorDetail = ErrorDetail(code: .serialization)
            self.handleErrorDetail(errorDetail, in: error, retryAction: retryAction, alertDismissButtonClickHandler: alertDismissButtonClickHandler)
            
        case .network:
            
            if let nsError = error.error as NSError?, nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
                
                let errorDetail = ErrorDetail(code: .cancel)
                self.handleErrorDetail(errorDetail, in: error, retryAction: retryAction, alertDismissButtonClickHandler: alertDismissButtonClickHandler)
            }
            else {
            
                let errorDetail = ErrorDetail(code: .network)
                self.handleErrorDetail(errorDetail, in: error, retryAction: retryAction, alertDismissButtonClickHandler: alertDismissButtonClickHandler)
            }
            
        case .unknown:
            
            let errorDetail = ErrorDetail(code: .unknown)
            self.handleErrorDetail(errorDetail, in: error, retryAction: retryAction, alertDismissButtonClickHandler: alertDismissButtonClickHandler)
            
        case .api:
        
            let errorDetail = ErrorDetail(code: .unknown)
            self.handleErrorDetail(errorDetail, in: error, retryAction: retryAction, alertDismissButtonClickHandler: alertDismissButtonClickHandler)
        }
    }
    
    private static func handleUnknownError(_ error: TapSDKUnknownError, retryAction: TypeAlias.ArgumentlessClosure?, alertDismissButtonClickHandler: TypeAlias.ArgumentlessClosure?) {
        
        let errorDetail = ErrorDetail(code: .unknown)
        self.handleErrorDetail(errorDetail, in: error, retryAction: retryAction, alertDismissButtonClickHandler: alertDismissButtonClickHandler)
    }
    
    private static func errorCode(from internalErrorCode: InternalError) -> ErrorCode {
        
        switch internalErrorCode {
            
        case .invalidCountryCode:           return .invalidCountryCode
        case .invalidAmountModificatorType: return .invalidAmountModificatorType
        case .invalidAuthorizeActionType:   return .invalidAuthorizeAutoScheduleType
        case .invalidCurrency:              return .invalidCurrency
        case .invalidCustomerInfo:          return .missingCustomerIDOrCustomerInformation
		case .customerAlreadyExists:		return .customerAlreadyExists
		case .cardAlreadyExists:			return .cardAlreadyExists
        case .invalidEmail:                 return .invalidEmailAddress
        case .invalidISDNumber:             return .invalidPhoneNumberCountryCode
        case .invalidPhoneNumber:           return .invalidPhoneNumber
        case .invalidUnitOfMeasurement:     return .invalidUnitOfMeasurement
        case .invalidMeasurement:           return .invalidMeasurement
        case .invalidEnumValue:             return .invalidEnumValue

        }
    }
    
    private static func handleErrorDetail(_ errorDetail: ErrorDetail, in error: TapSDKError, retryAction: TypeAlias.ArgumentlessClosure?, alertDismissButtonClickHandler: TypeAlias.ArgumentlessClosure?, completion: TypeAlias.BooleanClosure? = nil) {
        
        let action = self.action(for: errorDetail.code)
        
        let paymentPotentiallyClosedClosure: TypeAlias.ArgumentlessClosure = {
            
            if action.contains(.alert) {
                
                let titleKey = LocalizationStorage.alertTitleKey(for: errorDetail.code)
                let messageKey = LocalizationStorage.alertMessageKey(for: errorDetail.code)
                
                let alertTitle = LocalizationStorage.localizedString(for: titleKey)
                let alertMessage = LocalizationStorage.localizedString(for: messageKey)
                
                let localCompletion: TypeAlias.BooleanClosure  = { (retryClicked) in
                    
                    if !retryClicked {
                        
                        alertDismissButtonClickHandler?()
                    }
                    
                    completion?(retryClicked)
                }
                
                if action.contains(.retry) {
                    
                    ErrorActionExecutor.showAlert(with: alertTitle, message: alertMessage, retryAction: retryAction, completion: localCompletion)
                }
                else {
                    
                    ErrorActionExecutor.showAlert(with: alertTitle, message: alertMessage, retryAction: nil, completion: localCompletion)
                }
            }
        }
        
        if action.contains(.closePayment) {
            
            ErrorActionExecutor.closePayment(with: error, paymentPotentiallyClosedClosure)
        }
        else {
            
            paymentPotentiallyClosedClosure()
        }
    }
    
    private static func action(for code: ErrorCode) -> ErrorAction {
        
        switch code {
            
        case .requestHeadersMissing,
             .keyAndEnvironmentMismatch,
             .emptyRequest,
             .invalidCustomerID,
             .customerNotFound,
             .customerIDMismatch,
			 .customerAlreadyExists,
             .redirectURLMissing,
             .redirectURLInvalid,
             .invalidMerchantOrderReference,
             .invalidMerchantTransactionReference,
             .invalidStatementDescriptor,
             .invalidDescription,
             .missingSourceID,
             .invalidSourceID,
             .invalidMetadataKey,
             .invalidMetadataValue,
             .invalidJSONRequest,
             .applicationRequired:
            
            return .closePayment
            
        case .invalidInput,
             .saveCardFeatureDisabled,
             .non3DSecureTransactionsForbidden,
             .authorizeIDMissing,
             .authorizeIDInvalid,
             .authorizeStatus,
             .authorizeIDNotFound,
             .saveCardFeatureNotSupported,
             .invalidCardNumber,
             .invalidExpirationDate,
             .missingChargeID,
             .invalidChargeID,
             .chargeIDNotFound,
             .missingConfirmationCode,
             .invalidConfirmationCode,
             .currencyCodeMismatch,
             .captureAmountExceeds,
             .invalidCountryCode,
             .serialization,
             .invalidEnumValue,
			 .cardAlreadyExists:
            
            return .alert
            
        case .sourceAlreadyUsed,
             .gatewayTimeout,
             .serverUnavailable,
             .requestNotFound,
             .network,
             .unknown:
            
            return [.retry, .alert]
            
        case .missingCustomerIDOrCustomerInformation,
             .missingCustomerFirstName,
             .missingCustomerLastName,
             .invalidCustomerFirstName,
             .invalidCustomerLastName,
             .invalidCustomerMiddleName,
             .missingPhoneNumber,
             .invalidPhoneNumberCountryCode,
             .invalidPhoneNumber,
             .invalidEmailAddress,
             .missingCustomerPhoneNumberAndEmail,
             .missingAuthenticationType,
             .invalidAuthorizeAutoScheduleType,
             .invalidAuthorizeAutoScheduleTime,
             .invalidAuthenticationType,
             .invalidAmountModificatorType,
             .invalidUnitOfMeasurement,
             .invalidMeasurement,
             .invalidAmount,
             .invalidCurrency,
             .unsupportedCurrency,
             .missingCustomerID,
             .invalidAPIKey,
             .missingAPICredentials,
             .publicKeyGivenInsteadOfSecret,
             .permissionDenied:
            
            return [.alert, .closePayment]
            
        case .missingBINNumber,
             .invalidBINNumber,
             .cancel:
            
            return .tap_none
        }
    }
}
