import XCTest
@testable import LeetReview

final class CacheManagerTests: XCTestCase {

    private let cache = CacheManager.shared
    private let testKey = "test_cache_key_\(UUID().uuidString)"

    override func tearDown() {
        super.tearDown()
        cache.remove(key: testKey)
    }

    func testCacheAndRetrieveData() {
        let data = "hello world".data(using: .utf8)!
        cache.cache(key: testKey, data: data)

        let retrieved = cache.get(key: testKey)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved, data)
    }

    func testCacheAndRetrieveCodable() {
        struct TestModel: Codable, Equatable {
            let name: String
            let value: Int
        }

        let model = TestModel(name: "test", value: 42)
        cache.cache(key: testKey, value: model)

        let retrieved = cache.get(key: testKey, as: TestModel.self)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved, model)
    }

    func testExistsReturnsTrueForCachedKey() {
        let data = "test".data(using: .utf8)!
        cache.cache(key: testKey, data: data)
        XCTAssertTrue(cache.exists(key: testKey))
    }

    func testExistsReturnsFalseForMissingKey() {
        XCTAssertFalse(cache.exists(key: "nonexistent_key_\(UUID().uuidString)"))
    }

    func testRemoveDeletesCachedData() {
        let data = "test".data(using: .utf8)!
        cache.cache(key: testKey, data: data)
        XCTAssertTrue(cache.exists(key: testKey))

        cache.remove(key: testKey)
        XCTAssertFalse(cache.exists(key: testKey))
    }

    func testCacheSizeReturnsNonNegative() {
        let size = cache.cacheSize()
        XCTAssertGreaterThanOrEqual(size, 0)
    }

    func testCacheSizeStringReturnsNonEmpty() {
        let sizeString = cache.cacheSizeString()
        XCTAssertFalse(sizeString.isEmpty)
    }

    func testConvenienceKeys() {
        let detailKey = CacheManager.problemDetailKey("two-sum")
        XCTAssertEqual(detailKey, "problem_detail_two-sum")

        let codeKey = CacheManager.submissionCodeKey("12345")
        XCTAssertEqual(codeKey, "submission_code_12345")

        let listKey = CacheManager.submissionListKey("two-sum")
        XCTAssertEqual(listKey, "submission_list_two-sum")
    }

    func testGetReturnsNilForMissingKey() {
        let result = cache.get(key: "definitely_missing_\(UUID().uuidString)")
        XCTAssertNil(result)
    }

    func testGetCodableReturnsNilForMissingKey() {
        struct Dummy: Codable { let x: Int }
        let result = cache.get(key: "definitely_missing_\(UUID().uuidString)", as: Dummy.self)
        XCTAssertNil(result)
    }
}
