#!/bin/sh

# --- Bước 0: Đặt các thông số chung ---
fps=60
preset="veryfast"
video_quality=22
pan_range=30
video_width=720
video_height=1280

echo "Bắt đầu tạo video từ hình ảnh và âm thanh..."

# --- Bước 1: Tạo thư mục tạm để lưu trữ các file tải về ---
temp_dir="temp_files_{{ $('Generate Output Groups').item.json.id }}"
mkdir -p "$temp_dir"

# --- Bước 2: Tải các file hình ảnh về máy cục bộ ---
images="{{ $('Generate Output Groups').item.json.images.join(' ') }}"
durations="{{ $('Generate Output Groups').item.json.durations.join(' ') }}"

echo "Tải các file hình ảnh về máy cục bộ..."
local_images=""
i=1
for img in $images; do
  echo "Đang tải $img..."
  local_img="$temp_dir/image_$i.jpeg"
  
  # Tải file và kiểm tra kết quả
  curl -s -o "$local_img" "$img"
  if [ $? -ne 0 ] || [ ! -s "$local_img" ]; then
    echo "Lỗi: Không thể tải file $img"
    # Tạo một hình ảnh trống thay thế (màu đen)
    ffmpeg -y -f lavfi -i color=c=black:s=${video_width}x${video_height}:d=1 -frames:v 1 "$local_img"
  fi
  
  # Thêm đường dẫn cục bộ vào danh sách
  local_images="$local_images $local_img"
  i=$((i+1))
done

# --- Bước 3: Tạo file danh sách ảnh cho nhóm ---
filename="images_{{ $('Generate Output Groups').item.json.id }}.txt"
rm -f "$filename"

echo "Tạo danh sách hình ảnh..."
i=1
for img in $local_images; do
  duration=$(echo "$durations" | cut -d' ' -f"$i")
  echo "file '$img'" >> "$filename"
  echo "duration $duration" >> "$filename"
  i=$((i+1))
done
last_img=$(echo "$local_images" | awk '{print $NF}')
echo "file '$last_img'" >> "$filename"

# Tính tổng thời gian của tất cả các ảnh
total_duration=0
for d in $durations; do
  total_duration=$(echo "$total_duration + $d" | bc -l)
done
echo "Tổng thời gian video: $total_duration giây"

# --- Bước 4: Tạo thư mục chứa video cho nhóm ---
dir="temp_videos_{{ $('Generate Output Groups').item.json.id }}"
mkdir -p "$dir"

# --- Bước 5: Tải file âm thanh và phụ đề ---
voice_url="{{ $('Generate Output Groups').item.json.voiceUrl }}"
bg_url="{{ $('Generate Output Groups').item.json.bgUrl }}"
subtitle_url="{{ $('Generate Output Groups').item.json.subtitleUrl }}"

voice_file="$temp_dir/voice.mp3"
bg_file="$temp_dir/bg.mp3"
subtitle_file="$temp_dir/subtitle.srt"

echo "Tải file âm thanh và phụ đề..."
curl -s -o "$voice_file" "$voice_url"
if [ $? -ne 0 ] || [ ! -s "$voice_file" ]; then
  echo "Cảnh báo: Không thể tải file giọng nói $voice_url"
  # Tạo file âm thanh trống
  ffmpeg -y -f lavfi -i anullsrc=r=44100:cl=stereo -t 1 -q:a 9 -acodec libmp3lame "$voice_file"
fi

curl -s -o "$bg_file" "$bg_url"
if [ $? -ne 0 ] || [ ! -s "$bg_file" ]; then
  echo "Cảnh báo: Không thể tải file nhạc nền $bg_url"
  # Tạo file âm thanh trống
  ffmpeg -y -f lavfi -i anullsrc=r=44100:cl=stereo -t 1 -q:a 9 -acodec libmp3lame "$bg_file"
fi

curl -s -o "$subtitle_file" "$subtitle_url"
if [ $? -ne 0 ] || [ ! -s "$subtitle_file" ]; then
  echo "Cảnh báo: Không thể tải file phụ đề $subtitle_url"
  # Tạo file phụ đề trống
  echo "1" > "$subtitle_file"
  echo "00:00:00,000 --> 00:00:05,000" >> "$subtitle_file"
  echo "Không có phụ đề" >> "$subtitle_file"
  echo "" >> "$subtitle_file"
fi

