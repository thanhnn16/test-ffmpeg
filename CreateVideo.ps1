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
            $vf = "scale=${largeScale}:-1,zoompan=z='min(zoom+${zoomSpeed},${maxZoom})':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=${frames}:s=${videoWidth}x${videoHeight}:fps=${fps},setsar=1" 
        }
        2 { 
            $vf = "scale=${largeScale}:-1,zoompan=z='if(eq(on,1),${maxZoom},zoom-${zoomSpeed})':x='iw-iw/zoom':y='0':d=${frames}:s=${videoWidth}x${videoHeight}:fps=${fps},setsar=1" 
        }
        3 { 
            $vf = "scale=${largeScale}:-1,zoompan=z='min(zoom+${zoomSpeed},${maxZoom})':x='0':y='ih-ih/zoom':d=${frames}:s=${videoWidth}x${videoHeight}:fps=${fps},setsar=1" 
        }
        4 { 
            $vf = "scale=${largeScale}:-1,zoompan=z='1.1':x='min(max((iw-iw/zoom)*((on)/${frames}),0),iw)':y='ih/2-(ih/zoom/2)':d=${frames}:s=${videoWidth}x${videoHeight}:fps=${fps},setsar=1" 
        }
        5 { 
            $vf = "scale=${largeScale}:-1,zoompan=z='if(eq(on,1),${maxZoom},zoom-${zoomSpeed})':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=${frames}:s=${videoWidth}x${videoHeight}:fps=${fps},setsar=1" 
        }
        6 { 
            $vf = "scale=${largeScale}:-1,zoompan=z='1.1':x='iw/2-(iw/zoom/2)':y='min(max((ih-ih/zoom)*((on)/${frames}),0),ih)':d=${frames}:s=${videoWidth}x${videoHeight}:fps=${fps},setsar=1" 
        }
        7 { 
            $vf = "scale=${largeScale}:-1,zoompan=z='min(zoom+${zoomSpeed},${maxZoom})':x='iw-iw/zoom':y='0':d=${frames}:s=${videoWidth}x${videoHeight}:fps=${fps},setsar=1" 
        }
        8 { 
            $vf = "scale=${largeScale}:-1,zoompan=z='if(eq(on,1),${maxZoom},zoom-${zoomSpeed})':x='iw-iw/zoom':y='ih-ih/zoom':d=${frames}:s=${videoWidth}x${videoHeight}:fps=${fps},setsar=1" 
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

# Tính toán các offset dựa theo thời lượng từng đoạn
$offset1 = 4 - $transitionDuration
$offset2 = (4 + 3) - 2*$transitionDuration
$offset3 = (4 + 3 + 5) - 3*$transitionDuration
$offset4 = (4 + 3 + 5 + 3) - 4*$transitionDuration
$offset5 = (4 + 3 + 5 + 3 + 4) - 5*$transitionDuration
$offset6 = (4 + 3 + 5 + 3 + 4 + 3) - 6*$transitionDuration
$offset7 = (4 + 3 + 5 + 3 + 4 + 3 + 5) - 7*$transitionDuration

# Xây dựng chuỗi filter_complex cho xfade
$filterComplex = "[0:v]format=pix_fmts=yuva420p,setpts=PTS-STARTPTS[v0];" +
"[1:v]format=pix_fmts=yuva420p,setpts=PTS-STARTPTS[v1];" +
"[2:v]format=pix_fmts=yuva420p,setpts=PTS-STARTPTS[v2];" +
"[3:v]format=pix_fmts=yuva420p,setpts=PTS-STARTPTS[v3];" +
"[4:v]format=pix_fmts=yuva420p,setpts=PTS-STARTPTS[v4];" +
"[5:v]format=pix_fmts=yuva420p,setpts=PTS-STARTPTS[v5];" +
"[6:v]format=pix_fmts=yuva420p,setpts=PTS-STARTPTS[v6];" +
"[7:v]format=pix_fmts=yuva420p,setpts=PTS-STARTPTS[v7];" +
"[v0][v1]xfade=transition=smoothleft:duration=${transitionDuration}:offset=$offset1[v01];" +
"[v01][v2]xfade=transition=smoothleft:duration=${transitionDuration}:offset=$offset2[v02];" +
"[v02][v3]xfade=transition=smoothleft:duration=${transitionDuration}:offset=$offset3[v03];" +
"[v03][v4]xfade=transition=smoothleft:duration=${transitionDuration}:offset=$offset4[v04];" +
"[v04][v5]xfade=transition=smoothleft:duration=${transitionDuration}:offset=$offset5[v05];" +
"[v05][v6]xfade=transition=smoothleft:duration=${transitionDuration}:offset=$offset6[v06];" +
"[v06][v7]xfade=transition=smoothleft:duration=${transitionDuration}:offset=$offset7[vout]"

$ffmpegXfade = "ffmpeg -y -threads 0 -i temp_videos\1.mp4 -i temp_videos\2.mp4 -i temp_videos\3.mp4 -i temp_videos\4.mp4 -i temp_videos\5.mp4 -i temp_videos\6.mp4 -i temp_videos\7.mp4 -i temp_videos\8.mp4 -filter_complex `"$filterComplex`" -map `"[vout]`" -c:v libx264 -preset $preset -crf $videoQuality -r $fps -pix_fmt yuv420p -movflags +faststart final_video_no_audio.mp4"
Write-Host "Executing xfade command:"
Write-Host $ffmpegXfade
Invoke-Expression $ffmpegXfade

if (-not (Test-Path "final_video_no_audio.mp4")) {
    Write-Error "Error: Failed to combine videos with transition."
    exit 1
} else {
    Write-Host "Video combined with transition successfully."
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
