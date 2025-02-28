﻿# basic-ass-creator.ps1
# Script PowerShell tạo phụ đề ASS đẹp mắt từ file JSON của Whisper với hiệu ứng highlight từng từ

# ------------ CẤU HỆNH CHUNG ------------
# Biến toàn cục dùng cho toàn bộ script
$script:ampersand = [char]38 # Ký tự '&'
$script:backslash = [char]92 # Ký tự '\'
$script:defaultColor = "FFFFFF" # Màu chữ mặc định (định dạng: bbggrr)
$script:highlightColor = "0CF4FF" # Màu highlight (định dạng: bbggrr)
$script:outlineColor = "000000" # Màu viền
$script:shadowColor = "000000" # Màu bóng đổ
$script:titleText = "VIDEO TIẾNG VIỆT" # Văn bản tiêu đề

# ------------ CÁC HÀM XỬ LÝ CƠ BẢN ------------
# Hàm thêm số 0 vào đầu
function PadZero {
    param (
        [int]$num,
        [int]$length = 2
    )
    
    return $num.ToString().PadLeft($length, '0')
}

# Hàm chuyển đổi số giây thành định dạng thời gian ASS (H:MM:SS.cs)
function FormatAssTime {
    param (
        [double]$seconds
    )
    
    $totalCentiseconds = [Math]::Floor($seconds * 100)
    $cs = $totalCentiseconds % 100
    $totalSeconds = [Math]::Floor($totalCentiseconds / 100)
    $s = $totalSeconds % 60
    $totalMinutes = [Math]::Floor($totalSeconds / 60)
    $m = $totalMinutes % 60
    $h = [Math]::Floor($totalMinutes / 60)
    
    return "${h}:$(PadZero $m):$(PadZero $s).$(PadZero $cs)"
}

# ------------ TẠO NỘI DUNG ASS ------------
# Hàm tạo header cho file ASS
function CreateAssHeader {
    $bs = $script:backslash
    $amp = $script:ampersand
    
    # Tạo từng phần riêng biệt
    $scriptInfo = @"
[Script Info]
; Script generated by basic-ass-creator.ps1
Title: Beautiful ASS Subtitle
ScriptType: v4.00+
Collisions: Normal
PlayResX: 1920
PlayResY: 1080
Timer: 100.0000
WrapStyle: 0
"@

    $stylesHeader = @"

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
"@

    # Tạo style riêng lẻ
    $defColorPrimary = "${amp}H00FFFFFF"
    $defColorSecondary = "${amp}H000000FF" 
    $defColorOutline = "${amp}H00000000"
    $defColorShadow = "${amp}H80000000"
    
    $defaultStyle = "Style: Default,Arial,54,$defColorPrimary,$defColorSecondary,$defColorOutline,$defColorShadow,-1,0,0,0,100,100,0,0,1,2.5,1.5,2,10,10,30,1"
    $titleStyle = "Style: Title,Arial Black,64,$defColorPrimary,$defColorSecondary,$defColorOutline,$defColorShadow,-1,0,0,0,100,100,0,0,1,3,2,8,10,10,10,1"
    
    $eventsHeader = @"

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
"@

    # Kết hợp tất cả
    $header = $scriptInfo + $stylesHeader + "`n" + $defaultStyle + "`n" + $titleStyle + $eventsHeader
    return $header
}

# Hàm tạo dòng tiêu đề
function CreateTitleLine {
    $bs = $script:backslash
    $amp = $script:ampersand
    
    # Tạo tag fade
    $fadTag = "$bs" + "fad(300,300)"
    
    # Tạo tag màu
    $colorTag = "$bs" + "c$amp" + "H00FFFF"
    
    # Tạo tag viền
    $outlineTag = "$bs" + "3c$amp" + "H000000"
    
    # Tạo tag blur
    $blurTag = "$bs" + "blur0.8"
    
    # Kết hợp các tag
    $allTags = "{$fadTag$colorTag$outlineTag$blurTag}"
    
    # Tạo dòng dialogue hoàn chỉnh
    $titleLine = "Dialogue: 0,0:00:00.00,0:00:05.00,Title,,0,0,0,,$allTags$script:titleText"
    
    return $titleLine
}

