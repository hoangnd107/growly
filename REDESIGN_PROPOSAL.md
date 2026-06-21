# Growly — Đề xuất Redesign toàn diện hướng tới UI/UX world-class

> **Trạng thái:** Đề xuất (chưa implement). Tài liệu này phác thảo định hướng thiết kế tổng thể + lộ trình tính năng cho Growly. Triển khai sẽ chia thành các giai đoạn nhỏ, test độc lập, sau khi anh duyệt định hướng.
>
> **Cập nhật v3:** (1) Đổi hướng bề mặt sang **GlassCard / chiều sâu** (thay vì phẳng) để có cảm giác *world-class iOS*. (2) Bắt buộc **mọi phần thống kê có filter thời gian đầy đủ**. (3) Bổ sung loạt tính năng nâng cao lấy cảm hứng từ **NEXUS** (AI coach, life review, Life OS Score, Future Self Simulator, Live Activities…).

---

## 1. Tóm tắt nhanh (TL;DR)

Growly có nền tảng tốt: design tokens (`DLColor`, `Font.dl/serif`, `DLSpace`, `DLRadius`), bộ component editorial (`EditorialHeader`, `StatTile`, `Hairline`), gamification phong phú, analytics sâu, và đã chuẩn hoá filter năm (`YearStepper`/`YearActivityHeatmap`).

Định hướng redesign xoay quanh 5 trụ:

1. **Một ngôn ngữ bề mặt duy nhất = GlassCard cao cấp** — chiều sâu, vibrancy, chất liệu kiểu iOS, áp dụng nhất quán toàn app (thay cho bề mặt phẳng).
2. **Editorial typography + Glass surfaces** — giữ phân cấp chữ editorial, nhưng "đặt" lên các thẻ kính có chiều sâu → premium.
3. **Thống kê luôn có filter thời gian đầy đủ** — mọi view số liệu đều lọc được theo thời gian, đồng nhất.
4. **Chuyển động world-class** — Rive/Lottie + micro-interactions, mỗi hành động quan trọng có motion + haptic + phản hồi thị giác.
5. **Trí tuệ trên-thiết-bị, hướng con người** — AI coach, life review, Life OS Score, Future Self Simulator… ưu tiên privacy & on-device.

---

## 2. Đánh giá hiện trạng

### Điểm mạnh
- Hệ token adaptive light/dark hoàn chỉnh, accent Violet đặc trưng, màu data rực (v1.12).
- Component editorial (`Editorial.swift`) đẹp; `GlassCard` đã có sẵn và được dùng rộng ở Today/History/Me/Insights.
- Analytics chuyên sâu (Mood, Sleep, Habits, Writing, Life areas, Consistency) + filter năm dùng chung.
- Dữ liệu đầu vào giàu: mood/energy, WMLA reflection, notes, habits, sleep, goals, **life areas (health/work/finance/psychology/relationships)**, identity, manifesto — nền tảng lý tưởng cho các tính năng "life OS".

### Điểm cần cải thiện
| Vấn đề | Biểu hiện | Hệ quả |
|---|---|---|
| Bề mặt thiếu nhất quán & thiếu chiều sâu | Một số nơi phẳng (editorial tiles, hairline) xen kẽ `GlassCard` | Cảm giác "ghép", chưa "đắt" như app iOS hạng nhất |
| Thống kê filter chưa đồng đều | Một số view có range/year, một số chưa đầy đủ | Khó so sánh theo thời gian nhất quán |
| Quá tải thông tin | Insights cuộn rất dài | Khó tìm điều quan trọng |
| Empty state nhạt | Icon + 1 dòng | Bỏ lỡ onboarding |
| Chưa khai thác hệ sinh thái Apple | Không có Live Activities, Dynamic Island, Widgets, CloudKit | Bỏ lỡ điểm chạm "world-class iOS" |

---

## 3. Tầm nhìn thiết kế

> **"A premium, glassy companion that quietly guides your growth."**

Growly nên cho cảm giác như một **ứng dụng iOS hạng nhất**: bề mặt **kính có chiều sâu** (depth, vibrancy, blur tinh tế), typography editorial làm chủ đạo, màu dùng có ý nghĩa, chuyển động mềm và "có sức nặng". Gamification vui nhưng không ồn ào.

