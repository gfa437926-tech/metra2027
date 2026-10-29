// daily_main.js - الملف الرئيسي لوظائف الملخص اليومي مع تصحيح تنسيق الإشارة

document.addEventListener('DOMContentLoaded', function() {
    console.log('🚀 بدء تهيئة نظام النشرات اليومية...');
    
    // تهيئة اختيار نوع الملخص
    initReportTypeSelector();
    
    // تحميل بيانات المستخدم
    loadUserData();
    
    // تهيئة الأزرار
    initButtons();
    
    // تهيئة أزرار الإشارات
    initSignButtons();
    
    // تهيئة التنسيق التلقائي
    initAutoFormat();
    
    // تهيئة أزرار "لا تتوفر معلومات"
    initNoDataButtons();
    
    // تهيئة التحكم في الحقول
    if (typeof initFieldsControl === 'function') {
        initFieldsControl();
    }
    
    // تحديث معلومات التوقيت عند التحميل
    updateTimezoneInfo();
    
    console.log('✅ تم تهيئة النظام بنجاح');
});

// ✅ تعريف الدوال المفقودة لتجنب أخطاء الكونسول
function updateReportPeriod() {
    console.log('تحديث فترة التقرير (لا حاجة فعلية)');
}

function updateReportStatus() {
    console.log('تحديث حالة التقرير (لا حاجة فعلية)');
}

// تحميل بيانات المستخدم من الذاكرة 
function loadUserData() {
    try {
        const userData = JSON.parse(localStorage.getItem('currentUser') || '{}');

        if (userData.first_name) {
            const fullName = `${userData.first_name} ${userData.father_name || ''} ${userData.last_name || ''}`;
            const userName = document.getElementById('userName');
            const userStation = document.getElementById('userStation');
            const userRole = document.getElementById('userRole');

            if (userName) userName.textContent = fullName.trim();
            if (userStation) userStation.textContent = userData.station || 'غير محدد';
            if (userRole) userRole.textContent = userData.role || 'غير محدد';
        }

        // تعيين التاريخ الميلادي بصيغة YYYY-MM-DD
        const now = new Date();
        const currentDateField = document.getElementById('currentDate');
        if (currentDateField) {
            const formattedDate = now.toISOString().split('T')[0];
            currentDateField.value = formattedDate;
        }
    } catch (error) {
        console.error('خطأ في تحميل بيانات المستخدم:', error);
    }
}

// تهيئة اختيار نوع الملخص مع التحكم في إظهار الأقسام
function initReportTypeSelector() {
    const reportTypeRadios = document.querySelectorAll('input[name="reportType"]');
    
    reportTypeRadios.forEach(radio => {
        radio.addEventListener('change', function() {
            updateTimezoneInfo();
            // تم إزالة استدعاء updateReportPeriod و updateReportStatus (لمنع الأخطاء)
            if (typeof updateFieldsVisibility === 'function') {
                updateFieldsVisibility();
            }
        });
    });
}

// تهيئة أزرار "لا تتوفر معلومات"
function initNoDataButtons() {
    const noDataButtons = document.querySelectorAll('.btn-no-data');
    noDataButtons.forEach(button => {
        button.addEventListener('click', function() {
            const targetId = this.getAttribute('data-target');
            const targetField = document.getElementById(targetId);
            if (targetField) {
                targetField.value = '#';
                targetField.disabled = true;
                targetField.style.backgroundColor = '#f8f9fa';
                targetField.style.color = '#6c757d';
                targetField.style.cursor = 'not-allowed';
                this.classList.remove('btn-outline-info');
                this.classList.add('btn-success');
                this.innerHTML = '<i class="fas fa-check"></i> لا تتوفر معلومات';
                
                if (typeof clearFieldError === 'function') clearFieldError(targetField);
                targetField.classList.remove('is-valid', 'is-invalid');
                
                if (targetId === 'minTemp' || targetId === 'maxTemp') {
                    const signButton = document.querySelector(`.sign-btn[data-target="${targetId}"]`);
                    if (signButton) resetSignButton(signButton);
                }
            }
        });
    });
}

// إعادة تعيين زر الإشارة
function resetSignButton(button) {
    button.classList.remove('btn-outline-danger');
    button.classList.add('btn-outline-secondary');
    button.innerHTML = '<i class="fas fa-plus"></i>';
    button.title = 'تغيير الإشارة';
}

