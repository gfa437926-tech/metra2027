// daily_db.js - إدارة قاعدة البيانات (جدول واحد daily_reports)

const DB_CONFIG = {
  url: 'https://vktcvkwqszehgmhqjrkb.supabase.co',
  anon_key: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZrdGN2a3dxc3plaGdtaHFqcmtiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIxNzE3NTEsImV4cCI6MjA3Nzc0Nzc1MX0.KTX1c8BAJpy1Jp3-IDXFRqb4Jo7SLabiwICBtn_mR5o',
};

let supabaseClient = null;

function initializeSupabase() {
  try {
    if (supabaseClient && typeof supabaseClient.from === 'function') return supabaseClient;
    if (typeof window.supabase === 'undefined') throw new Error('مكتبة Supabase غير محملة');
    supabaseClient = window.supabase.createClient(DB_CONFIG.url, DB_CONFIG.anon_key);
    console.log('✅ تم تهيئة supabase بنجاح');
    return supabaseClient;
  } catch (error) {
    console.error('❌ فشل في تهيئة supabase:', error);
    if (typeof showNotification === 'function') showNotification('❌ فشل في الاتصال بقاعدة البيانات', 'error');
    return null;
  }
}

function getSupabaseClient() {
  if (!supabaseClient) supabaseClient = initializeSupabase();
  return supabaseClient;
}

// إرسال التقرير اليومي إلى جدول daily_reports فقط
async function sendDailyReportToDB() {
  try {
    const supabase = getSupabaseClient();
    if (!supabase) throw new Error('الاتصال بقاعدة البيانات غير متوفر');

    if (typeof validateForm === 'function' && !validateForm()) {
      showNotification('يرجى تصحيح الأخطاء في النموذج قبل الإرسال', 'error');
      return { success: false, message: 'النموذج غير صالح' };
    }

    const userData = JSON.parse(localStorage.getItem('currentUser') || '{}');
    if (!userData.id) {
      showNotification('يجب تسجيل الدخول أولاً', 'error');
      return { success: false, message: 'غير مصرح به' };
    }

    const formData = collectFormDataForDB();
    if (!formData.station || !formData.observer_name) throw new Error('بيانات المحطة أو الراصد غير مكتملة');

    showLoading('جاري إرسال التقرير إلى قاعدة البيانات...');

    // ✅ إرسال إلى جدول daily_reports فقط
    const { data, error } = await supabase.from('daily_reports').insert([formData]).select();

    if (error) throw error;

    const reportTypeNames = { '24h': 'التقرير اليومي ', '06utc': 'تقرير 06 توقيت عالمي', '18utc': 'تقرير 18 توقيت عالمي' };
    showNotification(`✅ تم إرسال ${reportTypeNames[formData.report_type] || 'التقرير'} بنجاح`, 'success');
    resetFormAfterSubmission();
    logSubmissionStats(formData.report_type);
    return { success: true, data };
  } catch (error) {
    console.error('❌ خطأ في إرسال البيانات:', error);
    showNotification(`❌ فشل الإرسال: ${error.message}`, 'error');
    return { success: false, message: error.message };
  } finally {
    hideLoading();
  }
}