### 3 từ khoá định hướng
- **Depth (Glass)** — bề mặt kính nhiều lớp, bóng mềm, vibrancy; nội dung "nổi" trên nền theme.
- **Editorial** — phân cấp chữ mạnh, tiêu đề lớn đậm, khoảng thở rộng.
- **Intelligent & Personal** — nội dung của người dùng là nhân vật chính; AI dẫn dắt nhẹ nhàng.

---

## 4. Hệ thống thiết kế (Design System v2)

### 4.1 Màu
- Giữ **paper palette** adaptive làm nền, accent **Violet** (`7E5BEF`), và các màu data/gamification rực của v1.12.
- **Quy ước màu theo loại dữ liệu** (nhất quán toàn app): Reviews→accent, Notes→xpGold, Words→success, Sleep→cool, Streak→cam→đỏ, Mood→màu catalog.
- **Gradient-first** cho mọi cột/thanh thống kê (đầy → ~55%).

### 4.2 Typography
- Thang rõ ràng: Display → Title → Headline → Body → Caption.
- Mỗi màn hình một Display (hero). Tiêu đề **rounded + bold**, đồng nhất giữa trang chính và detailed reports.
- Số liệu `monospacedDigit()` + `contentTransition(.numericText())`.

### 4.3 Bề mặt — **GlassCard-first (định hướng mới)**
> Đảo hướng so với bản trước (vốn đề xuất làm phẳng). Người dùng muốn cảm giác **world-class iOS** ⇒ thống nhất toàn app trên một **hệ GlassCard cao cấp**, KHÔNG quay về bề mặt phẳng.

Chuẩn hoá `GlassCard` thành hệ bề mặt chính, với các biến thể rõ ràng:
- **`GlassCard` (chuẩn):** nền `ultraThinMaterial`/`regularMaterial`, bo góc `DLRadius.card`, viền sáng mảnh (hairline highlight ở mép trên), bóng mềm nhiều lớp (ambient + key shadow) → chiều sâu thật.
- **`GlassCard.raised` (hero/CTA):** đậm hơn, bóng sâu hơn, dùng cho hero metric, nút chính, celebration.
- **`GlassCard.inset` (hàng trong thẻ):** kính nhạt, không bóng, cho các row lồng bên trong.
- **Vibrancy:** chữ/icon dùng vibrancy trên material để "ăn" vào nền theme; tránh chữ đặc cứng.
- **Depth on scroll:** parallax nhẹ + bóng động khi cuộn (tham khảo Apple Wallet, Flighty).
- **Liquid-glass ready:** thiết kế token để dễ nâng lên chất liệu kính kiểu iOS mới khi nâng target OS.
- **StatTile/StatTileGrid:** bọc trong GlassCard thay vì viền phẳng; hero tile = `GlassCard.raised`.
- Tôn trọng `reduceTransparency` (fallback sang nền đặc) và `reduceMotion`.

> Editorial typography + layout **giữ nguyên**; chỉ "đặt" lên bề mặt kính có chiều sâu. Đây là điểm khác biệt: *editorial content trên glass surfaces*.

### 4.4 Spacing & lưới
- Nhịp 4/8/16/24; section cách `DLSpace.xl`; nội dung rộng tối đa ~640pt canh giữa trên máy lớn.

### 4.5 Component cần bổ sung / chuẩn hoá
- `GlassCard` biến thể (chuẩn/raised/inset) + token bóng/blur/viền.
- `HeroMetric` (đã có hero cho `StatTileGrid`) → render trên `GlassCard.raised`.
- `YearStepper` (đã có, hỗ trợ chọn năm trực tiếp) + `YearActivityHeatmap` (đã có).
- `TimeFilterBar` **(mới, mục 5)** — control filter thời gian dùng chung cho mọi view thống kê.
- `EditorialEmptyState` — empty state có minh hoạ + CTA.
- `InsightCalloutCard` — 1 insight nổi bật của tuần.

---

## 5. Nguyên tắc thống kê: **luôn có filter thời gian đầy đủ**

