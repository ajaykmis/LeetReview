import XCTest
@testable import LeetReview

final class CacheManagerTests: XCTestCase {

    private let cache = CacheManager.shared
    private let testKey = "test_cache_key_\(UUID().uuidString)"

    override func tearDown() async throws {
        try await super.tearDown()
        await cache.remove(key: testKey)
    }

    func testCacheAndRetrieveData() async {
        let data = "hello world".data(using: .utf8)!
        await cache.cache(key: testKey, data: data)

        let retrieved = await cache.get(key: testKey)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved, data)
    }

    func testCacheAndRetrieveCodable() async {
        struct TestModel: Codable, Equatable {
            let name: String
            let value: Int
        }

        let model = TestModel(name: "test", value: 42)
        await cache.cache(key: testKey, value: model)

        let retrieved = await cache.get(key: testKey, as: TestModel.self)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved, model)
    }

    func testExistsReturnsTrueForCachedKey() async {
        let data = "test".data(using: .utf8)!
        await cache.cache(key: testKey, data: data)
        let exists = await cache.exists(key: testKey)
        XCTAssertTrue(exists)
    }

    func testExistsReturnsFalseForMissingKey() async {
        let exists = await cache.exists(key: "nonexistent_key_\(UUID().uuidString)")
        XCTAssertFalse(exists)
    }

    func testRemoveDeletesCachedData() async {
        let data = "test".data(using: .utf8)!
        await cache.cache(key: testKey, data: data)
        let existsBefore = await cache.exists(key: testKey)
        XCTAssertTrue(existsBefore)

        await cache.remove(key: testKey)
        let existsAfter = await cache.exists(key: testKey)
        XCTAssertFalse(existsAfter)
    }

    func testCacheSizeReturnsNonNegative() async {
        let size = await cache.cacheSize()
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

    func testGetReturnsNilForMissingKey() async {
        let result = await cache.get(key: "definitely_missing_\(UUID().uuidString)")
        XCTAssertNil(result)
    }

    func testGetCodableReturnsNilForMissingKey() async {
        struct Dummy: Codable { let x: Int }
        let result = await cache.get(key: "definitely_missing_\(UUID().uuidString)", as: Dummy.self)
        XCTAssertNil(result)
    }
}
