# MoneyMate — Ứng dụng quản lý thu chi cá nhân

<p align="center">
  <strong>Ghi chép thu chi · Quản lý ví · Ngân sách · OCR hóa đơn · Báo cáo PDF · Đồng bộ offline</strong>
</p>

<p align="center">
  <a href="https://github.com/vdprogramm/MoneyMate/actions/workflows/mobile-check.yml"><img src="https://github.com/vdprogramm/MoneyMate/actions/workflows/mobile-check.yml/badge.svg?branch=main" alt="Flutter analysis"></a>
  <a href="https://github.com/vdprogramm/MoneyMate/actions/workflows/android-apk.yml"><img src="https://github.com/vdprogramm/MoneyMate/actions/workflows/android-apk.yml/badge.svg?branch=main" alt="Android APK build"></a>
  <a href="https://github.com/vdprogramm/MoneyMate/actions/workflows/backend-check.yml"><img src="https://github.com/vdprogramm/MoneyMate/actions/workflows/backend-check.yml/badge.svg?branch=main" alt="Backend checks"></a>
  <a href="https://github.com/vdprogramm/MoneyMate/actions/workflows/cloud-smoke.yml"><img src="https://github.com/vdprogramm/MoneyMate/actions/workflows/cloud-smoke.yml/badge.svg?branch=main" alt="Cloud smoke test"></a>
</p>

MoneyMate là ứng dụng Android hỗ trợ quản lý tài chính cá nhân. Người dùng có thể ghi nhận thu/chi, quản lý ví, theo dõi ngân sách và xem thống kê theo tháng. Ứng dụng còn hỗ trợ nhận dạng thông tin hóa đơn ngay trên thiết bị, xuất báo cáo PDF và lưu giao dịch mới khi mất mạng để đồng bộ lại khi có kết nối.

> **Phiên bản:** v0.3.0 — MVP đã được kiểm thử thủ công trên điện thoại. Đây là dự án MVP/portfolio, chưa phải bản phát hành thương mại hoặc bản phát hành Google Play.

## Liên kết nhanh

