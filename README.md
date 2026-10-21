# MoneyMate — Ứng dụng quản lý thu chi Flutter + Spring Boot

> **Trạng thái: MVP code v0.1 (chưa deploy, chưa có URL demo hoặc APK được build).** Không sử dụng API localhost. Ứng dụng dùng URL HTTPS Render được truyền vào lúc build; PostgreSQL dùng Neon. Dữ liệu thật, không sử dụng mock trong UI.

Thiết kế Figma: https://www.figma.com/design/KSq5FBb1GhBIDXw8bIMS3P

## Đã có trong MVP

- Flutter + Riverpod: đăng ký/đăng nhập, JWT trong secure storage, dashboard, 5 tab, biểu đồ danh mục `fl_chart`, quản lý ví, tạo/sửa/xóa giao dịch, cấu hình ngân sách và cảnh báo 90%, chuyển tháng.
- Java 21 + Spring Boot: Spring Security, JWT HS256, BCrypt, REST API, lọc dữ liệu theo user, kiểm tra quyền sở hữu ví/giao dịch/ngân sách.
- PostgreSQL Neon: script Flyway V1 khởi tạo bảng và chỉ số tự chạy lần đầu.
- Dockerfile và `render.yaml` cho backend Render.
- Smoke test cloud có kiểm tra chống truy cập chéo người dùng.

## Chưa có trong MVP

- OCR hóa đơn, xuất PDF, đồng bộ ghi offline, notification push, phát hành iOS/App Store và APK signed chính thức. Đây là giai đoạn sau khi API cloud đầu tiên hoạt động.
- Chưa có URL production hoặc cơ sở dữ liệu triển khai; **không khẳng định đã chạy deploy**.

## 1. Database Neon (cloud)

1. Tạo dự án PostgreSQL tên `MoneyMate` trên [Neon](https://console.neon.tech/).
2. Vào **Connect** và lấy host, database, user và password của role. Chọn kết nối pooler nếu dùng Render. Với Neon yêu cầu TLS `sslmode=require`.
3. Trên Render tạo 3 biến riêng tư:

   - `JDBC_DATABASE_URL=jdbc:postgresql://YOUR-NEON-HOST/NEON-DB?sslmode=require` (đây **phải là JDBC URL**, không phải URL `postgresql://user:password@host/db`).
   - `DB_USERNAME=YOUR-NEON-ROLE`
   - `DB_PASSWORD=YOUR-NEON-PASSWORD`

**Không** commit mật khẩu, DATABASE_URL có credential, JWT secret vào GitHub hay README. Flyway tạo bảng ở lần chạy đầu tiên.

## 2. Render (backend online)

1. Tạo repo GitHub `MoneyMate`, đưa toàn bộ nội dung vào nhánh `main`.
2. Render → **New → Blueprint** → chọn repo và `render.yaml`.
3. Điền ba biến Neon ở trên; `JWT_SECRET` được Render sinh ngẫu nhiên theo Blueprint.
4. Đợi `/actuator/health` trả `{"status":"UP"}`. API có tiền tố `/api/v1`.
5. URL API sẽ là URL HTTPS thực được Render cấp, ví dụ `https://moneymate-api-xxxx.onrender.com` (chỉ ví dụ, chưa có thật).

Lưu ý Render Free có thể sleep sau thời gian không có request, khiến lần gọi đầu chậm. Không kiểm tra ứng dụng bằng cách truy cập root `/` — hãy kiểm tra `/actuator/health`.

## 3. Build app Flutter Android thật, không cần localhost

Yêu cầu Flutter SDK, Android Studio + Android SDK, Dart 3.5+ trên máy build. Source Flutter đã có ở `mobile/lib/` và `mobile/pubspec.yaml`. Do môi trường tạo project chưa có Flutter SDK nên các platform runner (`android/`, `ios/`) cần được sinh bằng Flutter CLI:

```bash
cd mobile
flutter create . --platforms=android,ios --project-name=moneymate
python tool/configure_android.py
flutter pub get
flutter run --dart-define=API_BASE_URL=https://YOUR-REAL-RENDER-URL.onrender.com
flutter build apk --release --dart-define=API_BASE_URL=https://YOUR-REAL-RENDER-URL.onrender.com
```

APK đầu ra sau khi build thành công: `mobile/build/app/outputs/flutter-apk/app-release.apk`. Phải thay URL ví dụ bằng URL Render được cấp thực tế. **Không dùng `http://localhost`, `127.0.0.1` hoặc IP LAN**.

Nếu `API_BASE_URL` trống hoặc không bắt đầu bằng `https://`, app hiện thông báo cấu hình thay vì hiển thị dữ liệu demo giả.

## 4. Thử nghiệm sau khi deploy

```bash
API_BASE_URL=https://YOUR-REAL-RENDER-URL.onrender.com python scripts/cloud_smoke.py
```

Script tạo 2 user test trên Neon, kiểm tra health, auth, ví, thêm/xóa giao dịch, ngân sách, thống kê và chống user B sửa giao dịch user A. Hãy chỉ chạy trên môi trường demo/test; script cố ý để lại tài khoản test phục vụ đối soát.

## 5. API

| Method | URL | Ghi chú |
|---|---|---|
| POST | `/api/v1/auth/register` | Công khai |
| POST | `/api/v1/auth/login` | Công khai |
| GET | `/api/v1/users/me` | Bearer JWT |
| GET, POST | `/api/v1/wallets` | Xem và thêm ví |
| GET, POST | `/api/v1/transactions` | Thu/chi |
| PUT, DELETE | `/api/v1/transactions/{id}` | Sửa/xóa |
| GET, POST | `/api/v1/budgets?month=YYYY-MM` | Xem/cấu hình |
| DELETE | `/api/v1/budgets/{id}` | Xóa |
| GET | `/api/v1/reports/summary?month=YYYY-MM` | Số dư, chi/thu, danh mục |
| GET | `/api/v1/categories` | Danh mục mẫu |
| GET | `/actuator/health` | Healthcheck công khai |

## 6. Quy tắc nghiệp vụ

- Các khoản thu và chi có `amount > 0`, `type = INCOME/EXPENSE`, `occurredOn` là ngày phát sinh. Số tiền ở Postgres dùng NUMERIC(19,2).
- Số dư một ví = số dư mở đầu + tổng thu – tổng chi. Tổng số dư dashboard = tổng số dư các ví.
- Ngân sách chỉ tính những khoản `EXPENSE` cùng danh mục, cùng tháng, cùng user.
- Dữ liệu của user khác luôn trả `404` khi thử sửa/xóa bằng ID; JWT không thay thế kiểm tra owner.
- Không hỗ trợ ghi offline ở bản v0.1: cần mạng và API cloud đang hoạt động để thêm khoản thu chi.

## 7. Chạy backend chỉ trên cloud

MVP này thiết kế sẵn để Docker build Spring Boot ngay trên Render; bạn **không cần khởi chạy backend ở localhost**. Cần repo + Neon + Render kết nối thực tế. Không có mật khẩu demo hardcoded.

## 8. Build APK ngay trên GitHub Actions (không cần máy bạn cài Flutter)

Sau khi có URL Render thật, vào repository **Settings → Secrets and variables → Actions**, tạo secret `API_BASE_URL` có giá trị như `https://<service-cua-ban>.onrender.com`. Vào **Actions → Build MoneyMate Android APK → Run workflow**. Khi workflow thành công, tải artifact `MoneyMate-Android-APK` rồi cài APK lên điện thoại Android. Build mặc định là bản thử nghiệm, không phải bản ký phát hành Play Store.
