import XCTest
@testable import LeetReview

final class StoreManagerTests: XCTestCase {

    func testRemoveAdsProductID() {
        XCTAssertEqual(StoreManager.removeAdsProductID, "com.leetreview.removeads")
    }

    @MainActor
    func testInitialState() {
        let store = StoreManager()
        XCTAssertFalse(store.isPurchased)
        XCTAssertFalse(store.isLoading)
        XCTAssertNil(store.errorMessage)
        XCTAssertNil(store.removeAdsProduct)
    }

    @MainActor
    func testShouldShowAdsWhenNotPurchased() {
        let store = StoreManager()
        XCTAssertTrue(store.shouldShowAds)
    }

    @MainActor
    func testPriceStringDefaultsWhenNoProduct() {
        let store = StoreManager()
        XCTAssertEqual(store.priceString, "$4.99")
    }
}
