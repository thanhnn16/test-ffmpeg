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

:: Kiểm tra sự tồn tại của file âm thanh và phụ đề
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

:: Các thông số cho video
set fps=30
set preset=medium
set video_quality=20
set transition_duration=0.5
set zoom_speed=0.0008
set max_zoom=1.3
set bitrate=3M
set gop_size=15

echo Tao video voi hieu ung Ken Burns cho tung anh...

:: Xử lý từng ảnh với hiệu ứng Ken Burns
for %%i in (1 2 3 4 5 6 7 8) do (
  echo Dang xu ly anh %%i.jpeg...
  set /a actual_time=!time_%%i!
  set /a frames=!actual_time! * %fps%
  if %%i==1 (
    ffmpeg -y -threads 0 -loop 1 -i %%i.jpeg -t !actual_time! -vf "scale=%large_scale%:-1,zoompan=z='min(zoom+%zoom_speed%,%max_zoom%)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=!frames!:s=%video_width%x%video_height%:fps=%fps%,setsar=1" -c:v libx264 -pix_fmt yuv420p -preset %preset% -crf %video_quality% -r %fps% -g %gop_size% -keyint_min %gop_size% -sc_threshold 0 -b:v %bitrate% -movflags +faststart temp_videos\%%i.mp4
  ) else if %%i==2 (
    ffmpeg -y -threads 0 -loop 1 -i %%i.jpeg -t !actual_time! -vf "scale=%large_scale%:-1,zoompan=z='if(eq(on,1),%max_zoom%,zoom-%zoom_speed%)':x='iw-iw/zoom':y='0':d=!frames!:s=%video_width%x%video_height%:fps=%fps%,setsar=1" -c:v libx264 -pix_fmt yuv420p -preset %preset% -crf %video_quality% -r %fps% -g %gop_size% -keyint_min %gop_size% -sc_threshold 0 -b:v %bitrate% -movflags +faststart temp_videos\%%i.mp4
  ) else if %%i==3 (
    ffmpeg -y -threads 0 -loop 1 -i %%i.jpeg -t !actual_time! -vf "scale=%large_scale%:-1,zoompan=z='min(zoom+%zoom_speed%,%max_zoom%)':x='0':y='ih-ih/zoom':d=!frames!:s=%video_width%x%video_height%:fps=%fps%,setsar=1" -c:v libx264 -pix_fmt yuv420p -preset %preset% -crf %video_quality% -r %fps% -g %gop_size% -keyint_min %gop_size% -sc_threshold 0 -b:v %bitrate% -movflags +faststart temp_videos\%%i.mp4
  ) else if %%i==4 (
    ffmpeg -y -threads 0 -loop 1 -i %%i.jpeg -t !actual_time! -vf "scale=%large_scale%:-1,zoompan=z='1.1':x='min(max((iw-iw/zoom)*((on)/(!frames!)),0),iw)':y='ih/2-(ih/zoom/2)':d=!frames!:s=%video_width%x%video_height%:fps=%fps%,setsar=1" -c:v libx264 -pix_fmt yuv420p -preset %preset% -crf %video_quality% -r %fps% -g %gop_size% -keyint_min %gop_size% -sc_threshold 0 -b:v %bitrate% -movflags +faststart temp_videos\%%i.mp4
  ) else if %%i==5 (
    ffmpeg -y -threads 0 -loop 1 -i %%i.jpeg -t !actual_time! -vf "scale=%large_scale%:-1,zoompan=z='if(eq(on,1),%max_zoom%,zoom-%zoom_speed%)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=!frames!:s=%video_width%x%video_height%:fps=%fps%,setsar=1" -c:v libx264 -pix_fmt yuv420p -preset %preset% -crf %video_quality% -r %fps% -g %gop_size% -keyint_min %gop_size% -sc_threshold 0 -b:v %bitrate% -movflags +faststart temp_videos\%%i.mp4
  ) else if %%i==6 (
    ffmpeg -y -threads 0 -loop 1 -i %%i.jpeg -t !actual_time! -vf "scale=%large_scale%:-1,zoompan=z='1.1':x='iw/2-(iw/zoom/2)':y='min(max((ih-ih/zoom)*((on)/(!frames!)),0),ih)':d=!frames!:s=%video_width%x%video_height%:fps=%fps%,setsar=1" -c:v libx264 -pix_fmt yuv420p -preset %preset% -crf %video_quality% -r %fps% -g %gop_size% -keyint_min %gop_size% -sc_threshold 0 -b:v %bitrate% -movflags +faststart temp_videos\%%i.mp4
  ) else if %%i==7 (
    ffmpeg -y -threads 0 -loop 1 -i %%i.jpeg -t !actual_time! -vf "scale=%large_scale%:-1,zoompan=z='min(zoom+%zoom_speed%,%max_zoom%)':x='iw-iw/zoom':y='0':d=!frames!:s=%video_width%x%video_height%:fps=%fps%,setsar=1" -c:v libx264 -pix_fmt yuv420p -preset %preset% -crf %video_quality% -r %fps% -g %gop_size% -keyint_min %gop_size% -sc_threshold 0 -b:v %bitrate% -movflags +faststart temp_videos\%%i.mp4
  ) else if %%i==8 (
    ffmpeg -y -threads 0 -loop 1 -i %%i.jpeg -t !actual_time! -vf "scale=%large_scale%:-1,zoompan=z='if(eq(on,1),%max_zoom%,zoom-%zoom_speed%)':x='iw-iw/zoom':y='ih-ih/zoom':d=!frames!:s=%video_width%x%video_height%:fps=%fps%,setsar=1" -c:v libx264 -pix_fmt yuv420p -preset %preset% -crf %video_quality% -r %fps% -g %gop_size% -keyint_min %gop_size% -sc_threshold 0 -b:v %bitrate% -movflags +faststart temp_videos\%%i.mp4
  )
  
  :: Kiểm tra lỗi sau khi tạo video tạm cho từng ảnh
  if not exist temp_videos\%%i.mp4 (
    echo Loi: Khong the tao file video tam cho anh %%i.jpeg
    goto :cleanup
  ) else (
    echo Tao video tam cho anh %%i.jpeg thanh cong.
  )
)