> Yêu cầu bắt buộc: **mọi phần/màn hình thống kê đều phải lọc được theo thời gian**, với bộ filter nhất quán toàn app.

- **Bộ filter chuẩn (`TimeFilterBar`):** `Tuần · Tháng · Quý · Năm · Toàn bộ` (range trượt) **+** bộ chọn **Năm** (`YearStepper`, chọn trực tiếp) cho các view dạng cả-năm.
- Áp dụng cho **tất cả**: Mood, Sleep (duration/quality), Habits, Writing/Notes, Life areas, Consistency, Stats (reviews/notes/words), XP, Growth score, và mọi card số liệu trong Insights.
- **Đồng nhất vị trí & hành vi:** filter đặt ngay dưới tiêu đề mỗi view; đổi filter cập nhật toàn bộ số liệu + biểu đồ của view đó (kèm `contentTransition` mượt).
- **Ghi nhớ lựa chọn** (per-view) để lần sau mở lại giữ nguyên khoảng thời gian.
- **Tổng số liệu phản hồi theo filter** (đã làm cho Stats theo tháng/năm) — mở rộng nguyên tắc này ra mọi view.

---

## 6. Redesign theo từng màn hình
(Áp dụng GlassCard-first + `TimeFilterBar` ở mọi nơi có số liệu.)

### 6.1 Today
- **Hero header** trên `GlassCard.raised`: lời chào theo thời điểm + 1 vòng tiến trình hoàn thành hôm nay.
- Reflection (WMLA): 4 GlassCard, ô nhập phản hồi tức thì (đã fix lag), chip gợi ý trượt mượt.
- Tách Evening/Morning rõ; CTA "Complete the day" dạng `GlassCard.raised` sticky đáy khi đủ điều kiện, preview XP.

### 6.2 Progress
- Calendar là hero trong GlassCard; "Daily moods" collapsible (đã có), thêm mini-summary tháng.
- Stats card: hero = tổng tháng đang chọn; `TimeFilterBar` đầy đủ (đã có year chọn trực tiếp).

### 6.3 Insights — tái cấu trúc 3 lớp
1. **Hôm nay/Tuần này:** `InsightCalloutCard` (1 insight nổi bật) + streak + growth score gọn (đều có filter thời gian).
2. **Báo cáo:** lưới "Detailed reports" làm cổng vào, mỗi mục là GlassCard có icon lớn.
3. **Biểu đồ nhanh:** gộp mood/XP/distribution vào 1 GlassCard có segmented + `TimeFilterBar`.

### 6.4 Notes
- Stats header hero (đã có) trên GlassCard; thanh filter/sort gọn; timeline sections collapsible.

### 6.5 Me
- Lifetime stats hero (đã có) trên GlassCard; gom Identity/Manifesto/Life areas vào "Your story"; badge gallery + "huy hiệu sắp đạt".

### 6.6 Onboarding (mới)
- 3–4 bước editorial trên glass + Rive: chọn mục tiêu, thiết lập nhắc nhở, viết review đầu tiên ngay trong onboarding.

---

## 7. Chuyển động (Motion) — world-class
Tham khảo: Apple Wallet, Arc, Linear, Superhuman, Flighty.
- **Framework:** SwiftUI Animations (chính) → **Rive** (onboarding, celebration, tiến hoá tiến trình, avatar, future-self) → **Lottie** (fallback).
- **Micro-interactions:** mỗi hành động quan trọng (hoàn thành habit, tracking nước, kết thúc Deep Work, đạt goal, hoàn thành review) có **motion + haptic + phản hồi thị giác**.
- Glass parallax/depth khi cuộn; celebration là điểm nhấn "ồn ào" duy nhất, trau chuốt kỹ.
- Mọi animation tôn trọng `reduceMotion`; Rive assets hỗ trợ dark mode + reduced motion + hiệu năng cao.

---

## 8. Tính năng nâng cao — lấy cảm hứng từ NEXUS

> Định hướng: biến Growly từ "nhật ký + thống kê" thành **"hệ điều hành cho phiên bản tốt nhất của bạn"**, nhưng **ưu tiên privacy & on-device**. Growly đã có sẵn phần lớn dữ liệu đầu vào (mood, habits, sleep, goals, life areas, journal) nên các tính năng dưới là mở rộng tự nhiên.

