// h_climate_send.js - نسخة نهائية مع تجاوز آمن للدوال المفقودة
console.log('🚀 تحميل نظام النشرات المناخية الساعية (UTC فقط)...');

// تعريف آمن للدوال التي قد تكون مفقودة
window.setupWhatsAppPreview = window.setupWhatsAppPreview || function() { console.log('⚠️ setupWhatsAppPreview غير معرفة (تم تجاوزها)'); };

let currentUser = null;

// ===================== المصادقة =====================
async function checkAuthentication() {
    try {
        const userData = localStorage.getItem("currentUser");
        if (!userData) {
            showAlert("❌ لم يتم تسجيل الدخول، جاري التوجيه...", "error");
            setTimeout(() => window.location.href = "../../../../index.html", 2000);
            return false;
        }
        currentUser = JSON.parse(userData);
        displayUserInfo();
        return true;
    } catch (error) {
        console.error("❌ خطأ في المصادقة:", error);
        localStorage.removeItem("currentUser");
        window.location.href = "../../../../index.html";
        return false;
    }
}

function displayUserInfo() {
    if (!currentUser) return;
    const userName = `${currentUser.first_name || ''} ${currentUser.father_name || ''} ${currentUser.last_name || ''}`.trim();
    document.getElementById("userName").textContent = userName || "مستخدم غير معروف";
    document.getElementById("userStation").textContent = currentUser.station || "غير محدد";
    document.getElementById("userRole").textContent = currentUser.role || "غير محدد";
}

// القائمة الجانبية (نفس الكود السابق - يمكنك الاحتفاظ به)
function loadSidebarMenu() { /* ... */ }
function setupMobileMenu() { /* ... */ }

// ===================== معالجات المدخلات =====================
function setupInputHandlers() {
    console.log("🔧 إعداد معالجات المدخلات الأساسية (UTC فقط)...");

    const utcSelect = document.getElementById("utcTime");
    if (utcSelect) {
        utcSelect.innerHTML = '<option value="" disabled>اختر الساعة (UTC)</option>';
        for (let i = 0; i < 24; i++) {
            const hour = i.toString().padStart(2, '0');
            utcSelect.appendChild(new Option(`${hour}:00 UTC`, `${hour}:00`));
        }
        utcSelect.appendChild(new Option("غير متوفر (#)", "#"));
        const now = new Date();
        const currentHour = now.getUTCHours().toString().padStart(2, '0');
        utcSelect.value = `${currentHour}:00`;
    }

    // أزرار الإشارة
    document.querySelectorAll('.sign-toggle').forEach(btn => {
        btn.addEventListener('click', function(e) {
            const targetId = this.dataset.target;
            const sign = this.dataset.sign;
            const input = document.getElementById(targetId);
            if (!input) return;
            let val = input.value;
            if (val === '#') val = '';
            if (sign === '-') {
                if (!val.startsWith('-')) input.value = '-' + val;
            } else if (sign === '+') {
                if (val.startsWith('-')) input.value = val.slice(1);
            }
            input.dispatchEvent(new Event('input'));
        });
    });

    // أزرار "غير متوفرة"
    document.querySelectorAll('.missing-toggle').forEach(btn => {
        btn.addEventListener('click', function() {
            const targetId = this.dataset.target;
            const input = document.getElementById(targetId);
            if (!input) return;
            const isActive = this.classList.contains('active');
            if (isActive) {
                this.classList.remove('active');
                input.value = '';
                input.placeholder = input.dataset.originalPlaceholder || '';
                input.parentElement.classList.remove('has-missing');
            } else {
                this.classList.add('active');
                if (!input.dataset.originalPlaceholder) input.dataset.originalPlaceholder = input.placeholder;
                input.value = '#';
                input.placeholder = 'غير متوفرة (#)';
                input.parentElement.classList.add('has-missing');
                const err = document.getElementById(targetId + 'Error');
                if (err) err.style.display = 'none';
            }
            input.dispatchEvent(new Event('input'));
        });
    });

    // التحقق من علاقة درجات الحرارة
    const dry = document.getElementById('dryTemp'), wet = document.getElementById('wetTemp');
    if (dry && wet) {
        const validateTempRel = () => {
            const dryVal = dry.value, wetVal = wet.value;
            const errDiv = document.getElementById('tempRelationError');
            if (!errDiv) return;
            if (dryVal === '#' || wetVal === '#' || !dryVal || !wetVal) {
                errDiv.style.display = 'none';
                return;
            }
            const dryNum = parseFloat(dryVal), wetNum = parseFloat(wetVal);
            if (!isNaN(dryNum) && !isNaN(wetNum) && dryNum < wetNum) {
                errDiv.style.display = 'block';
                errDiv.innerHTML = '<i class="fas fa-exclamation-triangle"></i> الحرارة الجافة يجب أن تكون ≥ الحرارة الرطبة';
            } else {
                errDiv.style.display = 'none';
            }
        };
        dry.addEventListener('input', validateTempRel);
        wet.addEventListener('input', validateTempRel);
    }

    // التنسيق التلقائي
    const decimalFields = ['dryTemp', 'wetTemp', 'vaporPressure', 'dewPoint'];
    decimalFields.forEach(id => {
        const el = document.getElementById(id);
        if (el) el.addEventListener('blur', () => autoFormatDecimalField(el));
    });
    const intFields = ['relativeHumidity', 'windDirection', 'windSpeed', 'avgWindDirection', 'avgWindSpeed', 'totalCloudCover'];
    intFields.forEach(id => {
        const el = document.getElementById(id);
        if (el) {
            const len = (id === 'relativeHumidity' ? 3 : (id === 'totalCloudCover' ? 1 : 2));
            el.addEventListener('blur', () => autoFormatIntegerField(el, len));
        }
    });
}