echo Ghep cac video voi hieu ung transition smoothleft...

:: Ghép các video tạm sử dụng hiệu ứng xfade với transition "smoothleft"
:: Tính toán offset chuyển cảnh:
::   Transition 1: 4 - 0.5 = 3.5 giây
::   Transition 2: (4+3-0.5) - 0.5 = 6.0 giây
::   Transition 3: (4+3+5-0.5*2) - 0.5 = 10.5 giây
::   Transition 4: (4+3+5+3-0.5*3) - 0.5 = 13.0 giây
::   Transition 5: (4+3+5+3+4-0.5*4) - 0.5 = 16.5 giây
::   Transition 6: (4+3+5+3+4+3-0.5*5) - 0.5 = 19.0 giây
::   Transition 7: (4+3+5+3+4+3+5-0.5*6) - 0.5 = 23.5 giây

ffmpeg -y -threads 0 -i temp_videos\1.mp4 -i temp_videos\2.mp4 -i temp_videos\3.mp4 -i temp_videos\4.mp4 -i temp_videos\5.mp4 -i temp_videos\6.mp4 -i temp_videos\7.mp4 -i temp_videos\8.mp4 -filter_complex "[0:v]format=pix_fmts=yuva420p,setpts=PTS-STARTPTS[v0];[1:v]format=pix_fmts=yuva420p,setpts=PTS-STARTPTS[v1];[2:v]format=pix_fmts=yuva420p,setpts=PTS-STARTPTS[v2];[3:v]format=pix_fmts=yuva420p,setpts=PTS-STARTPTS[v3];[4:v]format=pix_fmts=yuva420p,setpts=PTS-STARTPTS[v4];[5:v]format=pix_fmts=yuva420p,setpts=PTS-STARTPTS[v5];[6:v]format=pix_fmts=yuva420p,setpts=PTS-STARTPTS[v6];[7:v]format=pix_fmts=yuva420p,setpts=PTS-STARTPTS[v7];[v0][v1]xfade=transition=smoothleft:duration=0.5:offset=3.5[v01];[v01][v2]xfade=transition=smoothleft:duration=0.5:offset=6.0[v02];[v02][v3]xfade=transition=smoothleft:duration=0.5:offset=10.5[v03];[v03][v4]xfade=transition=smoothleft:duration=0.5:offset=13.0[v04];[v04][v5]xfade=transition=smoothleft:duration=0.5:offset=16.5[v05];[v05][v6]xfade=transition=smoothleft:duration=0.5:offset=19.0[v06];[v06][v7]xfade=transition=smoothleft:duration=0.5:offset=23.5[vout]" -map "[vout]" -c:v libx264 -preset %preset% -crf %video_quality% -r %fps% -pix_fmt yuv420p -movflags +faststart final_video_no_audio.mp4

