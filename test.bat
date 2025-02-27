@echo off
setlocal enabledelayedexpansion

echo Bat dau tao video tu hinh anh va am thanh...

:: Kiểm tra NVIDIA CUDA và thiết lập codec tương ứng
echo Kiem tra NVIDIA GPU...
ffmpeg -hide_banner -hwaccel cuda -f lavfi -i color=black:s=32x32 -frames:v 1 -f null - >nul 2>&1
if %errorlevel% equ 0 (
    echo Da tim thay NVIDIA GPU, su dung CUDA de tang toc...
    set "hwaccel=-hwaccel cuda"
    set "video_codec=-c:v h264_nvenc"
    set "video_codec_params=-rc:v vbr_hq -preset:v p7 -tune:v hq -spatial-aq 1 -temporal-aq 1"
    :: Thêm tham số giảm số lượng luồng để tránh lỗi CUDA
    set "threads=-threads 8"
    
    :: Tắt acceleration cho zoompan do nó không tương thích tốt với CUDA
    set "hwaccel_filter="
    
    :: Hiển thị thông tin GPU
    echo Thong tin GPU:
    ffmpeg -hide_banner -hwaccel cuda -hwaccel_output_format cuda -filters | findstr "cuda" | more
) else (
    echo Khong tim thay NVIDIA GPU hoac driver khong ho tro, su dung CPU...
    set "hwaccel="
    set "hwaccel_filter="
    set "video_codec=-c:v libx264"
    set "video_codec_params=-preset:v %preset% -crf %video_quality%"
    set "threads=-threads 0"
)

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

:: Thiết lập kích thước hình ảnh đầu vào và kích thước video đầu ra
set img_width=512
set img_height=768
set video_width=512
set video_height=768

:: Thiết lập kích thước scale lớn cho hiệu ứng mượt mà
set large_scale=6000

:: Tính tổng thời gian của tất cả các ảnh
set /a total_duration=0
for %%i in (1 2 3 4 5 6 7 8) do (
  set /a total_duration=!total_duration!+!time_%%i!
)
echo Tong thoi gian video: !total_duration! giay

:: Tính thời điểm bắt đầu fade out (tổng thời gian - 1 giây)
set /a fade_out_start=!total_duration!-1

:: Thiết lập tham số cho video
set fps=30
set preset=medium
set video_quality=20
set transition_duration=1
set zoom_speed=0.0004
set max_zoom=1.25

:: Đặt hệ số tăng frame để đảm bảo hiệu ứng không bị ngắt
set frame_multiplier=8

:: Sử dụng một hằng số lớn cho duration để tránh hiệu ứng bị reset
set constant_duration=999999