// تهيئة التنسيق التلقائي
function initAutoFormat() {
    const autoFormatFields = [
        'minTemp', 'maxTemp', 'precipitation', 'snowThickness',
        'precipitationTrace', 'evaporation', 'sunshineDuration',
        'sunshinePercentage', 'maxGustSpeed', 'maxGustDirection',
        'maxGustTime', 'maxHumidity', 'maxHumidityTime',
        'minHumidity', 'minHumidityTime'
    ];
    
    autoFormatFields.forEach(fieldId => {
        const field = document.getElementById(fieldId);
        if (field) {
            field.addEventListener('blur', function() {
                if (this.value !== '#') formatFieldOnBlur(this);
            });
            field.addEventListener('keydown', function(e) {
                if (e.key === 'Enter' && this.value !== '#') {
                    e.preventDefault();
                    formatFieldOnBlur(this);
                    moveToNextField(this);
                }
            });
            if (field.value.trim() && field.value !== '#') {
                setTimeout(() => formatFieldOnBlur(field), 100);
            }
        }
    });
}

// تنسيق الحقل عند الخروج
function formatFieldOnBlur(field) {
    const value = field.value.trim();
    if (!value || value === '#') return;
    
    const fieldId = field.id;
    let formattedValue = value;
    
    switch(fieldId) {
        case 'minTemp':
        case 'maxTemp':
            formattedValue = formatTemperature(value, fieldId);
            break;
        case 'precipitation':
            formattedValue = formatPrecipitation(value);
            break;
        case 'snowThickness':
            formattedValue = formatSnowThickness(value);
            break;
        case 'precipitationTrace':
            formattedValue = formatPrecipitationTrace(value);
            break;
        case 'evaporation':
            formattedValue = formatEvaporation(value);
            break;
        case 'sunshineDuration':
            formattedValue = formatSunshineDuration(value);
            break;
        case 'sunshinePercentage':
            formattedValue = formatSunshinePercentage(value);
            break;
        case 'maxGustSpeed':
            formattedValue = formatWindSpeed(value);
            break;
        case 'maxGustDirection':
            formattedValue = formatWindDirection(value);
            break;
        case 'maxGustTime':
        case 'maxHumidityTime':
        case 'minHumidityTime':
            formattedValue = formatTime(value);
            break;
        case 'maxHumidity':
            formattedValue = formatMaxHumidity(value);
            break;
        case 'minHumidity':
            formattedValue = formatMinHumidity(value);
            break;
        default:
            formattedValue = formatGenericFieldValue(value);
    }
    
    if (formattedValue !== value) {
        const oldValue = field.value;
        field.value = formattedValue;
        field.classList.add('formatted-highlight');
        setTimeout(() => field.classList.remove('formatted-highlight'), 500);
        if (typeof validateField === 'function') validateField(field);
        showFormatSuccess(field, oldValue, formattedValue);
    }
}

// تنسيق درجة الحرارة مع وضع الإشارة على يسار الرقم الصحيح
function formatTemperature(value, fieldId) {
    if (value === '#') return value;
    value = value.trim().replace(/[^\d.-]/g, '');
    if (value.startsWith('+')) value = value.substring(1);
    if (!value) return '';
    let numValue = parseFloat(value);
    if (isNaN(numValue)) return value;
    const isNegative = numValue < 0;
    numValue = Math.abs(numValue);
    if (numValue > 50) numValue = 50;
    if (numValue < 0.1) numValue = 0;
    const integerPart = Math.floor(numValue).toString().padStart(2, '0');
    const decimalPart = numValue.toFixed(1).split('.')[1];
    const formattedValue = (isNegative ? '-' : '') + integerPart + '.' + decimalPart;
    // تحديث زر الإشارة
    const signButton = document.querySelector(`.sign-btn[data-target="${fieldId}"]`);
    if (signButton && typeof updateSignButtonState === 'function') {
        updateSignButtonState(signButton, isNegative);
    }
    return formattedValue;
}

