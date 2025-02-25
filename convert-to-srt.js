// Hàm chuyển đổi trực tiếp từ Whisper transcription thành SRT
function whisperToSRT(items) {
  try {
    // Kiểm tra input hợp lệ
    if (!items || !Array.isArray(items) || items.length === 0) {
      throw new Error('Không có dữ liệu đầu vào');
    }

    // Lấy dữ liệu từ input - xử lý dữ liệu từ node "Create Transcription" trong n8n
    let inputData;
    
    // Xử lý dữ liệu từ biểu thức $("Create Transcription").last()
    // Trong n8n, biểu thức này sẽ trả về dữ liệu từ node "Create Transcription"
    // Dữ liệu này sẽ được truyền vào hàm này thông qua tham số items
    
    // Kiểm tra nếu dữ liệu đến từ node "Create Transcription"
    if (items[0] && items[0].json && items[0].json.task === 'transcribe') {
      // Dữ liệu trực tiếp từ node "Create Transcription"
      inputData = items[0].json;
    } else if (items[0] && items[0].json && Array.isArray(items[0].json) && items[0].json[0] && items[0].json[0].task === 'transcribe') {
      // Dữ liệu từ input.json (mảng trong json)
      inputData = items[0].json[0];
    } else if (items[0] && items[0].json) {
      // Dữ liệu có thể được bọc trong json
      inputData = items[0].json;
    } else {
      // Trường hợp khác
      inputData = items;
    }

    // Kiểm tra loại dữ liệu đầu vào
    let srtObjects, srtString;

    // Xử lý dữ liệu theo định dạng từ "Create Transcription"
    if (inputData.task === 'transcribe' && inputData.words && Array.isArray(inputData.words)) {
      // Định dạng từ node "Create Transcription"
      srtObjects = processTranscriptionData(inputData);
      srtString = generateSrtString(srtObjects);
    } else if (Array.isArray(inputData) && inputData[0] && inputData[0].task === 'transcribe') {
      // Định dạng mới từ input.json trong mảng
      const transcriptionData = inputData[0];
      srtObjects = processTranscriptionData(transcriptionData);
      srtString = generateSrtString(srtObjects);
    } else if (inputData.id !== undefined && inputData.startTime !== undefined && inputData.endTime !== undefined && inputData.text !== undefined) {
      // Đã là SRT object
      srtObjects = items;
      srtString = generateSrtString(srtObjects);
    } else if (Array.isArray(inputData) && inputData[0] && inputData[0].id !== undefined) {
      // Mảng SRT objects
      srtObjects = inputData;
      srtString = generateSrtString(srtObjects);
    } else if (inputData.words && Array.isArray(inputData.words) && inputData.text) {
      // Dữ liệu Whisper cần xử lý từ đầu
      const groups = processWhisperGroups(inputData);
      srtObjects = convertGroupsToSRT(groups);
      srtString = generateSrtString(srtObjects);
    } else if (inputData.groups && Array.isArray(inputData.groups)) {
      // Đã có groups
      srtObjects = convertGroupsToSRT(inputData.groups);
      srtString = generateSrtString(srtObjects);
    } else {
      throw new Error('Định dạng dữ liệu không được hỗ trợ');
    }

    // Trả về kết quả
    return [{ 
      json: { 
        srtContent: srtString,
        srtObjects: srtObjects 
      } 
    }];
  } catch (error) {
    console.error('Lỗi khi xử lý dữ liệu:', error.message);
    return [{ json: { error: error.message } }];
  }
}

