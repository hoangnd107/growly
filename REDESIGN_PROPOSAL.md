# Growly — Đề xuất Redesign toàn diện hướng tới UI/UX world-class

> **Trạng thái:** Đề xuất (chưa implement). Tài liệu này phác thảo định hướng thiết kế tổng thể cho Growly. Việc triển khai sẽ chia thành các giai đoạn nhỏ, có thể test độc lập, sau khi anh duyệt định hướng.

---

## 1. Tóm tắt nhanh (TL;DR)

Growly hiện đã có nền tảng tốt: design tokens (`DLColor`, `Font.dl/serif`, `DLSpace`, `DLRadius`), bộ component editorial (`EditorialHeader`, `StatTile`, `Hairline`), gamification phong phú và analytics sâu. Vấn đề không nằm ở thiếu tính năng mà ở **sự thiếu nhất quán giữa hai ngôn ngữ thiết kế** (glass/card cũ vs. editorial mới) và **mật độ thông tin cao gây quá tải** ở một số màn hình.

Đề xuất xoay quanh 4 trụ:

1. **Một ngôn ngữ thiết kế duy nhất** — chuẩn hoá toàn app về hệ "editorial calm" đã bắt đầu ở Insights.
2. **Phân cấp thông tin rõ ràng** — mỗi màn hình có một "hero", phần còn lại lùi xuống.
3. **Chuyển động có chủ đích** — animation kể chuyện tiến trình, không trang trí.
4. **Cá nhân hoá & cảm xúc** — app phản ánh hành trình riêng của người dùng.

---

## 2. Đánh giá hiện trạng

### Điểm mạnh
- Hệ token adaptive light/dark hoàn chỉnh, accent Violet đặc trưng.
- Component editorial mới (`Editorial.swift`) rất "đắt" về thẩm mỹ.
- Analytics chuyên sâu (Mood, Sleep, Habits, Writing, Life areas, Consistency).
- Gamification (XP, level, badge, streak freeze) tạo động lực quay lại.

### Điểm cần cải thiện
| Vấn đề | Biểu hiện | Hệ quả |
|---|---|---|
| Hai ngôn ngữ thiết kế song song | `GlassCard` (bo tròn, đổ bóng) ở Today/History/Me vs. editorial phẳng + hairline ở Insights | App cảm giác "ghép" từ hai thời kỳ |
| Quá tải thông tin | Insights cuộn rất dài (10+ card), Today nhiều card cùng trọng số | Khó tìm điều quan trọng |
| Thiếu hero/điểm nhấn | Nhiều màn hình toàn card "ngang hàng" | Mắt không biết nhìn đâu trước |
| Empty state nhạt | Chủ yếu icon + 1 dòng chữ | Bỏ lỡ cơ hội onboarding |
| Điều hướng phẳng | 5 tab ngang hàng, một số chức năng chôn sâu (Identity, Manifesto) | Tính năng hay bị bỏ quên |

---

## 3. Tầm nhìn thiết kế

> **"A calm, editorial journal that quietly celebrates your growth."**

Growly nên cho cảm giác như một **cuốn tạp chí cá nhân in đẹp**: nhiều khoảng trắng, typography làm chủ đạo, màu dùng tiết chế và có ý nghĩa (mỗi màu = một loại dữ liệu), chuyển động mềm. Gamification vẫn vui nhưng **không ồn ào** — nó là phần thưởng, không phải sân khấu.

### 3 từ khoá định hướng
- **Calm** — ít nhiễu, nhiều khoảng thở, không màu loè loẹt trừ khi có lý do.
- **Editorial** — typography phân cấp mạnh, hairline thay vì box, ảnh/biểu đồ "full-bleed".
- **Personal** — nội dung của người dùng (chữ viết, tâm trạng, hành trình) là nhân vật chính.

---

## 4. Hệ thống thiết kế (Design System v2)

