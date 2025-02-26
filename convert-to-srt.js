// Hàm chuyển đổi trực tiếp từ Whisper transcription thành SRT
function whisperToSRT(input) {
  try {
    // Kiểm tra input hợp lệ
    if (!input || typeof input !== "object" || !input.words || !Array.isArray(input.words) || input.words.length === 0) {
      throw new Error('Không có dữ liệu đầu vào');
    }

    // Xử lý dữ liệu Whisper thành groups
    const groups = processWhisperGroups(input);
    
    // Chuyển đổi groups thành SRT objects
    const srtObjects = convertGroupsToSRT(groups);
    
    // Tạo chuỗi SRT
    const srtString = generateSrtString(srtObjects);
    
    // Trả về kết quả
    return { 
      srtContent: srtString,
      srtObjects: srtObjects,
      groups: groups
    };
  } catch (error) {
    console.error('Lỗi khi xử lý dữ liệu:', error.message);
    return { error: error.message };
  }
}

// Hàm xử lý dữ liệu transcription mới
function processTranscriptionData(data) {
  if (!data || typeof data !== "object" || !data.words || !Array.isArray(data.words) || !data.text) {
    throw new Error('Dữ liệu transcription không hợp lệ');
  }

  // Xử lý dữ liệu Whisper thành groups
  const groups = processWhisperGroups(data);
  
  // Chuyển đổi groups thành đối tượng SRT
  return convertGroupsToSRT(groups);
}

// Hàm tạo các nhóm phụ đề từ danh sách từ
function createSubtitleGroups(words, fullText) {
  const groups = [];
  let currentGroup = {
    text: "",
    start: words[0].start,
    end: null,
    index: 1
  };
  
  let currentLength = 0;
  const MAX_CHARS_PER_GROUP = 80; // Số ký tự tối đa cho mỗi phụ đề
  const MIN_GROUP_DURATION = 1.0; // Thời lượng tối thiểu cho mỗi phụ đề (giây)
  const MAX_GROUP_DURATION = 5.0; // Thời lượng tối đa cho mỗi phụ đề (giây)
  
  // Tìm và lưu trữ vị trí của các dấu câu trong văn bản đầy đủ
  const punctuationPositions = [];
  const punctuationRegex = /[\.!?;:,]/g;
  let match;
  
  while ((match = punctuationRegex.exec(fullText)) !== null) {
    punctuationPositions.push({
      position: match.index,
      punctuation: match[0]
    });
  }
  
  let textPosition = 0;
  
  for (let i = 0; i < words.length; i++) {
    const word = words[i];
    const wordText = word.word;
    const wordStart = word.start;
    const wordEnd = word.end;
    
    // Tìm vị trí của từ trong văn bản đầy đủ
    const wordPosition = fullText.indexOf(wordText, textPosition);
    if (wordPosition !== -1) {
      textPosition = wordPosition + wordText.length;
      
      // Kiểm tra xem có dấu câu ngay sau từ này không
      const hasPunctuation = punctuationPositions.some(p => 
        p.position >= wordPosition && p.position <= textPosition
      );
      
      // Lấy dấu câu nếu có
      let punctuation = '';
      const punctuationObj = punctuationPositions.find(p => 
        p.position >= wordPosition && p.position <= textPosition
      );
      
      if (punctuationObj) {
        punctuation = punctuationObj.punctuation;
      }
      
      // Kiểm tra xem có nên bắt đầu nhóm mới không
      const groupDuration = wordEnd - currentGroup.start;
      const isPunctuation = /[\.!?]/.test(punctuation); // Dấu câu kết thúc câu
      const isBreakPunctuation = /[;:,]/.test(punctuation); // Dấu câu ngắt câu (thêm dấu phẩy vào đây)
      const isLongEnough = groupDuration >= MIN_GROUP_DURATION;
      const isTooLong = groupDuration > MAX_GROUP_DURATION;
      const wouldBeTooLong = currentLength + wordText.length + 1 > MAX_CHARS_PER_GROUP;
      
      // Thêm từ vào nhóm hiện tại (bao gồm cả dấu câu nếu có)
      if (currentGroup.text) {
        currentGroup.text += " " + wordText + (punctuation || '');
        currentLength += wordText.length + 1 + (punctuation ? punctuation.length : 0);
      } else {
        currentGroup.text = wordText + (punctuation || '');
        currentLength = wordText.length + (punctuation ? punctuation.length : 0);
      }
      currentGroup.end = wordEnd;
      
      // Kiểm tra điều kiện để tạo nhóm mới
      if (currentGroup.text && (
          (isPunctuation && isLongEnough) || 
          (isBreakPunctuation && isLongEnough) ||
          isTooLong || 
          wouldBeTooLong
        ) && i < words.length - 1) { // Đảm bảo không phải từ cuối cùng
        
        // Hoàn thành nhóm hiện tại
        groups.push({...currentGroup});
        
        // Bắt đầu nhóm mới
        currentGroup = {
          text: "",
          start: words[i+1].start,
          end: null,
          index: groups.length + 1
        };
        currentLength = 0;
      }
    } else {
      // Nếu không tìm thấy từ trong văn bản, thêm vào nhóm hiện tại
      if (currentGroup.text) {
        currentGroup.text += " " + wordText;
        currentLength += wordText.length + 1;
      } else {
        currentGroup.text = wordText;
        currentLength = wordText.length;
      }
      currentGroup.end = wordEnd;
    }
  }
  
  // Thêm nhóm cuối cùng nếu có
  if (currentGroup.text) {
    groups.push({...currentGroup});
  }
  
  return groups;
}

