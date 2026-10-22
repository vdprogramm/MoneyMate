# MoneyMate — Quản lý thu chi cá nhân (Android + Cloud)

**Trạng thái: MoneyMate v0.3.0 — MVP hoàn thành và nghiệm thu trên Android ngày 22/10/2026.** Backend chạy trên Render, dữ liệu PostgreSQL lưu trên Neon. Không yêu cầu backend localhost. Đây là bản MVP/demo, **chưa phải bản phát hành thương mại hoặc Google Play**.

## Demo, mã nguồn và kết quả CI

- **Repository:** https://github.com/vdprogramm/MoneyMate
- **Thiết kế Figma:** https://www.figma.com/design/KSq5FBb1GhBIDXw8bIMS3P
- **Backend HTTPS:** https://moneymate-api-snmi.onrender.com
- **API Health Check:** https://moneymate-api-snmi.onrender.com/actuator/health
- **APK Android v0.3 (CI Success):** https://github.com/vdprogramm/MoneyMate/actions/runs/39755315664
- **Flutter analysis + tests (Success):** https://github.com/vdprogramm/MoneyMate/actions/runs/39755315762
- **Backend Maven/JUnit (Success):** https://github.com/vdprogramm/MoneyMate/actions/runs/39754224582
- **API cloud smoke test (Success):** https://github.com/vdprogramm/MoneyMate/actions/runs/39755128264

**Tải APK:** Mở liên kết APK phía trên → Artifacts → MoneyMate-Android-APK → tải ZIP → giải nén → cài app-release.apk. Artifact của lần build này hết hạn ngày **05/11/2026**. Build test có thể không cập nhật đè lên APK khác chữ ký; cần kiểm tra và đồng bộ mọi khoản chi offline trước khi gỡ ứng dụng cũ.

## Bài toán và kiến trúc

MoneyMate giúp theo dõi ví tiền, khoản thu/chi, ngân sách và thống kê theo tháng. Khi điện thoại mất mạng, một khoản chi mới được lưu trước vào SQLite; sau đó gửi qua HTTPS tới API khi kết nối được khôi phục.

**Kiến trúc:** Flutter + Riverpod → Spring Boot Java 21 (Render) → PostgreSQL (Neon).

**Offline:** Flutter → SQLite Outbox (tách theo email tài khoản) → POST /api/v1/transactions/offline-sync → Neon.

Mỗi khoản thu/chi offline mang UUID được tạo trên thiết bị và giữ nguyên qua các lần retry. API sử dụng insert idempotent nên cùng UUID và nội dung chỉ tạo một giao dịch; UUID trùng với nội dung khác bị từ chối thay vì ghi đè.

## Chức năng đã triển khai

- **Xác thực:** Đăng ký, đăng nhập, đăng xuất; BCrypt và JWT HS256, token cất trong Flutter Secure Storage.
- **Dashboard:** Tổng số dư, tổng thu/chi và giao dịch gần đây.
- **Ví:** Tạo và xem số dư ví; chọn ví khi nhập thu/chi.
- **Giao dịch:** Tạo, sửa, xóa, gán ví và danh mục, chọn ngày và ghi chú.
- **Ngân sách:** Hạn mức tháng, tỷ lệ đã dùng và cảnh báo từ 90%.
- **Thống kê:** Biểu đồ danh mục chi tiêu và chọn tháng.
- **OCR (v0.2):** Chụp/chọn hóa đơn qua Android, nhận dạng chữ bằng Google ML Kit trên thiết bị, đề xuất cửa hàng và số tiền; luôn yêu cầu kiểm tra thủ công và nhấn lưu. Không upload ảnh hóa đơn lên backend.
- **PDF (v0.2):** Báo cáo thu/chi theo tháng dựa trên dữ liệu API thật, có chức năng chia sẻ.
- **Offline (v0.3):** SQLite lưu giao dịch mới khi mất mạng và sau khi đóng/mở app, hàng đợi tách theo tài khoản, cache danh sách ví, nút đồng bộ và thử đồng bộ khi app tiếp tục chạy.
- **Bảo vệ dữ liệu backend:** Phân quyền theo chủ sở hữu; người dùng không được sửa/xóa giao dịch của người khác.
- **DevOps:** Docker trên Render, Neon PostgreSQL, Flyway migration, GitHub Actions cho Java/Flutter/API cloud và Android APK.

### API chính

| Method | Endpoint | Chức năng |
| --- | --- | --- |
| POST | /api/v1/auth/register | Tạo tài khoản |
| POST | /api/v1/auth/login | Đăng nhập |
| GET | /api/v1/users/me | Xem tài khoản hiện tại |
| GET, POST | /api/v1/wallets | Danh sách và tạo ví |
| GET, POST | /api/v1/transactions | Danh sách và tạo giao dịch online |
| PUT, DELETE | /api/v1/transactions/{id} | Sửa/xóa giao dịch |
| POST | /api/v1/transactions/offline-sync | Nhận UUID cố định từ thiết bị, đồng bộ idempotent |
| GET, POST | /api/v1/budgets | Ngân sách; GET dùng month=YYYY-MM |
| DELETE | /api/v1/budgets/{id} | Xóa ngân sách |
| GET | /api/v1/reports/summary?month=YYYY-MM | Báo cáo tháng |
| GET | /api/v1/categories | Danh mục |
| GET | /actuator/health | Healthcheck |

