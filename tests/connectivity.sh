#!/usr/bin/env bash
# Usage : ./tests/connectivity.sh test|prod
set -u
MODE="${1:-test}"
FAIL=0
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5"

ok() { echo "[OK] $1"; }
ko() { echo "[ECHEC] $1"; FAIL=1; }

if [ "$MODE" = "test" ]; then
    WEB="http://127.0.0.1:8081"; DNS_HOST="127.0.0.1"; DNS_PORT="5353"
else
    WEB="http://172.20.1.10"; DNS_HOST="172.20.2.10"; DNS_PORT="53"
fi

# 1. Le site web repond (script Python)
if python3 scripts/healthcheck.py "$WEB/" > /dev/null; then
    ok "Web : $WEB repond"
else
    ko "Web : $WEB ne repond pas"
fi

# 2. Le DNS resout web.pme.local
if dig +short +time=2 +tries=1 @"$DNS_HOST" -p "$DNS_PORT" web.pme.local \
    | grep -q "172.20.1.10"; then
    ok "DNS : web.pme.local -> 172.20.1.10"
else
    ko "DNS : mauvaise reponse de $DNS_HOST:$DNS_PORT"
fi

if [ "$MODE" = "prod" ]; then
    # 3. nmap : le port 80 est ouvert sur le serveur web
    if nmap -Pn -p 80 172.20.1.10 | grep -qE "^80/tcp +open"; then
        ok "nmap : port 80 ouvert sur vm-srv"
    else
        ko "nmap : port 80 ferme sur vm-srv"
    fi
    # 4. Les regles nftables sont en place
    if $SSH devops@172.20.3.1 "sudo nft list ruleset" | grep -q "policy drop"; then
        ok "nftables : politique drop presente"
    else
        ko "nftables : regles absentes"
    fi
    # 5. Prometheus est en bonne sante
    if curl -sf http://172.20.3.20:9090/-/healthy > /dev/null; then
        ok "Prometheus : en bonne sante"
    else
        ko "Prometheus : ne repond pas"
    fi
fi
exit "$FAIL"
