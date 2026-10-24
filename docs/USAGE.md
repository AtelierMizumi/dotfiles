# Hướng dẫn dùng niri + Noctalia

Bảng phím và cách làm việc hằng ngày cho laptop và bàn phím Sofle. Gõ `Super+Shift+/` bất cứ lúc nào để niri hiện
bảng các phím quan trọng ngay trên màn hình.

## Bắt đầu trong hai phút

| Muốn | Bấm |
|---|---|
| Mở terminal (ghostty) | `Super+T` hoặc `Super+Return` |
| Mở app / tìm file / chạy lệnh | `Super+Space` hoặc `Super+D` |
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
- Trên Sofle, `Super+Space`, `Super+-` và `Super+=` là ba phím ngón cái cạnh nhau, bấm bằng một tay.

## Bảng phím

### Ứng dụng

| Phím | Việc |
|---|---|
| `Super+T`, `Super+Return` | terminal (ghostty) |
| `Super+B` | trình duyệt (zen) |
| `Super+E` | file manager (dolphin) |
| `Super+C` | VS Code |

### Noctalia (shell)

| Phím | Việc |
|---|---|
| `Super+Space`, `Super+D` | launcher |
| `Super+S` | control center (mạng, âm thanh, độ sáng, thông báo) |
| `Super+Alt+S` | settings của Noctalia |
| `Super+Shift+V` | lịch sử clipboard |
| `Super+N` | bật/tắt Do Not Disturb |
| `Super+Esc`, `Super+Alt+L` | khóa màn hình |

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
| `XF86AudioLowerVolume`, `XF86AudioRaiseVolume`, `XF86AudioMute` | âm lượng (phím laptop, núm xoay Sofle) |
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
- **Hai màn hình:** laptop (`eDP-1`, scale 1.25) ở trái, màn ngoài (`HDMI-A-1`) ở bên phải, đúng như trên Plasma.
  `Super+Tab` qua lại giữa hai màn, `Super+Shift+Tab` mang cột theo. niri không ép tần số quét nên màn ngoài dùng tần
  số cao nhất của nó.
- **Clipboard:** `Super+Shift+V` mở lịch sử, chọn mục để dán lại.
- **Tập trung:** `Super+N` bật Do Not Disturb khi họp hoặc code sâu.
- **Gõ tiếng Việt và tiếng Nhật:** `fcitx5` tự khởi động cùng session. Đổi bộ gõ bằng phím bạn đã đặt trong
  `fcitx5-configtool`.

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
  thoát 0 và không có dòng `WARN` hay `ERROR`). Đừng bật template hay `sync_color_scheme`: chúng ghi vào file của Plasma.
- Mỗi lần xong một thay đổi, commit để có thể quay lại.

## Khi có sự cố

- Về TTY bằng `Ctrl+Alt+F3` (hoặc F4) để sửa lỗi mà không cần giao diện đồ họa.
- Gỡ rice: `stow -D --no-folding -t ~ noctalia niri`, rồi trả bản sao lưu `~/.config/niri/config.kdl.bak.<ngày>` về
  `~/.config/niri/config.kdl`. Cấu hình mặc định nguyên bản của niri nằm ở `docs/baseline/niri-config.default.kdl`.
- Kiểm tra Plasma còn nguyên: đăng xuất Plasma rồi `scripts/check-plasma-intact.sh compare` (README mô tả quy trình).

## Chưa kiểm chứng

- Rule mở VS Code và Antigravity full width dựa trên app-id `code` và `antigravity`; chưa chạy thật để xác nhận.
- Nếu chữ trong VS Code bị mờ ở scale 1.25 hoặc bộ gõ không nhận trong VS Code, đó là do app chạy qua XWayland. Cách xử
  lý (cờ Electron cho Wayland) sẽ đổi hành vi VS Code cả trên Plasma, nên chưa đưa vào cấu hình.
- Chưa kiểm tra thực tế các tổ hợp phím trên Sofle; chúng được chọn từ keymap `sofle.keymap` trong
  `~/Projects/Keyboards/sofle-v2-oled-zmk-firmware`.
