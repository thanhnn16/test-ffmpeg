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

:: Thiết lập kích thước hình ảnh đầu vào và kích thước video đầu ra
set img_width=512
set img_height=768
set video_width=512
set video_height=768

:: Thiết lập kích thước scale lớn cho hiệu ứng mượt mà
set large_scale=3000

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
set transition_duration=1.5
set zoom_speed=0.0008
set max_zoom=1.3

:: Xử lý từng ảnh với hiệu ứng Ken Burns
echo Tao video voi hieu ung Ken Burns...
for %%i in (1 2 3 4 5 6 7 8) do (
  echo Dang xu ly anh %%i.jpeg...
  
  :: Tính toán số frame dựa trên thời gian hiển thị
  set /a actual_time=!time_%%i!
  set /a frames=!actual_time! * %fps%
  
  if %%i==1 (
    :: Ảnh 1: Zoom in từ giữa
    ffmpeg -y -threads 0 -loop 1 -i %%i.jpeg -t !actual_time! -vf "scale=%large_scale%:-1,zoompan=z='min(zoom+%zoom_speed%,%max_zoom%)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=!frames!:s=%video_width%x%video_height%:fps=%fps%,setsar=1" -c:v libx264 -pix_fmt yuv420p -preset %preset% -crf %video_quality% temp_videos\%%i.mp4
  ) else if %%i==2 (
    :: Ảnh 2: Zoom out từ góc trên bên phải
    ffmpeg -y -threads 0 -loop 1 -i %%i.jpeg -t !actual_time! -vf "scale=%large_scale%:-1,zoompan=z='if(eq(on,1),%max_zoom%,zoom-%zoom_speed%)':x='iw-iw/zoom':y='0':d=!frames!:s=%video_width%x%video_height%:fps=%fps%,setsar=1" -c:v libx264 -pix_fmt yuv420p -preset %preset% -crf %video_quality% temp_videos\%%i.mp4
  ) else if %%i==3 (
    :: Ảnh 3: Zoom in từ góc dưới bên trái
    ffmpeg -y -threads 0 -loop 1 -i %%i.jpeg -t !actual_time! -vf "scale=%large_scale%:-1,zoompan=z='min(zoom+%zoom_speed%,%max_zoom%)':x='0':y='ih-ih/zoom':d=!frames!:s=%video_width%x%video_height%:fps=%fps%,setsar=1" -c:v libx264 -pix_fmt yuv420p -preset %preset% -crf %video_quality% temp_videos\%%i.mp4
  ) else if %%i==4 (
    :: Ảnh 4: Pan từ trái sang phải
    ffmpeg -y -threads 0 -loop 1 -i %%i.jpeg -t !actual_time! -vf "scale=%large_scale%:-1,zoompan=z='1.1':x='min(max((iw-iw/zoom)*((on)/(!frames!)),0),iw)':y='ih/2-(ih/zoom/2)':d=!frames!:s=%video_width%x%video_height%:fps=%fps%,setsar=1" -c:v libx264 -pix_fmt yuv420p -preset %preset% -crf %video_quality% temp_videos\%%i.mp4
  ) else if %%i==5 (
    :: Ảnh 5: Zoom out từ giữa
    ffmpeg -y -threads 0 -loop 1 -i %%i.jpeg -t !actual_time! -vf "scale=%large_scale%:-1,zoompan=z='if(eq(on,1),%max_zoom%,zoom-%zoom_speed%)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=!frames!:s=%video_width%x%video_height%:fps=%fps%,setsar=1" -c:v libx264 -pix_fmt yuv420p -preset %preset% -crf %video_quality% temp_videos\%%i.mp4
  ) else if %%i==6 (
    :: Ảnh 6: Pan từ trên xuống dưới
    ffmpeg -y -threads 0 -loop 1 -i %%i.jpeg -t !actual_time! -vf "scale=%large_scale%:-1,zoompan=z='1.1':x='iw/2-(iw/zoom/2)':y='min(max((ih-ih/zoom)*((on)/(!frames!)),0),ih)':d=!frames!:s=%video_width%x%video_height%:fps=%fps%,setsar=1" -c:v libx264 -pix_fmt yuv420p -preset %preset% -crf %video_quality% temp_videos\%%i.mp4
  ) else if %%i==7 (
    :: Ảnh 7: Zoom in từ góc trên bên phải
    ffmpeg -y -threads 0 -loop 1 -i %%i.jpeg -t !actual_time! -vf "scale=%large_scale%:-1,zoompan=z='min(zoom+%zoom_speed%,%max_zoom%)':x='iw-iw/zoom':y='0':d=!frames!:s=%video_width%x%video_height%:fps=%fps%,setsar=1" -c:v libx264 -pix_fmt yuv420p -preset %preset% -crf %video_quality% temp_videos\%%i.mp4
  ) else if %%i==8 (
    :: Ảnh 8: Zoom out từ góc dưới bên phải
    ffmpeg -y -threads 0 -loop 1 -i %%i.jpeg -t !actual_time! -vf "scale=%large_scale%:-1,zoompan=z='if(eq(on,1),%max_zoom%,zoom-%zoom_speed%)':x='iw-iw/zoom':y='ih-ih/zoom':d=!frames!:s=%video_width%x%video_height%:fps=%fps%,setsar=1" -c:v libx264 -pix_fmt yuv420p -preset %preset% -crf %video_quality% temp_videos\%%i.mp4
  )
  
  if not exist temp_videos\%%i.mp4 (
    echo Loi: Khong the tao file video tam cho anh %%i.jpeg
    goto :cleanup
  )
)

