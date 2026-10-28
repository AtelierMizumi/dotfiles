# Hướng dẫn dùng niri + Noctalia

Bảng phím và cách làm việc hằng ngày cho laptop và bàn phím Sofle. Gõ `Super+Shift+/` bất cứ lúc nào để niri hiện
bảng các phím quan trọng ngay trên màn hình.

## Bắt đầu trong hai phút

| Muốn | Bấm |
|---|---|
| Mở terminal (ghostty) | `Super+T` hoặc `Super+Return` |
| Mở app / tìm file / chạy lệnh | `Super+D` |
| Đổi bộ gõ (Anh → Việt → Nhật → Anh) | `Super+Backspace` |
| Mở trình duyệt, file manager, VS Code | `Super+B`, `Super+E`, `Super+C` |
| Đóng cửa sổ | `Super+Q` |
| Chuyển sang cột bên trái / phải | `Super+H`, `Super+L` |
| Xem tất cả cửa sổ (overview) | `Super+O` |
| Xem bảng phím | `Super+Shift+/` |

Super là phím Windows trên laptop, và là **phím ngón cái trái** (`LGUI`) trên Sofle.

## Quy tắc thiết kế của bộ phím

- Mọi tổ hợp chỉ có **tối đa 3 phím**: Super, thêm tối đa một phím sửa đổi (Shift hoặc Alt), và một phím thường. Có test
  tự động kiểm tra điều này.
- Chỉ dùng chữ cái, chữ số và các phím ngón cái ở **layer chính** của Sofle: không cần F1-F12, Print, Home, End,
  PgUp, PgDn hay mũi tên. Các biến thể mũi tên chỉ là phần thêm cho laptop (hoặc giữ layer NAV trên Sofle).
- Phím sửa đổi thứ hai là **Shift hoặc Alt**, không phải Ctrl: trên Sofle, Ctrl chỉ có khi giữ `Space`, khó chạm cùng
  Super. Alt nằm ở ngón út trái, Shift ở ngón út trái hàng dưới.
- Trên Sofle, `Super+-` và `Super+=` là các phím ngón cái cạnh nhau, bấm bằng một tay. `Super+Backspace` (đổi bộ gõ)
  là hai ngón cái: Super ở ngón cái trái, Backspace ở ngón cái phải.

## Bảng phím

### Ứng dụng

| Phím | Việc |
|---|---|
| `Super+T`, `Super+Return` | terminal (ghostty) |
| `Super+B` | trình duyệt (zen) |
| `Super+E` | file manager (dolphin) |
| `Super+C` | VS Code |

### Desktop shell (mizu / Noctalia)

| Phím | Việc |
|---|---|
| `Super+D` | launcher |
| `Super+S` | control center (quick panel) |
| `Super+Alt+S` | settings của shell |
| `Super+Shift+V` | lịch sử clipboard |
| `Super+N` | bật/tắt Do Not Disturb |
| `Super+Alt+W` | chuyển hình nền kế tiếp (palette tự đổi theo) |
| `Super+Esc`, `Super+Alt+L` | khóa màn hình |

### Bộ gõ

| Phím | Việc |
|---|---|
| `Super+Backspace` | chuyển sang bộ gõ kế tiếp, xoay vòng: bàn phím US → Lotus (tiếng Việt) → anthy (tiếng Nhật) → US |
| `Super+Alt+Space` | chọn thẳng tiếng Việt (Lotus) |
| `Super+Shift+Space` | chọn thẳng tiếng Nhật (anthy) |

Chi tiết và cách xử lý khi gõ không ra tiếng Việt: xem mục "Gõ tiếng Việt và tiếng Nhật" bên dưới.

### Di chuyển và cửa sổ

| Phím | Việc |
|---|---|
| `Super+H`, `Super+L` | focus cột trái / phải |
| `Super+J`, `Super+K` | focus cửa sổ dưới / trên trong cột |
| `Super+Shift+H/J/K/L` | **di chuyển** cột sang trái / cửa sổ xuống / cửa sổ lên / cột sang phải |
| `Super+Z` | căn giữa cột (Z là zen) |
| `Super+F`, `Super+Shift+F` | phóng to cột / toàn màn hình |
| `Super+R`, `Super+Alt+R` | đổi nhanh độ rộng cột / chiều cao cửa sổ theo mức đặt sẵn |
| `Super+-`, `Super+=` | thu / phóng cột 10% |
| `Super+W` | gộp các cửa sổ của cột thành tab |
| `Super+V`, `Super+Alt+V` | cửa sổ nổi hay xếp / đổi focus giữa nổi và xếp |
| `Super+Q` | đóng cửa sổ |
| `Super+O` | overview |

