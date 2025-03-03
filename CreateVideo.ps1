# CreateVideo.ps1
# Phiên bản PowerShell script tích hợp tạo video với hiệu ứng Ken Burns, xfade (smoothleft),
# kết hợp âm thanh, thêm phụ đề ASS với hiệu ứng karaoke và cleanup các file tạm.

# -------------------------------
# 1. Kiểm tra sự tồn tại của các file cần thiết
# -------------------------------

$times = @(5.42, 5.82, 4.26, 3.82, 2.98, 5.8, 4.42, 7.36)
$imgFiles = 1..8 | ForEach-Object { "$_.jpeg" }
$missingFiles = 0
Write-Host "Checking image files..."
foreach ($img in $imgFiles) {
    if (-not (Test-Path $img)) {
        Write-Error "Error: File $img not found."
        $missingFiles++
    }
}
if ($missingFiles -gt 0) {
    Write-Error "$missingFiles image files missing. Exiting."
    exit 1
}

# Kiểm tra file âm thanh
foreach ($file in @("voice.mp3", "bg.mp3")) {
    if (-not (Test-Path $file)) {
        Write-Error "Error: File $file not found."
        exit 1
    }
}

# Kiểm tra và chuyển đổi từ SRT sang ASS nếu cần
if ((Test-Path "subtitle.srt") -and (-not (Test-Path "subtitle.ass"))) {
    Write-Host "Converting subtitle.srt to subtitle.ass..."
    # Chạy script basic-ass-creator.ps1 để chuyển đổi SRT sang ASS
    .\basic-ass-creator.ps1 subtitle.srt subtitle.ass
    if (-not (Test-Path "subtitle.ass")) {
        Write-Error "Error: Failed to convert subtitle.srt to subtitle.ass."
        exit 1
    }
    Write-Host "Conversion successful."
} elseif (-not (Test-Path "subtitle.ass")) {
    Write-Error "Error: Neither subtitle.srt nor subtitle.ass found."
    exit 1
}

# Tạo thư mục tạm nếu chưa có
$tempDir = "temp_videos"
if (-not (Test-Path $tempDir)) {
    New-Item -ItemType Directory -Path $tempDir | Out-Null
}

# -------------------------------
# 2. Thiết lập tham số video
# -------------------------------
$videoWidth    = 512
$videoHeight   = 768
$largeScale    = 3000
$fps           = 30
$preset        = "medium"
$videoQuality  = 20
$transitionDuration = 0.5
$zoomSpeed     = 0.0008
$maxZoom       = 1.3
$bitrate       = "3M"
$gopSize       = 15

$totalDuration = ($times | Measure-Object -Sum).Sum
Write-Host "Total video duration: $totalDuration seconds."

# -------------------------------
# 3. Xử lý từng ảnh với hiệu ứng Ken Burns
# -------------------------------
for ($i = 0; $i -lt $imgFiles.Count; $i++) {
    $img   = $imgFiles[$i]
    $time  = $times[$i]
    $frames = $time * $fps
    Write-Host "Processing image $img..."
    $outputVideo = "$tempDir\$($i+1).mp4"
    switch ($i+1) {
        1 { 
            $vf = "scale=${largeScale}:-1,zoompan=z='min(zoom+${zoomSpeed},${maxZoom})':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=${frames}:s=${videoWidth}x${videoHeight}:fps=${fps},setsar=1,format=yuv420p" 
        }
        2 { 
            $vf = "scale=${largeScale}:-1,zoompan=z='if(eq(on,1),${maxZoom},zoom-${zoomSpeed})':x='iw-iw/zoom':y='0':d=${frames}:s=${videoWidth}x${videoHeight}:fps=${fps},setsar=1,format=yuv420p" 
        }
        3 { 
            $vf = "scale=${largeScale}:-1,zoompan=z='min(zoom+${zoomSpeed},${maxZoom})':x='0':y='ih-ih/zoom':d=${frames}:s=${videoWidth}x${videoHeight}:fps=${fps},setsar=1,format=yuv420p" 
        }
        4 { 
            $vf = "scale=${largeScale}:-1,zoompan=z='1.1':x='min(max((iw-iw/zoom)*((on)/${frames}),0),iw)':y='ih/2-(ih/zoom/2)':d=${frames}:s=${videoWidth}x${videoHeight}:fps=${fps},setsar=1,format=yuv420p" 
        }
        5 { 
            $vf = "scale=${largeScale}:-1,zoompan=z='if(eq(on,1),${maxZoom},zoom-${zoomSpeed})':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=${frames}:s=${videoWidth}x${videoHeight}:fps=${fps},setsar=1,format=yuv420p" 
        }
        6 { 
            $vf = "scale=${largeScale}:-1,zoompan=z='1.1':x='iw/2-(iw/zoom/2)':y='min(max((ih-ih/zoom)*((on)/${frames}),0),ih)':d=${frames}:s=${videoWidth}x${videoHeight}:fps=${fps},setsar=1,format=yuv420p" 
        }
        7 { 
            $vf = "scale=${largeScale}:-1,zoompan=z='min(zoom+${zoomSpeed},${maxZoom})':x='iw-iw/zoom':y='0':d=${frames}:s=${videoWidth}x${videoHeight}:fps=${fps},setsar=1,format=yuv420p" 
        }
        8 { 
            $vf = "scale=${largeScale}:-1,zoompan=z='if(eq(on,1),${maxZoom},zoom-${zoomSpeed})':x='iw-iw/zoom':y='ih-ih/zoom':d=${frames}:s=${videoWidth}x${videoHeight}:fps=${fps},setsar=1,format=yuv420p" 
        }
    }
    $ffmpegCmd = "ffmpeg -y -threads 0 -loop 1 -i $img -t $time -vf `"$vf`" -c:v libx264 -pix_fmt yuv420p -preset $preset -crf $videoQuality -r $fps -g $gopSize -keyint_min $gopSize -sc_threshold 0 -b:v $bitrate -movflags +faststart $outputVideo"
    Write-Host "Executing: $ffmpegCmd"
    Invoke-Expression $ffmpegCmd
    if (-not (Test-Path $outputVideo)) {
        Write-Error "Error: Failed to create temporary video for $img"
        exit 1
    } else {
        Write-Host "Created temporary video for $img successfully."
    }
}

# -------------------------------
# 4. Ghép các video với hiệu ứng xfade "smoothleft"
# -------------------------------

# Tạo file danh sách video để concat
$concatList = "concat_list.txt"
$concatContent = ""
for ($i = 1; $i -le 8; $i++) {
    $videoPath = "temp_videos\$i.mp4"
    if (-not (Test-Path $videoPath)) {
        Write-Error "Error: Video file $videoPath not found."
        exit 1
    }
    $concatContent += "file '$videoPath'`n"
    if ($i -lt 8) {
        $concatContent += "duration $($times[$i-1])`n"
    }
}