:: Tạo file danh sách để ghép video đơn giản (backup method)
(
  echo file 'temp_videos\1.mp4'
  echo file 'temp_videos\2.mp4'
  echo file 'temp_videos\3.mp4'
  echo file 'temp_videos\4.mp4'
  echo file 'temp_videos\5.mp4'
  echo file 'temp_videos\6.mp4'
  echo file 'temp_videos\7.mp4'
  echo file 'temp_videos\8.mp4'
) > concat_list.txt

:: Phương pháp 1: Sử dụng concat demuxer (đơn giản nhất, nhưng không có hiệu ứng)
ffmpeg -y -threads 0 -f concat -safe 0 -i concat_list.txt -c copy temp_videos\basic_concat.mp4

echo Dang noi cac video va ap dung hieu ung chuyen canh...

:: Phương pháp mới cải tiến: Tạo tất cả chuyển cảnh trong một lệnh FFmpeg duy nhất
echo Tao video voi chuyen canh bang phuong phap toi uu...

:: Tạo một filter_complex phức tạp để xử lý tất cả các chuyển cảnh trong một lần thực thi
ffmpeg -y -threads 0 ^
  -i temp_videos\1.mp4 ^
  -i temp_videos\2.mp4 ^
  -i temp_videos\3.mp4 ^
  -i temp_videos\4.mp4 ^
  -i temp_videos\5.mp4 ^
  -i temp_videos\6.mp4 ^
  -i temp_videos\7.mp4 ^
  -i temp_videos\8.mp4 ^
  -filter_complex ^
  "[0:v][1:v]xfade=transition=fade:duration=%transition_duration%:offset=%time_1%-%transition_duration%[v01]; ^
   [v01][2:v]xfade=transition=slideleft:duration=%transition_duration%:offset=%time_1%+%time_2%-%transition_duration%[v012]; ^
   [v012][3:v]xfade=transition=slideright:duration=%transition_duration%:offset=%time_1%+%time_2%+%time_3%-%transition_duration%[v0123]; ^
   [v0123][4:v]xfade=transition=circlecrop:duration=%transition_duration%:offset=%time_1%+%time_2%+%time_3%+%time_4%-%transition_duration%[v01234]; ^
   [v01234][5:v]xfade=transition=circleopen:duration=%transition_duration%:offset=%time_1%+%time_2%+%time_3%+%time_4%+%time_5%-%transition_duration%[v012345]; ^
   [v012345][6:v]xfade=transition=hblur:duration=%transition_duration%:offset=%time_1%+%time_2%+%time_3%+%time_4%+%time_5%+%time_6%-%transition_duration%[v0123456]; ^
   [v0123456][7:v]xfade=transition=dissolve:duration=%transition_duration%:offset=%time_1%+%time_2%+%time_3%+%time_4%+%time_5%+%time_6%+%time_7%-%transition_duration%[vfinal]" ^
  -map "[vfinal]" -c:v libx264 -pix_fmt yuv420p -preset %preset% -crf %video_quality% temp_videos\all_transitions.mp4

