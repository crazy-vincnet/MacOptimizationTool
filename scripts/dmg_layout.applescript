-- DMG 설치 창 레이아웃 지정.
-- 사용법: osascript scripts/dmg_layout.applescript <볼륨이름> <앱번들이름> <배경파일이름>
--
-- Finder 는 아이콘 위치를 "뷰 설정이 이미 적용된 창"에서만 저장하므로,
-- 뷰 설정 → 닫기 → 다시 열기 → 위치 지정 순서를 지켜야 한다.

on run argv
    set volumeName to item 1 of argv
    set appName to item 2 of argv
    set backgroundFile to item 3 of argv

    tell application "Finder"
        -- 마운트 직후에는 디스크가 아직 보이지 않을 수 있으므로 잠시 기다린다.
        repeat 20 times
            if exists disk volumeName then exit repeat
            delay 0.5
        end repeat

        if not (exists disk volumeName) then
            error "볼륨을 찾을 수 없습니다: " & volumeName
        end if

        tell disk volumeName
            open
            delay 1

            set current view of container window to icon view
            set toolbar visible of container window to false
            set statusbar visible of container window to false
            set the bounds of container window to {200, 120, 840, 520}
            delay 1

            set viewOptions to the icon view options of container window
            set arrangement of viewOptions to not arranged
            set icon size of viewOptions to 128
            set text size of viewOptions to 12
            set label position of viewOptions to bottom
            -- `.background` 는 숨김 폴더라 Finder 의 folder/file 객체 조회로는 찾지 못한다(-1728).
            -- HFS 경로 문자열을 alias 로 변환해 지정해야 안정적으로 적용된다.
            -- 배경 폴더는 이 시점에 숨겨져 있으면 안 된다. 숨김 상태면 Finder 가 파일을
            -- 해석하지 못하고 배경을 단색으로 폴백해 버린다. (호출 측에서 나중에 숨긴다.)
            set background picture of viewOptions to file backgroundFile of folder "background"
            delay 1

            close
            delay 1
            open
            delay 2

            set position of item appName of container window to {165, 185}
            set position of item "Applications" of container window to {475, 185}
            delay 1

            update without registering applications
            -- 창을 닫지 않고 잠시 유지해야 Finder 가 .DS_Store 를 디스크에 기록한다.
            delay 3
        end tell
    end tell

    return "layout applied"
end run