function autoFormatDecimalField(field) {
    let val = field.value.trim();
    if (!val || val === '#') return;
    let negative = val.startsWith('-');
    if (negative) val = val.slice(1);
    val = val.replace(/[^\d.]/g, '');
    let parts = val.split('.');
    if (parts.length > 2) val = parts[0] + '.' + parts.slice(1).join('');
    if (!val.includes('.')) val += '.0';
    parts = val.split('.');
    if (parts[1].length > 1) parts[1] = parts[1].charAt(0);
    let intPart = parts[0];
    if (intPart.length > 2) intPart = intPart.slice(0, 2);
    val = intPart + '.' + (parts[1] || '0');
    if (negative) val = '-' + val;
    field.value = val;
    validateTemperatureInput(field);
}

function autoFormatIntegerField(field, length) {
    let val = field.value.trim();
    if (!val || val === '#') return;
    val = val.replace(/\D/g, '');
    if (val.length > length) val = val.slice(0, length);
    while (val.length < length) val = '0' + val;
    field.value = val;
    validateField(field);
}

function validateTemperatureInput(input) {
    const val = input.value;
    const err = document.getElementById(input.id + 'Error');
    const fmt = document.getElementById(input.id + 'FormatMessage');
    if (!val) return false;
    if (val === '#') {
        if (err) err.style.display = 'none';
        if (fmt) fmt.textContent = '✅ غير متوفر (#)';
        input.parentElement.classList.add('has-success', 'has-missing');
        return true;
    }
    const pattern = /^-?\d{1,2}\.\d$/;
    if (!pattern.test(val)) {
        if (err) err.style.display = 'block';
        if (fmt) fmt.textContent = '❌ التنسيق المطلوب: ±dd.d (مثال: 25.5 أو -5.3)';
        input.parentElement.classList.add('has-error');
        return false;
    }
    const num = parseFloat(val);
    let min = -20, max = 60;
    if (input.id === 'vaporPressure') { min = -50; max = 50; }
    if (num < min || num > max) {
        if (err) err.style.display = 'block';
        if (fmt) fmt.textContent = `❌ القيمة خارج النطاق (${min} إلى ${max})`;
        input.parentElement.classList.add('has-error');
        return false;
    }
    if (err) err.style.display = 'none';
    if (fmt) fmt.textContent = '✅ صحيح';
    input.parentElement.classList.add('has-success');
    const parent = input.parentElement;
    const signSpan = parent.querySelector('.sign-indicator');
    if (signSpan) {
        if (num < 0) { signSpan.textContent = '-'; parent.classList.add('has-negative'); }
        else { signSpan.textContent = '+'; parent.classList.add('has-positive'); }
    }
    return true;
}

