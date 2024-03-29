#!/bin/bash

# 使用可能なメモリを取得 (単位: MB)
available_memory=$(free -m | awk '/^Mem:/{print $7}')

# 使用可能なメモリが特定の閾値以下の場合にアクションを実行
threshold=1000 # この値は例です。必要に応じて調整してください。

if [ "$available_memory" -lt "$threshold" ]; then
    echo "使用可能なメモリが${threshold}MB以下です。現在の使用可能メモリ: ${available_memory}MB"
    # 必要なアクションをここに記述
else
    echo "メモリ状態正常。現在の使用可能メモリ: ${available_memory}MB"
fi
