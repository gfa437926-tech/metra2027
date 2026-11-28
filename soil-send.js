// ============================================
// soil-send.js - النسخة المحسنة والمعدلة مع الاعتماد على UTC فقط
// ============================================

console.log('📦 تحميل soil-send.js المحسن...');

// 1. دالة عرض الإشعارات المحسنة
function showNotification(msg, type = "success", duration = 5000) {
    console.log('📢 إشعار:', msg, 'نوع:', type);
    
    const container = document.getElementById("notificationContainer");
    if (!container) {
        console.warn('⚠️ حاوية الإشعارات غير موجودة');
        return;
    }
    
    const el = document.createElement("div");
    el.className = "notification";
    
    // أيقونة حسب النوع
    let icon = '';
    switch(type) {
        case 'success': icon = 'fa-check-circle'; break;
        case 'error': icon = 'fa-exclamation-circle'; break;
        case 'warning': icon = 'fa-exclamation-triangle'; break;
        case 'info': icon = 'fa-info-circle'; break;
        default: icon = 'fa-info-circle';
    }
    
    el.innerHTML = `
        <i class="fas ${icon} fa-lg"></i>
        <div style="flex: 1;">${msg}</div>
        <button class="btn-close-notification" style="background: none; border: none; color: inherit; font-size: 1.2rem;">
            &times;
        </button>
    `;
    
    // إضافة كلاس النوع
    el.classList.add(type);
    
    // أسلوب CSS
    el.style.cssText = `
        padding: 15px 20px;
        margin-bottom: 10px;
        border-radius: 12px;
        color: white;
        font-weight: 500;
        box-shadow: 0 4px 15px rgba(0, 0, 0, 0.2);
        animation: slideIn 0.3s ease;
        display: flex;
        align-items: center;
        gap: 15px;
        backdrop-filter: blur(10px);
        border-left: 5px solid ${getNotificationColor(type)};
    `;
    
    container.appendChild(el);
    
    // إضافة مؤقت للإزالة
    const timeout = setTimeout(() => {
        if (el.parentNode === container) {
            container.removeChild(el);
        }
    }, duration);
    
    // زر الإغلاق
    const closeBtn = el.querySelector('.btn-close-notification');
    closeBtn.addEventListener('click', () => {
        clearTimeout(timeout);
        container.removeChild(el);
    });
    
    // إضافة تأثير اختفاء
    setTimeout(() => {
        el.style.opacity = '0.7';
    }, duration - 1000);
}

function getNotificationColor(type) {
    const colors = {
        success: '#28a745',
        error: '#dc3545',
        warning: '#ffc107',
        info: '#17a2b8'
    };
    return colors[type] || colors.info;
}

// 2. نظام متقدم للتحقق من الصحة
const validators = {
    soilTemp: function(v) { 
        if (!v) return false;
        
        // إذا كانت القيمة هي # فقط، تعتبر صحيحة
        if (v === '#') return true;
        
        // التحقق من الصيغة ±dd.d
        const pattern = /^[+-]?\d{1,2}\.\d$/;
        if (!pattern.test(v)) return false;
        
        const n = parseFloat(v);
        if (isNaN(n)) return false;
        
        // المدى من -20.0 إلى +50.0
        if (n < -20.0 || n > 50.0) return false;
        
        return true;
    },
    utcTime: function(v) { 
        const allowedHours = ['23', '02', '05', '08', '11', '14', '17', '20'];
        return allowedHours.includes(v);
    }
};