:: Xử lý từng ảnh với hiệu ứng Ken Burns
echo Tao video voi hieu ung Ken Burns...
for %%i in (1 2 3 4 5 6 7 8) do (
  echo Dang xu ly anh %%i.jpeg...
  
  :: Tính toán số frame dựa trên thời gian hiển thị và thời gian chuyển cảnh
  set /a real_time=!time_%%i!
  set /a frames=!real_time! * %fps%
  
  if %%i==1 (
    :: Ảnh 1: Zoom in từ giữa
    ffmpeg -y %threads% -loop 1 -i %%i.jpeg -t !real_time! -vf "scale=%large_scale%:-1,zoompan=z='min(1+%zoom_speed%*on,%max_zoom%)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=%constant_duration%:s=%video_width%x%video_height%:fps=%fps%" %video_codec% %video_codec_params% -r %fps% -pix_fmt yuv420p temp_videos\%%i.mp4
  ) else if %%i==2 (
    :: Ảnh 2: Zoom out từ góc trên bên phải
    ffmpeg -y %threads% -loop 1 -i %%i.jpeg -t !real_time! -vf "scale=%large_scale%:-1,zoompan=z='max(%max_zoom%-%zoom_speed%*on,1)':x='iw-iw/zoom':y='0':d=%constant_duration%:s=%video_width%x%video_height%:fps=%fps%" %video_codec% %video_codec_params% -r %fps% -pix_fmt yuv420p temp_videos\%%i.mp4
  ) else if %%i==3 (
    :: Ảnh 3: Zoom in từ góc dưới bên trái
    ffmpeg -y %threads% -loop 1 -i %%i.jpeg -t !real_time! -vf "scale=%large_scale%:-1,zoompan=z='min(1+%zoom_speed%*on,%max_zoom%)':x='0':y='ih-ih/zoom':d=%constant_duration%:s=%video_width%x%video_height%:fps=%fps%" %video_codec% %video_codec_params% -r %fps% -pix_fmt yuv420p temp_videos\%%i.mp4
  ) else if %%i==4 (
    :: Ảnh 4: Pan từ trái sang phải
    ffmpeg -y %threads% -loop 1 -i %%i.jpeg -t !real_time! -vf "scale=%large_scale%:-1,zoompan=z='1.1':x='min((iw-iw/zoom)*(on/%constant_duration%),iw-iw/zoom)':y='ih/2-(ih/zoom/2)':d=%constant_duration%:s=%video_width%x%video_height%:fps=%fps%" %video_codec% %video_codec_params% -r %fps% -pix_fmt yuv420p temp_videos\%%i.mp4
  ) else if %%i==5 (
    :: Ảnh 5: Zoom out từ giữa
    ffmpeg -y %threads% -loop 1 -i %%i.jpeg -t !real_time! -vf "scale=%large_scale%:-1,zoompan=z='max(%max_zoom%-%zoom_speed%*on,1)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=%constant_duration%:s=%video_width%x%video_height%:fps=%fps%" %video_codec% %video_codec_params% -r %fps% -pix_fmt yuv420p temp_videos\%%i.mp4
  ) else if %%i==6 (
    :: Ảnh 6: Pan từ trên xuống dưới
    ffmpeg -y %threads% -loop 1 -i %%i.jpeg -t !real_time! -vf "scale=%large_scale%:-1,zoompan=z='1.1':x='iw/2-(iw/zoom/2)':y='min((ih-ih/zoom)*(on/%constant_duration%),ih-ih/zoom)':d=%constant_duration%:s=%video_width%x%video_height%:fps=%fps%" %video_codec% %video_codec_params% -r %fps% -pix_fmt yuv420p temp_videos\%%i.mp4
  ) else if %%i==7 (
    :: Ảnh 7: Zoom in từ góc trên bên phải
    ffmpeg -y %threads% -loop 1 -i %%i.jpeg -t !real_time! -vf "scale=%large_scale%:-1,zoompan=z='min(1+%zoom_speed%*on,%max_zoom%)':x='iw-iw/zoom':y='0':d=%constant_duration%:s=%video_width%x%video_height%:fps=%fps%" %video_codec% %video_codec_params% -r %fps% -pix_fmt yuv420p temp_videos\%%i.mp4
  ) else if %%i==8 (
    :: Ảnh 8: Zoom out từ góc dưới bên phải
    ffmpeg -y %threads% -loop 1 -i %%i.jpeg -t !real_time! -vf "scale=%large_scale%:-1,zoompan=z='max(%max_zoom%-%zoom_speed%*on,1)':x='iw-iw/zoom':y='ih-ih/zoom':d=%constant_duration%:s=%video_width%x%video_height%:fps=%fps%" %video_codec% %video_codec_params% -r %fps% -pix_fmt yuv420p temp_videos\%%i.mp4
  )
  
  if not exist temp_videos\%%i.mp4 (
    echo Loi: Khong the tao file video tam cho anh %%i.jpeg
    goto :cleanup
  )
  
  :: Kiểm tra thời lượng thực sự của video đã tạo
  for /f "tokens=1 delims=" %%d in ('ffprobe -v error -show_entries format^=duration -of default^=noprint_wrappers^=1:nokey^=1 temp_videos\%%i.mp4') do (
    echo Video %%i thoi luong: %%d giay
  )
)

:: Tạo thư mục để lưu video sau khi xử lý chuyển cảnh
if not exist transitions mkdir transitions

:: Tạo danh sách tệp tin tạm thời và thời gian của từng clip
echo Tao danh sach video...
del clips.txt 2>nul

:: Tính toán trước các giá trị offset cho các hiệu ứng chuyển cảnh
set /a offset1=%time_1%-%transition_duration%
set /a offset2=%time_1%+%time_2%-%transition_duration%
set /a offset3=%time_1%+%time_2%+%time_3%-%transition_duration%
set /a offset4=%time_1%+%time_2%+%time_3%+%time_4%-%transition_duration%
set /a offset5=%time_1%+%time_2%+%time_3%+%time_4%+%time_5%-%transition_duration%
set /a offset6=%time_1%+%time_2%+%time_3%+%time_4%+%time_5%+%time_6%-%transition_duration%
set /a offset7=%time_1%+%time_2%+%time_3%+%time_4%+%time_5%+%time_6%+%time_7%-%transition_duration%