| Tài nguyên | Liên kết |
| --- | --- |
| Mã nguồn | [GitHub repository](https://github.com/vdprogramm/MoneyMate) |
| Thiết kế giao diện | [Figma](https://www.figma.com/design/KSq5FBb1GhBIDXw8bIMS3P) |
| Backend API | [moneymate-api-snmi.onrender.com](https://moneymate-api-snmi.onrender.com) |
| Kiểm tra tình trạng API | [`/actuator/health`](https://moneymate-api-snmi.onrender.com/actuator/health) |
| Build APK gần nhất thành công | [GitHub Actions #40304069779](https://github.com/vdprogramm/MoneyMate/actions/runs/40304069779) |
| Flutter analysis gần nhất thành công | [GitHub Actions #40304072678](https://github.com/vdprogramm/MoneyMate/actions/runs/40304072678) |
| Backend CI | [Maven/JUnit](https://github.com/vdprogramm/MoneyMate/actions/runs/39754224582) |
| Cloud smoke test | [API smoke test](https://github.com/vdprogramm/MoneyMate/actions/runs/39755128264) |

### Tải và cài APK

1. Mở [workflow build APK](https://github.com/vdprogramm/MoneyMate/actions/runs/40304069779).
2. Trong mục **Artifacts**, tải `MoneyMate-Android-APK`.
3. Giải nén file ZIP, sau đó cài `app-release.apk` trên thiết bị Android.

Artifact của lần build hiện tại dự kiến hết hạn ngày **09/11/2026**. Nếu GitHub yêu cầu đăng nhập hoặc artifact hết hạn, chạy lại workflow hoặc dùng APK từ lần build mới hơn. Khi cài đè, Android có thể từ chối nếu chữ ký khác; hãy đồng bộ giao dịch đang chờ trước khi gỡ bản cũ.

## Chức năng

| Tính năng | Mô tả |
| --- | --- |
| Đăng ký và đăng nhập | Xác thực bằng JWT; mật khẩu được băm bằng BCrypt; token lưu trong Flutter Secure Storage. |
| Dashboard | Tổng số dư, tổng thu/chi và giao dịch gần đây. |
| Quản lý ví | Tạo ví, xem số dư và chọn ví khi ghi nhận giao dịch. |
| Thu chi | Thêm, sửa, xóa giao dịch; chọn danh mục, ngày và ghi chú. |
| Ngân sách | Thiết lập hạn mức theo tháng và theo dõi mức đã sử dụng; cảnh báo khi gần/vượt ngưỡng. |
| Thống kê | Biểu đồ chi tiêu theo danh mục và chọn tháng báo cáo. |
| Quét hóa đơn OCR | Dùng Google ML Kit nhận dạng văn bản trên thiết bị; người dùng kiểm tra thông tin rồi chủ động lưu giao dịch. Ảnh hóa đơn không được tải lên backend. |
| Báo cáo PDF | Tạo báo cáo thu/chi theo tháng từ dữ liệu API và chia sẻ tệp PDF. |
| Ghi giao dịch offline | Khi mất mạng, giao dịch mới được lưu vào SQLite trên thiết bị và có thể tồn tại sau khi đóng/mở lại ứng dụng. |
| Đồng bộ an toàn | Hàng đợi tách theo tài khoản; UUID cố định và xử lý idempotent giúp tránh tạo giao dịch trùng khi gửi lại. |

## Kiến trúc và công nghệ

```text
Android App
Flutter + Dart + Riverpod
       |
       | HTTPS + Bearer JWT
       v
Spring Boot REST API (Java 21) — Render
       |
       v
PostgreSQL — Neon

Offline transaction queue:
Flutter -> SQLite Outbox -> POST /api/v1/transactions/offline-sync
```

- **Mobile:** Flutter, Dart, Riverpod, Dio, fl_chart.
- **OCR:** Google ML Kit Text Recognition chạy trên thiết bị.
- **Local storage:** SQLite/sqflite cho hàng đợi giao dịch offline; Flutter Secure Storage cho token.
- **Backend:** Java 21, Spring Boot, Spring Security, JWT HS256, BCrypt, Flyway.
- **Database:** PostgreSQL trên Neon.
- **Hosting:** Render Web Service chạy bằng Docker.
- **CI/CD:** GitHub Actions kiểm tra Flutter, build APK Android và chạy kiểm tra backend/API.

### Đồng bộ offline hoạt động như thế nào?

1. Khi không có mạng, ứng dụng ghi giao dịch mới vào SQLite và gán một UUID trên thiết bị.
2. Giao dịch ở trạng thái chờ đồng bộ được giữ lại khi đóng và mở lại ứng dụng.
3. Khi kết nối trở lại, ứng dụng gửi hàng đợi lên API qua HTTPS.
4. Backend xử lý UUID theo cách idempotent: gửi lại cùng UUID và cùng nội dung không tạo thêm giao dịch; UUID trùng nhưng nội dung khác bị từ chối.

**Lưu ý:** Offline hiện hỗ trợ tạo mới khoản thu/chi. Dashboard, lịch sử đầy đủ, ngân sách và sửa/xóa giao dịch vẫn cần kết nối backend.

## API

Các endpoint nghiệp vụ cần header `Authorization: Bearer <JWT>`, ngoại trừ đăng ký, đăng nhập và health check.

| Method | Endpoint | Mục đích |
| --- | --- | --- |
| `POST` | `/api/v1/auth/register` | Đăng ký tài khoản |
| `POST` | `/api/v1/auth/login` | Đăng nhập và nhận JWT |
| `GET` | `/api/v1/users/me` | Thông tin tài khoản hiện tại |
| `GET`, `POST` | `/api/v1/wallets` | Liệt kê và tạo ví |
| `GET`, `POST` | `/api/v1/transactions` | Liệt kê và tạo giao dịch online |
| `PUT`, `DELETE` | `/api/v1/transactions/{id}` | Sửa hoặc xóa giao dịch |
| `POST` | `/api/v1/transactions/offline-sync` | Đồng bộ hàng đợi offline |
| `GET`, `POST` | `/api/v1/budgets` | Liệt kê và tạo ngân sách; GET nhận `month=YYYY-MM` |
| `DELETE` | `/api/v1/budgets/{id}` | Xóa ngân sách |
| `GET` | `/api/v1/reports/summary?month=YYYY-MM` | Tổng hợp báo cáo tháng |
| `GET` | `/api/v1/categories` | Danh sách danh mục |
| `GET` | `/actuator/health` | Health check |

Backend kiểm tra quyền sở hữu dữ liệu để người dùng không thể sửa hoặc xóa giao dịch thuộc tài khoản khác.

## Kiểm thử và trạng thái nghiệm thu

### Kiểm thử thủ công trên Android

- **Luồng cơ bản:** đăng ký, đăng nhập, Dashboard, tạo ví, thêm thu/chi và kiểm tra số dư, tạo ngân sách, xem biểu đồ, đăng xuất rồi đăng nhập lại — **đạt**.
- **OCR/PDF v0.2.0:** đăng nhập, mở OCR, nhận dạng số tiền hóa đơn, lưu giao dịch từ OCR, xuất PDF — **5/5 đạt**.
- **Offline v0.3.0:** đăng nhập khi có mạng, bật chế độ máy bay, lưu khoản chi 50.000 VND, đóng/mở lại app, bật mạng và đồng bộ; xác nhận giao dịch chỉ xuất hiện một lần — **5/5 đạt**.

### Kiểm thử tự động

- [Flutter analysis — thành công](https://github.com/vdprogramm/MoneyMate/actions/runs/40304072678).
- [Android release APK — build thành công](https://github.com/vdprogramm/MoneyMate/actions/runs/40304069779).
- [Backend Maven/JUnit](https://github.com/vdprogramm/MoneyMate/actions/runs/39754224582).
- [Cloud API smoke test](https://github.com/vdprogramm/MoneyMate/actions/runs/39755128264).

Các kết quả trên xác nhận những luồng đã kiểm thử; không đồng nghĩa ứng dụng đã được kiểm thử trên mọi thiết bị hoặc sẵn sàng cho môi trường production.

## Build ứng dụng Android

Có thể tải APK từ GitHub Actions mà không cần cài Flutter trên máy. Nếu muốn tự build, cần cài Flutter SDK, Android SDK và Python trước.

Trong PowerShell hoặc terminal, chạy:

```bash
cd mobile
flutter create . --platforms=android --project-name=moneymate
python tool/configure_android.py
flutter pub get
flutter analyze
flutter test
flutter build apk --release --dart-define=API_BASE_URL=https://moneymate-api-snmi.onrender.com
```

APK được tạo tại:

```text
mobile/build/app/outputs/flutter-apk/app-release.apk
```

Ứng dụng phát hành phải trỏ đến API HTTPS thật. Không cấu hình URL localhost cho bản APK dùng trên điện thoại.

## Cấu hình backend cloud

Backend hiện được triển khai trên Render và sử dụng PostgreSQL trên Neon. Khi cấu hình hoặc triển khai lại:

- Render cần các biến môi trường `JDBC_DATABASE_URL`, `DB_USERNAME`, `DB_PASSWORD`, `JWT_SECRET`.
- `JWT_SECRET` phải là giá trị ngẫu nhiên đủ mạnh, tối thiểu 32 byte UTF-8.
- Flyway quản lý migration cơ sở dữ liệu khi ứng dụng khởi động.
- Không commit mật khẩu, chuỗi kết nối có thông tin xác thực, JWT secret hoặc dữ liệu cá nhân thật lên GitHub.
- Gói Render miễn phí có thể tạm ngừng khi không hoạt động, khiến yêu cầu đầu tiên mất thêm thời gian.
- Cần kiểm tra trạng thái deploy và health check sau khi thay đổi backend. Nếu dịch vụ dùng Manual Deploy, push code lên GitHub không tự động có nghĩa là bản cloud đã cập nhật.

Script `scripts/cloud_smoke.py` tạo dữ liệu thử nghiệm. Chỉ chạy trên môi trường thử nghiệm hoặc sau khi đã xác nhận tác động lên dữ liệu.

## Giới hạn hiện tại và việc nên làm tiếp

MoneyMate đã hoàn thành các luồng MVP được nêu ở trên, nhưng chưa nên xem là ứng dụng production-ready. Những việc nên hoàn thiện tiếp:

1. **Quản lý hàng đợi lỗi:** hiển thị chi tiết giao dịch đồng bộ thất bại, phân biệt lỗi cần đăng nhập lại, dữ liệu không hợp lệ và xung đột UUID; cung cấp cách sửa/thử lại/hủy có xác nhận.
2. **Bảo vệ dữ liệu offline:** đánh giá mã hóa dữ liệu SQLite, thời gian lưu trữ và cách xóa dữ liệu khi đăng xuất hoặc xóa tài khoản.
3. **Xử lý phiên đăng nhập:** kiểm thử JWT hết hạn, đăng xuất, khôi phục phiên và quy trình refresh token nếu cần.
4. **Độ tin cậy:** kiểm thử mạng chập chờn, request timeout sau khi server đã ghi dữ liệu, nhiều lần retry và đồng bộ trên nhiều thiết bị.
5. **Sẵn sàng phát hành:** bổ sung privacy policy, ký APK bằng keystore phát hành được quản lý an toàn, crash reporting có cân nhắc quyền riêng tư, kiểm thử đa thiết bị và đánh giá bảo mật dependency.
6. **Sao lưu và khôi phục:** xác định quy trình backup/restore cho dữ liệu backend.

## Mô tả ngắn cho CV

**MoneyMate — Personal Finance Android App**  
*Flutter, Riverpod, Java Spring Boot, PostgreSQL/Neon, Render*

Built an Android personal-finance app with JWT authentication, wallet management, income/expense tracking, monthly budgets and charts, on-device receipt OCR, and PDF reporting. Implemented an SQLite offline transaction queue with UUID-based idempotent synchronization to prevent duplicate transactions during retries. Deployed the Spring Boot API to Render with Neon PostgreSQL and automated Flutter checks and Android APK builds using GitHub Actions.
