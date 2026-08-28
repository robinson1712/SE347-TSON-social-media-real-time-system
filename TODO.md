# TODO — Social Media Backend

Theo dõi tiến độ đồ án: đã làm gì, service nào xong, còn thiếu gì để hoàn chỉnh.

## Tổng quan

18 module Maven (`common-lib` + 3 service hạ tầng + 14 business service) đã **scaffold xong, build sạch, VÀ đã chạy thật qua Docker Compose thành công** — `mvn clean install` sạch + `docker compose up -d --build` từ trạng thái sạch hoàn toàn (`down -v`) lên đủ 16/16 service trên Eureka, test end-to-end qua gateway thật (đăng ký → login → post → feed → comment → group → dating swipe/match → auto-tạo chat conversation → notification) đều pass. Quá trình chạy thật này lộ ra **6 lỗi runtime thật** mà build/compile không bắt được — đã tìm và sửa hết, xem mục ngay dưới. Còn thiếu chủ yếu là: **chưa có test tự động**, và một số logic nghiệp vụ nâng cao vẫn ở mức đơn giản hoá có chủ đích.

---

## Đã hoàn thành — buổi trước (scaffold ban đầu)

- Thiết kế kiến trúc: Eureka + Config Server + API Gateway, JWT issue ở `auth-service` / xác thực tập trung ở gateway, forward `X-User-Id`/`X-User-Roles` xuống downstream.
- `common-lib`: `ApiResponse`/`PageResponse`, exception hierarchy (`ApiException` + 5 subclass + `GlobalExceptionHandler`), `JwtTokenProvider`, `CurrentUserContext`/`HeaderAuthFilter`, 11 Kafka event record + `KafkaTopics`, enum dùng chung.
- 3 service hạ tầng: `eureka-server`, `config-server` (native, đọc `config-repo/`), `api-gateway` (routing 14 service, JWT filter, CORS, WebSocket proxy).
- 14 business service — scaffold đầy đủ entity/repository/service/controller/DTO, Kafka producer/consumer đúng chỗ, Feign client nơi cần (comment→post, story/feed→user, feed→group/fanpage/post), WebSocket/STOMP thật cho chat + notification.
- `docker-compose.yml` (Postgres 9 DB, MongoDB 4 DB, Redis, Kafka KRaft, MinIO + 17 service) + Dockerfile từng service + `README.md`.
- Build verify: từng service riêng lẻ + toàn bộ reactor từ root — sạch, không lỗi.
- 2 artifact tài liệu: sequence diagram 4 luồng chính (auth/feed/chat/dating), catalog đầy đủ 191 class kèm minh hoạ 4 nguyên lý OOP bằng code thật.

## Đã hoàn thành — hôm nay

- **`ServiceUnavailableException`** (common-lib) — bổ sung vào exception hierarchy, dùng cho lỗi hạ tầng (503) phân biệt với lỗi nghiệp vụ (404/409...).
- **`group-service`**: sửa `GET /api/groups` để trả cả group PRIVATE mà caller đã là thành viên APPROVED (trước đó chỉ trả PUBLIC). Đổi JPQL entity name `Group` → `SocialGroup` để tránh xung đột với keyword `GROUP BY`.
- **Resilience4j circuit breaker** trên toàn bộ Feign client (`comment-service`, `story-service`, `feed-service`) — mỗi client có `fallbackFactory` riêng, cấu hình sliding window/failure threshold/half-open, phân biệt lỗi 404 hợp lệ với lỗi service sập.
- **Feed ranking theo engagement** (`feed-service`) — công thức kiểu Hacker News (`recencyScore × (1 + log(1 + reaction + 2×comment))`), tính lúc đọc chứ không phải lúc ghi.
- **Dating matching algorithm** (`dating-service`) — thêm `gender`/`birthDate` vào `DatingProfile` (trước đó thiếu, không đủ dữ liệu để tính tương thích thật), lọc tương thích giới tính hai chiều + chấm điểm 0-100 (tuổi 60đ, sở thích chung Jaccard 40đ), trả kèm điểm số qua `CandidateResponse`.
- Cập nhật `README.md` phản ánh đúng những gì đã hoàn thiện.
- **Rate limiting ở `api-gateway`** (Redis token-bucket, `RequestRateLimiter` của Spring Cloud Gateway) — bean `userOrIpKeyResolver` khoá theo `X-User-Id` nếu đã đăng nhập, fallback theo IP cho request công khai. Route `/api/auth/**` bị giới hạn chặt (1 req/s, burst 5) để chống brute-force login/spam đăng ký; 13 route còn lại dùng giới hạn chung thoáng hơn (20 req/s, burst 40 mỗi user). Route WebSocket (`/ws/**`) chưa áp rate-limit (rủi ro tương tác với handshake chưa kiểm chứng được vì chưa chạy Docker thật).

