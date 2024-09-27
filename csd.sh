#!/bin/bash

set -e  # エラーが発生した時点でスクリプトを終了

# 第一引数のチェック
if [ -z "$1" ]; then
  echo "使用法: $0 <フォルダ> [gitignoreファイル]"
  exit 1
fi

TARGET_DIR="$1"

# 指定したフォルダが存在するか確認
if [ ! -d "$TARGET_DIR" ]; then
  echo "エラー: ディレクトリ '$TARGET_DIR' が存在しません。"
  exit 1
fi

# 絶対パスに変換
TARGET_DIR=$(realpath "$TARGET_DIR")

# 出力ファイルのパス
OUTPUT_FILE="$TARGET_DIR/csd.txt"

# 出力ファイルを作成（既に存在する場合は上書き）
if ! touch "$OUTPUT_FILE" 2>/dev/null; then
  echo "エラー: 出力ファイル '$OUTPUT_FILE' を作成できません。権限を確認してください。"
  exit 1
fi

# 対象ディレクトリへ移動
cd "$TARGET_DIR" || { echo "エラー: ディレクトリ '$TARGET_DIR' に移動できません。"; exit 1; }

# Gitリポジトリかどうかを確認
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "エラー: 指定したディレクトリはGitリポジトリではありません。"
  exit 1
fi

# 無視されていないすべてのファイルを取得し、バイナリファイルを除外
FILE_LIST=$(git ls-files --others --exclude-standard --cached | grep -vE '\.(png|jpg|jpeg|gif|bmp|tiff|ico|svg|psd|mp3|wav|flac|ogg|mp4|avi|mov|mkv|webm|zip|tar|gz|bz2|rar|7z|pdf|doc|docx|xls|xlsx|ppt|pptx|exe|dll|so|bin|o|vrm|ttf|otf|woff|woff2|eot|suo|pdb|class|jar|war|ear)$')

# ツリー構造を再現する関数
generate_tree() {
  local path="$1"
  local indent="$2"
  local last="$3"

  # 現在のディレクトリ内のエントリを取得
  local entries=()
  while IFS= read -r line; do
    entries+=("$line")
  done < <(echo "$FILE_LIST" | grep "^$path" | sed "s|^$path||" | cut -d'/' -f1 | sort | uniq)

  local count=${#entries[@]}
  local i=0
  for entry in "${entries[@]}"; do
    ((i++))
    local connector="├──"
    local new_indent="$indent│   "
    if [ "$i" -eq "$count" ]; then
      connector="└──"
      new_indent="$indent    "
    fi
    echo "${indent}${connector} $entry" >> "$OUTPUT_FILE"

    if [ -d "${path}${entry}" ]; then
      generate_tree "${path}${entry}/" "$new_indent" "$([ "$i" -eq "$count" ] && echo "true" || echo "false")"
    fi
  done
}

# 全ての出力を一時ファイルに書き込む
TMP_FILE=$(mktemp)

{
  echo "ツリー構造:"
  generate_tree "" "" "false"
  echo ""
  echo "ファイル名と内容:"
  while IFS= read -r file; do
    # ファイル名から先頭の './' を削除
    file="${file#./}"
    # バイナリファイルを除外（念のため再度チェック）
    if [[ ! "$file" =~ \.(png|jpg|jpeg|gif|bmp|tiff|ico|svg|psd|mp3|wav|flac|ogg|mp4|avi|mov|mkv|webm|zip|tar|gz|bz2|rar|7z|pdf|doc|docx|xls|xlsx|ppt|pptx|exe|dll|so|bin|o|vrm|ttf|otf|woff|woff2|eot|suo|pdb|class|jar|war|ear)$ ]]; then
      echo "ファイル: $file"
      echo '```'
      cat "$file"
      echo '```'
      echo ""
    fi
  done <<< "$FILE_LIST"
} > "$TMP_FILE"

# 一時ファイルの内容を出力ファイルに移動
mv "$TMP_FILE" "$OUTPUT_FILE"

echo "処理が完了しました。出力ファイル: $OUTPUT_FILE"
