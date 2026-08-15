#!/bin/bash
set -e

# マスターエージェント（snmpd）をバックグラウンドで起動
/usr/sbin/snmpd -f -LS0-6d &

# snmpd がリッスンするまで待機（最大 10 秒）
for i in {1..10}; do
    if netstat -ulnp 2>/dev/null | grep -q ':161 ' || \
       ss -ulnp 2>/dev/null | grep -q ':161 '; then
        echo "snmpd is listening on port 161"
        break
    fi
    echo "Waiting for snmpd to start... ($i/10)"
    sleep 1
done

# AgentX サブエージェントをフォアグラウンドで起動
/opt/subagent-example/example-demon -f -LS0-6d &

# 両方のプロセスを待ち続ける（Docker コンテナが終了しないように）
wait
