// Hàm chuyển đổi số giây thành định dạng thời gian ASS (H:MM:SS.cs)
function formatAssTime(seconds) {
    seconds = parseFloat(seconds);
    const totalCentiseconds = Math.floor(seconds * 100);
    const cs = totalCentiseconds % 100;
    const totalSeconds = Math.floor(totalCentiseconds / 100);
    const s = totalSeconds % 60;
    const totalMinutes = Math.floor(totalSeconds / 60);
    const m = totalMinutes % 60;
    const h = Math.floor(totalMinutes / 60);
    return `${h}:${padZero(m)}:${padZero(s)}.${padZero(cs, 2)}`;
  }
  
  // Hàm thêm số 0 vào đầu
  function padZero(num, length = 2) {
    return num.toString().padStart(length, '0');
  }
  
  // Hàm chuyển đổi groups thành ASS dialogue events với hiệu ứng karaoke cho từng từ
  function convertGroupsToASS(groups, words) {
    return groups.map((group) => {
      let karaokeLine = "";
      // Duyệt qua các từ từ startIndex đến endIndex trong mảng words
      let startIndex = group.startIndex || 0;
      let endIndex = group.endIndex || 0;
      for (let i = startIndex; i <= endIndex; i++) {
        const wordObj = words[i];
        // Tính thời lượng của từ tính theo centisecond (1 giây = 100 cs)
        const duration = Math.round((wordObj.end - wordObj.start) * 100);
        // Ghép với tag {\k<duration>}
        karaokeLine += `{\\k${duration}}${wordObj.word} `;
      }
      karaokeLine = karaokeLine.trim();
      return {
        id: group.index,
        startTime: formatAssTime(group.start),
        endTime: formatAssTime(group.end),
        text: karaokeLine
      };
    });
  }
  
  // Hàm tạo header cho file ASS
  function generateAssHeader() {
    return `[Script Info]
  ; Script generated by Whisper to ASS converter
  Title: Whisper to ASS
  ScriptType: v4.00+
  Collisions: Normal
  PlayResX: 1920
  PlayResY: 1080
  Timer: 100.0000
  
  [V4+ Styles]
  Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
  Style: Default,Arial,48,&H00FFFFFF,&H0000FFFF,&H00000000,&H80000000,0,0,0,0,100,100,0,0,1,2,0,2,10,10,10,1
  
  [Events]
  Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text`;
  }
  
  // Hàm tạo chuỗi ASS từ các dialogue events
  function generateAssString(assObjects) {
    const header = generateAssHeader();
    const dialogueLines = assObjects.map(entry => {
      return `Dialogue: 0,${entry.startTime},${entry.endTime},Default,,0,0,0,,${entry.text}`;
    }).join('\n');
    return `${header}\n${dialogueLines}`;
  }
  
  // Hàm xử lý whisper transcription thành groups theo cấu trúc mới (giữ nguyên logic cũ)
  function processWhisperGroups(input) {
    if (!input || typeof input !== "object" || !input.words || !Array.isArray(input.words) || input.words.length === 0) {
      throw new Error('Dữ liệu đầu vào không hợp lệ');
    }
  
    const words = input.words;
    const fullText = input.text;
  
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
        charCount += wordObj.word.length + 1;
      } else {
        currentGroup.text = wordObj.word;
        charCount += wordObj.word.length;
      }
      
      currentGroup.end = wordObj.end;
      currentGroup.endIndex = i;
      
      // Xác định vị trí từ trong fullText
      const wordPos = fullText.indexOf(wordObj.word, lastPosition);
      if (wordPos !== -1) {
        lastPosition = wordPos + wordObj.word.length;
        
        const nextChar = fullText.charAt(lastPosition);
        const isPunctuation = /[\.,;!?:]/.test(nextChar);
        
        if (isPunctuation && charCount >= 3) {
          groups.push({ ...currentGroup });
          
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
            currentGroup = null;
            break;
          }
        } else if (isPunctuation && charCount < 3) {
          lastPosition++; // Bỏ qua dấu câu ngắn
        }
      }
    }
  
    if (currentGroup && currentGroup.text) {
      groups.push({ ...currentGroup });
    }
  
    return groups;
  }
  
  // Hàm chính để sử dụng trong n8n: chuyển Whisper transcription thành ASS subtitle
  function main() {
    try {
      // Lấy dữ liệu đầu vào từ $input.item.json
      const input = $input.item.json;
      
      if (!input || typeof input !== "object" || !input.words || !Array.isArray(input.words) || input.words.length === 0) {
        return [{ json: { error: 'Dữ liệu đầu vào không hợp lệ' } }];
      }
      
      // Xử lý dữ liệu Whisper thành groups
      const groups = processWhisperGroups(input);
      
      // Chuyển đổi groups thành ASS objects với hiệu ứng karaoke
      const assObjects = convertGroupsToASS(groups, input.words);
      
      // Tạo chuỗi ASS
      const assString = generateAssString(assObjects);
      
      return [{
        json: {
          assContent: assString,
          assObjects: assObjects,
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
  