function validateField(input) {
    const val = input.value;
    const err = document.getElementById(input.id + 'Error');
    const fmt = document.getElementById(input.id + 'FormatMessage');
    if (!val) return false;
    if (val === '#') {
        if (err) err.style.display = 'none';
        if (fmt) fmt.textContent = '✅ غير متوفر (#)';
        input.parentElement.classList.add('has-success', 'has-missing');
        return true;
    }
    let ok = false, msg = '';
    switch (input.id) {
        case 'relativeHumidity':
            ok = /^\d{3}$/.test(val) && parseInt(val) >= 1 && parseInt(val) <= 100;
            msg = ok ? '✅ صحيح (001-100)' : '❌ يجب 3 أرقام بين 001 و 100';
            break;
        case 'windDirection': case 'avgWindDirection':
            ok = /^\d{2}$/.test(val) && parseInt(val) >= 0 && parseInt(val) <= 36;
            msg = ok ? '✅ صحيح (00-36)' : '❌ رقمين بين 00 و 36';
            break;
        case 'windSpeed': case 'avgWindSpeed':
            ok = /^\d{2}$/.test(val) && parseInt(val) >= 0 && parseInt(val) <= 99;
            msg = ok ? '✅ صحيح (00-99)' : '❌ رقمين بين 00 و 99';
            break;
        case 'totalCloudCover':
            ok = /^[0-9]$/.test(val) && parseInt(val) >= 0 && parseInt(val) <= 9;
            msg = ok ? '✅ صحيح (0-9)' : '❌ رقم واحد بين 0 و 9';
            break;
        default: ok = true;
    }
    if (ok) {
        if (err) err.style.display = 'none';
        input.parentElement.classList.add('has-success');
    } else {
        if (err) err.style.display = 'block';
        input.parentElement.classList.add('has-error');
    }
    if (fmt) { fmt.textContent = msg; fmt.style.display = 'block'; }
    return ok;
}

// ===================== الإشعارات =====================
function showAlert(message, type = "success") {
    const container = document.getElementById("notificationContainer");
    if (!container) return;
    const notif = document.createElement("div");
    notif.className = `notification ${type}`;
    notif.textContent = message;
    container.appendChild(notif);
    setTimeout(() => notif.remove(), 5000);
}
function setLoading(show) {
    const overlay = document.getElementById("loadingOverlay");
    if (overlay) overlay.style.display = show ? "flex" : "none";
}

// ===================== تهيئة الصفحة =====================
async function initializePage() {
    if (!await checkAuthentication()) return;
    loadSidebarMenu();
    setupMobileMenu();
    setupInputHandlers();
    // استدعاء آمن
    if (typeof setupWhatsAppPreview === 'function') {
        setupWhatsAppPreview();
    }
    showAlert("مرحباً بك في نظام النشرات المناخية الساعية - UTC فقط", "success");
}

document.addEventListener("DOMContentLoaded", initializePage);

window.showAlert = showAlert;
window.setLoading = setLoading;
window.validateTemperatureInput = validateTemperatureInput;
window.validateField = validateField;
window.autoFormatDecimalField = autoFormatDecimalField;
window.autoFormatIntegerField = autoFormatIntegerField;

console.log('🚀 تم تحميل النظام المصحح بنجاح');