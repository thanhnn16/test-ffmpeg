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
    
    :: Kiểm tra sâu hơn về sự tương thích của CUDA với zoompan
    ffmpeg -hide_banner -hwaccel cuda -f lavfi -i testsrc=duration=1:size=32x32 -vf "zoompan=z=1.1:d=25" -frames:v 1 -f null - >nul 2>&1
    if not %errorlevel% equ 0 (
        echo Canh bao: CUDA khong tuong thich voi hieu ung zoompan, se su dung CPU cho cac hieu ung...
        set "hwaccel_filter="
    ) else (
        set "hwaccel_filter=%hwaccel%"
    )
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
set large_scale=4000

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
set zoom_speed=0.0005
set max_zoom=1.25

:: Xử lý từng ảnh với hiệu ứng Ken Burns
echo Tao video voi hieu ung Ken Burns...
for %%i in (1 2 3 4 5 6 7 8) do (
  echo Dang xu ly anh %%i.jpeg...
  
  :: Tính toán số frame dựa trên thời gian hiển thị
  set /a frames=!time_%%i! * %fps%
  
  if %%i==1 (
    :: Ảnh 1: Zoom in từ giữa
    ffmpeg -y %threads% %hwaccel_filter% -loop 1 -i %%i.jpeg -t !time_%%i! -vf "scale=%large_scale%:-1,zoompan=z='min(zoom+%zoom_speed%,%max_zoom%)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=!frames!:s=%video_width%x%video_height%:fps=%fps%,setsar=1,minterpolate=fps=%fps%:mi_mode=mci,format=yuv420p" %video_codec% %video_codec_params% -r %fps% -fps_mode cfr temp_videos\%%i.mp4
  ) else if %%i==2 (
    :: Ảnh 2: Zoom out từ góc trên bên phải
    ffmpeg -y %threads% %hwaccel_filter% -loop 1 -i %%i.jpeg -t !time_%%i! -vf "scale=%large_scale%:-1,zoompan=z='if(eq(on,1),%max_zoom%,zoom-%zoom_speed%)':x='iw-iw/zoom':y='0':d=!frames!:s=%video_width%x%video_height%:fps=%fps%,setsar=1,minterpolate=fps=%fps%:mi_mode=mci,format=yuv420p" %video_codec% %video_codec_params% -r %fps% -fps_mode cfr temp_videos\%%i.mp4
  ) else if %%i==3 (
    :: Ảnh 3: Zoom in từ góc dưới bên trái
    ffmpeg -y %threads% %hwaccel_filter% -loop 1 -i %%i.jpeg -t !time_%%i! -vf "scale=%large_scale%:-1,zoompan=z='min(zoom+%zoom_speed%,%max_zoom%)':x='0':y='ih-ih/zoom':d=!frames!:s=%video_width%x%video_height%:fps=%fps%,setsar=1,minterpolate=fps=%fps%:mi_mode=mci,format=yuv420p" %video_codec% %video_codec_params% -r %fps% -fps_mode cfr temp_videos\%%i.mp4
  ) else if %%i==4 (
    :: Ảnh 4: Pan từ trái sang phải
    ffmpeg -y %threads% %hwaccel_filter% -loop 1 -i %%i.jpeg -t !time_%%i! -vf "scale=%large_scale%:-1,zoompan=z='1.1':x='min(max((iw-iw/zoom)*((on)/(!frames!)),0),iw)':y='ih/2-(ih/zoom/2)':d=!frames!:s=%video_width%x%video_height%:fps=%fps%,setsar=1,minterpolate=fps=%fps%:mi_mode=mci,format=yuv420p" %video_codec% %video_codec_params% -r %fps% -fps_mode cfr temp_videos\%%i.mp4
  ) else if %%i==5 (
    :: Ảnh 5: Zoom out từ giữa
    ffmpeg -y %threads% %hwaccel_filter% -loop 1 -i %%i.jpeg -t !time_%%i! -vf "scale=%large_scale%:-1,zoompan=z='if(eq(on,1),%max_zoom%,zoom-%zoom_speed%)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=!frames!:s=%video_width%x%video_height%:fps=%fps%,setsar=1,minterpolate=fps=%fps%:mi_mode=mci,format=yuv420p" %video_codec% %video_codec_params% -r %fps% -fps_mode cfr temp_videos\%%i.mp4
  ) else if %%i==6 (
    :: Ảnh 6: Pan từ trên xuống dưới
    ffmpeg -y %threads% %hwaccel_filter% -loop 1 -i %%i.jpeg -t !time_%%i! -vf "scale=%large_scale%:-1,zoompan=z='1.1':x='iw/2-(iw/zoom/2)':y='min(max((ih-ih/zoom)*((on)/(!frames!)),0),ih)':d=!frames!:s=%video_width%x%video_height%:fps=%fps%,setsar=1,minterpolate=fps=%fps%:mi_mode=mci,format=yuv420p" %video_codec% %video_codec_params% -r %fps% -fps_mode cfr temp_videos\%%i.mp4
  ) else if %%i==7 (
    :: Ảnh 7: Zoom in từ góc trên bên phải
    ffmpeg -y %threads% %hwaccel_filter% -loop 1 -i %%i.jpeg -t !time_%%i! -vf "scale=%large_scale%:-1,zoompan=z='min(zoom+%zoom_speed%,%max_zoom%)':x='iw-iw/zoom':y='0':d=!frames!:s=%video_width%x%video_height%:fps=%fps%,setsar=1,minterpolate=fps=%fps%:mi_mode=mci,format=yuv420p" %video_codec% %video_codec_params% -r %fps% -fps_mode cfr temp_videos\%%i.mp4
  ) else if %%i==8 (
    :: Ảnh 8: Zoom out từ góc dưới bên phải
    ffmpeg -y %threads% %hwaccel_filter% -loop 1 -i %%i.jpeg -t !time_%%i! -vf "scale=%large_scale%:-1,zoompan=z='if(eq(on,1),%max_zoom%,zoom-%zoom_speed%)':x='iw-iw/zoom':y='ih-ih/zoom':d=!frames!:s=%video_width%x%video_height%:fps=%fps%,setsar=1,minterpolate=fps=%fps%:mi_mode=mci,format=yuv420p" %video_codec% %video_codec_params% -r %fps% -fps_mode cfr temp_videos\%%i.mp4
  )
  
  if not exist temp_videos\%%i.mp4 (
    echo Loi: Khong the tao file video tam cho anh %%i.jpeg
    goto :cleanup
  )
)

