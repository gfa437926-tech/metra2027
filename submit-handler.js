// submit-handler.js - معالج إرسال التقارير المناخية (محدث - دعم كامل لـ # و UTC)
console.log('📤 تحميل معالج إرسال التقارير المناخية (UTC فقط)...');

// دالة إنشاء عميل Supabase
function getSupabaseClient() {
    if (typeof supabase === 'undefined') {
        console.error('❌ مكتبة Supabase غير محملة');
        return null;
    }
    const SUPABASE_URL = "https://vktcvkwqszehgmhqjrkb.supabase.co";
    const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZrdGN2a3dxc3plaGdtaHFqcmtiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIxNzE3NTEsImV4cCI6MjA3Nzc0Nzc1MX0.KTX1c8BAJpy1Jp3-IDXFRqb4Jo7SLabiwICBtn_mR5o";
    return supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
}

// التحقق من صحة النموذج
function validateForm() {
    console.log('🔍 التحقق من صحة النموذج (UTC فقط)...');
    let isValid = true;
    const errorMessages = [];

    // الحقول الأساسية المطلوبة (كلها مسموح فيها #)
    const requiredFields = [
        'utcTime', 'dryTemp', 'wetTemp', 'relativeHumidity',
        'vaporPressure', 'dewPoint', 'windDirection', 'windSpeed',
        'avgWindDirection', 'avgWindSpeed', 'totalCloudCover'
    ];

    for (let fieldId of requiredFields) {
        const field = document.getElementById(fieldId);
        const value = field?.value?.trim();
        if (!value) {
            isValid = false;
            errorMessages.push(`الحقل ${getFieldName(fieldId)} مطلوب`);
        }
    }

    // التحقق من العلاقة بين درجتي الحرارة (إذا كانت كلتاهما أرقاماً)
    const dryVal = document.getElementById('dryTemp')?.value;
    const wetVal = document.getElementById('wetTemp')?.value;
    if (dryVal !== '#' && wetVal !== '#' && dryVal && wetVal) {
        const dryNum = parseFloat(dryVal);
        const wetNum = parseFloat(wetVal);
        if (!isNaN(dryNum) && !isNaN(wetNum) && dryNum < wetNum) {
            isValid = false;
            errorMessages.push('درجة الحرارة الجافة يجب أن تكون ≥ درجة الحرارة الرطبة');
        }
    }

    // التحقق من نطاق التغطية السحابية (0-9) إذا لم تكن #
    const cloudField = document.getElementById('totalCloudCover');
    if (cloudField && cloudField.value !== '#') {
        const cloudVal = parseInt(cloudField.value);
        if (isNaN(cloudVal) || cloudVal < 0 || cloudVal > 9) {
            isValid = false;
            errorMessages.push('التغطية السحابية يجب أن تكون رقماً بين 0 و 9 (أو #)');
        }
    }

    // التحقق من الموافقة على المسؤولية
    const responsibility = document.getElementById('responsibilityAgreement');
    if (!responsibility?.checked) {
        isValid = false;
        errorMessages.push('يجب الموافقة على إقرار المسؤولية');
    }

    if (!isValid) {
        console.error('❌ أخطاء التحقق:', errorMessages);
        showAlert(`❌ ${errorMessages.join('، ')}`, 'error');
    } else {
        console.log('✅ النموذج صالح للإرسال');
    }
    return { isValid, errorMessages };
}

// الحصول على اسم الحقل بالعربية
function getFieldName(fieldId) {
    const names = {
        'utcTime': 'التوقيت العالمي (UTC)',
        'dryTemp': 'الحرارة الجافة',
        'wetTemp': 'الحرارة الرطبة',
        'relativeHumidity': 'الرطوبة النسبية',
        'vaporPressure': 'ضغط البخار',
        'dewPoint': 'درجة الندى',
        'windDirection': 'اتجاه الرياح',
        'windSpeed': 'سرعة الرياح',
        'avgWindDirection': 'متوسط الاتجاه',
        'avgWindSpeed': 'متوسط السرعة',
        'totalCloudCover': 'التغطية السحابية'
    };
    return names[fieldId] || fieldId;
}

// تحويل قيمة الحقل (# → null، وإلا رقم)
function sanitizeNumber(value) {
    if (!value || value === '#') return null;
    const num = parseFloat(value);
    return isNaN(num) ? null : num;
}

