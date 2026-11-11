const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const read = (relative) => fs.readFileSync(path.join(__dirname, '..', 'src', 'app', relative), 'utf8');

test('Angular operational routes require an active METRA account', () => {
  const routes = read('app.routes.ts');
  const guard = read('core/supabase/auth.guard.ts');
  assert.match(routes, /requireActiveMetraAccount/);
  assert.match(routes, /path: 'account'.*requireAuthenticatedUser/);
  assert.match(guard, /status\.account_state === 'active'/);
  assert.match(guard, /accountState: 'unavailable'/);
});

test('Angular password recovery has request and completion routes', () => {
  const auth = read('core/supabase/supabase-auth.service.ts');
  const routes = read('app.routes.ts');
  const request = read('features/auth/forgot-password.component.ts');
  const reset = read('features/auth/reset-password.component.ts');
  assert.match(auth, /resetPasswordForEmail/);
  assert.match(auth, /updateUser\(\{ password \}\)/);
  assert.match(routes, /path: 'forgot-password'/);
  assert.match(routes, /path: 'auth\/reset-password'/);
  assert.match(request, /auth\/reset-password/);
  assert.match(reset, /getAccessToken/);
});

test('specialist workspaces do not claim live AI, Climatol or AFTN results', () => {
  const ai = read('features/ai/ai-workspace.component.ts');
  const climatol = read('features/climatol/climatol-workspace.component.ts');
  const aftn = read('features/aftn/aftn-console.component.ts');
  assert.match(ai, /AI Gateway/);
  assert.match(ai, /لن تُعرض نتائج مصطنعة/);
  assert.match(climatol, /getAllStations/);
  assert.match(climatol, /Climatol worker/);
  assert.match(aftn, /معاينة محلية/);
  assert.match(aftn, /إرسال الرسالة — بانتظار القناة الخادمية/);
});

test('electronic auditor keeps evidence selection local until storage API exists', () => {
  const auditor = read('features/electronic-auditor/electronic-auditor-workspace.component.ts');
  assert.match(auditor, /selectPaperFile/);
  assert.match(auditor, /selectMechanicalFile/);
  assert.match(auditor, /لم يُرفع/);
  assert.match(auditor, /بصمة الأصل/);
});

test('account profile reads server registration status and does not infer grants', () => {
  const profile = read('features/account/account-profile.component.ts');
  assert.match(profile, /getMyStatus/);
  assert.match(profile, /لا يعيد API الحالي قائمة المحطات المسندة/);
});
