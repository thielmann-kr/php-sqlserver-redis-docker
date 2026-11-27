# php-sqlserver-redis-docker

PHP, SQLSERVER, REDIS docker 이미지 (thielmann 공용 PHP 베이스)

## 사용 방법 — 불변 태그 + digest 로만 참조

```dockerfile
FROM thielmann/php-sqlserver-redis-docker:8.2.36-bookworm-v1@sha256:<digest>
```

- digest 는 GitHub Actions 실행 요약(Summary)에 출력된다.
- **`latest` 는 더 이상 갱신하지 않는다.** 2023-12-04 빌드(PHP 8.2.13)에 고정된 채로 남는다.
  `latest` 를 쓰는 기존 저장소가 예고 없이 바뀌지 않게 하기 위함이며, 새 저장소는 쓰지 않는다.

## 태그 정책

- 태그는 `VERSION` 파일 한 줄에서만 온다. 형식: `<PHP 버전>-<debian>-v<n>`
- 이미 게시된 태그는 덮어쓰지 않는다(워크플로가 건너뜀). 이미지를 바꾸려면 `VERSION` 을 올린다.
  - PHP 패치: `8.2.36-bookworm-v1` -> `8.2.37-bookworm-v1`
  - 같은 PHP 에서 구성만 변경: `-v1` -> `-v2`
- PR 은 빌드 + 자체검사만 하고 push 하지 않는다.

## 구성 (8.2.36-bookworm-v1)

- 기반: 공식 `php:8.2.36-fpm-bookworm` (index digest 고정)
- 확장: pcntl, gd(freetype/jpeg), zip, intl, ftp(SSL), sodium, sqlsrv/pdo_sqlsrv 5.11.1, redis 6.0.2
- OS: msodbcsql18 18.3.2.1-1, mssql-tools18 18.2.1.1-1, unixodbc, nodejs 20.10.0, TZ=Asia/Seoul
- composer 2.6.5, opcache 미로드
- `session.upload_progress.enabled = 0` (CVE-2026-126714 / CVE-2026-115560 입력 경로 차단)

## 로컬 빌드

```
docker buildx build --platform linux/amd64 --load -t thielmann/php-sqlserver-redis-docker:local-test .
```

## 업데이트 이력

- 2026. 11. 27. PHP 8.2.36 보안 릴리스 반영(`8.2.36-bookworm-v1`), 버전 고정, 불변 태그 정책 도입, `latest` 갱신 중단
- 2023. 11. 30. php 버전 업데이트, node 추가, sql server 설치 스크립트 수정, mcrypt 제거