---

## 6 lỗi runtime tìm ra khi chạy Docker thật (build/compile không bắt được)

Đây là lý do vì sao bước "chạy thử thật" quan trọng — cả 6 lỗi dưới đây đều compile sạch, chỉ lộ ra khi thực sự gọi API qua container:

1. **17 jar không phải executable jar** — `spring-boot-maven-plugin` thiếu `<executions>` bind goal `repackage` vào phase `package` (root pom không kế thừa `spring-boot-starter-parent` nên không tự động có). → Sửa 1 chỗ ở root `pom.xml`.
2. **Script init multi-database Postgres lỗi** — `psql` thiếu `--dbname`, mặc định nối vào DB trùng tên user (không tồn tại). → Sửa `docker/postgres/init-multi-db.sh`.
3. **Mọi Kafka consumer lỗi deserialize** (`No type information in headers`) — producer tắt `spring.json.add.type.headers` nhưng consumer không có type mặc định thay thế. Lỗi hệ thống trên **12 service**. → Bỏ dòng tắt header ở cả 12 `application.yml`, dùng lại default (Spring Kafka tự thêm `__TypeId__` header).
4. **Toàn bộ `@PathVariable`/`@RequestParam` không tên tường minh bị lỗi 500** (`Name ... not specified, and parameter name information not available via reflection`) — thiếu cờ compiler `-parameters` (cũng do không kế thừa `spring-boot-starter-parent`). → Sửa 1 chỗ ở root `pom.xml` (`<parameters>true</parameters>`).
5. **`Account.roles` (auth-service) lazy-init exception** khi serialize `/api/auth/me` — `@ElementCollection` thiếu `fetch = FetchType.EAGER` trong khi `open-in-view: false`. → Thêm EAGER.
6. **`Unable to access lob stream`** trên post/comment/dating/group/fanpage — dùng `@Lob` cho field text thường trên Postgres (tạo kiểu `oid` cần stream trong transaction, vỡ khi session đã đóng). → Đổi cả 5 field sang `@Column(columnDefinition = "TEXT")`.
7. *(bonus, phát hiện cùng đợt)* **`function lower(bytea) does not exist`** ở `GET /api/groups` — tham số JPQL `null` khiến Postgres JDBC không suy được kiểu text. → Đổi sang truyền chuỗi rỗng `""` thay vì `null`.

Sau khi sửa hết, đã build sạch từ đầu (`mvn clean install`) + `docker compose down -v && up -d --build` một lần nữa và test lại toàn bộ — pass hết, không cần patch tay.

## Unit test — 279 test trên toàn bộ 14/14 business service

Thêm `CurrentUserContext.setForTests()/clearForTests()` (public, common-lib) làm "cửa hậu" test-only cho service dùng `CurrentUserContext.getUserId()` — `set()`/`clear()` gốc vẫn package-private, chỉ `HeaderAuthFilter` gọi được ở production. Một số service (`user-service`, `media-service`) nhận `currentUserId` qua tham số method thay vì đọc `CurrentUserContext` trực tiếp nên không cần seam này.

Bắt đầu với 3 service lõi (`auth-service`, `post-service`, `dating-service` — 40 test, tự làm), sau đó giao 6 batch song song cho agent viết nốt 11 service còn lại (mỗi agent tự đọc source thật, viết test theo đúng pattern, tự chạy `mvn test` verify trước khi báo cáo).

| Service | Số test | Điểm đáng chú ý |
|---|---|---|
| `auth-service` | 14 | register/login/refresh/logout/me — mọi nhánh lỗi |
| `post-service` | 14 | ownership check, denormalized count clamp về 0 |
| `dating-service` | 12 | **điểm tương thích khớp chính xác 80** — trùng con số verify qua curl thật |
| `comment-service` | 16 | soft-delete, Feign 404→ResourceNotFound |
| `reaction-service` | 11 | upsert cùng 1 row, projection `TypeCount` |
| `story-service` | 11 | delta hết hạn 24h chính xác, Set idempotent |
| `reels-service` | 18 | listener denormalized count (comment/reaction) |
| `group-service` | 28 | `""` thay `null` cho JDBC type-inference, memberCount clamp |
| `fanpage-service` | 24 | chặn xoá owner cuối cùng của page |
| `feed-service` | 22 | **verify công thức ranking bằng số liệu tính tay** (viral ≈0.345 vs fresh ≈0.333) |
| `chat-service` | 22 | dedup PRIVATE conversation, MessageEvent recipientId theo loại hội thoại |
| `notification-service` | 21 | cả 6 nhánh `@KafkaListener` + toàn bộ điều kiện skip |
| `user-service` | 50 | friend request/block/unblock — nhánh quyền requester/addressee |
| `media-service` | 16 | MinIO put/remove qua captor, sanitize filename |

