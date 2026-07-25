import Foundation

/// 누적 바이트 카운터로 초당 전송량을 계산한다.
///
/// `getifaddrs` 가 돌려주는 `if_data.ifi_ibytes` / `ifi_obytes` 는 **u_int32_t** 다.
/// 인터페이스가 4 GiB 를 넘겨 전송하면 카운터가 0 으로 되돌아가고, 인터페이스가
/// 사라지거나 재생성될 때도 누적치가 줄어든다. 이 경우 뺄셈을 그대로 하면
/// 부호 없는 정수 언더플로로 프로세스가 트랩된다.
public enum NetworkThroughput {

    /// 두 표본 사이의 초당 바이트 수.
    /// 카운터가 되돌아갔거나 시간 간격이 유효하지 않으면 `nil` — 지어낸 값을 돌려주지 않는다.
    public static func bytesPerSecond(current: UInt64, previous: UInt64, interval: TimeInterval) -> Double? {
        guard interval > 0 else { return nil }
        guard current >= previous else { return nil }
        return Double(current - previous) / interval
    }
}