### Workspace

| Phím | Việc |
|---|---|
| `Super+1..9` | sang workspace 1 đến 9 |
| `Super+Shift+1..9` | chuyển cột đang chọn sang workspace 1 đến 9 |
| `Super+U`, `Super+I` | workspace dưới / trên |

### Nhiều màn hình

| Phím | Việc |
|---|---|
| `Super+Tab` | focus sang màn hình kế (hai màn hình: qua lại) |
| `Super+Shift+Tab` | gửi cột sang màn hình kế |
| `Super+Shift+Left`, `Super+Shift+Right`, `Super+Shift+Up`, `Super+Shift+Down` | focus màn hình theo hướng |
| `Super+Alt+Left`, `Super+Alt+Right`, `Super+Alt+Up`, `Super+Alt+Down` | gửi cột sang màn hình theo hướng |

### Chụp màn hình, độ sáng, âm thanh

| Phím | Việc |
|---|---|
| `Super+Shift+S` | chụp một vùng (laptop: `Print` cũng được) |
| `Super+Alt+-`, `Super+Alt+=` | giảm / tăng độ sáng (cho Sofle, không có phím độ sáng) |
| `XF86MonBrightnessDown`, `XF86MonBrightnessUp` | phím độ sáng của laptop |
| `XF86AudioLowerVolume`, `XF86AudioRaiseVolume`, `XF86AudioMute`, `XF86AudioMicMute` | âm lượng và micro (phím laptop, núm xoay Sofle) |
| `XF86AudioPlay`, `XF86AudioStop`, `XF86AudioPrev`, `XF86AudioNext` | điều khiển nhạc |

Các phím mặc định khác của niri vẫn hoạt động, ví dụ `Super+M` (phóng to sát mép), `Super+,` và `Super+.` (gộp hoặc
tách cửa sổ vào cột), `Super+[` và `Super+]`, các biến thể `Super+Ctrl+...`, kéo chuột kèm Super để di chuyển cửa sổ.

## Phím đã chuyển so với mặc định của niri

| Chức năng | Trước | Nay |
|---|---|---|
| Căn giữa cột | `Super+C` | `Super+Z` |
| Đổi focus giữa nổi và xếp | `Super+Shift+V` | `Super+Alt+V` |
| Chặn phím tắt (cho VM, điều khiển từ xa) | `Super+Esc` | `Super+Alt+Esc` |
| Đổi chiều cao cửa sổ theo mức đặt sẵn | `Super+Ctrl+Shift+R` | `Super+Alt+R` |
| Chuyển cột sang màn hình khác | `Super+Shift+Ctrl+H/J/K/L` (4 phím) | `Super+Shift+Tab` hoặc `Super+Alt+mũi tên` |
| Focus màn hình bằng `H/J/K/L` | `Super+Shift+H/J/K/L` | mũi tên, hoặc `Super+Tab` (`H/J/K/L` nay là di chuyển) |

Đã bỏ: các bind 4 phím (`Super+Shift+Ctrl+...` và cuộn chuột `Super+Ctrl+Shift`), và bind bật Orca screen reader.

## Làm việc hằng ngày khi code

- **Bố cục:** niri xếp cửa sổ thành các **cột** cuộn ngang. Mở terminal (`Super+T`) cạnh editor (`Super+C`): VS Code
  mở full width, nên cuộn bằng `Super+H` / `Super+L` giữa chúng, hoặc `Super+R` để chia cột theo tỷ lệ.
- **Nhiều terminal trong một cột:** `Super+,` đưa cửa sổ bên phải vào cột hiện tại; `Super+W` đổi sang dạng tab.
- **Mỗi dự án một workspace:** `Super+1..9` để chuyển, `Super+Shift+1..9` để đưa cửa sổ sang. `Super+O` để nhìn tổng
  quan.