:: Nối các clip với hiệu ứng chuyển cảnh xfade tích hợp
echo Noi cac video lai voi nhau...

:: Đảm bảo video có frame rate và thời lượng nhất quán
echo Tao lai cac video tu hinh anh de dam bao frame rate...

:: Tạo danh sách để nối các video
echo file 'temp_videos\1.mp4' > concat_list.txt
echo file 'temp_videos\2.mp4' >> concat_list.txt
echo file 'temp_videos\3.mp4' >> concat_list.txt
echo file 'temp_videos\4.mp4' >> concat_list.txt
echo file 'temp_videos\5.mp4' >> concat_list.txt
echo file 'temp_videos\6.mp4' >> concat_list.txt
echo file 'temp_videos\7.mp4' >> concat_list.txt
echo file 'temp_videos\8.mp4' >> concat_list.txt

:: Nối tất cả video lại với nhau (không dùng xfade)
echo Noi cac video lai voi concat...
ffmpeg -y -f concat -safe 0 -i concat_list.txt -c:v libx264 -preset medium -crf 22 -r %fps% temp_video_no_audio.mp4

if not exist temp_video_no_audio.mp4 (
    echo Loi: Khong the tao file video tam!
    goto :cleanup
)

:: Kiểm tra file video đã tạo
echo Kiem tra file video_no_audio...
ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 temp_video_no_audio.mp4 > nul 2>&1
if %errorlevel% neq 0 (
    echo Loi: File video tam khong hop le!
    goto :cleanup
)

:: Kết hợp video với âm thanh
echo Ket hop video voi am thanh...
:: Kiểm tra file âm thanh
ffprobe -v error -i voice.mp3 -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 > nul 2>&1
if %errorlevel% neq 0 (
    echo Loi: File voice.mp3 bi hong hoac khong tim thay!
    goto :cleanup
)

ffprobe -v error -i bg.mp3 -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 > nul 2>&1
if %errorlevel% neq 0 (
    echo Loi: File bg.mp3 bi hong hoac khong tim thay!
    goto :cleanup
)

ffmpeg -y %threads% -i temp_video_no_audio.mp4 -i voice.mp3 -i bg.mp3 -filter_complex "[1:a]volume=1.0[voice];[2:a]volume=0.3[bg];[voice][bg]amix=inputs=2:duration=longest,dynaudnorm=f=150:g=15[a]" -map 0:v -map "[a]" %video_codec% %video_codec_params% -c:a aac -b:a 192k -shortest temp_video_with_audio.mp4

if not exist temp_video_with_audio.mp4 (
    echo Loi: Khong the tao file video voi am thanh!
    goto :cleanup
)

:: Kiểm tra file subtitle
echo Kiem tra file subtitle.srt...
findstr /C:"-->" subtitle.srt > nul 2>&1
if %errorlevel% neq 0 (
    echo Canh bao: File subtitle.srt co the bi hong hoac dinh dang khong dung!
)

:: Thêm phụ đề vào video
echo Them phu de...
ffmpeg -y %threads% -i temp_video_with_audio.mp4 -vf "subtitles=subtitle.srt:force_style='FontName=Arial,FontSize=16,PrimaryColour=&H00FFFFFF,OutlineColour=&H00000000,BackColour=&H80000000,Bold=1,Italic=0,Alignment=2,MarginV=30'" %video_codec% %video_codec_params% -c:a copy final_video.mp4

if not exist final_video.mp4 (
    echo Loi: Khong the tao file video cuoi cung!
    goto :cleanup
)

echo Hoan thanh! Video da duoc tao: final_video.mp4
echo Kich thuoc video: %video_width%x%video_height%

:cleanup
echo Xoa file tam...
if exist images.txt del images.txt
if exist list.txt del list.txt
if exist transitions_list.txt del transitions_list.txt
if exist list_with_transitions.txt del list_with_transitions.txt
if exist concat_list.txt del concat_list.txt
if exist temp_fr.txt del temp_fr.txt
if exist temp_videos rmdir /s /q temp_videos 2>nul
if exist transitions rmdir /s /q transitions 2>nul
if exist temp_video_no_audio.mp4 del temp_video_no_audio.mp4
if exist temp_video_with_audio.mp4 del temp_video_with_audio.mp4

echo Qua trinh hoan tat.
exit /b 0