// تهيئة أزرار الإشارات
function initSignButtons() {
    const signButtons = document.querySelectorAll('.sign-btn');
    signButtons.forEach(button => {
        button.addEventListener('click', function() {
            const targetId = this.getAttribute('data-target');
            const inputField = document.getElementById(targetId);
            if (inputField && inputField.value !== '#') {
                let currentValue = inputField.value.trim();
                if (!currentValue) {
                    inputField.value = '-00.0';
                    updateSignButtonState(this, true);
                } else {
                    if (currentValue.startsWith('-')) {
                        inputField.value = currentValue.substring(1);
                        updateSignButtonState(this, false);
                    } else {
                        inputField.value = '-' + currentValue;
                        updateSignButtonState(this, true);
                    }
                }
                if (typeof validateField === 'function') validateField(inputField);
                formatFieldOnBlur(inputField);
            }
        });
    });
    setTimeout(() => {
        const tempFields = ['minTemp', 'maxTemp'];
        tempFields.forEach(fieldId => {
            const field = document.getElementById(fieldId);
            if (field && field.value !== '#') {
                const button = document.querySelector(`.sign-btn[data-target="${fieldId}"]`);
                if (button && typeof updateSignButtonState === 'function') {
                    updateSignButtonState(button, field.value.startsWith('-'));
                }
            }
        });
    }, 500);
}

// تحديث حالة زر الإشارة
function updateSignButtonState(button, isNegative) {
    if (isNegative) {
        button.classList.remove('btn-outline-secondary');
        button.classList.add('btn-outline-danger');
        button.innerHTML = '<i class="fas fa-minus"></i>';
        button.title = 'قيمة سالبة - انقر للتغيير';
    } else {
        button.classList.remove('btn-outline-danger');
        button.classList.add('btn-outline-secondary');
        button.innerHTML = '<i class="fas fa-plus"></i>';
        button.title = 'قيمة موجبة - انقر للتغيير';
    }
}

// باقي دوال التنسيق (مختصرة للمساحة – يمكنك إبقاؤها كما هي)
function formatPrecipitation(value) { if (value === '#') return value; value = value.replace(/[^\d.]/g, ''); if (!value) return ''; let n = parseFloat(value); if (isNaN(n)) return value; if (n > 999.9) n = 999.9; if (n < 0) n = 0; const int = Math.floor(n).toString().padStart(3, '0'); const dec = n.toFixed(1).split('.')[1]; return int + '.' + dec; }
function formatSnowThickness(value) { if (value === '#') return value; value = value.replace(/\D/g, ''); if (!value) return ''; let n = parseInt(value); if (isNaN(n)) return value; if (n > 999) n = 999; if (n < 0) n = 0; return n.toString().padStart(3, '0'); }
function formatPrecipitationTrace(value) { if (value === '#') return value; value = value.trim().toUpperCase(); return value === 'T' ? 'T' : ''; }
function formatEvaporation(value) { if (value === '#') return value; value = value.replace(/[^\d.]/g, ''); if (!value) return ''; let n = parseFloat(value); if (isNaN(n)) return value; if (n > 99.9) n = 99.9; if (n < 0) n = 0; const int = Math.floor(n).toString().padStart(2, '0'); const dec = n.toFixed(1).split('.')[1]; return int + '.' + dec; }
function formatSunshineDuration(value) { if (value === '#') return value; value = value.replace(/[^\d.]/g, ''); if (!value) return ''; let n = parseFloat(value); if (isNaN(n)) return value; if (n > 24.0) n = 24.0; if (n < 0) n = 0; const int = Math.floor(n).toString().padStart(2, '0'); const dec = n.toFixed(1).split('.')[1]; return int + '.' + dec; }
function formatSunshinePercentage(value) { if (value === '#') return value; value = value.replace(/\D/g, ''); if (!value) return ''; let n = parseInt(value); if (isNaN(n)) return value; if (n > 100) n = 100; if (n < 0) n = 0; return n.toString().padStart(3, '0'); }
function formatWindSpeed(value) { if (value === '#') return value; value = value.replace(/\D/g, ''); if (!value) return ''; let n = parseInt(value); if (isNaN(n)) return value; if (n > 36) n = 36; if (n < 0) n = 0; return n.toString().padStart(2, '0'); }
function formatWindDirection(value) { return formatWindSpeed(value); }
function formatTime(value) { if (value === '#') return value; value = value.replace(/[^\d.]/g, ''); if (!value) return ''; let n = parseFloat(value); if (isNaN(n)) return value; if (n > 23.9) n = 23.9; if (n < 0) n = 0; const int = Math.floor(n).toString().padStart(2, '0'); const dec = n.toFixed(1).split('.')[1]; return int + '.' + dec; }
function formatMaxHumidity(value) { if (value === '#') return value; value = value.replace(/\D/g, ''); if (!value) return ''; let n = parseInt(value); if (isNaN(n)) return value; if (n > 100) n = 100; if (n < 0) n = 0; return n.toString().padStart(3, '0'); }
function formatMinHumidity(value) { if (value === '#') return value; value = value.replace(/\D/g, ''); if (!value) return ''; let n = parseInt(value); if (isNaN(n)) return value; if (n > 99) n = 99; if (n < 0) n = 0; return n.toString().padStart(2, '0'); }
function formatGenericFieldValue(value) { return value.trim(); }