# --- Bước 6: Chuyển từng ảnh thành file video với hiệu ứng zoompan ---
echo "Tạo video từ hình ảnh với hiệu ứng pan dọc..."
num_images=$(echo "$local_images" | wc -w | tr -d ' ')
i=1
for img in $local_images; do
  duration=$(echo "$durations" | cut -d' ' -f"$i")
  
  echo "Đang xử lý ảnh $img với hiệu ứng pan dọc..."
  
  mod=$((i % 2))
  if [ "$mod" -eq 0 ]; then
    # Ảnh chẵn: cuộn lên (y giảm từ pan_range về 0)
    y_expr="${pan_range} - (${pan_range}*on/((${fps}*${duration})-1))"
  else
    # Ảnh lẻ: cuộn xuống (y tăng từ 0 đến pan_range)
    y_expr="(${pan_range}*on/((${fps}*${duration})-1))"
  fi
  
  ffmpeg -y -threads 0 -loop 1 -i "$img" -t "$duration" \
    -vf "scale=${video_width}:${video_height}:force_original_aspect_ratio=increase,crop=${video_width}:${video_height},zoompan=z='1.1':d=${fps}*${duration}:x='iw/2-(iw/1.1)/2':y=${y_expr}:s=${video_width}x${video_height}:fps=${fps}" \
    -c:v libx264 -pix_fmt yuv420p -preset "$preset" -crf "$video_quality" "$dir/$i.mp4"
  
  # Kiểm tra xem file video đã được tạo thành công chưa
  if [ ! -f "$dir/$i.mp4" ] || [ ! -s "$dir/$i.mp4" ]; then
    echo "Lỗi: Không thể tạo video cho ảnh $img"
    # Tạo một video trống thay thế
    ffmpeg -y -f lavfi -i color=c=black:s=${video_width}x${video_height}:d=$duration -c:v libx264 -pix_fmt yuv420p -preset "$preset" -crf "$video_quality" "$dir/$i.mp4"
  fi
  
  i=$((i+1))
done

# --- Bước 7: Tạo danh sách các video tạm thời ---
echo "Tạo danh sách các video tạm thời..."
list_file="list_{{ $('Generate Output Groups').item.json.id }}.txt"
rm -f "$list_file"
for i in $(seq 1 $num_images); do
  if [ -f "$dir/$i.mp4" ]; then
    echo "file '$dir/$i.mp4'" >> "$list_file"
  fi
done

# Kiểm tra xem có video nào được tạo không
if [ ! -s "$list_file" ]; then
  echo "Lỗi: Không có video nào được tạo thành công!"
  exit 1
fi

# Tính thời điểm bắt đầu fade out (tổng thời gian - 1 giây)
fade_out_start=$(echo "$total_duration - 1" | bc -l)

# --- Bước 8: Nối các video lại với nhau và thêm hiệu ứng chuyển tiếp ---
echo "Nối các video lại với nhau và thêm hiệu ứng chuyển tiếp..."
temp_video_no_audio="temp_video_no_audio_{{ $('Generate Output Groups').item.json.id }}.mp4"
ffmpeg -y -threads 0 -f concat -safe 0 -i "$list_file" \
  -filter_complex "fps=${fps},format=yuv420p,fade=t=in:st=0:d=0.5,fade=t=out:st=${fade_out_start}:d=0.5" \
  -c:v libx264 -pix_fmt yuv420p -preset "$preset" -crf "$video_quality" "$temp_video_no_audio"

if [ ! -f "$temp_video_no_audio" ] || [ ! -s "$temp_video_no_audio" ]; then
  echo "Lỗi: Không thể tạo file video tạm!"
  exit 1
fi

# --- Bước 9: Kết hợp video với âm thanh ---
echo "Kết hợp video với âm thanh..."
temp_video_with_audio="temp_video_with_audio_{{ $('Generate Output Groups').item.json.id }}.mp4"
ffmpeg -y -threads 0 -i "$temp_video_no_audio" \
  -i "$voice_file" \
  -i "$bg_file" \
  -filter_complex "[1:a]volume=1.0[voice];[2:a]volume=0.3[bg];[voice][bg]amix=inputs=2:duration=longest,dynaudnorm=f=150:g=15[a]" \
  -map 0:v -map "[a]" -c:v copy -c:a aac -b:a 192k -shortest "$temp_video_with_audio"

if [ ! -f "$temp_video_with_audio" ] || [ ! -s "$temp_video_with_audio" ]; then
  echo "Lỗi: Không thể tạo file video với âm thanh!"
  exit 1
fi

# --- Bước 10: Thêm phụ đề vào video ---
echo "Thêm phụ đề..."
final_video="final_video_{{ $('Generate Output Groups').item.json.id }}.mp4"
ffmpeg -y -threads 0 -i "$temp_video_with_audio" \
  -vf "subtitles=${subtitle_file}:force_style='FontName=Arial,FontSize=16,PrimaryColour=&H00FFFFFF,OutlineColour=&H00000000,BackColour=&H80000000,Bold=1,Italic=0,Alignment=2,MarginV=30'" \
  -c:a copy "$final_video"

if [ ! -f "$final_video" ] || [ ! -s "$final_video" ]; then
  echo "Lỗi: Không thể tạo file video cuối cùng!"
  exit 1
fi

echo "Hoàn thành! Video đã được tạo: $final_video"
echo "Kích thước video: ${video_width}x${video_height} (9:16 ratio)"

# --- Bước 11: Dọn dẹp các file tạm ---
echo "Xóa file tạm..."
rm -f "$filename" "$list_file"
rm -rf "$dir" "$temp_dir" 