**Không có bug sản xuất nào bị phát hiện** trong toàn bộ 11 service ở đợt này — mọi hành vi khớp đúng với những gì đã thiết kế/verify qua Docker trước đó.

Build+test toàn reactor (`mvn clean install`, không `-DskipTests`): **18/18 module, 279/279 test pass**, không có xung đột dù 6 agent chỉnh sửa song song.

---

## Trạng thái từng service

| Service | Port | Trạng thái | Còn thiếu / có thể nâng cấp |
|---|---|---|---|
| `eureka-server` | 8761 | ✅ Xong | — |
| `config-server` | 8888 | ✅ Xong | Đang bị dùng ít — có thể đẩy thêm config dùng chung (vd. resilience4j defaults) sang đây |
| `api-gateway` | 8080 | ✅ Xong + rate limit | Route WebSocket `/ws/**` chưa có rate-limit |
| `auth-service` | 8081 | ✅ Xong | Chưa có: reset mật khẩu, xác minh email, khoá tài khoản sau N lần login sai, OAuth2/social login |
| `user-service` | 8082 | ✅ Xong | Chưa có: tìm kiếm user, gợi ý bạn chung |
| `media-service` | 8083 | ✅ Xong | Chưa có: resize ảnh/tạo thumbnail, giới hạn dung lượng/loại file, transcode video |
| `post-service` | 8084 | ✅ Xong | Chưa có: lịch sử chỉnh sửa, ghim bài, report bài viết |
| `comment-service` | 8085 | ✅ Xong + circuit breaker | — |
| `reaction-service` | 8086 | ✅ Xong | Đơn giản hoá có chủ đích: nhận `targetOwnerId` từ client thay vì tự resolve qua Feign |
| `story-service` | 8087 | ✅ Xong + circuit breaker | Chưa có: story highlights (lưu vĩnh viễn), reply story qua chat |
| `reels-service` | 8088 | ✅ Xong | Feed reels vẫn thuần theo thời gian (chưa áp dụng ranking như feed-service) |
| `group-service` | 8089 | ✅ Xong + fix visibility | Chưa có: vai trò MODERATOR, kiểm duyệt bài đăng trong group |
| `fanpage-service` | 8090 | ✅ Xong | Chưa có: thống kê/insight cho page |
| `dating-service` | 8091 | ✅ Xong + matching algorithm | Chưa có: unmatch, report trong ngữ cảnh dating, xác minh ảnh |
| `chat-service` | 8092 | ✅ Xong (WebSocket thật) | Chưa có: sửa/xoá tin nhắn, typing indicator, read-receipt chi tiết (hiện chỉ có mark-all-read) |
| `notification-service` | 8093 | ✅ Xong (WebSocket thật) | Chưa có: push notification ra mobile (FCM/APNs), cài đặt loại thông báo |
| `feed-service` | 8094 | ✅ Xong + engagement ranking | Chưa gộp story/reels vào cùng feed logic |

**14/14 business service + 3/3 hạ tầng đều đã hoàn thành scaffold và build được** — không có service nào còn ở dạng rỗng/chưa code.

---

## Việc cần làm tiếp theo (theo thứ tự ưu tiên đề xuất)

1. **Test WebSocket thật** (chat/notification) — unit test đã phủ toàn bộ logic nghiệp vụ (dedup conversation, participant check, denormalized preview, listener) bằng mock, nhưng chưa test STOMP/SockJS thật qua dây mạng (gửi/nhận tin nhắn realtime end-to-end) vì khó làm bằng curl — cần client WebSocket thật (browser/Postman/wscat).
2. **Integration test** (tối thiểu 1-2 test dùng Testcontainers cho Postgres/Mongo/Kafka thật) — 279 unit test hiện tại đều mock repository/Kafka, chưa có test nào chạy qua DB thật để bắt các lỗi kiểu mục "6 lỗi runtime" (vd. lỗi JPQL, lỗi mapping cột) mà chỉ mock thì không thấy được.
3. **Swagger/OpenAPI UI** — dependency `springdoc-openapi` đã khai version sẵn ở root `pom.xml` nhưng **chưa service nào thực sự thêm vào** để có UI test API trên trình duyệt.
4. **Observability** — chưa có distributed tracing (Zipkin/OpenTelemetry), chưa có log tập trung, chưa có dashboard metrics (hiện chỉ có `actuator/health` + `actuator/circuitbreakers`).
5. **Content moderation** — chưa có filter/kiểm duyệt nội dung post/comment.
6. **CI/CD pipeline** — chưa có (giờ có 279 test, chạy CI mỗi lần push sẽ rất có giá trị).
7. **Nâng cấp nhỏ theo từng service** — xem cột "Còn thiếu" ở bảng trên.