:: Tạo thư mục để lưu video đã thêm hiệu ứng chuyển cảnh
if not exist transitions mkdir transitions

:: Chuẩn hóa tất cả video trước khi xử lý
echo Chuan hoa video truoc khi xu ly chuyen canh...
for %%i in (1 2 3 4 5 6 7 8) do (
  ffmpeg -y %threads% %hwaccel% -i temp_videos\%%i.mp4 -vf "fps=%fps%,format=yuv420p" %video_codec% %video_codec_params% -r %fps% -fps_mode cfr transitions\norm_%%i.mp4
)

:: Tạo hiệu ứng chuyển cảnh cho từng cặp video
echo Tao hieu ung chuyen canh giua cac video...
setlocal enabledelayedexpansion

for /l %%i in (1, 1, 7) do (
  set /a next=%%i+1
  
  :: Tính toán giá trị thời lượng của video hiện tại
  if %%i==1 set /a current_duration=%time_1%
  if %%i==2 set /a current_duration=%time_2%
  if %%i==3 set /a current_duration=%time_3%
  if %%i==4 set /a current_duration=%time_4%
  if %%i==5 set /a current_duration=%time_5%
  if %%i==6 set /a current_duration=%time_6%
  if %%i==7 set /a current_duration=%time_7%
  
  :: Tính toán vị trí cắt để áp dụng hiệu ứng chuyển cảnh
  set /a cut_position=!current_duration! - %transition_duration%
  set /a fade_duration_frames=%transition_duration% * %fps%
  
  :: Chọn kiểu chuyển cảnh luân phiên
  set /a trans_type=%%i %% 5
  
  echo Tao hieu ung chuyen canh giua video %%i va !next!...
  
  :: Cắt đoạn video đầu tiên và thêm hiệu ứng fade-out
  ffmpeg -y %threads% %hwaccel% -i transitions\norm_%%i.mp4 -vf "trim=0:!cut_position!,setpts=PTS-STARTPTS" %video_codec% %video_codec_params% -r %fps% -fps_mode cfr transitions\part1_%%i.mp4
  
  :: Cắt đoạn chuyển cảnh từ video đầu tiên
  ffmpeg -y %threads% %hwaccel% -i transitions\norm_%%i.mp4 -vf "trim=!cut_position!:!current_duration!,setpts=PTS-STARTPTS" %video_codec% %video_codec_params% -r %fps% -fps_mode cfr transitions\part2_%%i.mp4
  
  :: Cắt đoạn chuyển cảnh từ video thứ hai
  ffmpeg -y %threads% %hwaccel% -i transitions\norm_!next!.mp4 -vf "trim=0:%transition_duration%,setpts=PTS-STARTPTS" %video_codec% %video_codec_params% -r %fps% -fps_mode cfr transitions\part1_!next!.mp4
  
  :: Cắt phần còn lại của video thứ hai
  ffmpeg -y %threads% %hwaccel% -i transitions\norm_!next!.mp4 -vf "trim=%transition_duration%,setpts=PTS-STARTPTS" %video_codec% %video_codec_params% -r %fps% -fps_mode cfr transitions\part2_!next!.mp4
  
  :: Tạo hiệu ứng chuyển cảnh giữa 2 đoạn video
  if !trans_type! equ 0 (
    :: Hiệu ứng crossfade (hòa trộn)
    echo Ap dung hieu ung crossfade...
    ffmpeg -y %threads% %hwaccel% -i transitions\part2_%%i.mp4 -i transitions\part1_!next!.mp4 -filter_complex "[0:v][1:v]xfade=transition=fade:duration=%transition_duration%:offset=0,format=yuv420p" %video_codec% %video_codec_params% -r %fps% -fps_mode cfr transitions\middle_%%i_!next!.mp4
  ) else if !trans_type! equ 1 (
    :: Hiệu ứng wipe (lau màn hình)
    echo Ap dung hieu ung wipe left...
    ffmpeg -y %threads% %hwaccel% -i transitions\part2_%%i.mp4 -i transitions\part1_!next!.mp4 -filter_complex "[0:v][1:v]xfade=transition=wipeleft:duration=%transition_duration%:offset=0,format=yuv420p" %video_codec% %video_codec_params% -r %fps% -fps_mode cfr transitions\middle_%%i_!next!.mp4
  ) else if !trans_type! equ 2 (
    :: Hiệu ứng fade through black
    echo Ap dung hieu ung fade through black...
    ffmpeg -y %threads% %hwaccel% -i transitions\part2_%%i.mp4 -i transitions\part1_!next!.mp4 -filter_complex "[0:v][1:v]xfade=transition=fadeblack:duration=%transition_duration%:offset=0,format=yuv420p" %video_codec% %video_codec_params% -r %fps% -fps_mode cfr transitions\middle_%%i_!next!.mp4
  ) else if !trans_type! equ 3 (
    :: Hiệu ứng wipe right (lau từ phải sang)
    echo Ap dung hieu ung wipe right...
    ffmpeg -y %threads% %hwaccel% -i transitions\part2_%%i.mp4 -i transitions\part1_!next!.mp4 -filter_complex "[0:v][1:v]xfade=transition=wiperight:duration=%transition_duration%:offset=0,format=yuv420p" %video_codec% %video_codec_params% -r %fps% -fps_mode cfr transitions\middle_%%i_!next!.mp4
  ) else (
    :: Hiệu ứng circle close
    echo Ap dung hieu ung circle close...
    ffmpeg -y %threads% %hwaccel% -i transitions\part2_%%i.mp4 -i transitions\part1_!next!.mp4 -filter_complex "[0:v][1:v]xfade=transition=circleclose:duration=%transition_duration%:offset=0,format=yuv420p" %video_codec% %video_codec_params% -r %fps% -fps_mode cfr transitions\middle_%%i_!next!.mp4
  )
  
  :: Tạo file danh sách cho từng cặp video
  echo file 'part1_%%i.mp4' > transitions\list_%%i_!next!.txt
  echo file 'middle_%%i_!next!.mp4' >> transitions\list_%%i_!next!.txt
  echo file 'part2_!next!.mp4' >> transitions\list_%%i_!next!.txt
  
  :: Ghép các phần video lại với nhau
  ffmpeg -y %threads% %hwaccel% -f concat -safe 0 -i transitions\list_%%i_!next!.txt %video_codec% %video_codec_params% -r %fps% -fps_mode cfr transitions\transition_%%i_!next!.mp4
  
  if not exist transitions\transition_%%i_!next!.mp4 (
    echo Loi: Khong the tao hieu ung chuyen canh giua video %%i va !next!
    goto :cleanup
  )
)