:: Kiểm tra xem video chuyển cảnh đã được tạo thành công chưa
if not exist temp_videos\all_transitions.mp4 (
    echo Loi: Khong the tao video voi chuyen canh bang phuong phap toi uu.
    echo Thu phuong phap thay the...
    
    :: Thử phương pháp thay thế (chuyển cảnh tuần tự)
    :: Hiệu ứng chuyển cảnh giữa video 1 và 2
    ffmpeg -y -threads 0 -i temp_videos\1.mp4 -i temp_videos\2.mp4 -filter_complex "xfade=transition=fade:duration=%transition_duration%:offset=%time_1%-%transition_duration%" temp_videos\transition_1_2.mp4
    
    if not exist temp_videos\transition_1_2.mp4 (
        echo Loi: Khong the tao chuyen canh giua video 1 va 2.
        goto :use_simple_method
    )
    
    :: Hiệu ứng chuyển cảnh giữa video 1_2 và 3
    ffmpeg -y -threads 0 -i temp_videos\transition_1_2.mp4 -i temp_videos\3.mp4 -filter_complex "xfade=transition=slideleft:duration=%transition_duration%:offset=%time_1%+%time_2%-%transition_duration%" temp_videos\transition_1_2_3.mp4
    
    if not exist temp_videos\transition_1_2_3.mp4 (
        echo Loi: Khong the tao chuyen canh giua video 1_2 va 3.
        goto :use_simple_method
    )
    
    :: Hiệu ứng chuyển cảnh giữa video 1_2_3 và 4
    ffmpeg -y -threads 0 -i temp_videos\transition_1_2_3.mp4 -i temp_videos\4.mp4 -filter_complex "xfade=transition=slideright:duration=%transition_duration%:offset=%time_1%+%time_2%+%time_3%-%transition_duration%" temp_videos\transition_1_2_3_4.mp4
    
    if not exist temp_videos\transition_1_2_3_4.mp4 (
        echo Loi: Khong the tao chuyen canh giua video 1_2_3 va 4.
        goto :use_simple_method
    )
    
    :: Hiệu ứng chuyển cảnh giữa video 1_2_3_4 và 5
    ffmpeg -y -threads 0 -i temp_videos\transition_1_2_3_4.mp4 -i temp_videos\5.mp4 -filter_complex "xfade=transition=circlecrop:duration=%transition_duration%:offset=%time_1%+%time_2%+%time_3%+%time_4%-%transition_duration%" temp_videos\transition_1_2_3_4_5.mp4
    
    if not exist temp_videos\transition_1_2_3_4_5.mp4 (
        echo Loi: Khong the tao chuyen canh giua video 1_2_3_4 va 5.
        goto :use_simple_method
    )
    
    :: Hiệu ứng chuyển cảnh giữa video 1_2_3_4_5 và 6
    ffmpeg -y -threads 0 -i temp_videos\transition_1_2_3_4_5.mp4 -i temp_videos\6.mp4 -filter_complex "xfade=transition=circleopen:duration=%transition_duration%:offset=%time_1%+%time_2%+%time_3%+%time_4%+%time_5%-%transition_duration%" temp_videos\transition_1_2_3_4_5_6.mp4
    
    if not exist temp_videos\transition_1_2_3_4_5_6.mp4 (
        echo Loi: Khong the tao chuyen canh giua video 1_2_3_4_5 va 6.
        goto :use_simple_method
    )
    
    :: Hiệu ứng chuyển cảnh giữa video 1_2_3_4_5_6 và 7
    ffmpeg -y -threads 0 -i temp_videos\transition_1_2_3_4_5_6.mp4 -i temp_videos\7.mp4 -filter_complex "xfade=transition=hblur:duration=%transition_duration%:offset=%time_1%+%time_2%+%time_3%+%time_4%+%time_5%+%time_6%-%transition_duration%" temp_videos\transition_1_2_3_4_5_6_7.mp4
    
    if not exist temp_videos\transition_1_2_3_4_5_6_7.mp4 (
        echo Loi: Khong the tao chuyen canh giua video 1_2_3_4_5_6 va 7.
        goto :use_simple_method
    )
    
    :: Hiệu ứng chuyển cảnh giữa video 1_2_3_4_5_6_7 và 8
    ffmpeg -y -threads 0 -i temp_videos\transition_1_2_3_4_5_6_7.mp4 -i temp_videos\8.mp4 -filter_complex "xfade=transition=dissolve:duration=%transition_duration%:offset=%time_1%+%time_2%+%time_3%+%time_4%+%time_5%+%time_6%+%time_7%-%transition_duration%" temp_videos\final_transition.mp4
    
    if not exist temp_videos\final_transition.mp4 (
        echo Loi: Khong the tao chuyen canh giua video 1_2_3_4_5_6_7 va 8.
        goto :use_simple_method
    )
    
    :: Thêm hiệu ứng fade in/out cho video cuối từ phương pháp tuần tự
    ffmpeg -y -threads 0 -i temp_videos\final_transition.mp4 -vf "fade=t=in:st=0:d=0.5,fade=t=out:st=%fade_out_start%:d=0.5" -c:v libx264 -pix_fmt yuv420p -preset %preset% -crf %video_quality% temp_video_no_audio.mp4
    
    if exist temp_video_no_audio.mp4 (
        goto :add_audio
    )
)