# Hàm tạo dòng dialogue với hiệu ứng highlight từng từ
function CreateHighlightDialogueLine2 {
    param (
        [double]$startTime,
        [double]$endTime,
        [PSCustomObject[]]$wordObjects
    )
    
    $bs = $script:backslash
    $amp = $script:ampersand
    
    # Định dạng thời gian bắt đầu và kết thúc
    $startTimeAss = FormatAssTime $startTime
    $endTimeAss = FormatAssTime $endTime
    
    # Tạo tag fade đơn giản
    $fadeTag = "$bs" + "fad(200,200)"
    
    # Tạo các tag hiệu ứng cơ bản
    $blurTag = "$bs" + "blur0.5"
    $borderTag = "$bs" + "bord1.5"
    $shadowTag = "$bs" + "shad1"
    
    # Tạo tag hiệu ứng cơ bản
    $basicEffect = "{$fadeTag$blurTag$borderTag$shadowTag}"
    
    # Tạo tag màu mặc định và highlight
    $defaultColorTag = "$bs" + "c$amp" + "H$script:defaultColor"
    $highlightColorTag = "$bs" + "c$amp" + "H$script:highlightColor"
    $outlineTag = "$bs" + "3c$amp" + "H$script:outlineColor"
    
    # Xây dựng chuỗi phụ đề với hiệu ứng highlight
    $dialogueLines = @()
    
    # Tạo một dòng phụ đề với màu mặc định cho tất cả các từ
    $defaultText = "{$defaultColorTag$outlineTag}"
    foreach ($wordObj in $wordObjects) {
        $defaultText += "$($wordObj.word) "
    }
    $defaultText = $defaultText.TrimEnd()
    
    # Thêm dòng phụ đề mặc định (layer 0)
    $dialoguePrefix = "Dialogue: 0,$startTimeAss,$endTimeAss,Default,,0,0,0,,"
    $dialogueLines += $dialoguePrefix + $basicEffect + $defaultText
    
    # Tạo các dòng phụ đề highlight cho từng từ (layer 1)
    foreach ($wordObj in $wordObjects) {
        $wordStart = $wordObj.start
        $wordEnd = $wordObj.end
        
        # Chỉ tạo highlight nếu từ nằm trong khoảng thời gian của đoạn
        if (($wordStart -ge $startTime) -and ($wordEnd -le $endTime)) {
            # Định dạng thời gian bắt đầu và kết thúc cho từng từ
            $wordStartAss = FormatAssTime $wordStart
            $wordEndAss = FormatAssTime $wordEnd
            
            # Tạo văn bản phụ đề với từ được highlight
            $highlightText = ""
            
            # Tạo văn bản với từ được highlight
            $highlightText = "{$defaultColorTag$outlineTag}"
            
            for ($i = 0; $i -lt $wordObjects.Length; $i++) {
                $w = $wordObjects[$i]
                
                if ($w -eq $wordObj) {
                    # Đây là từ cần highlight
                    $highlightText += "{$highlightColorTag}$($w.word){$defaultColorTag}"
                } else {
                    # Đây là từ bình thường
                    $highlightText += "$($w.word)"
                }
                
                # Thêm khoảng trắng sau mỗi từ (trừ từ cuối cùng)
                if ($i -lt $wordObjects.Length - 1) {
                    $highlightText += " "
                }
            }
            
            # Thêm dòng highlight cho từ này
            $highlightPrefix = "Dialogue: 1,$wordStartAss,$wordEndAss,Default,,0,0,0,,"
            $dialogueLines += $highlightPrefix + "{$blurTag$borderTag$shadowTag}" + $highlightText
        }
    }
    
    return $dialogueLines -join "`n"
}

# Hàm chuyển đổi JSON thành ASS
function ConvertJsonToAss {
    param (
        [string]$whisperJsonPath,
        [string]$outputJsonPath,
        [string]$assFilePath = "subtitle.ass"
    )
    
    # Kiểm tra file JSON có tồn tại không
    if (-not (Test-Path $whisperJsonPath)) {
        Write-Error "File $whisperJsonPath không tồn tại."
        return $false
    }
    
    if (-not (Test-Path $outputJsonPath)) {
        Write-Error "File $outputJsonPath không tồn tại."
        return $false
    }
    
    try {
        # Đọc dữ liệu từ file JSON
        $whisperData = Get-Content -Path $whisperJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $outputData = Get-Content -Path $outputJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
        
        # Tạo header và tiêu đề cho file ASS
        $assHeader = CreateAssHeader
        $titleLine = CreateTitleLine
        $assContent = $assHeader + "`n" + $titleLine
        
        # Lấy dữ liệu từ whisper
        $transcription = $whisperData[0]
        $allWords = $transcription.words
        
        # Lấy dữ liệu từ output.json
        $groups = $outputData[0].groups
        
        # Xử lý từng nhóm phụ đề
        foreach ($group in $groups) {
            $startTime = $group.start
            $endTime = $group.end
            $startIndex = $group.startIndex
            $endIndex = $group.endIndex
            
            # Lấy các từ trong nhóm này từ whisper data
            $groupWords = $allWords[$startIndex..$endIndex]
            
            # Tạo hiệu ứng highlight cho nhóm từ này (sử dụng phương pháp thay thế)
            $dialogueLine = CreateHighlightDialogueLine2 $startTime $endTime $groupWords
            $assContent += "`n" + $dialogueLine
        }
        
        # Ghi nội dung ASS vào file
        $assContent | Out-File -FilePath $assFilePath -Encoding UTF8
        Write-Host "Đã tạo thành công file phụ đề ASS: $assFilePath"
        
        return $true
    }
    catch {
        Write-Error "Lỗi khi chuyển đổi file: $_"
        return $false
    }
}

# ------------ THỰC THI CHƯƠNG TRÌNH ------------
# Xác định đường dẫn file đầu vào và đầu ra
$whisperJsonFile = if ($args.Count -gt 0) { $args[0] } else { "whisper-transcription.json" }
$outputJsonFile = if ($args.Count -gt 1) { $args[1] } else { "output.json" }
$assFile = if ($args.Count -gt 2) { $args[2] } else { "subtitle.ass" }

# Chạy chương trình chuyển đổi
Write-Host "Bắt đầu chuyển đổi từ $whisperJsonFile và $outputJsonFile sang $assFile..."
$result = ConvertJsonToAss -whisperJsonPath $whisperJsonFile -outputJsonPath $outputJsonFile -assFilePath $assFile

# Kiểm tra kết quả
if (-not $result) {
    Write-Host "Chuyển đổi không thành công." -ForegroundColor Red
    exit 1
} else {
    Write-Host "Chuyển đổi thành công! File ASS đã được tạo với hiệu ứng highlight từng từ." -ForegroundColor Green
}
