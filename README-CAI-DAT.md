# Cài KOReader + viết tay S Pen lên thiết bị Android mới

Ghi chú này để lần sau cài lên tablet Samsung khác (hoặc cài lại Tab S10) khỏi phải mò lại.
Chuỗi đã test chạy ổn: Samsung Galaxy Tab S10 FE (gts10fewifixx), KOReader 2026.07.1 GitHub APK, ngày 2026-08-19.

## Cái gì cài cho thiết bị nào

| Thiết bị | Cài gì | Ghi chú |
|---|---|---|
| Tablet có S Pen (Tab S10 FE, Tab S9...) | APK arm64 + plugin + patch | Đủ chức năng viết/tẩy bằng bút |
| Điện thoại A55 (không bút) | CHỈ APK arm64 | Không cần plugin/patch — A55 không có S Pen, đọc sách bình thường |
| Máy nào khác | APK arm64 | Gần như mọi thiết bị Android hiện đại đều arm64 |

Lưu ý quan trọng về APK:
- Dùng bản **GitHub APK** (file trong `releases/` của repo KOReader) — **không phải F-Droid** (flavor F-Droid vô hiệu hóa user patch).
- KOReader từ Play Store chữ ký khác GitHub APK — muốn đổi nguồn thì gỡ trước rồi cài.
- Version tối thiểu: **2026.07** (có API `registerStylusCallback`). 2026.03 trở xuống không dùng được.
- Từ stable **2026.08 trở lên** (khi ra): mảnh tool type đã có sẵn trong app → patch tự tắt, CHỈ cần cài plugin, KHÔNG cần patch nữa.

## File nằm ở đâu (trên máy tính)

```
D:\pcloud\workspace\code\website\book.quoc.app\koreader\
├── releases\
│   └── koreader-android-arm64-v2026.07.1.apk    ← APK cài (cho cả Tab + A55)
├── pencil.koplugin-main\
│   ├── pencil.koplugin\                          ← SOURCE của plugin (đã patch Android)
│   ├── README-ANDROID.md                         ← giải thích kỹ thuật chi tiết
│   └── ...                                       ← source gốc từ GitHub mysticknits/pencil.koplugin
├── patches\
│   └── 1-android-stylus.lua                      ← SOURCE OF TRUTH của patch (sửa ở ĐÂY)
└── pencil-android-s10.zip                        ← gói vận chuyển = plugin + patch + README
```

Luật: sửa gì thì sửa ở `pencil.koplugin-main\` hoặc `patches\`, xong re-zip lại rồi mới chép lên máy. Zip chỉ là xe chở hàng.

## Các bước cài (tablet có S Pen)

1. Cài APK: `releases\koreader-android-arm64-*.apk` (mở file, cho phép cài từ nguồn không rõ, cài đè nếu đã có GitHub APK cũ).
2. Mở KOReader 1 lần để nó tạo thư mục dữ liệu.
3. Nối cáp (chế độ MTP), chép 2 thứ vào bộ nhớ trong:
   - folder `pencil.koplugin` → vào `koreader/plugins/pencil.koplugin`
   - file `1-android-stylus.lua` → vào `koreader/patches/1-android-stylus.lua` (tạo folder `patches` nếu chưa có)
   - Lấy 2 thứ này từ `pencil-android-s10.zip` hoặc trực tiếp từ source folder.
4. Swipe kill KOReader khỏi Recent apps, mở lại.
5. Mở 1 cuốn sách (EPUB hoặc PDF) → menu trên cùng → **More tools → Pencil → Enabled**.
6. Viết thử bằng S Pen. NGÓN TAY vẫn lật trang/menu bình thường — không bị coi là bút.

## Cách dùng

- Viết: chạm S Pen và viết trực tiếp lên trang.
- Tẩy: **giữ nút bên S Pen + quét** qua nét. Nhả nút = viết tiếp.
- Đổi màu bút: bật Color picker (menu Pencil → Experimental) rồi giữ bút đứng yên tại chỗ ~0.5s.
- Undo: menu Pencil → Undo last stroke.
- Toggle bút/tẩy nhanh bằng gesture: menu trên cùng → Taps and gestures → gán "Pencil: toggle pencil/eraser" vào double-tap.
- Nếu giữ nút mà nó HIGHLIGHT thay vì tẩy (bút 2 nút): menu Pencil → tắt **Swap Eraser and Highlighter**.

## Vấn đề đã biết (không phải bug cài đặt)

- Zoom/rotate sách giữa chừng làm lệch annotation — chốt zoom trước khi viết. Nét vẽ session trước ở hướng khác sẽ hiện dạng ảnh chụp, tẩy không trúng: xoay về đúng hướng cũ hoặc dùng Clear page strokes.
- KHÔNG bật Input debug mode khi dùng thường — nó ghi log dồn vào main thread, Android kill app (đã bị 1 lần).
- Không có palm rejection — tay Rest lên màn hình khi không viết có thể lật trang.

## Sau khi update KOReader (OTA / cài APK mới)

Kiểm tra nhanh:
1. Viết thử S Pen. Chạy = xong.
2. Nếu S Pen im lặng → xem log khởi động (menu → Help → crash.log hoặc Report bug): tìm dòng `android-stylus-backport`.
   - `installing backported ffi/input_android` = patch đang chạy → sự cố ở chỗ khác.
   - `not needed` = app đã có sẵn tính năng (2026.08+) → patch đã tự rút lui, bình thường.
   - Không có dòng nào = patch chưa được copy lại sau update → chép lại `1-android-stylus.lua` vào `koreader/patches/`, restart.

## Nếu S Pen không vẽ được (chẩn đoán)

1. Menu Pencil → bật Input debug mode → viết vài nét → tắt ngay.
2. Lấy file `koreader/pencil_input_debug.log`:
   - Có dòng `STYLUS SLOT ... tool=1` = input chạy tốt, vấn đề ở plugin.
   - Log trống / không có STYLUS = KOReader thiếu mảnh tool type → sai version APK hoặc patch chưa nạp.

## Lịch sử các patch đã áp (đóng gói trong bản hiện tại)

- `pencil.koplugin/main.lua`: bỏ rotation-transform toạ độ trên Android (toạ độ pointer đã là hệ logical sẵn); đóng nét dở thành stroke thật khi nhấn nút tẩy giữa chừng (hết ghost pixel tẩy không trúng).
- `pencil.koplugin/lib/geometry.lua`: bbox prefilter cho eraser (tẩy không còn quét toàn bộ điểm mỗi lần di chuyển — hết nguy cơ ANR).
- `patches/1-android-stylus.lua` (v2): backport tool type từ koreader-base PR #2501 + tự cdecl binding NDK thiếu + đọc buttonState từng frame dịch thành BTN_STYLUS (giữ nút = tẩy).