// جمع البيانات للإرسال (نفس الكود السليم)
function collectFormDataForDB() {
  const userData = JSON.parse(localStorage.getItem('currentUser') || '{}');
  const reportType = document.querySelector('input[name="reportType"]:checked');
  let reportPeriod = '';
  if (reportType) {
    switch (reportType.value) {
      case '24h': reportPeriod = '24 ساعة توقيت (00:00-24:00)'; break;
      case '06utc': reportPeriod = '24 ساعة تنتهي عند 06:00 توقيت عالمي'; break;
      case '18utc': reportPeriod = '24 ساعة تنتهي عند 18:00 توقيت عالمي'; break;
    }
  }

  const currentDateField = document.getElementById('currentDate');
  let reportDate = currentDateField?.value || new Date().toISOString().split('T')[0];
  let displayDate = '';
  const parts = reportDate.split('-');
  if (parts.length === 3) displayDate = `${parts[2]}/${parts[1]}/${parts[0]}`;
  else displayDate = reportDate;

  const is24hReport = reportType?.value === '24h';
  const formData = {
    user_id: userData.id || null,
    station: userData.station || document.getElementById('userStation')?.textContent || '',
    observer_name: document.getElementById('userName')?.textContent || '',
    observer_role: document.getElementById('userRole')?.textContent || '',
    report_date: reportDate,
    display_date: displayDate,
    collection_date: reportDate,
    submission_date: new Date().toISOString(),
    report_type: reportType?.value || '',
    report_period: reportPeriod,
    min_temperature: formatTemperatureForDB(document.getElementById('minTemp')?.value),
    max_temperature: formatTemperatureForDB(document.getElementById('maxTemp')?.value),
    precipitation: is24hReport ? formatValueForDB(document.getElementById('precipitation')?.value, 'precipitation') : null,
    snow_thickness: is24hReport ? formatValueForDB(document.getElementById('snowThickness')?.value, 'snow') : null,
    precipitation_trace: is24hReport ? formatPrecipitationTraceForDB(document.getElementById('precipitationTrace')?.value) : null,
    observer_notes: document.getElementById('observerNotes')?.value || null,
    responsibility_agreed: document.getElementById('responsibilityAgreement')?.checked || false,
    user_agent: navigator.userAgent,
    submission_method: 'web_form',
    status: 'submitted'
  };

  // إضافة الظواهر الجوية فقط لتقرير 24 ساعة
  if (is24hReport) {
    const weather = {
      thunderstorm: document.getElementById('thunderstorm')?.checked || false,
      hail: document.getElementById('hail')?.checked || false,
      snow_phenomena: document.getElementById('snow')?.checked || false,
      rain: document.getElementById('rain')?.checked || false,
      frost: document.getElementById('frost')?.checked || false,
      fog: document.getElementById('fog')?.checked || false,
      mist: document.getElementById('mist')?.checked || false,
      dust_storm: document.getElementById('dustStorm')?.checked || false,
      blowing_dust: document.getElementById('blowingDust')?.checked || false,
      haze: document.getElementById('haze')?.checked || false,
      stormy_wind: document.getElementById('stormyWind')?.checked || false,
    };
    Object.assign(formData, weather);
    formData.evaporation = formatValueForDB(document.getElementById('evaporation')?.value, 'evaporation');
    formData.sunshine_duration = formatValueForDB(document.getElementById('sunshineDuration')?.value, 'sunshine');
    formData.sunshine_percentage = formatValueForDB(document.getElementById('sunshinePercentage')?.value, 'percentage3');
    formData.max_gust_speed = formatValueForDB(document.getElementById('maxGustSpeed')?.value, 'wind');
    formData.max_gust_direction = formatValueForDB(document.getElementById('maxGustDirection')?.value, 'wind');
    formData.max_gust_time = formatValueForDB(document.getElementById('maxGustTime')?.value, 'time');
    formData.max_humidity = formatValueForDB(document.getElementById('maxHumidity')?.value, 'humidity_max');
    formData.max_humidity_time = formatValueForDB(document.getElementById('maxHumidityTime')?.value, 'time');
    formData.min_humidity = formatValueForDB(document.getElementById('minHumidity')?.value, 'humidity_min');
    formData.min_humidity_time = formatValueForDB(document.getElementById('minHumidityTime')?.value, 'time');
  } else {
    // لتقرير 06/18: نُرسل null لكل الحقول الإضافية
    const optionalFields = [
      'thunderstorm','hail','snow_phenomena','rain','frost','fog','mist','dust_storm','blowing_dust','haze','stormy_wind',
      'evaporation','sunshine_duration','sunshine_percentage','max_gust_speed','max_gust_direction','max_gust_time',
      'max_humidity','max_humidity_time','min_humidity','min_humidity_time'
    ];
    optionalFields.forEach(f => formData[f] = null);
  }

  // تنظيف القيم الفارغة
  Object.keys(formData).forEach(k => { if (formData[k] === '' || formData[k] === undefined) formData[k] = null; });
  return formData;
}

// دوال التنسيق (كما هي)
function formatTemperatureForDB(val) { if (!val || val === '#') return null; const n = parseFloat(val.trim()); if (isNaN(n) || n < -50 || n > 50) return null; return n; }
function formatValueForDB(val, type) { if (!val || val === '#') return null; val = val.trim(); if (type === 'precipitation') return parseFloat(val.replace(/[^\d.]/g,'').padStart(3,'0') || '0'); if (type === 'snow') return parseInt(val) || null; if (type === 'evaporation') return parseFloat(val) || null; if (type === 'sunshine') return parseFloat(val) || null; if (type === 'percentage3') return Math.min(100, Math.max(0, parseInt(val) || 0)); if (type === 'time') return parseFloat(val) || null; if (type === 'wind') return parseInt(val) || null; if (type === 'humidity_max') return Math.min(100, Math.max(0, parseInt(val) || 0)); if (type === 'humidity_min') return Math.min(99, Math.max(0, parseInt(val) || 0)); return val; }
function formatPrecipitationTraceForDB(val) { if (!val || val === '#') return null; return val.trim().toUpperCase() === 'T' ? 'T' : null; }