endlocal

:: Tạo danh sách các video đã có hiệu ứng chuyển cảnh
echo Tao danh sach cac video co hieu ung chuyen canh...
del transitions_list.txt 2>nul

for /L %%i in (1, 1, 7) do (
  set /a next=%%i+1
  echo file 'transitions\transition_%%i_!next!.mp4' >> transitions_list.txt
)

:: Nối tất cả các video có hiệu ứng chuyển cảnh lại với nhau
echo Noi cac video co hieu ung chuyen canh lai voi nhau...
ffmpeg -y %threads% %hwaccel% -f concat -safe 0 -i transitions_list.txt %video_codec% %video_codec_params% -r %fps% -fps_mode cfr temp_video_no_audio.mp4

if not exist temp_video_no_audio.mp4 (
    echo Loi: Khong the tao file video tam!
    goto :cleanup
)

:: Kết hợp video với âm thanh
echo Ket hop video voi am thanh...
ffmpeg -y %threads% %hwaccel% -i temp_video_no_audio.mp4 -i voice.mp3 -i bg.mp3 -filter_complex "[1:a]volume=1.0[voice];[2:a]volume=0.3[bg];[voice][bg]amix=inputs=2:duration=longest,dynaudnorm=f=150:g=15[a]" -map 0:v -map "[a]" %video_codec% %video_codec_params% -c:a aac -b:a 192k -shortest temp_video_with_audio.mp4

if not exist temp_video_with_audio.mp4 (
    echo Loi: Khong the tao file video voi am thanh!
    goto :cleanup
)

:: Thêm phụ đề vào video
echo Them phu de...
ffmpeg -y %threads% %hwaccel% -i temp_video_with_audio.mp4 -vf "subtitles=subtitle.srt:force_style='FontName=Arial,FontSize=16,PrimaryColour=&H00FFFFFF,OutlineColour=&H00000000,BackColour=&H80000000,Bold=1,Italic=0,Alignment=2,MarginV=30'" %video_codec% %video_codec_params% -c:a copy final_video.mp4

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
if exist temp_videos rmdir /s /q temp_videos 2>nul
if exist transitions rmdir /s /q transitions 2>nul
if exist temp_video_no_audio.mp4 del temp_video_no_audio.mp4
if exist temp_video_with_audio.mp4 del temp_video_with_audio.mp4

echo Qua trinh hoan tat.
exit /b 0
