# Production 私密媒体清单：第一阶段（只读）

承接 docs/migration/GLYPHORA_CLOUDFLARE_MIGRATION_HANDOFF_2026-10-22.md。不重复 Staging 播放测试，不重新上传 Secret，不部署 Production，不删除媒体。

## 1. 数据来源

从现有 Production Neon 连接以只读方式导出 UTF-8 CSV，字段为：

    id,isPublic,videoStorageId,coverStorageId,videoStorageKey,coverStorageKey

SQL 模板（先确认连接的是 Production neondb，而不是 Staging）：

```sql
SELECT "id", "isPublic", "videoStorageId", "coverStorageId",
       "videoStorageKey", "coverStorageKey"
FROM "video" ORDER BY "id";
```

通过 SQL 客户端的 CSV 导出功能保存。不要把数据库密码、连接串、导出 CSV 或 JSON 计划提交 Git；NULL 留空。

## 2. 离线生成计划（不访问远端）

```powershell
python cloudflare/plan_production_private_media.py .\private-media-production.csv --output .\private-media-plan.json
```

工具不连接数据库、不调用 rclone、不访问 R2、不写远端对象；若目标文件已经存在则拒绝覆盖。

- copyCandidates：仅 isPublic=false 且相应 StorageId=public 的视频/封面，候选操作是从 glyphora-media 复制到 glyphora-media-private；不是执行指令。
- manualReview：StorageId 为 NULL 或未知、状态与位置不一致、异常 key、重复键等；不能从 isPublic 推断实际位置，旧对象可能仍在 GCS。
- counts：行数、候选数和待审查数量。

## 3. 实际迁移前必须完成

1. 保持 media.glyphora.net 的公开访问关闭或受限；Cloud Run 继续运行。
2. 逐项核对候选对象真实所在位置（GCS/R2），特别区分视频和封面；对 NULL、重复键和冲突记录人工审查。
3. 协调迁移期间上传、删除、可见性改变造成的并发变更。
4. 明确源目标对象、冲突处理、目标凭证、回滚和审计方案，之后再设计受控的逐对象 copy-only 迁移，不删除源文件。
5. 实际复制后核验目标对象与内容一致，再安排数据库迁移和安全切流；未核验前绝不开放公共 Bucket。

现有 cloudflare/migrate_gcs_to_r2.sh 是 Bucket 级复制工具，不适合直接用于私密对象隔离。
建议将导出的 CSV 和 JSON 放在仓库外的受控目录中。