function resetFormAfterSubmission() {
  const fields = ['minTemp','maxTemp','precipitation','snowThickness','precipitationTrace','evaporation','sunshineDuration','sunshinePercentage','maxGustSpeed','maxGustDirection','maxGustTime','maxHumidity','maxHumidityTime','minHumidity','minHumidityTime','observerNotes'];
  fields.forEach(id => {
    const el = document.getElementById(id);
    if (el) {
      el.value = '';
      el.classList.remove('is-valid','is-invalid');
      el.disabled = false;
      const btn = document.querySelector(`.btn-no-data[data-target="${id}"]`);
      if (btn) {
        btn.classList.remove('btn-success');
        btn.classList.add('btn-outline-info');
        btn.innerHTML = '<i class="fas fa-hashtag"></i> لا تتوفر معلومات';
      }
    }
  });
  document.querySelectorAll('input[name="weatherPhenomena"]').forEach(cb => cb.checked = false);
  const agree = document.getElementById('responsibilityAgreement');
  if (agree) agree.checked = false;
  const now = new Date();
  const dateField = document.getElementById('currentDate');
  if (dateField) dateField.value = now.toISOString().split('T')[0];
  console.log('🔄 تم إعادة تعيين النموذج');
}

function showLoading(m) {
  let ov = document.getElementById('loadingOverlay');
  if (!ov) {
    ov = document.createElement('div');
    ov.id = 'loadingOverlay';
    ov.style.cssText = 'position:fixed;top:0;left:0;width:100%;height:100%;background:rgba(0,0,0,0.85);display:flex;flex-direction:column;align-items:center;justify-content:center;z-index:9999;color:white;';
    ov.innerHTML = '<div class="spinner-border" style="width:4rem;height:4rem;color:#3498db;"></div><div id="loadingText" style="margin-top:20px;font-size:1.3rem;"></div>';
    document.body.appendChild(ov);
  }
  const txt = document.getElementById('loadingText');
  if (txt) txt.textContent = m;
  ov.style.display = 'flex';
}

function hideLoading() {
  const ov = document.getElementById('loadingOverlay');
  if (ov) ov.style.display = 'none';
}

function showNotification(msg, type) {
  const c = document.getElementById('notificationContainer');
  if (!c) { console.log(msg); return; }
  const cls = type === 'success' ? 'alert-success' : type === 'error' ? 'alert-danger' : 'alert-info';
  const icon = type === 'success' ? '✅' : type === 'error' ? '❌' : 'ℹ️';
  const n = document.createElement('div');
  n.className = `alert ${cls} alert-dismissible fade show`;
  n.style.cssText = 'position:fixed;top:20px;right:20px;z-index:9999;min-width:300px;max-width:400px;box-shadow:0 4px 12px rgba(0,0,0,0.15);';
  n.innerHTML = `<div class="d-flex"><div style="font-size:1.5rem;margin-left:10px;">${icon}</div><div>${msg}</div></div><button type="button" class="btn-close" data-bs-dismiss="alert"></button>`;
  c.appendChild(n);
  setTimeout(() => n.remove(), 5000);
}

function logSubmissionStats(t) {
  try {
    const s = JSON.parse(localStorage.getItem('dailySubmissionStats') || '{}');
    s.total = (s.total || 0) + 1;
    s.byType = s.byType || {};
    s.byType[t] = (s.byType[t] || 0) + 1;
    s.last = new Date().toISOString();
    localStorage.setItem('dailySubmissionStats', JSON.stringify(s));
    console.log('📈 تم تحديث إحصائيات الإرسال');
  } catch(e) {}
}

// تهيئة زر الإرسال
function initReportSubmission() {
  const btn = document.getElementById('submitBtn');
  if (btn) {
    btn.addEventListener('click', async (e) => {
      e.preventDefault();
      if (typeof validateForm === 'function' && !validateForm()) {
        showNotification('يرجى تصحيح الأخطاء في النموذج قبل الإرسال', 'error');
        return;
      }
      if (!localStorage.getItem('currentUser')?.includes('id')) {
        showNotification('يجب تسجيل الدخول أولاً', 'error');
        return;
      }
      await sendDailyReportToDB();
    });
    console.log('✅ تم تهيئة زر الإرسال');
  }
}

document.addEventListener('DOMContentLoaded', () => {
  console.log('🚀 تهيئة نظام النشرات اليومية');
  initReportSubmission();
  setTimeout(() => { const sup = getSupabaseClient(); if (sup) console.log('✅ supabase جاهز'); }, 1000);
});

window.sendDailyReportToDB = sendDailyReportToDB;
window.getSupabaseClient = getSupabaseClient;
window.showNotification = showNotification;
window.showLoading = showLoading;
window.hideLoading = hideLoading;