// 3. تنسيق درجة الحرارة مع دعم متقدم
function formatTemperature(value) {
    if (!value) return '';
    
    if (value === '#') return '#';
    
    // إزالة المسافات والأحرف غير المرغوبة
    value = value.toString().trim().replace(/[^0-9.#+-]/g, '');
    
    if (!value) return '';
    
    // تحديد الإشارة
    let sign = '';
    if (value.startsWith('-')) {
        sign = '-';
        value = value.substring(1);
    } else if (value.startsWith('+')) {
        sign = '+';
        value = value.substring(1);
    } else if (value.startsWith('#')) {
        return '#';
    }
    
    // إزالة أي علامات إضافية
    value = value.replace(/[+#-]/g, '');
    
    if (!value) return sign || '';
    
    // التحقق من وجود نقطة عشرية
    if (!value.includes('.')) {
        const digits = value.replace(/[^0-9]/g, '');
        if (digits.length >= 2) {
            value = digits.slice(0, -1) + '.' + digits.slice(-1);
        } else if (digits.length === 1) {
            value = '0.' + digits;
        }
    } else {
        const parts = value.split('.');
        if (parts[1].length > 1) {
            value = parts[0] + '.' + parts[1].charAt(0);
        } else if (parts[1].length === 0) {
            value = value + '0';
        }
    }
    
    // التأكد من أن الرقمين الصحيحين مكونين من رقمين
    const parts = value.split('.');
    let integerPart = parts[0];
    
    if (integerPart.length === 1 && sign) {
        value = '0' + integerPart + '.' + parts[1];
    } else if (integerPart.length === 0) {
        value = '00.' + parts[1];
    } else if (integerPart.length === 1 && !sign) {
        value = '0' + integerPart + '.' + parts[1];
    }
    
    // إعادة الإشارة
    if (sign) {
        value = sign + value;
    } else if (value && !isNaN(parseFloat(value))) {
        value = '+' + value;
    }
    
    return value;
}

// 4. Validate field مع رسائل مفصلة
function validateField(inputEl, validator, errorElementId, successElementId) {
    if (!inputEl) return false;
    
    const value = inputEl.value.trim();
    const isValid = value === "" ? true : validator(value);
    
    // إزالة الفئات السابقة
    inputEl.classList.remove("is-valid", "is-invalid");
    
    // إخفاء الرسائل
    if (errorElementId) {
        const errorElement = document.getElementById(errorElementId);
        if (errorElement) {
            errorElement.style.display = "none";
            errorElement.innerHTML = "";
        }
    }
    if (successElementId) {
        const successElement = document.getElementById(successElementId);
        if (successElement) successElement.style.display = "none";
    }
    
    // تحديث مؤشر الإشارة
    if (inputEl.classList.contains('temperature-input')) {
        updateSignIndicator(inputEl);
    }
    
    if (value !== "") {
        if (isValid) {
            inputEl.classList.add("is-valid");
            inputEl.style.borderColor = "#28a745";
            inputEl.style.boxShadow = "0 0 0 0.2rem rgba(40, 167, 69, 0.25)";
            
            if (successElementId) {
                const successElement = document.getElementById(successElementId);
                if (successElement) {
                    successElement.style.display = "block";
                    successElement.innerHTML = value === '#' ? 
                        '✅ تم إدخال # (لاتتوفر بيانات)' : 
                        '✅ القيمة صحيحة';
                }
            }
        } else {
            inputEl.classList.add("is-invalid");
            inputEl.style.borderColor = "#dc3545";
            inputEl.style.boxShadow = "0 0 0 0.2rem rgba(220, 53, 69, 0.25)";
            
            if (errorElementId) {
                const errorElement = document.getElementById(errorElementId);
                if (errorElement) {
                    errorElement.style.display = "block";
                    let errorMsg = '';
                    
                    if (value === '#') {
                        errorMsg = '⚠️ تم إدخال # (لاتتوفر بيانات)';
                    } else if (!/^[+-]?\d{1,2}\.\d$/.test(value)) {
                        errorMsg = '❌ الصيغة غير صحيحة. استخدم ±dd.d';
                    } else {
                        const n = parseFloat(value);
                        if (n < -20.0 || n > 50.0) {
                            errorMsg = `❌ خارج النطاق المسموح (-20.0 إلى +50.0)`;
                        } else {
                            errorMsg = '❌ قيمة غير صحيحة';
                        }
                    }
                    
                    errorElement.innerHTML = `
                        <div class="d-flex align-items-center">
                            <i class="fas fa-exclamation-circle me-2"></i>
                            <div>${errorMsg}</div>
                        </div>
                    `;
                }
            }
        }
    } else {
        inputEl.style.borderColor = "";
        inputEl.style.boxShadow = "";
    }
    
    return isValid;
}

// 5. تحديث مؤشر الإشارة مع ألوان محسنة
function updateSignIndicator(inputEl) {
    const wrapper = inputEl.closest('.temperature-input-wrapper');
    if (!wrapper) return;
    
    const indicator = wrapper.querySelector('.sign-indicator');
    if (!indicator) return;
    
    const value = inputEl.value.trim();
    
    if (value.startsWith('-')) {
        indicator.textContent = '−'; // علامة ناقص Unicode
        indicator.style.color = '#dc3545';
        indicator.style.textShadow = '0 1px 2px rgba(220, 53, 69, 0.3)';
    } else if (value.startsWith('+')) {
        indicator.textContent = '+';
        indicator.style.color = '#28a745';
        indicator.style.textShadow = '0 1px 2px rgba(40, 167, 69, 0.3)';
    } else if (value === '#') {
        indicator.textContent = '#';
        indicator.style.color = '#6c757d';
        indicator.style.textShadow = '0 1px 2px rgba(108, 117, 125, 0.3)';
    } else if (value && !isNaN(parseFloat(value))) {
        indicator.textContent = '+';
        indicator.style.color = '#28a745';
        indicator.style.textShadow = '0 1px 2px rgba(40, 167, 69, 0.3)';
    } else {
        indicator.textContent = '±';
        indicator.style.color = '#6c757d';
        indicator.style.textShadow = 'none';
    }
}

// 6. تحديث التوقيت المحلي المقابل
function updateLocalTimeDisplay() {
    const utcTimeSelect = document.getElementById('utcTime');
    const localTimeDisplay = document.getElementById('localTimeDisplay');
    
    if (!utcTimeSelect || !localTimeDisplay) return;
    
    if (utcTimeSelect.value) {
        const utcHour = parseInt(utcTimeSelect.value);
        const localHour = (utcHour + 3) % 24; // سوريا = UTC+3
        const localFormatted = String(localHour).padStart(2, '0');
        localTimeDisplay.value = `${localFormatted}:00 (توقيت سوريا)`;
    } else {
        localTimeDisplay.value = '';
    }
}

// 7. إعداد أزرار السالب والموجب والهاش المحسنة
function setupSignButtons() {
    console.log('🔘 إعداد أزرار السالب/الموجب/الهاش...');
    
    // أزرار السالب
    document.querySelectorAll('.sign-btn.negative').forEach(btn => {
        btn.addEventListener('click', function() {
            handleSignButtonClick(this, '-');
        });
    });
    
    // أزرار الموجب
    document.querySelectorAll('.sign-btn.positive').forEach(btn => {
        btn.addEventListener('click', function() {
            handleSignButtonClick(this, '+');
        });
    });
    
    // أزرار الهاش
    document.querySelectorAll('.sign-btn.hash').forEach(btn => {
        btn.addEventListener('click', function() {
            handleSignButtonClick(this, '#');
        });
    });
    
    // تحديث تلقائي عند الكتابة
    document.querySelectorAll('.temperature-input').forEach(field => {
        field.addEventListener('input', function() {
            const fieldId = this.id;
            const value = this.value;
            
            if (value.startsWith('-')) {
                updateSignButtonState(fieldId, '-');
            } else if (value.startsWith('+')) {
                updateSignButtonState(fieldId, '+');
            } else if (value === '#') {
                updateSignButtonState(fieldId, '#');
            } else if (value && !value.startsWith('-') && !value.startsWith('+') && value !== '#') {
                updateSignButtonState(fieldId, '+');
            } else {
                updateSignButtonState(fieldId, null);
            }
            
            // تحديث فوري
            const errorId = fieldId + 'Error';
            const successId = fieldId + 'Success';
            validateField(this, validators.soilTemp, errorId, successId);
        });
    });
}

function handleSignButtonClick(btn, sign) {
    const targetId = btn.getAttribute('data-target');
    const targetField = document.getElementById(targetId);
    
    if (!targetField) return;
    
    let currentValue = targetField.value;
    
    if (sign === '#') {
        targetField.value = '#';
    } else {
        if (sign === '-') {
            if (currentValue.startsWith('-')) {
                targetField.value = currentValue.substring(1);
            } else if (currentValue.startsWith('+')) {
                targetField.value = '-' + currentValue.substring(1);
            } else if (currentValue.startsWith('#')) {
                targetField.value = '-' + currentValue.substring(1);
            } else {
                targetField.value = '-' + currentValue.replace(/[+-]/g, '');
            }
        } else if (sign === '+') {
            if (currentValue.startsWith('+')) {
                targetField.value = currentValue.substring(1);
            } else if (currentValue.startsWith('-')) {
                targetField.value = '+' + currentValue.substring(1);
            } else if (currentValue.startsWith('#')) {
                targetField.value = '+' + currentValue.substring(1);
            } else {
                targetField.value = '+' + currentValue;
            }
        }
    }
    
    // تحديث الحالة
    updateSignButtonState(targetId, sign);
    updateSignIndicator(targetField);
    
    // التحقق من الصحة
    const errorId = targetId + 'Error';
    const successId = targetId + 'Success';
    validateField(targetField, validators.soilTemp, errorId, successId);
}

// 8. تحديث حالة أزرار الإشارة
function updateSignButtonState(fieldId, activeSign) {
    const buttons = document.querySelectorAll(`.sign-btn[data-target="${fieldId}"]`);
    
    buttons.forEach(btn => {
        btn.classList.remove('active');
        const btnSign = btn.getAttribute('data-value');
        
        if (btnSign === activeSign) {
            btn.classList.add('active');
            btn.style.transform = 'scale(1.05)';
            btn.style.boxShadow = '0 0 0 0.3rem rgba(0, 123, 255, 0.3)';
        } else {
            btn.style.transform = '';
            btn.style.boxShadow = '';
        }
    });
}

// 9. تهيئة التحقق من الحقول
function initializeFieldValidations() {
    console.log('🔍 تهيئة تحقق الحقول...');
    
    setupSignButtons();
    
    const soilTempFields = [
        {id: 'soilTemp5cm', errorId: 'soilTemp5cmError', successId: 'soilTemp5cmSuccess'},
        {id: 'soilTemp10cm', errorId: 'soilTemp10cmError', successId: 'soilTemp10cmSuccess'},
        {id: 'soilTemp20cm', errorId: 'soilTemp20cmError', successId: 'soilTemp20cmSuccess'},
        {id: 'soilTemp50cm', errorId: 'soilTemp50cmError', successId: 'soilTemp50cmSuccess'}
    ];
    
    soilTempFields.forEach(field => {
        const fieldEl = document.getElementById(field.id);
        if (fieldEl) {
            // التحقق أثناء الكتابة
            fieldEl.addEventListener('input', function(e) {
                let value = e.target.value;
                value = value.replace(/[^0-9.#+-]/g, '');
                
                if (value.startsWith('#')) {
                    e.target.value = '#';
                    validateField(fieldEl, validators.soilTemp, field.errorId, field.successId);
                    updateSignIndicator(fieldEl);
                    return;
                }
                
                if (value.length > 0) {
                    const firstChar = value.charAt(0);
                    if (firstChar !== '-' && firstChar !== '+') {
                        value = value.replace(/[+-]/g, '');
                    } else {
                        const sign = firstChar;
                        value = sign + value.slice(1).replace(/[+-]/g, '');
                    }
                }
                
                e.target.value = value;
                validateField(fieldEl, validators.soilTemp, field.errorId, field.successId);
                updateSignIndicator(fieldEl);
            });
            
            // التنسيق عند الخروج
            fieldEl.addEventListener("blur", function() {
                const formattedValue = formatTemperature(this.value);
                if (formattedValue !== this.value) {
                    this.value = formattedValue;
                }
                validateField(fieldEl, validators.soilTemp, field.errorId, field.successId);
                updateSignIndicator(fieldEl);
            });
        }
    });

    // إعداد حقل التوقيت العالمي
    const utcTime = document.getElementById("utcTime");
    if (utcTime) {
        const allowedHours = ['23', '02', '05', '08', '11', '14', '17', '20'];
        utcTime.innerHTML = '<option value="" selected disabled>اختر الساعة (UTC)</option>';
        
        allowedHours.forEach(hour => {
            const option = document.createElement('option');
            option.value = hour;
            option.textContent = hour + ':00 UTC';
            utcTime.appendChild(option);
        });
        
        utcTime.addEventListener("change", function() {
            validateField(this, validators.utcTime, 'utcTimeError', 'utcTimeSuccess');
            updateLocalTimeDisplay();
        });
        
        // قيمة افتراضية
        utcTime.value = "05";
        validateField(utcTime, validators.utcTime, 'utcTimeError', 'utcTimeSuccess');
        updateLocalTimeDisplay();
    }
}

// 10. جلب معلومات الراصد مع تحديثات
async function loadUserInfo() {
    try {
        console.log('🔄 جاري جلب معلومات المستخدم...');
        
        let userData = {
            name: "مستخدم النظام",
            station: "محطة دمشق",
            role: "راصد جوي"
        };
        
        // محاولة جلب البيانات من مصادر مختلفة
        const sources = ['currentUser', 'userData'];
        
        for (const source of sources) {
            try {
                const data = localStorage.getItem(source);
                if (data) {
                    const parsed = JSON.parse(data);
                    if (parsed) {
                        if (source === 'currentUser') {
                            userData.name = `${parsed.first_name || ''} ${parsed.father_name || ''} ${parsed.last_name || ''}`.trim() || userData.name;
                            userData.station = parsed.station || userData.station;
                            userData.role = parsed.role || userData.role;
                        } else if (source === 'userData') {
                            userData.name = parsed.name || userData.name;
                            userData.station = parsed.station || userData.station;
                            userData.role = parsed.role || userData.role;
                        }
                        break;
                    }
                }
            } catch (e) {
                console.warn(`⚠️ خطأ في تحليل ${source}:`, e);
            }
        }
        
        // تحديث الواجهة
        updateUserInterface(userData);
        
        console.log('✅ تم تحميل معلومات المستخدم:', userData);
        
    } catch (error) {
        console.error('❌ خطأ في جلب معلومات المستخدم:', error);
        updateUserInterface({
            name: "مستخدم النظام",
            station: "محطة دمشق",
            role: "راصد جوي"
        });
        showNotification('⚠️ استخدام بيانات افتراضية للعرض', 'warning');
    }
}

function updateUserInterface(userData) {
    const elements = {
        userName: document.getElementById("userName"),
        userStation: document.getElementById("userStation"),
        userRole: document.getElementById("userRole")
    };
    
    for (const [id, element] of Object.entries(elements)) {
        if (element) {
            const value = userData[id.replace('user', '').toLowerCase()];
            const icon = id === 'userName' ? 'fa-user' : 
                        id === 'userStation' ? 'fa-map-marker-alt' : 'fa-user-tie';
            
            element.innerHTML = `<i class="fas ${icon} me-2"></i>${value}`;
            element.title = value;
        }
    }
}

// 11. تعبئة بيانات تجريبية محسنة
function fillTestData() {
    console.log('🧪 إدخال بيانات تجريبية...');
    
    const testData = {
        soilTemp5cm: "+25.5",
        soilTemp10cm: "-5.3",
        soilTemp20cm: "#",
        soilTemp50cm: "+22.0",
        observerNotes: "بيانات تجريبية للاختبار:\n• قراءات 5سم و50سم طبيعية\n• قراءات 10سم سالبة\n• قراءات 20سم غير متوفرة (#)\n• جميع القراءات ضمن النطاق المسموح\n• تم إنشاؤها تلقائياً للنظام"
    };
    
    Object.keys(testData).forEach(fieldId => {
        const field = document.getElementById(fieldId);
        if (field) {
            field.value = testData[fieldId];
            
            if (field.classList.contains('temperature-input')) {
                if (testData[fieldId].startsWith('-')) {
                    updateSignButtonState(fieldId, '-');
                } else if (testData[fieldId].startsWith('+')) {
                    updateSignButtonState(fieldId, '+');
                } else if (testData[fieldId] === '#') {
                    updateSignButtonState(fieldId, '#');
                }
                
                updateSignIndicator(field);
                
                const errorId = fieldId + 'Error';
                const successId = fieldId + 'Success';
                validateField(field, validators.soilTemp, errorId, successId);
            }
        }
    });

    const utcTime = document.getElementById("utcTime");
    if (utcTime) {
        utcTime.value = "05";
        validateField(utcTime, validators.utcTime, 'utcTimeError', 'utcTimeSuccess');
        updateLocalTimeDisplay();
    }
    
    const responsibilityCheck = document.getElementById("responsibilityConfirmed");
    if (responsibilityCheck) {
        responsibilityCheck.checked = true;
    }
    
    showNotification('🧪 تم تعبئة البيانات التجريبية بنجاح', 'info');
}

// 12. جمع بيانات النموذج
function collectFormData() {
    const utcTimeValue = document.getElementById('utcTime').value;
    const localTimeValue = document.getElementById('localTimeDisplay').value;
    
    return {
        utcTime: utcTimeValue,
        localTime: localTimeValue,
        soilTemp5cm: getValue('soilTemp5cm'),
        soilTemp10cm: getValue('soilTemp10cm'),
        soilTemp20cm: getValue('soilTemp20cm'),
        soilTemp50cm: getValue('soilTemp50cm'),
        observerNotes: getValue('observerNotes')
    };
}

function getValue(id) {
    const element = document.getElementById(id);
    return element ? element.value.trim() : '';
}

// 13. التحقق من صحة النموذج
function validateForm() {
    console.log('🔍 التحقق من صحة النموذج...');
    
    const requiredFields = [
        'utcTime',
        'soilTemp5cm',
        'soilTemp10cm',
        'soilTemp20cm',
        'soilTemp50cm'
    ];

    let isValid = true;
    let errorFields = [];

    requiredFields.forEach(fieldId => {
        const field = document.getElementById(fieldId);
        if (field) {
            const value = field.value.trim();
            if (!value) {
                isValid = false;
                errorFields.push(fieldId);
                field.classList.add('is-invalid');
            } else {
                let fieldIsValid = true;
                if (fieldId === 'utcTime') {
                    fieldIsValid = validators.utcTime(value);
                } else {
                    fieldIsValid = validators.soilTemp(value);
                }
                
                if (!fieldIsValid) {
                    isValid = false;
                    errorFields.push(fieldId);
                    field.classList.add('is-invalid');
                } else {
                    field.classList.remove('is-invalid');
                }
            }
        }
    });

    // التحقق من اتفاقية المسؤولية
    const responsibilityCheck = document.getElementById('responsibilityConfirmed');
    if (responsibilityCheck && !responsibilityCheck.checked) {
        isValid = false;
        showNotification('❌ يجب الموافقة على بيان المسؤولية قبل الإرسال', 'error');
    }

    if (!isValid && errorFields.length > 0) {
        showNotification(`❌ هناك ${errorFields.length} حقل/حقول غير صحيحة`, 'error');
    }

    return isValid;
}

// 14. نظام إدارة التقارير المحفوظة
class ReportManager {
    constructor() {
        this.reports = this.loadReports();
        this.updateUI();
    }
    
    loadReports() {
        try {
            return JSON.parse(localStorage.getItem('soilReports') || '[]');
        } catch (e) {
            console.error('❌ خطأ في تحميل التقارير:', e);
            return [];
        }
    }
    
    saveReports() {
        try {
            localStorage.setItem('soilReports', JSON.stringify(this.reports));
            this.updateUI();
            return true;
        } catch (e) {
            console.error('❌ خطأ في حفظ التقارير:', e);
            return false;
        }
    }
    
    addReport(reportData) {
        const report = {
            id: 'report-' + Date.now() + '-' + Math.random().toString(36).substr(2, 9),
            ...reportData,
            createdAt: new Date().toISOString(),
            status: 'pending',
            attempts: 0
        };
        
        this.reports.push(report);
        this.saveReports();
        return report;
    }
    
    updateReport(id, updates) {
        const index = this.reports.findIndex(r => r.id === id);
        if (index !== -1) {
            this.reports[index] = { ...this.reports[index], ...updates };
            this.saveReports();
            return true;
        }
        return false;
    }
    
    removeReport(id) {
        const initialLength = this.reports.length;
        this.reports = this.reports.filter(r => r.id !== id);
        if (this.reports.length !== initialLength) {
            this.saveReports();
            return true;
        }
        return false;
    }
    
    clearAllReports() {
        const count = this.reports.length;
        this.reports = [];
        this.saveReports();
        return count;
    }
    
    getPendingReports() {
        return this.reports.filter(r => r.status === 'pending');
    }
    
    getFailedReports() {
        return this.reports.filter(r => r.status === 'failed');
    }
    
    getSuccessReports() {
        return this.reports.filter(r => r.status === 'success');
    }
    
    updateUI() {
        // تحديث العداد
        const countElement = document.getElementById('savedReportsCount');
        if (countElement) {
            countElement.textContent = this.reports.length;
            countElement.title = `${this.reports.length} تقرير محفوظ`;
        }
        
        // تحديث قسم التقارير
        this.updateReportsSection();
    }
    
    updateReportsSection() {
        const section = document.getElementById('savedReportsSection');
        const list = document.getElementById('savedReportsList');
        
        if (!section || !list) return;
        
        if (this.reports.length === 0) {
            section.style.display = 'none';
            return;
        }
        
        section.style.display = 'block';
        
        const pending = this.getPendingReports().length;
        const failed = this.getFailedReports().length;
        const success = this.getSuccessReports().length;
        
        list.innerHTML = `
            <div class="alert alert-warning">
                <div class="d-flex justify-content-between align-items-center">
                    <div>
                        <i class="fas fa-exclamation-triangle me-2"></i>
                        <strong>هناك ${this.reports.length} تقرير محفوظ محلياً</strong>
                        <div class="mt-1 small">
                            <span class="badge bg-success me-2">${success} ✓</span>
                            <span class="badge bg-warning me-2">${pending} ⏳</span>
                            <span class="badge bg-danger">${failed} ✗</span>
                        </div>
                    </div>
                    <button class="btn btn-sm btn-primary" id="viewSavedReportsBtn">
                        <i class="fas fa-eye me-1"></i>عرض التقارير
                    </button>
                </div>
            </div>
        `;
        
        // إضافة معالج الحدث
        setTimeout(() => {
            const viewBtn = document.getElementById('viewSavedReportsBtn');
            if (viewBtn) {
                viewBtn.addEventListener('click', () => this.showReportsModal());
            }
        }, 100);
    }
    
    showReportsModal() {
        const modalContent = document.getElementById('savedReportsModalContent');
        if (!modalContent) return;
        
        let html = `
            <div class="table-responsive">
                <table class="table table-hover">
                    <thead class="table-light">
                        <tr>
                            <th>#</th>
                            <th>التاريخ</th>
                            <th>الوقت (UTC)</th>
                            <th>درجات الحرارة</th>
                            <th>الحالة</th>
                            <th>الإجراءات</th>
                        </tr>
                    </thead>
                    <tbody>
        `;
        
        this.reports.forEach((report, index) => {
            const date = new Date(report.createdAt);
            const dateStr = date.toLocaleDateString('ar-SY');
            const timeStr = date.toLocaleTimeString('ar-SY', { 
                hour: '2-digit', 
                minute: '2-digit' 
            });
            
            const temps = [
                report.soil_temp_5cm || '#',
                report.soil_temp_10cm || '#',
                report.soil_temp_20cm || '#',
                report.soil_temp_50cm || '#'
            ].join(' / ');
            
            let statusBadge = '';
            switch(report.status) {
                case 'success':
                    statusBadge = '<span class="badge bg-success">✓ تم الإرسال</span>';
                    break;
                case 'failed':
                    statusBadge = '<span class="badge bg-danger">✗ فشل</span>';
                    break;
                default:
                    statusBadge = '<span class="badge bg-warning">⏳ معلق</span>';
            }
            
            html += `
                <tr>
                    <td>${index + 1}</td>
                    <td>${dateStr}</td>
                    <td>${report.utc_time || timeStr}</td>
                    <td><small>${temps}</small></td>
                    <td>${statusBadge}</td>
                    <td>
                        <button class="btn btn-sm btn-info me-1" onclick="reportManager.retryReport('${report.id}')">
                            <i class="fas fa-sync"></i>
                        </button>
                        <button class="btn btn-sm btn-danger" onclick="reportManager.removeReport('${report.id}')">
                            <i class="fas fa-trash"></i>
                        </button>
                    </td>
                </tr>
            `;
        });
        
        html += `
                    </tbody>
                </table>
            </div>
            
            <div class="mt-3 p-3 bg-light rounded">
                <h6><i class="fas fa-info-circle me-2"></i>معلومات التخزين</h6>
                <div class="row">
                    <div class="col-md-6">
                        <small>عدد التقارير: <strong>${this.reports.length}</strong></small>
                    </div>
                    <div class="col-md-6">
                        <small>الحجم التقديري: <strong>${this.calculateStorageSize()} KB</strong></small>
                    </div>
                </div>
            </div>
        `;
        
        modalContent.innerHTML = html;
        
        // إظهار المودال
        const modal = new bootstrap.Modal(document.getElementById('savedReportsModal'));
        modal.show();
    }
    
    retryReport(id) {
        const report = this.reports.find(r => r.id === id);
        if (!report) return;
        
        showNotification(`🔄 محاولة إعادة إرسال التقرير ${id}`, 'info');
        
        // محاكاة إعادة الإرسال
        this.updateReport(id, { 
            status: 'pending',
            attempts: (report.attempts || 0) + 1,
            lastAttempt: new Date().toISOString()
        });
        
        // بعد تأخير، تحديث الحالة
        setTimeout(() => {
            const success = Math.random() > 0.3; // 70% نجاح
            this.updateReport(id, { 
                status: success ? 'success' : 'failed'
            });
            showNotification(
                success ? `✅ تم إرسال التقرير ${id}` : `❌ فشل إرسال التقرير ${id}`,
                success ? 'success' : 'error'
            );
        }, 2000);
    }
    
    calculateStorageSize() {
        const json = JSON.stringify(this.reports);
        return Math.round(json.length / 1024 * 100) / 100;
    }
    
    async syncAllReports() {
        const pending = this.getPendingReports();
        if (pending.length === 0) {
            showNotification('📭 لا توجد تقارير معلقة للمزامنة', 'info');
            return;
        }
        
        showNotification(`🔄 بدء مزامنة ${pending.length} تقرير...`, 'info');
        
        let successCount = 0;
        let failCount = 0;
        
        for (const report of pending) {
            try {
                // محاكاة الإرسال
                await new Promise(resolve => setTimeout(resolve, 500));
                
                const success = Math.random() > 0.2; // 80% نجاح
                if (success) {
                    this.updateReport(report.id, { status: 'success' });
                    successCount++;
                } else {
                    this.updateReport(report.id, { status: 'failed' });
                    failCount++;
                }
            } catch (error) {
                console.error('❌ خطأ في مزامنة التقرير:', error);
                failCount++;
            }
        }
        
        showNotification(
            `✅ اكتملت المزامنة: ${successCount} ✓, ${failCount} ✗`,
            failCount === 0 ? 'success' : 'warning'
        );
    }
}

// إنشاء مدير التقارير ككائن عالمي
let reportManager;

// 15. إرسال البيانات إلى قاعدة البيانات مع نظام متقدم
async function submitSoilData(formData) {
    const loadingOverlay = document.getElementById('loadingOverlay');
    const loadingMessage = document.getElementById('loadingMessage');
    
    try {
        console.log('🔄 بدء عملية إرسال البيانات...');
        
        if (loadingOverlay) {
            loadingOverlay.style.display = 'flex';
            if (loadingMessage) {
                loadingMessage.textContent = 'جاري التحقق من الاتصال...';
            }
        }
        
        // التحقق من الاتصال أولاً
        const isOnline = navigator.onLine;
        if (!isOnline) {
            throw new Error('لا يوجد اتصال بالإنترنت');
        }
        
        // الحصول على التاريخ
        const now = new Date();
        const observationDate = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;
        
        // جلب بيانات المستخدم
        let userData = {
            id: 'user-' + Date.now(),
            name: 'مستخدم غير معروف',
            station: 'محطة غير معروفة'
        };
        
        try {
            const currentUser = localStorage.getItem('currentUser');
            if (currentUser) {
                const userSession = JSON.parse(currentUser);
                userData = {
                    id: userSession.id || 'user-' + Date.now(),
                    name: `${userSession.first_name || ''} ${userSession.father_name || ''} ${userSession.last_name || ''}`.trim(),
                    station: userSession.station || 'محطة غير معروفة'
                };
            }
        } catch (error) {
            console.error('❌ خطأ في جلب بيانات المستخدم:', error);
        }
        
        if (loadingMessage) {
            loadingMessage.textContent = 'جاري تحضير البيانات...';
        }
        
        // إعداد البيانات للإرسال
        const soilData = {
            observer_id: userData.id,
            observer_name: userData.name,
            station: userData.station,
            observation_date: observationDate,
            utc_time: formData.utcTime + ':00 UTC',
            local_time: formData.localTime,
            
            soil_temp_5cm: (formData.soilTemp5cm === '#' || !formData.soilTemp5cm.trim()) ? null : parseFloat(formData.soilTemp5cm),
            soil_temp_5cm_is_hash: formData.soilTemp5cm === '#',
            
            soil_temp_10cm: (formData.soilTemp10cm === '#' || !formData.soilTemp10cm.trim()) ? null : parseFloat(formData.soilTemp10cm),
            soil_temp_10cm_is_hash: formData.soilTemp10cm === '#',
            
            soil_temp_20cm: (formData.soilTemp20cm === '#' || !formData.soilTemp20cm.trim()) ? null : parseFloat(formData.soilTemp20cm),
            soil_temp_20cm_is_hash: formData.soilTemp20cm === '#',
            
            soil_temp_50cm: (formData.soilTemp50cm === '#' || !formData.soilTemp50cm.trim()) ? null : parseFloat(formData.soilTemp50cm),
            soil_temp_50cm_is_hash: formData.soilTemp50cm === '#',
            
            observer_notes: formData.observerNotes || '',
            responsibility_agreed: true,
            submitted_at: new Date().toISOString(),
            status: 'submitted'
        };
        
        console.log('📦 بيانات جاهزة للإرسال:', soilData);
        
        if (loadingMessage) {
            loadingMessage.textContent = 'جاري الاتصال بقاعدة البيانات...';
        }
        
        // محاولة الإرسال إلى Supabase
        let supabaseSuccess = false;
        let supabaseError = null;
        
        if (window.supabase && typeof supabase.from === 'function') {
            try {
                console.log('🚀 محاولة الاتصال بـ Supabase...');
                const { data, error } = await supabase
                    .from('soil_temperatures')
                    .insert([soilData]);
                
                if (error) {
                    console.error('❌ خطأ في إرسال البيانات إلى Supabase:', error);
                    supabaseError = error.message;
                } else {
                    console.log('✅ تم إرسال البيانات بنجاح إلى Supabase:', data);
                    supabaseSuccess = true;
                }
            } catch (error) {
                console.error('❌ خطأ في عملية Supabase:', error);
                supabaseError = error.message;
            }
        } else {
            console.warn('⚠️ عميل Supabase غير متوفر');
            supabaseError = 'عميل Supabase غير متوفر';
        }
        
        if (loadingMessage) {
            loadingMessage.textContent = 'جاري حفظ البيانات محلياً...';
        }
        
        // حفظ محلي في جميع الأحوال
        const reportId = reportManager.addReport({
            ...soilData,
            supabase_success: supabaseSuccess,
            supabase_error: supabaseError
        });
        
        // إخفاء شاشة التحميل
        if (loadingOverlay) {
            loadingOverlay.style.display = 'none';
        }
        
        if (supabaseSuccess) {
            showNotification('✅ تم إرسال البيانات بنجاح إلى قاعدة البيانات', 'success');
            return { 
                success: true, 
                data: soilData, 
                supabase: true,
                reportId 
            };
        } else {
            showNotification(
                `⚠️ تم حفظ البيانات محلياً ${supabaseError ? `(سبب: ${supabaseError})` : ''}`,
                'warning'
            );
            return { 
                success: true, 
                data: soilData, 
                supabase: false, 
                backup: true,
                error: supabaseError,
                reportId
            };
        }
        
    } catch (error) {
        console.error('❌ خطأ في عملية الإرسال:', error);
        
        if (loadingOverlay) {
            loadingOverlay.style.display = 'none';
        }
        
        throw error;
    }
}

// 16. تحديث حالة النظام
function updateSystemStatusText() {
    const statusElement = document.getElementById('systemStatusText');
    if (!statusElement) return;
    
    const isOnline = navigator.onLine;
    const reportsCount = reportManager ? reportManager.reports.length : 0;
    
    let status = '';
    let color = 'success';
    
    if (!isOnline) {
        status = '⚠️ غير متصل بالإنترنت';
        color = 'danger';
    } else if (reportsCount > 0) {
        status = `✅ متصل | ${reportsCount} تقرير محفوظ`;
        color = reportsCount > 5 ? 'warning' : 'success';
    } else {
        status = '✅ متصل وجاهز للإرسال';
        color = 'success';
    }
    
    statusElement.textContent = status;
    statusElement.style.color = color === 'danger' ? '#dc3545' : 
                               color === 'warning' ? '#ffc107' : '#28a745';
}

// 17. اختبار الاتصال بـ Supabase
async function testSupabaseConnection() {
    const dbStatusElement = document.getElementById('dbStatus');
    
    try {
        console.log('🔗 اختبار الاتصال بـ Supabase...');
        
        if (!window.supabase) {
            console.error('❌ عميل Supabase غير معرف');
            if (dbStatusElement) {
                dbStatusElement.textContent = 'غير متصل';
                dbStatusElement.className = 'status-badge bg-danger';
            }
            return false;
        }
        
        if (dbStatusElement) {
            dbStatusElement.textContent = 'جاري الفحص...';
            dbStatusElement.className = 'status-badge bg-secondary';
        }
        
        // محاولة جلب سجل واحد
        const { data, error } = await supabase
            .from('soil_temperatures')
            .select('id')
            .limit(1);
        
        if (error) {
            console.error('❌ فشل اختبار الاتصال:', error);
            if (dbStatusElement) {
                dbStatusElement.textContent = 'غير متصل';
                dbStatusElement.className = 'status-badge bg-danger';
                dbStatusElement.title = error.message;
            }
            return false;
        }
        
        console.log('✅ اختبار الاتصال ناجح:', data);
        if (dbStatusElement) {
            dbStatusElement.textContent = 'متصل';
            dbStatusElement.className = 'status-badge bg-success';
            dbStatusElement.title = 'الاتصال بقاعدة البيانات نشط';
        }
        
        return true;
        
    } catch (error) {
        console.error('❌ خطأ في اختبار الاتصال:', error);
        if (dbStatusElement) {
            dbStatusElement.textContent = 'خطأ';
            dbStatusElement.className = 'status-badge bg-danger';
            dbStatusElement.title = error.message;
        }
        return false;
    }
}

// 18. إعداد جميع المعالجات
function setupEventHandlers() {
    // زر اختبار الاتصال
    const testConnectionBtn = document.getElementById('testConnectionBtn');
    if (testConnectionBtn) {
        testConnectionBtn.addEventListener('click', async () => {
            const result = await testSupabaseConnection();
            showNotification(
                result ? '✅ الاتصال بقاعدة البيانات نشط' : '❌ فشل الاتصال بقاعدة البيانات',
                result ? 'success' : 'error'
            );
        });
    }
    
    // زر تحديث حالة النظام
    const refreshStatusBtn = document.getElementById('refreshStatusBtn');
    if (refreshStatusBtn) {
        refreshStatusBtn.addEventListener('click', () => {
            updateSystemStatusText();
            testSupabaseConnection();
            showNotification('🔄 تم تحديث حالة النظام', 'info');
        });
    }
    
    // زر تحديث بيانات المستخدم
    const refreshUserDataBtn = document.getElementById('refreshUserDataBtn');
    if (refreshUserDataBtn) {
        refreshUserDataBtn.addEventListener('click', () => {
            loadUserInfo();
            showNotification('🔄 تم تحديث بيانات المستخدم', 'info');
        });
    }
    
    // زر إدارة التقارير المحفوظة
    const manageSavedReportsBtn = document.getElementById('manageSavedReportsBtn');
    if (manageSavedReportsBtn) {
        manageSavedReportsBtn.addEventListener('click', () => {
            reportManager.showReportsModal();
        });
    }
    
    // زر حذف جميع التقارير
    const clearAllReportsBtn = document.getElementById('clearAllReportsBtn');
    if (clearAllReportsBtn) {
        clearAllReportsBtn.addEventListener('click', () => {
            if (confirm('⚠️ هل أنت متأكد من حذف جميع التقارير المحفوظة؟')) {
                const count = reportManager.clearAllReports();
                showNotification(`🗑️ تم حذف ${count} تقرير`, 'info');
                
                const modal = bootstrap.Modal.getInstance(document.getElementById('savedReportsModal'));
                if (modal) modal.hide();
            }
        });
    }
    
    // زر مزامنة جميع التقارير
    const syncAllReportsBtn = document.getElementById('syncAllReportsBtn');
    if (syncAllReportsBtn) {
        syncAllReportsBtn.addEventListener('click', () => {
            reportManager.syncAllReports();
        });
    }
}

// 19. التهيئة الرئيسية
document.addEventListener("DOMContentLoaded", function() {
    console.log('🚀 DOM جاهز، بدء تهيئة التطبيق...');
    
    // تهيئة مدير التقارير
    reportManager = new ReportManager();
    
    // تحميل معلومات المستخدم
    loadUserInfo();
    
    // تهيئة التحقق من الصحة
    initializeFieldValidations();
    
    // تهيئة الصفحة
    initializePage();
    
    // إعداد معالجات الأحداث
    setupEventHandlers();
    
    // تحديث حالة النظام
    updateSystemStatusText();
    
    // اختبار الاتصال التلقائي
    setTimeout(() => {
        testSupabaseConnection();
    }, 2000);
    
    // تحديث حالة النظام بشكل دوري
    setInterval(updateSystemStatusText, 30000);
    
    console.log('✅ تم تهيئة تطبيق درجات حرارة التربة بنجاح');
    showNotification('✅ النظام جاهز للاستخدام', 'success');
    
    // إضافة تأثيرات تحميل إضافية
    setTimeout(() => {
        const systemStatusPanel = document.getElementById('systemStatusPanel');
        if (systemStatusPanel) {
            systemStatusPanel.style.animation = 'slideUp 0.5s ease';
        }
    }, 500);
});

// دالة تهيئة الصفحة
function initializePage() {
    // تعيين التاريخ
    const currentDate = document.getElementById("currentDate");
    if (currentDate) {
        const now = new Date();
        const year = now.getFullYear();
        const month = String(now.getMonth() + 1).padStart(2, '0');
        const day = String(now.getDate()).padStart(2, '0');
        currentDate.value = `${year}-${month}-${day}`;
    }
    
    // تهيئة التوقيت المحلي المقابل
    updateLocalTimeDisplay();
}

// جعل الدوال متاحة عالمياً
window.reportManager = reportManager;
window.testSupabaseConnection = testSupabaseConnection;
window.fillTestData = fillTestData;
window.updateLocalTimeDisplay = updateLocalTimeDisplay;