// Hàm xử lý dữ liệu transcription mới
function processTranscriptionData(data) {
  if (!data.words || !Array.isArray(data.words) || !data.text) {
    throw new Error('Dữ liệu transcription không hợp lệ');
  }

  // Tạo các nhóm phụ đề dựa trên thời gian và dấu câu
  const groups = createSubtitleGroups(data.words, data.text);
  
  // Chuyển đổi các nhóm thành đối tượng SRT
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
  
  for (let i = 0; i < words.length; i++) {
    const word = words[i];
    const wordText = word.word;
    const wordStart = word.start;
    const wordEnd = word.end;
    
    // Kiểm tra xem có nên bắt đầu nhóm mới không
    const groupDuration = wordEnd - currentGroup.start;
    const isPunctuation = /[\.!?]$/.test(wordText);
    const isLongEnough = groupDuration >= MIN_GROUP_DURATION;
    const isTooLong = groupDuration > MAX_GROUP_DURATION;
    const wouldBeTooLong = currentLength + wordText.length + 1 > MAX_CHARS_PER_GROUP;
    
    if (currentGroup.text && (
        (isPunctuation && isLongEnough) || 
        isTooLong || 
        wouldBeTooLong
      )) {
      // Hoàn thành nhóm hiện tại
      currentGroup.end = words[i-1].end;
      groups.push({...currentGroup});
      
      // Bắt đầu nhóm mới
      currentGroup = {
        text: wordText,
        start: wordStart,
        end: wordEnd,
        index: groups.length + 1
      };
      currentLength = wordText.length;
    } else {
      // Thêm từ vào nhóm hiện tại
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

// Hàm xử lý whisper transcription thành groups (giữ lại cho khả năng tương thích)
function processWhisperGroups(input) {
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
    let dataToProcess;
    
    // Trong môi trường n8n
    if (typeof $ !== 'undefined') {
      try {
        // Thử lấy dữ liệu trực tiếp từ biểu thức $("Create Transcription").last().json
        const directData = $("Create Transcription").last().json;
        
        if (directData && directData.task === 'transcribe') {
          console.log('Đang sử dụng dữ liệu trực tiếp từ $("Create Transcription").last().json');
          dataToProcess = [{ json: directData }];
        } else if (Array.isArray(directData) && directData[0] && directData[0].task === 'transcribe') {
          console.log('Đang sử dụng dữ liệu mảng từ $("Create Transcription").last().json');
          dataToProcess = [{ json: directData }];
        } else {
          throw new Error('Dữ liệu trực tiếp không hợp lệ');
        }
      } catch (directError) {
        console.log('Không thể lấy dữ liệu trực tiếp, thử phương pháp khác:', directError.message);
        
        // Ưu tiên lấy dữ liệu từ node "Create Transcription"
        const createTranscriptionNode = $("Create Transcription");
        
        if (createTranscriptionNode && createTranscriptionNode.last()) {
          console.log('Đang sử dụng dữ liệu từ node "Create Transcription"');
          
          // Lấy dữ liệu từ node "Create Transcription"
          const transcriptionData = createTranscriptionNode.last();
          
          // Ghi log thông tin về dữ liệu
          console.log('Loại dữ liệu:', typeof transcriptionData);
          console.log('Có thuộc tính json:', transcriptionData && typeof transcriptionData.json !== 'undefined');
          if (transcriptionData && transcriptionData.json) {
            console.log('Loại dữ liệu json:', typeof transcriptionData.json);
            console.log('Là mảng:', Array.isArray(transcriptionData.json));
            if (Array.isArray(transcriptionData.json)) {
              console.log('Độ dài mảng:', transcriptionData.json.length);
              if (transcriptionData.json.length > 0) {
                console.log('Phần tử đầu tiên có task:', transcriptionData.json[0] && transcriptionData.json[0].task);
              }
            } else {
              console.log('Có thuộc tính task:', transcriptionData.json && transcriptionData.json.task);
            }
          } else {
            console.log('Có thuộc tính task:', transcriptionData && transcriptionData.task);
            console.log('Là mảng:', Array.isArray(transcriptionData));
          }
          
          // Kiểm tra và xử lý các trường hợp khác nhau
          if (transcriptionData && transcriptionData.json) {
            // Trường hợp 1: Dữ liệu có thuộc tính json
            if (transcriptionData.json.task === 'transcribe') {
              // Trường hợp 1.1: Dữ liệu json là đối tượng transcription
              console.log('Xử lý trường hợp 1.1: Dữ liệu json là đối tượng transcription');
              dataToProcess = [{ json: transcriptionData.json }];
            } else if (Array.isArray(transcriptionData.json) && transcriptionData.json[0] && transcriptionData.json[0].task === 'transcribe') {
              // Trường hợp 1.2: Dữ liệu json là mảng chứa đối tượng transcription
              console.log('Xử lý trường hợp 1.2: Dữ liệu json là mảng chứa đối tượng transcription');
              dataToProcess = [{ json: transcriptionData.json }];
            } else {
              // Trường hợp 1.3: Dữ liệu json có định dạng khác
              console.log('Xử lý trường hợp 1.3: Dữ liệu json có định dạng khác');
              dataToProcess = [{ json: transcriptionData.json }];
            }
          } else if (transcriptionData && transcriptionData.task === 'transcribe') {
            // Trường hợp 2: Dữ liệu trực tiếp là đối tượng transcription
            console.log('Xử lý trường hợp 2: Dữ liệu trực tiếp là đối tượng transcription');
            dataToProcess = [{ json: transcriptionData }];
          } else if (Array.isArray(transcriptionData) && transcriptionData[0] && transcriptionData[0].task === 'transcribe') {
            // Trường hợp 3: Dữ liệu là mảng chứa đối tượng transcription
            console.log('Xử lý trường hợp 3: Dữ liệu là mảng chứa đối tượng transcription');
            dataToProcess = [{ json: transcriptionData }];
          } else {
            // Trường hợp 4: Định dạng không xác định, thử sử dụng trực tiếp
            console.log('Xử lý trường hợp 4: Định dạng không xác định, thử sử dụng trực tiếp');
            dataToProcess = [{ json: transcriptionData }];
          }
          
          console.log('Dữ liệu đã được xử lý:', JSON.stringify(dataToProcess).substring(0, 100) + '...');
        } else {
          // Thử tìm node "Read Binary File" hoặc "Read Binary Files" (có thể chứa input.json)
          const readBinaryNode = $("Read Binary File") || $("Read Binary Files");
          
          if (readBinaryNode && readBinaryNode.last()) {
            console.log('Đang sử dụng dữ liệu từ node đọc tệp nhị phân');
            const binaryData = readBinaryNode.last();
            
            // Kiểm tra xem dữ liệu có phải là JSON không
            if (binaryData && binaryData.json) {
              // Đã là JSON
              dataToProcess = [{ json: binaryData.json }];
            } else if (binaryData && binaryData.binary && binaryData.binary.data) {
              // Dữ liệu nhị phân, thử chuyển đổi thành JSON
              try {
                const base64Data = binaryData.binary.data;
                const jsonString = Buffer.from(base64Data, 'base64').toString('utf-8');
                const jsonData = JSON.parse(jsonString);
                
                // Đặt dữ liệu JSON vào định dạng mà whisperToSRT có thể xử lý
                dataToProcess = [{ json: jsonData }];
              } catch (e) {
                console.error('Không thể chuyển đổi dữ liệu nhị phân thành JSON:', e.message);
                // Sử dụng items nếu không thể chuyển đổi
                dataToProcess = items;
              }
            } else {
              // Sử dụng dữ liệu như đã có
              dataToProcess = [binaryData];
            }
          } else {
            console.log('Không tìm thấy node "Create Transcription" hoặc node đọc tệp, sử dụng items');
            dataToProcess = items;
          }
        }
      }
    } else {
      // Trong môi trường không phải n8n, sử dụng items
      console.log('Không phải môi trường n8n, sử dụng items');
      dataToProcess = items;
    }
    
    // Kiểm tra xem dữ liệu có hợp lệ không
    if (!dataToProcess || !Array.isArray(dataToProcess) || dataToProcess.length === 0) {
      console.error('Dữ liệu không hợp lệ:', dataToProcess);
      throw new Error('Dữ liệu đầu vào không hợp lệ');
    }
    
    // Chuyển đổi dữ liệu sang SRT
    return whisperToSRT(dataToProcess);
  } catch (error) {
    console.error('Lỗi khi xử lý dữ liệu:', error.message);
    return [{ json: { error: error.message } }];
  }
}

// Gọi hàm chính
return main();