- **Hai màn hình:** laptop (`eDP-1`, scale 1) ở trái, màn ngoài (`HDMI-A-1`) ở bên phải, đúng như trên Plasma.
  `Super+Tab` qua lại giữa hai màn, `Super+Shift+Tab` mang cột theo. niri không ép tần số quét nên màn ngoài dùng tần
  số cao nhất của nó.
- **Clipboard:** `Super+Shift+V` mở lịch sử, chọn mục để dán lại.
- **Tập trung:** `Super+N` bật Do Not Disturb khi họp hoặc code sâu.
- **Gõ tiếng Việt và tiếng Nhật:** xem mục riêng ngay bên dưới.

## Gõ tiếng Việt và tiếng Nhật

`fcitx5` tự khởi động cùng session niri (mục autostart của hệ thống), và `/etc/environment` đã đặt `GTK_IM_MODULE`,
`QT_IM_MODULE`, `XMODIFIERS` cho mọi session, giống như trên Plasma. Nhóm bộ gõ trong
`~/.config/fcitx5/profile` là: bàn phím US, Lotus (tiếng Việt, mặc định Telex) và anthy (tiếng Nhật).

- **Vì sao phím đổi bộ gõ nằm trong niri:** `Super+Backspace` chạy `~/.config/niri/scripts/fcitx5-cycle`. Script đọc
  thứ tự bộ gõ của nhóm hiện tại trong `~/.config/fcitx5/profile` (chỉ đọc, không ghi) rồi chọn bộ gõ kế tiếp bằng
  `fcitx5-remote -s`, kể cả khi chưa có ô nhập nào được focus. Trước đây `fcitx5-remote -t` chỉ bật qua lại với bộ gõ
  dùng gần nhất, nên bộ gõ thứ ba bị bỏ qua. Thêm bộ gõ trong `fcitx5-configtool` thì vòng xoay tự có bộ gõ đó.
  `Super+Space` không còn bind trong niri, nên phím `Super+space` riêng của fcitx5 (dùng chung với Plasma) vẫn chạy
  trong ô nhập. Trạng thái bộ gõ nhớ riêng cho từng cửa sổ (`ShareInputState=No`).
- **Kiểm tra nhanh trong terminal:** `fcitx5-remote -n` in tên bộ gõ hiện tại (`keyboard-us`, `lotus` hoặc `anthy`);
  `fcitx5-remote -s lotus` chọn Lotus ngay, `fcitx5-remote -s keyboard-us` về gõ thường.
- **Lotus cần dịch vụ nền:** `fcitx5-lotus-server@<tên user>` phải đang chạy (`systemctl status
  fcitx5-lotus-server@$USER`); trên máy này nó đã bật. Tùy chỉnh kiểu gõ bằng `fcitx5-lotus-settings`.
- **Nếu gõ không ra dấu trong một ứng dụng:** thử chế độ khác của Lotus cho ứng dụng đó (Lotus có nhiều chế độ gõ, xem
  `fcitx5-lotus-settings`), và lưu ý ứng dụng Electron (VS Code, Discord, Vesktop) thường chạy qua XWayland nên đi
  bằng `XMODIFIERS` (chưa kiểm chứng trên máy này).

## Khóa và tắt màn hình

Máy để ở bàn với hai màn hình cố định, nên thời gian khá dài: màn hình tắt sau **30 phút**, khóa sau **45 phút**,
và **không tự suspend** (build, docker hay tải xuống không bị ngắt). Ứng dụng nào yêu cầu chặn idle (thường là trình phát video) thì được
tôn trọng. Khóa thủ công bằng `Super+Esc`. Muốn đổi, sửa `timeout` (giây) trong `[idle.behavior.screen-off]` và `[idle.behavior.lock]`
của `noctalia/.config/noctalia/config.toml`; Noctalia tự nạp lại khi lưu.

## Thay đổi cấu hình

- Mọi cấu hình nằm trong repo `~/Projects/Tools/dotfiles`; `~/.config` chỉ chứa symlink do `stow` tạo.
- Sửa `niri/.config/niri/config.kdl`: niri tự nạp lại khi lưu. Kiểm tra trước bằng `niri validate`. Bind mới nên giữ
  quy tắc tối đa 3 phím, và phải thêm vào tài liệu này (test `bash tests/run-all.sh` sẽ nhắc nếu quên).
