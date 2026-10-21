"""Run after cloud deployment: API_BASE_URL=https://YOUR-RENDER-SERVICE.onrender.com python scripts/cloud_smoke.py
Creates throwaway accounts and tests multi-user isolation. Never uses localhost.
"""
import json
import os
import sys
import uuid
from datetime import date
from urllib.error import HTTPError
from urllib.request import Request, urlopen

BASE = os.environ.get('API_BASE_URL', '').rstrip('/')
if not BASE.startswith('https://'):
    raise SystemExit('Set API_BASE_URL to the HTTPS address of the deployed Render service')


def call(path, method='GET', payload=None, jwt=None):
    headers = {'Accept': 'application/json'}
    if payload is not None:
        headers['Content-Type'] = 'application/json'
    if jwt:
        headers['Authorization'] = f'Bearer {jwt}'
    request = Request(BASE + path, data=json.dumps(payload).encode() if payload is not None else None,
                      headers=headers, method=method)
    try:
        with urlopen(request, timeout=80) as response:
            raw = response.read()
            return response.status, json.loads(raw) if raw else None
    except HTTPError as e:
        raw = e.read()
        return e.code, json.loads(raw) if raw else None


def require(actual, expected, msg):
    if actual != expected:
        raise AssertionError(f'{msg}: expected {expected}, got {actual}')


if __name__ == '__main__':
    status, health = call('/actuator/health')
    require(status, 200, 'health HTTP')
    require(health.get('status'), 'UP', 'health status')
    token_test = uuid.uuid4().hex[:12]
    accounts = []
    for num in (1, 2):
        email = f'cloud-test-{token_test}-{num}@example.invalid'
        status, auth = call('/api/v1/auth/register', 'POST', {
            'displayName': f'Tester {num}', 'email': email, 'password': 'CloudSmokeTest_2026!'
        })
        require(status, 200, 'register')
        accounts.append(auth['token'])
    a, b = accounts
    status, wallets = call('/api/v1/wallets', jwt=a)
    require(status, 200, 'wallets')
    assert len(wallets) >= 1
    wallet = wallets[0]['id']
    status, entry = call('/api/v1/transactions', 'POST', {
        'walletId': wallet, 'type': 'EXPENSE', 'category': 'Ăn uống',
        'amount': 125000, 'note': 'Cloud smoke test', 'occurredOn': str(date.today()),
    }, jwt=a)
    require(status, 201, 'add transaction')
    month = date.today().strftime('%Y-%m')
    status, summary = call(f'/api/v1/reports/summary?month={month}', jwt=a)
    require(status, 200, 'summary')
    require(summary['expense'], 125000, 'expense sum')
    status, missing = call(f"/api/v1/transactions/{entry['id']}", 'PUT', {
        'walletId': wallet, 'type': 'EXPENSE', 'category': 'Ăn uống',
        'amount': 1, 'occurredOn': str(date.today()),
    }, jwt=b)
    require(status, 404, 'cross-user access must be hidden')
    status, budget = call('/api/v1/budgets', 'POST', {'category': 'Ăn uống', 'month': month, 'amount': 200000}, jwt=a)
    require(status, 200, 'upsert budget')
    require(budget['usedPercent'], 62, 'budget usage')
    status, deleted = call(f"/api/v1/transactions/{entry['id']}", 'DELETE', jwt=a)
    require(status, 204, 'delete transaction')
    print('PASS: HTTPS health, registration, wallet, transaction, report, budgets, authorization isolation, deletion')
    print('NOTE: Two test accounts remain in the Neon database.')
