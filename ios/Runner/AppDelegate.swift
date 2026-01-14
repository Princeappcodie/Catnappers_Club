import UIKit
import Flutter
import FirebaseCore
import StoreKit

@main
@objc class AppDelegate: FlutterAppDelegate, SKProductsRequestDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()

    GeneratedPluginRegistrant.register(with: self)

    let request = SKProductsRequest(productIdentifiers: Set(["catnappers_club_product"]))
    request.delegate = self
    request.start()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // MARK: - SKProductsRequestDelegate
  func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
    for product in response.products {
      print("Product: \(product.localizedTitle), ID: \(product.productIdentifier), Price: \(product.price)")
    }
    for invalidID in response.invalidProductIdentifiers {
      print("Invalid Product ID: \(invalidID)")
    }
  }
}