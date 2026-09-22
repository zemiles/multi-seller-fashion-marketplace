# 업무 서비스 공통 운영 내부 API

[OpenAPI](../../contracts/operations-internal.openapi.json) · [전체 API 뷰어](index.html)

| Method | Path | 설명 | 권한 | 요구사항 |
| --- | --- | --- | --- | --- |
| GET | /internal/v1/event-queues | queryLocalEventQueues | commerce-service | EVT-03, OPS-01 |
| POST | /internal/v1/event-queues/{entryId}/replays | replayLocalEventQueue | commerce-service | EVT-03, OPS-01 |
| GET | /internal/v1/recovery-jobs/{jobId} | queryLocalRecoveryJob | commerce-service | EVT-03, OPS-01 |