function showFormatSuccess(field, oldValue, newValue) {
    const oldTips = field.parentNode.querySelectorAll('.format-success-tip');
    oldTips.forEach(tip => tip.remove());
    if (oldValue !== newValue) {
        const tip = document.createElement('div');
        tip.className = 'format-success-tip';
        tip.innerHTML = `<i class="fas fa-check-circle"></i> ${oldValue} → ${newValue}`;
        field.parentNode.appendChild(tip);
        setTimeout(() => tip.remove(), 2000);
    }
}

function moveToNextField(currentField) {
    const allFields = ['minTemp','maxTemp','precipitation','snowThickness','precipitationTrace','evaporation','sunshineDuration','sunshinePercentage','maxGustSpeed','maxGustDirection','maxGustTime','maxHumidity','maxHumidityTime','minHumidity','minHumidityTime','observerNotes'];
    const idx = allFields.indexOf(currentField.id);
    if (idx !== -1 && idx < allFields.length - 1) {
        const next = document.getElementById(allFields[idx + 1]);
        if (next) setTimeout(() => { next.focus(); next.select(); }, 10);
    }
}

// تحديث معلومات التوقيت
function updateTimezoneInfo() {
    const selected = document.querySelector('input[name="reportType"]:checked');
    if (!selected) return;
    const timezoneInfo = document.getElementById('timezoneInfo');
    const convertedTimes = document.getElementById('convertedTimes');
    if (!timezoneInfo || !convertedTimes) return;
    let infoText = '', convertedText = '';
    switch(selected.value) {
        case '24h':
            infoText = 'التقرير اليومي (00:00 - 24:00)';
            convertedText = '<div>يتم ادخال ملخص اليوم السابق</div>';
            break;
        case '06utc':
            infoText = 'نشرة 06:00 توقيت عالمي (09:00 توقيت محلي)';
            convertedText = '<div>يتم ادخالها في الصباح</div><div>التوقيت العالمي: 06:00 UTC</div>';
            break;
        case '18utc':
            infoText = 'نشرة 18:00 توقيت عالمي (21:00 توقيت محلي)';
            convertedText = '<div>يتم ادخالها في المساء</div><div>التوقيت العالمي: 18:00 UTC</div>';
            break;
    }
    timezoneInfo.textContent = infoText;
    convertedTimes.innerHTML = convertedText;
}

// تهيئة الأزرار
function initButtons() {
    const saveDraftBtn = document.getElementById('saveDraftBtn');
    if (saveDraftBtn) saveDraftBtn.addEventListener('click', saveDraft);
    const testDataBtn = document.getElementById('testDataBtn');
    if (testDataBtn) testDataBtn.addEventListener('click', fillTestData);
    const previewBtn = document.getElementById('previewBtn');
    if (previewBtn) previewBtn.addEventListener('click', previewData);
    const whatsappBtn = document.getElementById('whatsappShareBtn');
    if (whatsappBtn) whatsappBtn.addEventListener('click', shareViaWhatsApp);
}

// حفظ مسودة
function saveDraft() {
    try {
        if (typeof validateForm === 'function' && !validateForm()) {
            if (typeof showNotification === 'function') showNotification('يرجى تصحيح الأخطاء قبل حفظ المسودة', 'error');
            return;
        }
        const formData = typeof collectFormDataForDB === 'function' ? collectFormDataForDB() : {};
        formData.status = 'draft';
        formData.draft_saved_at = new Date().toISOString();
        const drafts = JSON.parse(localStorage.getItem('dailyDrafts') || '[]');
        drafts.unshift(formData);
        if (drafts.length > 10) drafts.pop();
        localStorage.setItem('dailyDrafts', JSON.stringify(drafts));
        if (typeof showNotification === 'function') showNotification('تم حفظ المسودة بنجاح', 'success');
    } catch(e) { console.error(e); }
}

