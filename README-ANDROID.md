# pencil.koplugin — Hướng dẫn Android (Samsung Galaxy Tab S10)

Bản port này cho phép dùng S Pen vẽ annotation trực tiếp lên trang sách trong KOReader Android.

## Vì sao bản gốc chỉ chạy Kobo

Plugin cần 2 thứ ở tầng input của KOReader:

1. API `Input:registerStylusCallback()` — tách sự kiện bút ra khỏi gesture của ngón tay. Upstream KOReader đã merge từ 2026-07-11 (PR #15344), có trong stable **2026.07 trở lên**.
2. Android phải báo tool type của S Pen (`TOOL_TYPE_STYLUS`) xuống tầng input — upstream koreader-base chỉ merge ngày **2026-08-07** (PR #2501). Stable 2026.07.1 (ra 2026-08-01) **CHƯA có** cái này.

Vì vậy: cần **KOReader Android nightly build ≥ 2026-08-07**, hoặc chờ stable 2026.08.

## Cài đặt

Có 2 lộ trình. Cả hai đều cần plugin folder ở cùng chỗ, khác nhau ở chỗ xử lý phần thiếu mảnh tool type của KOReader.

### Bước chung: cài plugin

1. Chép thư mục `pencil.koplugin` vào `Android/data/org.koreader.koreader/files/` hoặc `/storage/emulated/0/koreader/plugins/` tùy bản KOReader (bản mới dùng thư mục app; cứ mở KOReader → menu → Help → xem đường dẫn "home" rồi đặt vào `<home>/plugins/`).
2. KHÔNG thay thế `frontend/device/input.lua` như hướng dẫn Kobo — vừa không cần vừa phá compat.
3. Khởi động lại KOReader, mở một cuốn sách → menu trên cùng → **More tools → Pencil → Enabled**.

### Lộ trình A — nightly (sạch, bền)

- Cài **KOReader Android nightly ≥ 2026-08-07** (arm64) từ build server chính thức, hoặc chờ stable 2026.08.
- Không cần thêm gì — plugin chạy ngay.
- Hạn chế: server build hay chết, nightly tự update có thể đổi behavior.

### Lộ trình B — user patch trên stable v2026.07/v2026.07.1 (dùng được ngay)

Cho KOReader stable 2026.07/2026.07.1 cài từ **GitHub APK hoặc Play Store** (bắt buộc — flavor F-Droid tắt user patch).

1. Chép file `1-android-stylus.lua` vào `/storage/emulated/0/koreader/patches/` (tạo thư mục `patches` nếu chưa có — nằm cạnh thư mục `plugins`).
2. Khởi động lại KOReader — patch tự backport phần nhận dạng S Pen từ upstream (base PR #2501).
3. Patch tự tắt khi KOReader đã có sẵn tính năng (nightly/stable 2026.08+) → chuyển lộ trình A không cần gỡ gì.

Cách hoạt động: patch khai báo lại binding NDK `AMotionEvent_getToolType` bị thiếu, rồi override module `ffi/input_android` bằng bản upstream — biến S Pen từ "ngón tay" thành tool type riêng mà plugin nhận được.

Rủi ro đã biết: mỗi lần KOReader update APK phải xác nhận patch vẫn ổn (xem log lúc khởi động, dòng `android-stylus-backport: installing...`).

## Dùng trên Tab S10

- Viết/vẽ bằng S Pen trực tiếp lên trang.
- **Tẩy: giữ nút bên S Pen + quét** qua nét vẽ — như Kobo. Nhả nút = về bút. Cần patch v2 (19-08, buttonState sync): bản v1 chỉ nghe event rời mà Samsung không gửi, v2 đọc trạng thái nút trực tiếp từ từng touch event.
- Nếu nút bên không ăn (Samsung đôi khi báo khác chuẩn): fallback là map gesture — menu trên cùng → **Taps and gestures** → gán "**Pencil: toggle pencil/eraser**" vào double-tap hoặc 1 góc màn hình, chỉ cần 1 chạm là đổi công cụ.
- Undo, clear page, đổi màu (giữ bút đứng yên nếu bật Color picker) — dùng như trên Kobo.
- Plugin có menu **Swap Eraser and Highlighter** đổi vai trò nút (nếu S Pen 2 nút).

## Hạn chế đã biết trên Android

- **Nút bên S Pen** phải dùng qua patch `1-android-stylus.lua` bản mới; nếu vendor báo button event lệch chuẩn thì nút im lặng (fallback: gesture toggle).
- **Không có eraser đầu bút**: S Pen của Samsung không có đầu tẩy — tẩy bằng nút bên hoặc menu.
- **Rest palm**: chống lòng bàn tay không có sẵn — đặt tay lên màn hình khi không viết có thể sinh tap/lật trang.
- **Đổi cỡ/rotate sách giữa chừng**: annotation sẽ lệch vị trí (giới hạn của plugin gốc, kể cả trên Kobo).

## Debug nếu S Pen không vẽ được

1. **More tools → Pencil → Input debug mode** bật log.
2. Viết vài nét bằng S Pen.
3. Đọc file `<koreader home>/pencil_input_debug.log`. Nếu log rỗng hoặc không có dòng `STYLUS` → bản KOReader đang dùng chưa có TOOL_TYPE (xem lại mục yêu cầu version ở trên).

**CẢNH BÁO: debug mode chỉ bật khi chẩn đoán.** Mỗi lần di chuyển tẩy, plugin ghi log từng nét một (mở/ghi/đóng file liên tục) — giữ bật khi tẩy nhiều sẽ nghẽn main thread và Android kill app (ANR). Đã từng ghi 2MB log trong 47 giây rồi crash giữa chừng. Chẩn đoán xong là tắt.

## Tẩy nét cũ từ lần đọc trước không được?

Nét vẽ ở hướng màn hình khác (hoặc layout sách đã đổi) sẽ KHÔNG render bằng toạ độ thật nữa — plugin hiển thị ảnh chụp thay thế, tẩy vào ảnh không bao giờ trúng. Cách xử lý:

1. Xoay máy về đúng hướng lúc vẽ nét đó rồi tẩy lại, HOẶC
2. Menu Pencil → **Clear page strokes** để xoá cả trang.

## Gỡ cài đặt

Xoá thư mục `plugins/pencil.koplugin` là xong. Plugin không đụng file lõi của KOReader.

## Thay đổi so với bản gốc

- `pencil.koplugin/main.lua` — `Pencil:transformCoordinates()` bỏ qua phép biến dạng rotation trên Android/SDL vì toạ độ pointer đã ở hệ logical (bản gốc giả định toạ độ thô kiểu evdev/Kobo, áp lên Android sẽ lệch stroke khi màn hình không ở hướng mặc định).