### 4.1 Màu
- Giữ **paper palette** (nền ấm, adaptive) làm nền tảng — đã được anh duyệt.
- Giữ accent **Violet** (`7E5BEF`) và các màu gamification rực của v1.12 (item 1 vòng này).
- **Quy ước màu theo loại dữ liệu** (semantic color map) áp dụng nhất quán toàn app:
  - Reviews/Reflection → accent (violet)
  - Notes → xpGold
  - Words/Writing → success (green)
  - Sleep → cool (blue)
  - Streak → streakStart→streakEnd (cam→đỏ)
  - Mood → màu riêng của từng mood (catalog)
- **Gradient bar** chuẩn (item 5 vòng này): mọi cột thống kê fade từ màu đầy → 55% theo trục chính.

### 4.2 Typography
- Một thang typography rõ ràng: Display (serif/rounded) → Title → Headline → Body → Caption.
- Quy tắc: mỗi màn hình chỉ **một** Display (hero). Section dùng `SectionLabel`.
- Số liệu luôn `monospacedDigit()` + `contentTransition(.numericText())` để đếm mượt.

### 4.3 Bề mặt (surfaces)
- **Thống nhất về editorial**: thay dần `GlassCard` (bóng đổ + blur) bằng bề mặt phẳng + `Hairline`/viền mảnh. Giữ một biến thể "raised" duy nhất cho phần cần nổi (vd. hero, CTA).
- Bo góc theo `DLRadius` (card 18 / small 12) — bỏ các bán kính lệ thuộc rải rác.

### 4.4 Spacing & lưới
- Lưới dọc nhịp 4/8/16/24. Section cách nhau `DLSpace.xl`.
- Nội dung rộng tối đa ~640pt, canh giữa trên iPad/máy lớn (Me đã làm).

### 4.5 Component cần bổ sung
- `HeroMetric` (đã thêm dạng hero cho `StatTileGrid` vòng này) — dùng lại ở mọi nơi cần "1 con số lớn".
- `YearStepper` + `YearActivityHeatmap` (thêm vòng này) — chuẩn hoá mọi view "cả năm".
- `EditorialEmptyState` — empty state có minh hoạ + CTA + gợi ý bước tiếp theo.
- `InsightCalloutCard` — 1 card "insight nổi bật của tuần" thay vì danh sách dài.

---

## 5. Redesign theo từng màn hình

### 5.1 Today (màn hình quan trọng nhất)
**Vấn đề:** nhiều card cùng trọng số; người dùng phải cuộn nhiều mới "complete the day".
**Đề xuất:**
- **Hero header**: lời chào theo thời điểm + tiến trình hoàn thành hôm nay dưới dạng 1 vòng tròn/progress duy nhất.
- **Reflection (WMLA)**: giữ 4 card nhưng gọn hơn; ô nhập phản hồi tức thì (item 7 đã fix). Chip gợi ý trượt mượt (đã làm).
- **Tách Evening/Morning rõ ràng** bằng segmented đã có; Morning rút gọn còn intention + adjustment check.
- **CTA "Complete the day"** dạng sticky ở đáy khi đủ điều kiện, kèm preview XP.

### 5.2 Progress (History)
**Vấn đề:** đã bỏ mood filter (item 2). Còn lại: calendar + daily moods + 3 mode (Calendar/Streak/Stats).
**Đề xuất:**
- Đưa Calendar/Streak/Stats lên đầu rõ ràng; calendar là hero.
- "Daily moods" giữ dạng collapsible (đã làm), thêm mini-summary tháng (số ngày có mood, mood phổ biến).
- Hợp nhất thị giác Stats card về editorial (hero = tổng của tháng đang chọn — item 3 đã làm logic).

### 5.3 Insights (dashboard)
**Vấn đề:** quá dài, 10+ card.
**Đề xuất — tái cấu trúc thành 3 lớp:**
1. **Lớp "Hôm nay/Tuần này"**: 1 `InsightCalloutCard` (1 insight nổi bật) + streak + growth score gọn.
2. **Lớp "Báo cáo"**: lưới các "Detailed reports" (đã có) làm cổng vào — đây là điểm mạnh, nên đưa lên cao và làm đẹp dạng grid 2 cột có icon lớn.
3. **Lớp "Biểu đồ nhanh"**: mood trend / XP / distribution gộp vào 1 card có segmented chuyển biểu đồ, thay vì 3 card rời.
- Mood calendar (đã sửa Month/Year — item 6) trở thành 1 entry point đẹp dẫn tới Consistency.