### 8.1 AI Coach trên-thiết-bị — **"AURA"** (nâng cấp `AICoach`/`InsightsEngine`)
- Tính cách: điềm tĩnh, thông thái, hỗ trợ — như một *elite coach/mentor*, không thao túng, không gây mặc cảm, không "hô khẩu hiệu".
- Năng lực: gợi ý hàng ngày (habit/focus/nghỉ ngơi), phát hiện mẫu (giảm tập trung, burnout, vấn đề giấc ngủ, tụt động lực), đo "hành động hôm nay có khớp con người bạn muốn trở thành không?", phân tích journal (cảm xúc/chủ đề lặp lại), và coaching tuần/tháng/quý tự động.
- **Privacy-first:** dùng **Apple Foundation Models / on-device inference** khi có (yêu cầu Apple Intelligence); fallback heuristic on-device như hiện tại. Dữ liệu không rời máy.

### 8.2 AI Weekly Life Review + "Letter to your future self"
- Mỗi tối Chủ nhật: tạo bản review theo 5 trụ — **Body** (sleep/exercise/recovery), **Mind** (mood/stress/reflection), **Focus** (deep work/distraction), **Money** (nếu bật), **Purpose** (goal/mission). (Map trực tiếp từ Life Areas + Sleep + Habits + Goals + Mood hiện có.)
- AI summary: thắng lợi lớn nhất / thử thách lớn nhất / bài học / đề xuất cải thiện — ngôn ngữ tự nhiên, cá nhân.
- **Weekly Letter:** AURA viết "một lá thư gửi bạn của tương lai" — cá nhân hoá, giàu cảm xúc.

### 8.3 Life OS Score (0–1000)
- Điểm tổng thể chất lượng "hệ vận hành cuộc sống": Body 200 · Mind 200 · Focus 200 · Money 150 · Purpose 150 · Consistency 100.
- Triết lý: **thưởng cho sự nhất quán, không phải hoàn hảo** — hành động nhỏ lặp lại > bùng nổ rời rạc.
- Trực quan: vòng tròn đẹp, tăng trưởng có animation, lịch sử xu hướng, milestone. (Mở rộng từ `growthScore` hiện có.)

### 8.4 Future Self Simulator — **(tính năng cờ hiệu)**
- Trả lời: *"Nếu bạn tiếp tục sống đúng như hiện tại, bạn sẽ trở thành ai?"*
- Horizon: 30 ngày · 90 ngày · 1 năm · 3 năm · 5 năm.
- Input: sleep, exercise, nutrition, focus, habits, tài chính, goal, mood, mẫu journal, phân bổ thời gian.
- Output: dự phóng Health / Financial / Personal Growth / Life Satisfaction.
- **Avatar tiến hoá** theo hành vi (ngủ tốt → khoẻ hơn; nhất quán → vững vàng hơn) — *aspirational, không phán xét*.
- **Future Self Letter:** lời nhắn từ phiên bản tương lai của người dùng.

### 8.5 Live Activities + Dynamic Island (ActivityKit + Widget extension)
- **Deep Work** (cần thêm tính năng focus timer): tiêu đề phiên, thời gian còn lại, streak, focus score, vòng tiến trình; trạng thái Active/Break/Completed.
- **Habit** (nước, thiền, chuẩn bị ngủ, tập): tiến trình, mốc kế tiếp, % hoàn thành — ngôn ngữ động viên nhẹ, không gây mặc cảm.
- **Dynamic Island = "Personal Growth Companion":** Focus session / Habit tracking / Reflection reminder (buổi tối) với truy cập một chạm.

### 8.6 Offline-first + CloudKit Sync
- Local-first (SwiftData) → background sync **CloudKit**; không bao giờ chặn UI vì mạng.
- Conflict: **Last-Write-Wins + version history**, change log, recovery point, cho phép rollback.
- AI features chạy offline khi có thể (Foundation Models on-device).