- Sửa `noctalia/.config/noctalia/config.toml`: kiểm tra bằng `noctalia config validate` (chạy không đối số; đạt khi
  thoát 0 và không có dòng `WARN` hay `ERROR`). Đừng bật template builtin/community hay `sync_color_scheme`: chúng ghi
  vào file của Plasma. Template duy nhất được phép là `niri-colors`, chỉ ghi `~/.config/niri/colors.kdl`.
- Màu giao diện lấy từ wallpaper (sơ đồ `faithful`). Đổi wallpaper bằng widget wallpaper trên bar (thư mục
  `~/Pictures/Wallpapers`: `landscape/`, `anime/`, `cinematic/`), màu bar và viền cửa sổ đổi theo. Đổi sơ đồ:
  `noctalia msg color-scheme-set wallpaper vibrant` (hoặc `faithful`, `soft`, `m3-content`...).
- Mỗi lần xong một thay đổi, commit để có thể quay lại.

## Tự khởi động app

Khi niri khởi động, `scripts/apps-start` mở lần lượt zen-browser, Antigravity, ZCode, Discord, Zalo, Steam, rồi
Waydroid (chỉ khi container Waydroid đang chạy). Mỗi nhóm nằm trên một workspace riêng:

| Workspace | Màn hình | App |
|---|---|---|
| `browser` | laptop (`eDP-1`) | zen-browser |
| `coding` | màn ngoài (`HDMI-A-1`) | Antigravity, ZCode |
| `games` | màn ngoài (`HDMI-A-1`) | Discord, Zalo, Steam, Waydroid |

- **Hai màn hình (ở nhà):** browser trên laptop, coding và games trên màn ngoài.
- **Một màn hình (chỉ laptop):** coding và games rơi về laptop. Vì cửa sổ Antigravity (Electron) mở chậm, script còn
  chuyển nó sang workspace `coding` khi nó xuất hiện.
- App lỗi hoặc chưa cài thì được ghi log và bỏ qua, các app còn lại vẫn mở. Log: `~/.local/state/niri/apps-start.log`.
- Discord là bản thường (`discord`), không phải Vesktop. Zalo khởi động với `--hidden`, như autostart cũ.

## Khi có sự cố

- Về TTY bằng `Ctrl+Alt+F3` (hoặc F4) để sửa lỗi mà không cần giao diện đồ họa.
- Gỡ rice: `stow -D --no-folding -t ~ noctalia niri`, rồi trả bản sao lưu `~/.config/niri/config.kdl.bak.<ngày>` về
  `~/.config/niri/config.kdl`. Cấu hình mặc định nguyên bản của niri nằm ở `docs/baseline/niri-config.default.kdl`.
- Kiểm tra Plasma còn nguyên: đăng xuất Plasma rồi `scripts/check-plasma-intact.sh compare` (README mô tả quy trình).

## Chưa kiểm chứng

- Rule mở VS Code, Antigravity và ZCode full width dựa trên app-id `code`, `antigravity` và `zcode`; chưa chạy thật để xác nhận.
- Autostart và workspace theo màn hình (`browser`, `coding`, `games`) chưa kiểm chứng trên session niri đang chạy. Sau khi
  đăng nhập, chạy `niri msg workspaces` và `cat ~/.local/state/niri/apps-start.log` để xác nhận.
- Nếu chữ trong VS Code bị mờ ở scale 1.25 hoặc bộ gõ không nhận trong VS Code, đó là do app chạy qua XWayland. Cách xử
  lý (cờ Electron cho Wayland) sẽ đổi hành vi VS Code cả trên Plasma, nên chưa đưa vào cấu hình.
- Việc đổi bộ gõ đã được kiểm tra bằng `fcitx5-remote` (đổi được giữa `keyboard-us`, `lotus`, `anthy`), nhưng gõ thật
  trong từng ứng dụng với Lotus trong niri thì chưa.
- Chưa kiểm tra thực tế các tổ hợp phím trên Sofle; chúng được chọn từ keymap `sofle.keymap` trong
  `~/Projects/Keyboards/sofle-v2-oled-zmk-firmware`.
