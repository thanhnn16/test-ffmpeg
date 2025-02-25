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

:: Tạo danh sách các file ảnh với thời gian hiển thị riêng
echo Tao danh sach hinh anh...
(
  for %%i in (1 2 3 4 5 6 7 8) do (
    echo file '%%i.jpeg'
    echo duration !time_%%i!
  )
  :: Dòng cuối để đảm bảo ảnh cuối được hiển thị đủ thời gian
  echo file '8.jpeg'
) > images.txt

:: Thiết lập kích thước video: 720x1280 (tỷ lệ 9:16)
set video_width=720
set video_height=1280

:: Tính tổng thời gian của tất cả các ảnh
set /a total_duration=0
for %%i in (1 2 3 4 5 6 7 8) do (
  set /a total_duration=!total_duration!+!time_%%i!
)
echo Tong thoi gian video: !total_duration! giay

:: Tạo video với hiệu ứng pan (không dùng zoom động)
echo Tao video tu hinh anh voi hieu ung pan doc...

:: Tạo thư mục tạm để lưu video tạm
if not exist temp_videos mkdir temp_videos

:: Thiết lập tham số cho video
:: Giảm fps từ 30 xuống 25 để giảm số frame xử lý
set fps=60
:: Sử dụng preset "veryfast" để tối ưu tốc độ mã hóa cho mọi máy
set preset=veryfast
set video_quality=22
set transition_duration=0.5

:: Giảm pan_range để chuyển động nhẹ nhàng hơn (vẫn dùng giá trị 30)
set pan_range=30

:: Xử lý từng ảnh:
:: - Dùng filter scale với force_original_aspect_ratio=increase và crop để đảm bảo ảnh lấp đầy khung (tránh khoảng đen)
:: - Áp dụng zoompan với z='1.1' (zoom cố định) để khởi đầu đã được zoom vào, hạn chế lộ khoảng trống khi pan
:: - Số frame tính = fps * thời gian của ảnh
:: - Công thức y:
::    + Ảnh lẻ: y tăng từ 0 đến pan_range (cuộn xuống)
::    + Ảnh chẵn: y giảm từ pan_range xuống 0 (cuộn lên)
for %%i in (1 2 3 4 5 6 7 8) do (
  echo Dang xu ly anh %%i.jpeg voi hieu ung pan doc...
  set /a mod=%%i %% 2
  if !mod! equ 0 (
    rem Ảnh chẵn: cuộn lên (y giảm từ pan_range về 0)
    set "y_expr=%pan_range% - (%pan_range%*on/((%fps%*!time_%%i!)-1))"
  ) else (
    rem Ảnh lẻ: cuộn xuống (y tăng từ 0 đến pan_range)
    set "y_expr=(%pan_range%*on/((%fps%*!time_%%i!)-1))"
  )
  ffmpeg -y -threads 0 -loop 1 -i %%i.jpeg -t !time_%%i! -vf "scale=720:1280:force_original_aspect_ratio=increase,crop=720:1280,zoompan=z='1.1':d=%fps%*!time_%%i!:x='iw/2-(iw/1.1)/2':y=!y_expr!:s=720x1280:fps=%fps%" -c:v libx264 -pix_fmt yuv420p -preset %preset% -crf %video_quality% temp_videos\%%i.mp4
)

:: Tạo danh sách các video tạm thời
echo Tao danh sach cac video tam thoi...
(
  for %%i in (1 2 3 4 5 6 7 8) do (
    echo file 'temp_videos\%%i.mp4'
  )
) > list.txt

:: Tính thời điểm bắt đầu fade out (tổng thời gian - 1 giây)
set /a fade_out_start=!total_duration!-1

:: Nối các video lại với nhau và thêm hiệu ứng chuyển tiếp (fade in/out)
echo Noi cac video lai voi nhau va them hieu ung chuyen tiep...
ffmpeg -y -threads 0 -f concat -safe 0 -i list.txt -filter_complex "fps=%fps%,format=yuv420p,fade=t=in:st=0:d=0.5,fade=t=out:st=%fade_out_start%:d=0.5" -c:v libx264 -pix_fmt yuv420p -preset %preset% -crf %video_quality% temp_video_no_audio.mp4

if not exist temp_video_no_audio.mp4 (
    echo Loi: Khong the tao file video tam!
    goto :cleanup
)

:: Kết hợp video với âm thanh
echo Ket hop video voi am thanh...
ffmpeg -y -threads 0 -i temp_video_no_audio.mp4 -accurate_seek -i voice.mp3 -accurate_seek -i bg.mp3 -filter_complex "[1:a]volume=1.0[voice];[2:a]volume=0.3[bg];[voice][bg]amix=inputs=2:duration=longest,dynaudnorm=f=150:g=15[a]" -map 0:v -map "[a]" -c:v copy -c:a aac -b:a 192k -shortest temp_video_with_audio.mp4

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
for %%i in (1 2 3 4 5 6 7 8) do (
  if exist temp_videos\%%i.mp4 del temp_videos\%%i.mp4
)
if exist temp_videos rmdir temp_videos
if exist temp_video_no_audio.mp4 del temp_video_no_audio.mp4
if exist temp_video_with_audio.mp4 del temp_video_with_audio.mp4
