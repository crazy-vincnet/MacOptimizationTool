import Foundation
import Testing
@testable import MacOptimizationCore

/// 메뉴바 네트워크 속도 계산 회귀 테스트.
/// `if_data.ifi_ibytes` 는 u_int32_t 라 4 GiB 마다 랩어라운드한다.
/// 이 경계에서 부호 없는 뺄셈을 그대로 하면 프로세스가 트랩됐다 (v1.7.3 크래시).
@Suite("네트워크 처리량 계산")
struct NetworkThroughputTests {

    @Test("정상 증가분은 초당 바이트로 환산된다")
    func computesRateForNormalIncrease() {
        let rate = NetworkThroughput.bytesPerSecond(current: 3_000, previous: 1_000, interval: 2.0)
        #expect(rate == 1_000)
    }

    @Test("카운터가 되돌아가면 값을 지어내지 않고 nil 을 돌려준다")
    func returnsNilWhenCounterRollsBack() {
        // 32비트 카운터가 4 GiB 를 넘겨 0 근처로 되돌아간 상황.
        let rate = NetworkThroughput.bytesPerSecond(current: 512, previous: 4_294_966_000, interval: 2.0)
        #expect(rate == nil)
    }

    @Test("인터페이스가 사라져 누적치가 줄어도 nil 이다")
    func returnsNilWhenTotalShrinks() {
        #expect(NetworkThroughput.bytesPerSecond(current: 10, previous: 11, interval: 2.0) == nil)
    }

    @Test("시간 간격이 0 이하면 nil 이다")
    func returnsNilForNonPositiveInterval() {
        #expect(NetworkThroughput.bytesPerSecond(current: 100, previous: 0, interval: 0) == nil)
        #expect(NetworkThroughput.bytesPerSecond(current: 100, previous: 0, interval: -1) == nil)
    }

    @Test("증가분이 없으면 0 이다")
    func returnsZeroWhenIdle() {
        #expect(NetworkThroughput.bytesPerSecond(current: 5_000, previous: 5_000, interval: 2.0) == 0)
    }

    @Test("UInt64 최대값 근처에서도 트랩하지 않는다")
    func doesNotTrapNearUInt64Max() {
        #expect(NetworkThroughput.bytesPerSecond(current: UInt64.max, previous: 0, interval: 1.0) != nil)
        #expect(NetworkThroughput.bytesPerSecond(current: 0, previous: UInt64.max, interval: 1.0) == nil)
    }
}
