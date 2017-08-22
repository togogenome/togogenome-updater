# togogenome-updater
## TogoGenomeデータ更新用スクリプト

## 動作条件

## 実行手順
### 1. 外部スクリプトの取り込み
> linksetsのリポジトリをclone(リポジトリは非公開)
````
$ cd bin
$ git clone git@github.com:XXXXX/linksets.git
$ cd linksets
$ git checkout -b output_dir_specification origin/output_dir_specification
````
> rdfsummitのリポジトリをclone
````
$ cd bin
$ git clone git@github.com:ddbj/rdfsummit.git
$ cd rdfsummit
$ git checkout -b togo_assembly_reports2ttl origin/togo_assembly_reports2ttl 
````
### 2. スクリプトの設置
