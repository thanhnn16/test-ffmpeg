@echo off
setlocal enabledelayedexpansion

echo Bat dau tao video tu hinh anh va am thanh...

:: Thiết lập thời gian hiển thị cho từng ảnh (giây)
set time_1=4
set time_2=3
set time_3=5
set time_4=3
set time_5=4
set time_6=3
set time_7=5
set time_8=3

:: Kiểm tra sự tồn tại của các file ảnh
echo Kiem tra cac file hinh anh...
set missing_files=0
for %%i in (1 2 3 4 5 6 7 8) do (
  if not exist %%i.jpeg (
    echo Loi: Khong tim thay file %%i.jpeg
    set /a missing_files+=1
  )
)

if !missing_files! gtr 0 (
  echo Tong cong !missing_files! file hinh anh bi thieu. Vui long kiem tra lai.
  exit /b 1
)

:: Kiểm tra sự tồn tại của file âm thanh
if not exist voice.mp3 (
  echo Loi: Khong tim thay file voice.mp3
  exit /b 1
)

if not exist bg.mp3 (
  echo Loi: Khong tim thay file bg.mp3
  exit /b 1
)

if not exist subtitle.srt (
  echo Loi: Khong tim thay file subtitle.srt
  exit /b 1
)

:: Tạo thư mục tạm để lưu video tạm
if not exist temp_videos mkdir temp_videos

:: Thiết lập kích thước video: 720x1280 (tỷ lệ 9:16)
set video_width=720
set video_height=1280

:: Tính tổng thời gian của tất cả các ảnh
set /a total_duration=0
for %%i in (1 2 3 4 5 6 7 8) do (
  set /a total_duration=!total_duration!+!time_%%i!
)
echo Tong thoi gian video: !total_duration! giay

:: Tính thời điểm bắt đầu fade out (tổng thời gian - 1 giây)
set /a fade_out_start=!total_duration!-1

:: Thiết lập tham số cho video
set fps=25
set preset=ultrafast
set video_quality=23
set transition_duration=0.5

:: Xử lý từng ảnh với hiệu ứng Ken Burns đơn giản
echo Tao video voi hieu ung Ken Burns...
for %%i in (1 2 3 4 5 6 7 8) do (
  echo Dang xu ly anh %%i.jpeg...
  set /a mod=%%i %% 2
  
  if !mod! equ 0 (
    :: Ảnh chẵn: chuyển động từ dưới lên
    ffmpeg -y -threads 0 -loop 1 -i %%i.jpeg -t !time_%%i! -vf "scale=%video_width%:%video_height%:force_original_aspect_ratio=increase,crop=%video_width%:%video_height%,fps=%fps%" -c:v libx264 -pix_fmt yuv420p -preset %preset% -crf %video_quality% temp_videos\%%i.mp4
  ) else (
    :: Ảnh lẻ: chuyển động từ trên xuống
    ffmpeg -y -threads 0 -loop 1 -i %%i.jpeg -t !time_%%i! -vf "scale=%video_width%:%video_height%:force_original_aspect_ratio=increase,crop=%video_width%:%video_height%,fps=%fps%" -c:v libx264 -pix_fmt yuv420p -preset %preset% -crf %video_quality% temp_videos\%%i.mp4
  )
  
  if not exist temp_videos\%%i.mp4 (
    echo Loi: Khong the tao file video tam cho anh %%i.jpeg
    goto :cleanup
  )
)

:: Tạo danh sách các video tạm thời
echo Tao danh sach cac video tam thoi...
(
  for %%i in (1 2 3 4 5 6 7 8) do (
    echo file 'temp_videos\%%i.mp4'
  )
) > list.txt

:: Nối các video lại với nhau và thêm hiệu ứng fade in/out và chuyển cảnh
echo Noi cac video lai voi nhau va them hieu ung fade in/out va chuyen canh...
ffmpeg -y -threads 0 -f concat -safe 0 -i list.txt -filter_complex "format=yuv420p,fade=t=in:st=0:d=0.5,fade=t=out:st=%fade_out_start%:d=0.5" -c:v libx264 -pix_fmt yuv420p -preset %preset% -crf %video_quality% temp_video_no_audio.mp4

if not exist temp_video_no_audio.mp4 (
    echo Loi: Khong the tao file video tam!
    goto :cleanup
)

:: Kết hợp video với âm thanh
echo Ket hop video voi am thanh...
ffmpeg -y -threads 0 -i temp_video_no_audio.mp4 -i voice.mp3 -i bg.mp3 -filter_complex "[1:a]volume=1.0[voice];[2:a]volume=0.3[bg];[voice][bg]amix=inputs=2:duration=longest,dynaudnorm=f=150:g=15[a]" -map 0:v -map "[a]" -c:v copy -c:a aac -b:a 192k -shortest temp_video_with_audio.mp4

if not exist temp_video_with_audio.mp4 (
    echo Loi: Khong the tao file video voi am thanh!
    goto :cleanup
)

:: Thêm phụ đề vào video
echo Them phu de...
ffmpeg -y -threads 0 -i temp_video_with_audio.mp4 -vf "subtitles=subtitle.srt:force_style='FontName=Arial,FontSize=16,PrimaryColour=&H00FFFFFF,OutlineColour=&H00000000,BackColour=&H80000000,Bold=1,Italic=0,Alignment=2,MarginV=30'" -c:a copy final_video.mp4

if not exist final_video.mp4 (
    echo Loi: Khong the tao file video cuoi cung!
    goto :cleanup
)

echo Hoan thanh! Video da duoc tao: final_video.mp4
echo Kich thuoc video: %video_width%x%video_height% (9:16 ratio)

:cleanup
echo Xoa file tam...
if exist images.txt del images.txt
if exist list.txt del list.txt
if exist list_with_transitions.txt del list_with_transitions.txt
if exist temp_videos rmdir /s /q temp_videos 2>nul
if exist temp_video_no_audio.mp4 del temp_video_no_audio.mp4
if exist temp_video_with_audio.mp4 del temp_video_with_audio.mp4

echo Qua trinh hoan tat.
exit /b 0