if exist temp_videos\all_transitions.mp4 (
    :: Thêm hiệu ứng fade in/out cho video cuối từ phương pháp tối ưu
    ffmpeg -y -threads 0 -i temp_videos\all_transitions.mp4 -vf "fade=t=in:st=0:d=0.5,fade=t=out:st=%fade_out_start%:d=0.5" -c:v libx264 -pix_fmt yuv420p -preset %preset% -crf %video_quality% temp_video_no_audio.mp4
    
    if exist temp_video_no_audio.mp4 (
        goto :add_audio
    )
)

:use_simple_method
echo Su dung phuong phap don gian...
ffmpeg -y -threads 0 -i temp_videos\basic_concat.mp4 -vf "fade=t=in:st=0:d=0.5,fade=t=out:st=%fade_out_start%:d=0.5" -c:v libx264 -pix_fmt yuv420p -preset %preset% -crf %video_quality% temp_video_no_audio.mp4

if not exist temp_video_no_audio.mp4 (
    echo Loi: Khong the tao file video tam!
    goto :cleanup
)

:add_audio
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
echo Kich thuoc video: %video_width%x%video_height%

:cleanup
echo Xoa file tam...
if exist concat_list.txt del concat_list.txt
if exist images.txt del images.txt
if exist list.txt del list.txt
if exist filter.txt del filter.txt
if exist list_with_transitions.txt del list_with_transitions.txt
if exist temp_videos rmdir /s /q temp_videos 2>nul
if exist temp_video_no_audio.mp4 del temp_video_no_audio.mp4
if exist temp_video_with_audio.mp4 del temp_video_with_audio.mp4

echo Qua trinh hoan tat.
exit /b 0