### 8.7 NEXUS Intelligence Engine
- Lớp trí tuệ nội bộ: input (Health/Habits/Time/Focus/Reflection/Money) → output (recommendation/prediction/intervention/coaching).
- Liên tục trả lời: *"Hành động đòn bẩy cao nhất tiếp theo của người này là gì?"*

### 8.8 North Star
- Mục tiêu không phải năng suất hay habit tracking, mà là **human flourishing** — giúp người dùng khoẻ hơn, bình tĩnh hơn, mạnh mẽ hơn, thông thái hơn, sống đúng hướng & trọn vẹn hơn.

> **Lưu ý khả thi & ưu tiên:** đây là tầm nhìn dài hạn. Phụ thuộc kỹ thuật: Foundation Models (iOS 18.1+/Apple Intelligence), ActivityKit + widget extension cho Live Activities/Dynamic Island, container CloudKit, SDK Rive. Nên làm sau khi nền tảng UI (glass + filter) ổn định; mỗi tính năng lớn (đặc biệt Future Self Simulator) nên có spike riêng để xác thực độ chính xác mô hình trước khi cam kết.

---

## 9. Accessibility & chất lượng
- Dynamic Type: hero/`largeTitle` không vỡ (đã dùng `minimumScaleFactor`).
- VoiceOver: mọi card `accessibilityElement(.combine)` + label nghĩa.
- **Glass:** tôn trọng `reduceTransparency` (fallback nền đặc) + `reduceMotion`; đảm bảo tương phản chữ trên material ở light/dark.
- Localization: 4 ngôn ngữ (en/vi/zh-Hans/ko) đồng bộ khi thêm chuỗi.

---

## 10. Lộ trình triển khai (đề xuất theo giai đoạn)

| GĐ | Nội dung | Rủi ro |
|---|---|---|
| **P1 — Hệ Glass thống nhất** | Chuẩn hoá `GlassCard` (chuẩn/raised/inset) + token bóng/blur/vibrancy; áp toàn app (thay bề mặt phẳng); bọc StatTile vào glass | TB (đụng nhiều view) |
| **P2 — Filter thời gian đầy đủ** | `TimeFilterBar` dùng chung; áp cho mọi view thống kê + ghi nhớ lựa chọn | Thấp–TB |
| **P3 — Gọn Insights + Empty/Onboarding** | 3 lớp Insights, `InsightCalloutCard`, `EditorialEmptyState`, onboarding (Rive) | TB |
| **P4 — Motion polish** | Rive/Lottie + micro-interactions + glass depth-on-scroll | Thấp–TB |
| **P5 — Intelligence (AURA)** | Nâng cấp AI Coach on-device, Weekly Life Review + Letter, Life OS Score | Cao (cần Foundation Models) |
| **P6 — Future Self Simulator** | Mô hình dự phóng + avatar tiến hoá + future-self letter | Cao (cần spike xác thực) |
| **P7 — Hệ sinh thái Apple** | Live Activities + Dynamic Island + Widgets; CloudKit sync (offline-first) | Cao (ActivityKit/CloudKit/quyền) |

Mỗi giai đoạn ship một preview để đánh giá trước khi sang bước sau.

---

## 11. Đã hoàn thành ở các vòng feedback gần đây (nền cho redesign)
- Màu item về v1.12 + **gradient bar** thống nhất; bổ sung gradient cho Sleep analysis (duration/quality), mood-distribution, thanh % habit.
- Hero `StatTileGrid` cho Notes & Me.
- `YearStepper` (chọn năm trực tiếp) + `YearActivityHeatmap` dùng chung cho Consistency, Habit analytics, Mood calendar.
- Tổng Stats phản hồi theo tháng/năm; bỏ mood filter & danh sách reflection thừa ở Progress.
- Nhập WMLA mượt (draft buffer + debounce).
- Tiêu đề trang chính **rounded + bold** đồng nhất với detailed reports.

> **Bước tiếp theo khuyến nghị:** bắt đầu **P1 (hệ Glass thống nhất)** — tạo cảm giác "world-class iOS, một app" rõ rệt nhất với chi phí vừa phải; rồi **P2 (filter thời gian đầy đủ)**. Các tính năng NEXUS (P5–P7) là tầm nhìn dài hạn, làm sau khi nền UI ổn định.