Tất cả API nghiệp vụ yêu cầu Bearer JWT, trừ auth và healthcheck.

## Kết quả kiểm thử

### Android — nghiệm thu thủ công

**6/6 luồng MVP ban đầu đạt:** Đăng ký, đăng nhập, Dashboard; tạo ví; ghi thu/chi và kiểm tra số dư; ngân sách; biểu đồ thống kê; đăng xuất/đăng nhập lại.

**5/5 luồng OCR/PDF v0.2 đạt:** Đăng nhập, mở OCR, nhận dạng số tiền hóa đơn, lưu giao dịch OCR, xuất PDF.

**5/5 luồng offline v0.3 đạt (22/10/2026):**

1. Cài và đăng nhập khi có mạng.
2. Bật chế độ máy bay.
3. Tạo khoản chi 50.000 VND và lưu offline.
4. Đóng/mở lại app, thấy giao dịch chờ đồng bộ.
5. Bật lại mạng, đồng bộ và xác nhận khoản chi chỉ xuất hiện **một lần**.

### Tự động

- Flutter analysis và widget/unit tests: Success.
- Android APK release build: Success; có artifact.
- Backend Maven/JUnit: Success.
- Cloud smoke test: Success, gồm JWT, ví, giao dịch, báo cáo, ngân sách, kiểm tra quyền giữa người dùng và UUID offline gửi lặp.
- Render API deploy: Live.

**Phạm vi:** Các luồng trên đạt. Chưa có bằng chứng kiểm thử toàn bộ điện thoại, phiên token hết hạn, mạng rất chập chờn, đồng bộ trên nhiều thiết bị hoặc sao lưu/khôi phục.

## Cách build Android

GitHub Actions tự build APK; không bắt buộc cài Flutter trên máy cá nhân. Nếu muốn chạy SDK tại máy build, thao tác ở thư mục mobile:

    flutter create . --platforms=android --project-name=moneymate
    python tool/configure_android.py
    flutter pub get
    flutter analyze
    flutter test
    flutter build apk --release --dart-define=API_BASE_URL=https://moneymate-api-snmi.onrender.com

APK nằm trong thư mục mobile/build/app/outputs/flutter-apk.

## Backend Render và Neon

- **Render:** Web Service moneymate-api, Docker, URL ở đầu tài liệu. Gói miễn phí có thể sleep khiến request đầu tiên chậm.
- **Neon:** Project MoneyMate, database moneymate. PostgreSQL migration qua Flyway.
- **Cấu hình bí mật chỉ trên Render:** JDBC_DATABASE_URL, DB_USERNAME, DB_PASSWORD, JWT_SECRET (tối thiểu 32 UTF-8 byte).
- **Không commit** chuỗi kết nối chứa mật khẩu, token, JWT secret hoặc tài khoản người dùng thật.
- Dịch vụ Render hiện dùng **Manual Deploy**: commit Java mới lên GitHub không đồng nghĩa đã cập nhật dịch vụ; phải kiểm tra commit đang live trên Render.
- Script scripts/cloud_smoke.py dùng tài khoản thử nghiệm; tránh chạy lặp trên database sản xuất vì script tạo thêm dữ liệu thử nghiệm.

## Giới hạn còn lại — chưa production-ready

1. **Mã hóa dữ liệu cục bộ:** SQLite hiện lưu payload giao dịch dưới dạng dữ liệu ứng dụng chưa được mã hóa riêng; nên thêm bảo vệ dữ liệu offline, sao lưu và xóa dữ liệu theo quy tắc.
2. **Xử lý lỗi đồng bộ:** Lỗi 4xx (giao dịch không hợp lệ, thiếu quyền, ví bị xóa, token hết hạn hoặc xung đột UUID) có thể giữ bản ghi trong hàng đợi. Cần UI chi tiết để xem, sửa, thử lại, hủy có xác nhận mà không mất dữ liệu.
3. **Phạm vi offline:** V0.3 chỉ hỗ trợ tạo mới thu/chi offline và cache danh sách ví; xem đầy đủ lịch sử, dashboard, ngân sách, sửa/xóa giao dịch vẫn cần cloud.
4. **Phát hành:** Chưa có Google Play release, keystore phát hành ổn định, privacy policy, telemetry/crash reporting và kiểm thử đa thiết bị.
5. **Tin cậy & bảo mật:** Cần backup/restore, kiểm thử mất mạng khi request đã được server xử lý, JWT expiration/refresh, rate-limiting, dependency/security audit và đánh giá hiệu năng.

Các giới hạn trên không phủ nhận 5/5 bước offline đã đạt; chúng là tiêu chí để nâng lên bản phát hành rộng rãi.

## Mô tả dự án cho CV / Portfolio

**MoneyMate — Personal Finance Android App** (Flutter, Riverpod, Java Spring Boot, PostgreSQL/Neon, Render)

Built an Android personal-finance application with JWT authentication, wallet management, income and expense tracking, monthly budgets and charts, on-device receipt OCR and PDF reporting. Implemented an SQLite offline transaction outbox with UUID-based idempotent synchronization to prevent duplicate expenses on network retries. Deployed the Spring Boot API to Render backed by Neon PostgreSQL; automated testing and Android APK builds with GitHub Actions.