# Lưu file danh sách
$concatContent | Out-File -FilePath $concatList -Encoding UTF8
if (-not (Test-Path $concatList)) {
    Write-Error "Error: Failed to create concat list file."
    exit 1
}

# Kiểm tra nội dung file danh sách
Write-Host "Concat list content:"
Get-Content $concatList | ForEach-Object { Write-Host $_ }

# Ghép video sử dụng concat filter
$ffmpegConcat = "ffmpeg -y -threads 0 -f concat -safe 0 -i $concatList -c:v libx264 -preset $preset -crf $videoQuality -r $fps -pix_fmt yuv420p -movflags +faststart final_video_no_audio.mp4"
Write-Host "Executing concat command:"
Write-Host $ffmpegConcat
Invoke-Expression $ffmpegConcat

if (-not (Test-Path "final_video_no_audio.mp4")) {
    Write-Error "Error: Failed to combine videos."
    exit 1
} else {
    Write-Host "Video combined successfully."
}

# -------------------------------
# 5. Kết hợp video với âm thanh
# -------------------------------
$filterComplexAudio = '[1:a]aresample=44100,volume=1.0[voice];[2:a]aresample=44100,volume=0.3[bg];[voice][bg]amix=inputs=2:duration=longest[a]'
$ffmpegAudio = "ffmpeg -y -threads 0 -i final_video_no_audio.mp4 -i voice.mp3 -i bg.mp3 -filter_complex `"$filterComplexAudio`" -map 0:v -map `"[a]`" -c:v copy -c:a aac -b:a 192k -shortest final_video_with_audio.mp4"
Write-Host "Executing audio merge command:"
Write-Host $ffmpegAudio
Invoke-Expression $ffmpegAudio

if (-not (Test-Path "final_video_with_audio.mp4")) {
    Write-Error "Error: Failed to merge audio with video."
    exit 1
} else {
    Write-Host "Audio merged with video successfully."
}

# -------------------------------
# 6. Thêm phụ đề ASS vào video
# -------------------------------
$ffmpegSubtitle = "ffmpeg -y -threads 0 -i final_video_with_audio.mp4 -vf `"ass=subtitle.ass`" -c:a copy -movflags +faststart final_video.mp4"
Write-Host "Executing ASS subtitle command:"
Write-Host $ffmpegSubtitle
Invoke-Expression $ffmpegSubtitle

if (-not (Test-Path "final_video.mp4")) {
    Write-Warning "Warning: Failed to add ASS subtitles. Copying video with audio as final output."
    Copy-Item final_video_with_audio.mp4 final_video.mp4
    if (Test-Path "final_video.mp4") {
        Write-Host "Final video (without subtitles) created."
    } else {
        Write-Error "Error: Could not create final video."
        exit 1
    }
} else {
    Write-Host "ASS subtitles added successfully."
}

Write-Host "Final video created: final_video.mp4"
Write-Host "Video dimensions: ${videoWidth}x${videoHeight}"

# -------------------------------
# 7. Cleanup các file tạm
# -------------------------------
Write-Host "Starting cleanup of temporary files..."
$tempFiles = @("final_video_no_audio.mp4", "final_video_with_audio.mp4", "simple_list.txt", "images_list.txt")
foreach ($file in $tempFiles) {
    if (Test-Path $file) {
        Remove-Item $file -Force -ErrorAction SilentlyContinue
        Write-Host "Deleted file: $file"
    }
}
if (Test-Path $tempDir) {
    Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Deleted directory: $tempDir"
}

Write-Host "Cleanup complete."