if not exist final_video_no_audio.mp4 (
  echo Loi: Khong the ghep cac video voi hieu ung transition.
  goto :cleanup
) else (
  echo Ghep cac video voi hieu ung transition thanh cong.
)

:audio_merge
echo Ket hop video voi am thanh...

:: Thiết lập bộ lọc âm thanh: kết hợp voice và nhạc nền
set filter_complex_audio="[1:a]aresample=44100,volume=1.0[voice];[2:a]aresample=44100,volume=0.3[bg];[voice][bg]amix=inputs=2:duration=longest[a]"

:: Ghép âm thanh với video
ffmpeg -y -threads 0 -i final_video_no_audio.mp4 -i voice.mp3 -i bg.mp3 -filter_complex %filter_complex_audio% -map 0:v -map "[a]" -c:v copy -c:a aac -b:a 192k -shortest final_video_with_audio.mp4

if not exist final_video_with_audio.mp4 (
  echo Loi: Khong the ket hop am thanh voi video.
  goto :cleanup
) else (
  echo Ket hop am thanh voi video thanh cong.
)

echo Them phu de vao video...
ffmpeg -y -threads 0 -i final_video_with_audio.mp4 -vf "subtitles=subtitle.srt:force_style='FontName=Arial,FontSize=16,PrimaryColour=&H00FFFFFF,OutlineColour=&H00000000,BackColour=&H80000000,Bold=1,Italic=0,Alignment=2,MarginV=30'" -c:a copy -movflags +faststart final_video.mp4

if not exist final_video.mp4 (
  echo Loi: Khong the tao file video cuoi cung voi phu de!
  copy final_video_with_audio.mp4 final_video.mp4
  if exist final_video.mp4 (
    echo Da sao chep video co am thanh thanh video cuoi cung (khong co phu de).
  ) else (
    echo Khong the tao duoc video cuoi cung! Qua trinh that bai.
    goto :cleanup
  )
) else (
  echo Them phu de thanh cong!
)

echo Hoan thanh! Video da duoc tao: final_video.mp4
echo Kich thuoc video: %video_width%x%video_height%

:cleanup
echo Xoa cac file tam...
if exist simple_list.txt del simple_list.txt 2>nul
if exist images_list.txt del images_list.txt 2>nul
if exist final_video_no_audio.mp4 del final_video_no_audio.mp4 2>nul
if exist final_video_with_audio.mp4 del final_video_with_audio.mp4 2>nul
:: Uncomment dòng dưới đây nếu muốn xoá thư mục chứa video tạm
:: if exist temp_videos rmdir /s /q temp_videos 2>nul

echo Qua trinh hoan tat.
exit /b 0