function sanitizeInteger(value) {
    if (!value || value === '#') return null;
    const num = parseInt(value);
    return isNaN(num) ? null : num;
}

// إعداد بيانات التقرير للإرسال - متوافقة مع جدول climate_reports
function prepareReportData() {
    console.log('📦 تجهيز بيانات التقرير...');
    const userData = JSON.parse(localStorage.getItem('currentUser') || '{}');
    const now = new Date();
    const reportDate = now.toISOString().split('T')[0];

    // الحصول على قيم الحقول
    const getField = (id) => document.getElementById(id)?.value?.trim() || '';

    const data = {
        // معلومات المستخدم
        user_id: userData.id?.toString() || null,
        user_name: `${userData.first_name || ''} ${userData.father_name || ''} ${userData.last_name || ''}`.trim(),
        user_station: userData.station || '',
        user_role: userData.role || '',
        user_email: userData.email || '',
        station: userData.station || '',
        observer_name: `${userData.first_name || ''} ${userData.father_name || ''} ${userData.last_name || ''}`.trim(),
        observer_role: userData.role || '',

        // التاريخ والوقت (UTC)
        report_date: reportDate,
        utc_time: getField('utcTime'),

        // البيانات المناخية (معالجة # → null)
        dry_temperature: sanitizeNumber(getField('dryTemp')),
        wet_temperature: sanitizeNumber(getField('wetTemp')),
        relative_humidity: sanitizeInteger(getField('relativeHumidity')),
        vapor_pressure: sanitizeNumber(getField('vaporPressure')),
        dew_point: sanitizeNumber(getField('dewPoint')),
        wind_direction: sanitizeInteger(getField('windDirection')),
        wind_speed: sanitizeInteger(getField('windSpeed')),
        avg_wind_direction: sanitizeInteger(getField('avgWindDirection')),
        avg_wind_speed: sanitizeInteger(getField('avgWindSpeed')),
        total_cloud_cover: sanitizeInteger(getField('totalCloudCover')),

        observer_notes: getField('observerNotes'),

        // حالات التقرير
        status: 'submitted',
        is_draft: false,
        whatsapp_shared: document.getElementById('enableWhatsAppShare')?.checked || false,
        responsibility_confirmed: document.getElementById('responsibilityAgreement')?.checked || false,
        data_validated: true,

        // الطوابع الزمنية
        created_at: now.toISOString(),
        updated_at: now.toISOString(),
        submitted_at: now.toISOString(),

        // معلومات الإرسال
        submission_method: 'web_form',
        user_agent: navigator.userAgent,
        browser_language: navigator.language,
        validation_notes: 'تم التحقق آلياً (UTC فقط)',

        // يمكن إضافة إحداثيات المحطة لاحقاً إذا وُجدت في userData
        station_latitude: userData.latitude ? parseFloat(userData.latitude) : null,
        station_longitude: userData.longitude ? parseFloat(userData.longitude) : null,
        station_altitude: userData.altitude ? parseFloat(userData.altitude) : null
    };

    // تنظيف الحقول الفارغة
    Object.keys(data).forEach(key => {
        if (data[key] === undefined) delete data[key];
    });

    console.log('📊 البيانات النهائية:', data);
    return data;
}

// إرسال التقرير إلى Supabase
async function submitReport() {
    console.log('🚀 بدء عملية الإرسال...');
    try {
        const validation = validateForm();
        if (!validation.isValid) return false;

        const reportData = prepareReportData();
        const supabase = getSupabaseClient();
        if (!supabase) throw new Error('فشل الاتصال بقاعدة البيانات');

        setLoading(true);
        const { data, error } = await supabase
            .from('climate_reports')
            .insert([reportData])
            .select();

        setLoading(false);

        if (error) {
            console.error('❌ خطأ Supabase:', error);
            showAlert(`❌ فشل الإرسال: ${error.message}`, 'error');
            return false;
        }

        console.log('✅ تم الإرسال بنجاح:', data);
        showAlert('✅ تم إرسال التقرير المناخي بنجاح (UTC فقط)', 'success');

        // تحديث الإحصائيات
        if (typeof loadStationStatistics === 'function') setTimeout(loadStationStatistics, 1000);

        // مشاركة واتساب إن أمكن
        if (document.getElementById('enableWhatsAppShare')?.checked && typeof shareOnWhatsApp === 'function') {
            setTimeout(() => shareOnWhatsApp(), 1500);
        }

        resetForm();
        return true;
    } catch (err) {
        console.error('❌ خطأ غير متوقع:', err);
        setLoading(false);
        showAlert(`❌ حدث خطأ: ${err.message}`, 'error');
        return false;
    }
}