### 5.4 Notes
- Stats header dạng hero (item 8 đã làm). 
- Hàng filter/sort gọn về 1 thanh; timeline sections giữ collapsible.
- Note row: tăng khoảng thở, ưu tiên tiêu đề + preview + 1 hàng metadata mảnh.

### 5.5 Me
- Lifetime stats dạng hero (item 8 đã làm).
- Gom Identity/Manifesto/Life areas vào một mục "Your story" để tăng khám phá.
- Badge gallery giữ nhưng thêm "huy hiệu sắp đạt được" nổi bật để tạo mục tiêu.

### 5.6 Onboarding (mới)
- 3–4 bước editorial: chọn mục tiêu, thiết lập nhắc nhở, viết review đầu tiên ngay trong onboarding (giảm rào cản "trang trắng").

---

## 6. Điều hướng & kiến trúc thông tin
- Giữ 5 tab nhưng **đổi nhãn rõ vai trò**: Today · Progress · Insights · Notes · Me.
- Cân nhắc gom các analytics chi tiết dưới Insights (đã làm) để tab không phình.
- Mọi destination đẩy (push) đều dùng `EditorialHeader` thống nhất.

---

## 7. Chuyển động (Motion)
- **Nguyên tắc:** animation phục vụ thông tin (đếm số, lấp đầy tiến trình, chuyển section), không trang trí.
- Tôn trọng `reduceMotion` ở mọi nơi (đa số đã có).
- Micro-interactions: nhấn nút co nhẹ (`ScaleButtonStyle`), số đếm `.numericText()`, heatmap/biểu đồ fade-in tuần tự nhẹ.
- Celebration (level up, complete day) là điểm nhấn "ồn ào" *duy nhất* — nên thật trau chuốt.

---

## 8. Accessibility & chất lượng
- Dynamic Type: kiểm tra hero/`largeTitle` không vỡ ở cỡ lớn (đã dùng `minimumScaleFactor`).
- VoiceOver: mọi card có `accessibilityElement(.combine)` + label nghĩa.
- Tương phản: kiểm màu data trên nền paper ở cả light/dark.
- Localization: 4 ngôn ngữ (en/vi/zh-Hans/ko) — giữ đồng bộ khi thêm chuỗi.

---

## 9. Lộ trình triển khai (đề xuất theo giai đoạn)

| Giai đoạn | Nội dung | Rủi ro |
|---|---|---|
| **P1 — Hợp nhất surface** | Thay `GlassCard` → editorial ở Today/History/Me; chuẩn hoá bo góc, hairline | Thấp–TB (đụng nhiều view) |
| **P2 — Hero hoá** | Áp `HeroMetric`/header cho Today, Progress, Insights | Thấp |
| **P3 — Gọn Insights** | Gộp card, thêm `InsightCalloutCard`, đẩy "Reports" lên | TB |
| **P4 — Empty states & Onboarding** | `EditorialEmptyState`, flow onboarding mới | TB |
| **P5 — Motion polish** | Chuẩn hoá micro-interactions, celebration | Thấp |

Mỗi giai đoạn ship một preview riêng để anh đánh giá trước khi sang bước sau.

---

## 10. Đã hoàn thành ở vòng feedback này (làm nền cho redesign)
Những thay đổi vòng này đã đặt nền móng cho hệ editorial v2:
- Màu item về v1.12 + gradient bar thống nhất (1, 5).
- Hero `StatTileGrid` cho Notes & Me (8).
- `YearStepper` + `YearActivityHeatmap` dùng chung cho Consistency, Habit analytics, Mood calendar (4, 6).
- Tổng Stats phản hồi theo tháng (3); bỏ mood filter ở Progress (2).
- Nhập WMLA mượt, không trễ (7).

> Bước tiếp theo khuyến nghị: bắt đầu **P1 (hợp nhất surface)** vì nó tạo cảm giác "một app" rõ rệt nhất với chi phí vừa phải.
