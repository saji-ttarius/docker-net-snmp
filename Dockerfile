# ============================================================
# ステージ 1: ビルド環境（サブエージェントのコンパイル用）
# ============================================================
FROM debian:trixie-slim AS builder

# ビルドに必要なパッケージをインストール
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libsnmp-dev \
    gcc \
    make \
    git \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Net-SNMP 公式のサブエージェント例をビルド
RUN git clone --depth 1 https://github.com/net-snmp/subagent-example.git /opt/subagent-example && \
    cd /opt/subagent-example && \
    make

# ============================================================
# ステージ 2: ランタイム環境（Net-SNMP マスターエージェント）
# ============================================================
FROM debian:trixie-slim

# ランタイムに必要なパッケージのみインストール
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    snmpd \
    snmp \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/* && \
    useradd -m -s /bin/false snmp

# サブエージェント用のディレクトリ作成
RUN mkdir -p /opt/subagent-example && \
    chown -R snmp:snmp /opt/subagent-example

# ビルドステージからサブエージェントバイナリをコピー
COPY --from=builder --chown=snmp:snmp /opt/subagent-example/example-demon /opt/subagent-example/example-demon

# ホストから snmpd.conf をコピー
COPY --chown=snmp:snmp config/snmpd.conf /etc/snmp/snmpd.conf

# ホストから start.sh をコピー
COPY --chown=snmp:snmp scripts/start.sh /start.sh

# SNMP ポート（161/udp）と AgentX TCP ポート（705/tcp）を公開
EXPOSE 161/udp 705/tcp

# 非 root ユーザーで実行
USER snmp

# デフォルトコマンド
CMD ["/start.sh"]