// Hàm xử lý whisper transcription thành groups theo cấu trúc mới
function processWhisperGroups(input) {
  // Kiểm tra input hợp lệ
  if (!input || typeof input !== "object" || !input.words || !Array.isArray(input.words) || input.words.length === 0) {
    throw new Error('Dữ liệu đầu vào không hợp lệ');
  }

  const words = input.words;
  const fullText = input.text;

  // Khởi tạo nhóm đầu tiên
  let groups = [];
  let currentGroup = {
    text: "",
    start: words[0].start,
    end: null,
    startIndex: 0,
    endIndex: null,
    index: 1,
  };

  let lastPosition = 0;
  let charCount = 0;

  for (let i = 0; i < words.length; i++) {
    const wordObj = words[i];
    
    // Thêm từ vào nhóm hiện tại
    if (currentGroup.text) {
      currentGroup.text += " " + wordObj.word;
      charCount += wordObj.word.length + 1; // +1 cho khoảng trắng
    } else {
      currentGroup.text = wordObj.word;
      charCount += wordObj.word.length;
    }
    
    currentGroup.end = wordObj.end;
    currentGroup.endIndex = i;
    
    // Tìm vị trí từ trong văn bản, bắt đầu từ vị trí lastPosition
    const wordPos = fullText.indexOf(wordObj.word, lastPosition);
    if (wordPos !== -1) {
      lastPosition = wordPos + wordObj.word.length;
      
      // Kiểm tra có dấu câu ngay sau từ này không
      const nextChar = fullText.charAt(lastPosition);
      const isPunctuation = /[\.,;!?:]/.test(nextChar);
      
      if (isPunctuation && charCount >= 3) {
        // Đủ điều kiện tạo nhóm mới
        groups.push({ ...currentGroup });
        
        // Khởi tạo nhóm mới nếu còn từ tiếp theo
        if (i + 1 < words.length) {
          currentGroup = {
            text: "",
            start: words[i + 1].start,
            end: null,
            startIndex: i + 1,
            endIndex: null,
            index: groups.length + 1,
          };
          charCount = 0;
        } else {
          // Không còn từ nào nữa
          currentGroup = null;
          break;
        }
      } else if (isPunctuation && charCount < 3) {
        // Có dấu câu nhưng đoạn quá ngắn, bỏ qua và tiếp tục
        lastPosition++; // Bỏ qua dấu câu để không kiểm tra lại nó
      }
    }
  }

  // Xử lý nhóm cuối cùng (nếu có)
  if (currentGroup && currentGroup.text) {
    groups.push({ ...currentGroup });
  }

  return groups;
}

// Hàm chuyển đổi groups thành SRT objects
function convertGroupsToSRT(groups) {
  return groups.map((group, index) => {
    return {
      id: index + 1,
      startTime: formatTime(group.start),
      endTime: formatTime(group.end),
      text: group.text
    };
  });
}

// Hàm chuyển đổi số giây thành định dạng thời gian SRT (HH:MM:SS,mmm)
function formatTime(seconds) {
  seconds = parseFloat(seconds);
  
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const secs = Math.floor(seconds % 60);
  const milliseconds = Math.floor((seconds - Math.floor(seconds)) * 1000);
  
  // Định dạng theo chuẩn SRT: HH:MM:SS,mmm
  return `${padZero(hours)}:${padZero(minutes)}:${padZero(secs)},${padZero(milliseconds, 3)}`;
}

// Hàm thêm số 0 vào đầu
function padZero(num, length = 2) {
  return num.toString().padStart(length, '0');
}

// Tạo định dạng SRT chuẩn từ JSON SRT
function generateSrtString(srtJson) {
  return srtJson.map(entry => {
    return `${entry.id}\n${entry.startTime} --> ${entry.endTime}\n${entry.text}\n`;
  }).join('\n');
}

// Hàm chính để sử dụng trong n8n
function main() {
  try {
    // Lấy dữ liệu đầu vào từ $input.item.json
    const input = $input.item.json;
    
    // Kiểm tra input hợp lệ
    if (!input || typeof input !== "object" || !input.words || !Array.isArray(input.words) || input.words.length === 0) {
      return [{ json: { error: 'Dữ liệu đầu vào không hợp lệ' } }];
    }
    
    // Xử lý dữ liệu Whisper thành groups
    const groups = processWhisperGroups(input);
    
    // Chuyển đổi groups thành SRT objects
    const srtObjects = convertGroupsToSRT(groups);
    
    // Tạo chuỗi SRT
    const srtString = generateSrtString(srtObjects);
    
    // Trả về kết quả
    return [{ 
      json: { 
        srtContent: srtString,
        srtObjects: srtObjects,
        groups: groups
      } 
    }];
  } catch (error) {
    console.error('Lỗi khi xử lý dữ liệu:', error.message);
    return [{ json: { error: error.message } }];
  }
}

// Gọi hàm chính
return main();