// ملء بيانات تجريبية
function fillTestData() {
    if (!confirm('هل تريد تعبئة النموذج ببيانات تجريبية؟ سيتم مسح أي بيانات حالية.')) return;
    try {
        console.log('بدء تعبئة البيانات التجريبية...');
        document.getElementById('minTemp').value = '-05.3';
        document.getElementById('maxTemp').value = '25.7';
        formatFieldOnBlur(document.getElementById('minTemp'));
        formatFieldOnBlur(document.getElementById('maxTemp'));
        document.getElementById('precipitation').value = '012.5';
        document.getElementById('snowThickness').value = '015';
        document.getElementById('precipitationTrace').value = 'T';
        document.getElementById('evaporation').value = '12.5';
        document.getElementById('sunshineDuration').value = '08.5';
        document.getElementById('sunshinePercentage').value = '075';
        document.getElementById('maxGustSpeed').value = '15';
        document.getElementById('maxGustDirection').value = '25';
        document.getElementById('maxGustTime').value = '14.5';
        document.getElementById('maxHumidity').value = '085';
        document.getElementById('maxHumidityTime').value = '06.0';
        document.getElementById('minHumidity').value = '35';
        document.getElementById('minHumidityTime').value = '14.0';
        if (document.getElementById('rain')) document.getElementById('rain').checked = true;
        if (document.getElementById('fog')) document.getElementById('fog').checked = true;
        if (document.getElementById('stormyWind')) document.getElementById('stormyWind').checked = true;
        document.getElementById('observerNotes').value = 'بيانات تجريبية لأغراض الاختبار';
        document.getElementById('responsibilityAgreement').checked = true;
        console.log('✅ تم تعبئة البيانات التجريبية بنجاح');
        if (typeof showNotification === 'function') showNotification('تم تعبئة البيانات التجريبية', 'success');
    } catch(e) { console.error(e); }
}

// معاينة البيانات
function previewData() {
    if (typeof validateForm === 'function' && !validateForm()) {
        if (typeof showNotification === 'function') showNotification('يرجى تصحيح الأخطاء قبل المعاينة', 'error');
        return;
    }
    const formData = typeof collectFormDataForDB === 'function' ? collectFormDataForDB() : {};
    const previewHTML = generateCompletePreviewHTML(formData);
    const win = window.open('', 'معاينة التقرير', 'width=1200,height=800,scrollbars=yes');
    win.document.write(previewHTML);
    win.document.close();
}

function generateCompletePreviewHTML(data) {
    // يمكنك الاحتفاظ بنفس الكود السابق للمعاينة
    return `<!DOCTYPE html><html dir="rtl"><head><meta charset="UTF-8"><title>معاينة التقرير</title><link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet"></head><body><div class="container mt-4"><h3>معاينة التقرير اليومي</h3><pre>${JSON.stringify(data, null, 2)}</pre></div></body></html>`;
}

// مشاركة واتساب
async function shareViaWhatsApp() {
    if (typeof validateForm === 'function' && !validateForm()) {
        showNotification('يرجى تصحيح الأخطاء قبل المشاركة', 'error');
        return;
    }
    const formData = typeof collectFormDataForDB === 'function' ? collectFormDataForDB() : {};
    const message = createWhatsAppMessage(formData);
    const encoded = encodeURIComponent(message);
    window.open(`https://wa.me/?text=${encoded}`, '_blank');
    showNotification('تم فتح واتساب مع نص التقرير', 'success');
}

function createWhatsAppMessage(data) {
    const typeNames = { '24h':'تقرير 24 ساعة', '06utc':'تقرير 06 عالمي', '18utc':'تقرير 18 عالمي' };
    return `🌤️ *التقرير اليومي* 🌤️\n\n📅 التاريخ: ${data.display_date}\n🏢 المحطة: ${data.station}\n👤 الراصد: ${data.observer_name}\n📊 نوع التقرير: ${typeNames[data.report_type] || data.report_type}\n\n🌡️ *درجات الحرارة*\nالصغرى: ${data.min_temperature !== null ? data.min_temperature+'°C' : '#'}\nالعظمى: ${data.max_temperature !== null ? data.max_temperature+'°C' : '#'}\n\n💧 *الهطول*: ${data.precipitation !== null ? data.precipitation+' مم' : '#'}\n❄️ *الثلج*: ${data.snow_thickness !== null ? data.snow_thickness+' سم' : '#'}\n\n📝 *ملاحظات*: ${data.observer_notes || 'لا توجد'}\n\n---\nتم الإنشاء بواسطة نظام إدارة البيانات الجوية`;
}

window.saveDraft = saveDraft;
window.fillTestData = fillTestData;
window.previewData = previewData;
window.shareViaWhatsApp = shareViaWhatsApp;
window.formatFieldOnBlur = formatFieldOnBlur;
window.updateSignButtonState = updateSignButtonState;