// إعادة تعيين النموذج بعد الإرسال
function resetForm() {
    console.log('🔄 إعادة تعيين النموذج...');
    const fields = ['dryTemp', 'wetTemp', 'relativeHumidity', 'vaporPressure', 'dewPoint',
                    'windDirection', 'windSpeed', 'avgWindDirection', 'avgWindSpeed',
                    'totalCloudCover', 'observerNotes'];
    fields.forEach(id => {
        const el = document.getElementById(id);
        if (el) el.value = '';
    });
    // إعادة تعيين UTC إلى الساعة الحالية
    const utcSelect = document.getElementById('utcTime');
    if (utcSelect) {
        const now = new Date();
        const hour = now.getUTCHours().toString().padStart(2, '0');
        utcSelect.value = `${hour}:00`;
    }
    // إلغاء تفعيل "غير متوفرة"
    document.querySelectorAll('.missing-toggle.active').forEach(btn => btn.classList.remove('active'));
    const resp = document.getElementById('responsibilityAgreement');
    if (resp) resp.checked = false;
    // إخفاء المعاينة
    const preview = document.getElementById('whatsappPreview');
    if (preview) preview.classList.remove('active');
    console.log('✅ تم مسح النموذج');
}

// تعبئة بيانات تجريبية (اختبار)
function fillTestData() {
    console.log('🧪 تعبئة بيانات تجريبية...');
    const now = new Date();
    const utcHour = now.getUTCHours().toString().padStart(2, '0');
    document.getElementById('utcTime').value = `${utcHour}:00`;
    document.getElementById('dryTemp').value = '25.5';
    document.getElementById('wetTemp').value = '20.3';
    document.getElementById('relativeHumidity').value = '075';
    document.getElementById('vaporPressure').value = '18.5';
    document.getElementById('dewPoint').value = '18.2';
    document.getElementById('windDirection').value = '15';
    document.getElementById('windSpeed').value = '12';
    document.getElementById('avgWindDirection').value = '16';
    document.getElementById('avgWindSpeed').value = '10';
    document.getElementById('totalCloudCover').value = '3';
    document.getElementById('observerNotes').value = 'بيانات تجريبية - UTC فقط';
    document.getElementById('responsibilityAgreement').checked = true;
    showAlert('✅ تم تعبئة بيانات تجريبية', 'success');
}

// تهيئة الأزرار
function setupSubmitButtons() {
    const submitBtn = document.getElementById('submitReportBtn');
    if (submitBtn) submitBtn.addEventListener('click', (e) => { e.preventDefault(); submitReport(); });
    const testBtn = document.getElementById('testDataBtn');
    if (testBtn) testBtn.addEventListener('click', fillTestData);
    const draftBtn = document.getElementById('saveDraftBtn');
    if (draftBtn) draftBtn.addEventListener('click', () => showAlert('حفظ المسودة متوفر قريباً', 'info'));
}

// اختبار الاتصال بقاعدة البيانات
async function testDatabaseConnection() {
    const supabase = getSupabaseClient();
    if (!supabase) return false;
    const { error } = await supabase.from('climate_reports').select('id').limit(1);
    if (error) console.error('❌ خطأ في الاتصال:', error);
    else console.log('✅ الاتصال بقاعدة البيانات ناجح');
    return !error;
}

// بدء التشغيل
function initSubmitHandler() {
    setupSubmitButtons();
    testDatabaseConnection().then(ok => {
        if (ok) showAlert('✅ الاتصال بقاعدة البيانات جاهز', 'success');
        else showAlert('⚠️ مشكلة في الاتصال بقاعدة البيانات', 'warning');
    });
}

// جعل الدوال عامة
window.submitReport = submitReport;
window.validateForm = validateForm;
window.fillTestData = fillTestData;
window.resetForm = resetForm;

if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', initSubmitHandler);
else initSubmitHandler();

console.log('📤 تم تحميل معالج الإرسال (النسخة المصححة)');