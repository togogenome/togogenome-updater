# togogenome-updater
## TogoGenomeデータ更新用スクリプト

## 動作条件

## 実行手順
### 1. コンテナ作成
```
docker-compose build updater
docker-compose run --rm updater /bin/bash
docker-compose down
```

rubyのgemを更新
Dockerfileを変更
```
#RUN bundle config --global frozen 1

WORKDIR /updater

#COPY Gemfile Gemfile.lock ./
COPY Gemfile ./
```
Gemfile.lockを削除して空ファイル作成
```
touch Gemfile.lock
```
```
docker-compose build --no-cache
```
