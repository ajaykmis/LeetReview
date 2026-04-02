import XCTest
import SwiftData
@testable import LeetReview

final class SM2AlgorithmTests: XCTestCase {

    // MARK: - SM2Algorithm.update tests

    @MainActor
    func testAgainResetsRepetitionsAndInterval() {
        let item = ReviewItem(
            titleSlug: "two-sum",
            title: "Two Sum",
            difficulty: "Easy",
            interval: 10.0,
            easeFactor: 2.5,
            repetitions: 3
        )

        SM2Algorithm.update(item: item, quality: .again)

        XCTAssertEqual(item.repetitions, 0)
        XCTAssertEqual(item.interval, 1.0)
        XCTAssertTrue(item.nextReviewDate > Date.now.addingTimeInterval(-60))
    }

    @MainActor
    func testHardAlsoResetsRepetitions() {
        let item = ReviewItem(
            titleSlug: "two-sum",
            title: "Two Sum",
            difficulty: "Easy",
            interval: 6.0,
            easeFactor: 2.5,
            repetitions: 2
        )

        SM2Algorithm.update(item: item, quality: .hard)

        // hard = quality 2 < 3, so resets
        XCTAssertEqual(item.repetitions, 0)
        XCTAssertEqual(item.interval, 1.0)
    }

    @MainActor
    func testGoodFirstRepSetsIntervalToOne() {
        let item = ReviewItem(
            titleSlug: "two-sum",
            title: "Two Sum",
            difficulty: "Easy",
            interval: 1.0,
            easeFactor: 2.5,
            repetitions: 0
        )

        SM2Algorithm.update(item: item, quality: .good)

        XCTAssertEqual(item.repetitions, 1)
        XCTAssertEqual(item.interval, 1.0)
    }

    @MainActor
    func testGoodSecondRepSetsIntervalToSix() {
        let item = ReviewItem(
            titleSlug: "two-sum",
            title: "Two Sum",
            difficulty: "Easy",
            interval: 1.0,
            easeFactor: 2.5,
            repetitions: 1
        )

        SM2Algorithm.update(item: item, quality: .good)

        XCTAssertEqual(item.repetitions, 2)
        XCTAssertEqual(item.interval, 6.0)
    }

    @MainActor
    func testGoodThirdRepMultipliesByEaseFactor() {
        let item = ReviewItem(
            titleSlug: "two-sum",
            title: "Two Sum",
            difficulty: "Easy",
            interval: 6.0,
            easeFactor: 2.5,
            repetitions: 2
        )

        SM2Algorithm.update(item: item, quality: .good)

        XCTAssertEqual(item.repetitions, 3)
        // EF updated first: 2.5 + (0.1 - 2*(0.08+2*0.02)) = 2.36, then 6.0 * 2.36 = 14.16
        XCTAssertEqual(item.interval, 6.0 * item.easeFactor, accuracy: 0.01)
    }

    @MainActor
    func testEasyIncreasesEaseFactor() {
        let item = ReviewItem(
            titleSlug: "two-sum",
            title: "Two Sum",
            difficulty: "Easy",
            interval: 6.0,
            easeFactor: 2.5,
            repetitions: 2
        )

        SM2Algorithm.update(item: item, quality: .easy)

        // EF' = 2.5 + (0.1 - (5 - 5) * (0.08 + (5 - 5) * 0.02)) = 2.5 + 0.1 = 2.6
        XCTAssertEqual(item.easeFactor, 2.6, accuracy: 0.01)
    }

    @MainActor
    func testEaseFactorNeverBelowMinimum() {
        let item = ReviewItem(
            titleSlug: "two-sum",
            title: "Two Sum",
            difficulty: "Hard",
            interval: 1.0,
            easeFactor: 1.3,
            repetitions: 0
        )

        SM2Algorithm.update(item: item, quality: .again)

        XCTAssertGreaterThanOrEqual(item.easeFactor, 1.3)
    }

    @MainActor
    func testNextReviewDateIsInFuture() {
        let item = ReviewItem(
            titleSlug: "two-sum",
            title: "Two Sum",
            difficulty: "Easy",
            interval: 1.0,
            easeFactor: 2.5,
            repetitions: 0
        )

        SM2Algorithm.update(item: item, quality: .good)

        XCTAssertTrue(item.nextReviewDate > Date.now)
    }

    // MARK: - ReviewQuality tests

    func testReviewQualityLabels() {
        XCTAssertEqual(ReviewQuality.again.label, "Again")
        XCTAssertEqual(ReviewQuality.hard.label, "Hard")
        XCTAssertEqual(ReviewQuality.good.label, "Good")
        XCTAssertEqual(ReviewQuality.easy.label, "Easy")
    }

    func testReviewQualityRawValues() {
        XCTAssertEqual(ReviewQuality.again.rawValue, 0)
        XCTAssertEqual(ReviewQuality.hard.rawValue, 2)
        XCTAssertEqual(ReviewQuality.good.rawValue, 3)
        XCTAssertEqual(ReviewQuality.easy.rawValue, 5)
    }
}
