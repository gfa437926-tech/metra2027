// agricultural_validation_fix.js - إصلاح كامل لنظام التحقق من الصحة
console.log('🔧 تحميل إصلاحات نظام التحقق من الصحة...');

// ===== نظام التحقق المصحح لدرجات الحرارة =====
const TemperatureValidator = {
    // نمط مرن لدرجات الحرارة
    pattern: /^[+-]?\d{1,2}(\.\d)?$/,
    
    // التحقق من صحة درجة الحرارة
    isValid(value) {
        if (!value || value.trim() === '') {
            return { valid: false, error: 'هذا الحقل مطلوب' };
        }
        
        const trimmed = value.trim();
        
        // التحقق من النمط
        if (!this.pattern.test(trimmed)) {
            return { 
                valid: false, 
                error: 'تنسيق درجة الحرارة غير صحيح. أمثلة: +25.5, -05.3, 25.5, +5' 
            };
        }
        
        // استخراج القيمة العددية
        let numericValue;
        try {
            numericValue = parseFloat(trimmed);
        } catch (e) {
            return { 
                valid: false, 
                error: 'القيمة يجب أن تكون رقمية' 
            };
        }
        
        // التحقق من النطاق
        if (numericValue < -20 || numericValue > 60) {
            return { 
                valid: false, 
                error: `درجة الحرارة ${numericValue} خارج النطاق المسموح (-20 إلى 60)` 
            };
        }
        
        return { valid: true, value: this.formatValue(trimmed) };
    },
    
    // تنسيق القيمة
    formatValue(value) {
        let formatted = value.trim();
        
        // إضافة إشارة + إذا كانت القيمة تبدأ برقم
        if (/^\d/.test(formatted) && !formatted.startsWith('+') && !formatted.startsWith('-')) {
            formatted = '+' + formatted;
        }
        
        // التأكد من وجود نقطة عشرية
        if (!formatted.includes('.')) {
            formatted = formatted + '.0';
        } else {
            // التأكد من أن الجزء العشري به رقم واحد فقط
            const parts = formatted.split('.');
            if (parts.length === 2) {
                const integerPart = parts[0];
                let decimalPart = parts[1];
                
                if (decimalPart.length > 1) {
                    decimalPart = decimalPart.substring(0, 1);
                }
                
                formatted = integerPart + '.' + decimalPart;
            }
        }
        
        // إذا كان الجزء الصحيح به رقم واحد فقط
        const parts = formatted.split('.');
        const integerWithSign = parts[0];
        const integerWithoutSign = integerWithSign.replace(/[+-]/g, '');
        
        if (integerWithoutSign.length === 1 && integerWithoutSign !== '0') {
            const sign = integerWithSign.startsWith('-') ? '-' : '+';
            formatted = sign + '0' + integerWithoutSign + '.' + (parts[1] || '0');
        }
        
        return formatted;
    },
    
    // تطبيق التنسيق على حقل
    formatField(field) {
        if (!field.value.trim()) return;
        
        const originalValue = field.value;
        const formattedValue = this.formatValue(originalValue);
        
        if (formattedValue !== originalValue) {
            field.value = formattedValue;
            field.classList.add('auto-formatted');
            
            setTimeout(() => {
                if (document.activeElement !== field) {
                    field.classList.remove('auto-formatted');
                }
            }, 2000);
        }
    }
};

// ===== إصلاح نظام التحقق الأساسي =====
function initFixedValidation() {
    console.log('🔄 تهيئة نظام التحقق المصحح...');
    
    // تحديث أنماط HTML
    updateFieldPatterns();
    
    // إضافة مستمعات الأحداث
    setupFixedEventListeners();
    
    // استبدال وظائف التحقق
    overrideValidationFunctions();
    
    console.log('✅ تم تهيئة نظام التحقق المصحح');
}

// تحديث أنماط الحقول في HTML
function updateFieldPatterns() {
    const temperatureFields = [
        'avgAirTemp', 'maxAirTemp', 'minAirTemp', 'minTemp2m',
        'maxSoilSurfaceTemp', 'minSoilSurfaceTemp', 'avgSoilTemp5cm',
        'avgSoilTemp10cm', 'avgSoilTemp20cm', 'avgSoilTemp50cm',
        'fieldSoilTemp5cm', 'fieldSoilTemp10cm'
    ];
    
    temperatureFields.forEach(fieldId => {
        const field = document.getElementById(fieldId);
        if (field) {
            field.setAttribute('pattern', '^[+-]?\\d{1,2}(\\.\\d)?$');
            field.setAttribute('maxlength', '6');
            field.setAttribute('title', 'درجة الحرارة: ±dd.d أو ±d.d (مثال: +25.5 أو -5.3 أو 25.5)');
            console.log(`✅ تم تحديث حقل: ${fieldId}`);
        }
    });
}

// إعداد مستمعات الأحداث المصححة
function setupFixedEventListeners() {
    // حقول درجات الحرارة
    const temperatureFields = document.querySelectorAll('.temperature-input');
    temperatureFields.forEach(field => {
        // إزالة المستمعات القديمة
        const newField = field.cloneNode(true);
        field.parentNode.replaceChild(newField, field);
        
        // إضافة مستمعات جديدة
        newField.addEventListener('blur', function() {
            TemperatureValidator.formatField(this);
            validateFieldFixed(this.id);
        });
        
        newField.addEventListener('input', function() {
            this.classList.remove('field-invalid', 'field-valid', 'auto-formatted');
            const errorElement = document.getElementById(this.id + 'Error');
            if (errorElement) errorElement.style.display = 'none';
        });
    });
    
    // الحقول الأخرى
    const otherFields = document.querySelectorAll('.input-mask:not(.temperature-input)');
    otherFields.forEach(field => {
        field.addEventListener('blur', function() {
            validateFieldFixed(this.id);
        });
    });
    
    // القوائم المنسدلة
    const selectFields = ['dew', 'fog', 'hail', 'sandstorm'];
    selectFields.forEach(fieldId => {
        const field = document.getElementById(fieldId);
        if (field) {
            field.addEventListener('change', function() {
                validateSelectField(this);
            });
        }
    });
}

// التحقق المصحح للحقل
function validateFieldFixed(fieldId) {
    const field = document.getElementById(fieldId);
    if (!field) return true;
    
    const value = field.value.trim();
    
    // إذا كان حقل درجة حرارة
    if (field.classList.contains('temperature-input')) {
        const result = TemperatureValidator.isValid(value);
        
        if (result.valid) {
            showFieldSuccessFixed(field);
            return true;
        } else {
            showFieldErrorFixed(field, result.error);
            return false;
        }
    }
    
    // الحقول الأخرى
    const rules = getFixedValidationRules()[fieldId];
    if (!rules) return true;
    
    // إذا كان الحقل مطلوباً وفارغاً
    if (rules.required && !value) {
        showFieldErrorFixed(field, 'هذا الحقل مطلوب');
        return false;
    }
    
    // إذا كان الحقل غير مطلوب وفارغ
    if (!rules.required && !value) {
        clearFieldValidationFixed(field);
        return true;
    }
    
    // التحقق من النمط
    if (rules.pattern && !rules.pattern.test(value)) {
        let errorMsg = '';
        
        switch(rules.type) {
            case 'humidity':
                errorMsg = 'يجب إدخال الرطوبة بصيغة: 3 أرقام (مثال: 075 أو 085 أو 100)';
                break;
            case 'decimal':
                errorMsg = 'يجب إدخال القيمة بصيغة: dd.d (رقمان صحيحان ورقم عشري واحد)';
                break;
            case 'integer':
                errorMsg = 'يجب إدخال رقمين صحيحين';
                break;
            case 'precipitation':
                errorMsg = 'يجب إدخال الهطول بصيغة: ddd.d (3 أرقام صحيحة ورقم عشري واحد)';
                break;
            default:
                errorMsg = 'الصيغة غير صحيحة';
        }
        
        showFieldErrorFixed(field, errorMsg);
        return false;
    }
    
    // التحقق من النطاق
    if (rules.min !== undefined || rules.max !== undefined) {
        const numericValue = parseFloat(value.replace(/[^0-9.]/g, ''));
        
        if (isNaN(numericValue)) {
            showFieldErrorFixed(field, 'القيمة يجب أن تكون رقمية');
            return false;
        }
        
        if (rules.min !== undefined && numericValue < rules.min) {
            showFieldErrorFixed(field, `القيمة ${numericValue} أقل من الحد الأدنى (${rules.min})`);
            return false;
        }
        
        if (rules.max !== undefined && numericValue > rules.max) {
            showFieldErrorFixed(field, `القيمة ${numericValue} أكبر من الحد الأقصى (${rules.max})`);
            return false;
        }
    }
    
    showFieldSuccessFixed(field);
    return true;
}

// التحقق من الحقل المنقوطة
function validateSelectField(field) {
    const value = field.value;
    
    if (!value || value === '') {
        showFieldErrorFixed(field, 'يرجى اختيار قيمة');
        return false;
    }
    
    showFieldSuccessFixed(field);
    return true;
}

// قواعد التحقق المصححة
function getFixedValidationRules() {
    return {
        // درجات الحرارة - تم التعامل معها بواسطة TemperatureValidator
        
        // الرطوبة النسبية
        avgHumidity: { 
            pattern: /^\d{3}$/,
            min: 0,
            max: 100,
            required: true,
            type: 'humidity'
        },
        minHumidity: { 
            pattern: /^\d{3}$/,
            min: 0,
            max: 100,
            required: false,
            type: 'humidity'
        },
        
        // القيم العشرية
        avgEsE: { 
            pattern: /^\d{1,2}\.\d$/,
            min: 0.0,
            max: 99.9,
            required: false,
            type: 'decimal'
        },
        minEsE: { 
            pattern: /^\d{1,2}\.\d$/,
            min: 0.0,
            max: 99.9,
            required: false,
            type: 'decimal'
        },
        sunshineHours: { 
            pattern: /^\d{1,2}\.\d$/,
            min: 0.0,
            max: 12.0,
            required: false,
            type: 'decimal'
        },
        classAEvaporation: { 
            pattern: /^\d{1,2}\.\d$/,
            min: 0.0,
            max: 99.9,
            required: false,
            type: 'decimal'
        },
        avgWindSpeed2m: { 
            pattern: /^\d{1,2}\.\d$/,
            min: 0.0,
            max: 36.0,
            required: false,
            type: 'decimal'
        },
        logEvaporation: { 
            pattern: /^\d{1,2}\.\d$/,
            min: 0.0,
            max: 99.9,
            required: false,
            type: 'decimal'
        },
        
        // القيم الصحيحة
        totalCloudCover: { 
            pattern: /^\d{1,2}$/,
            min: 0,
            max: 8,
            required: false,
            type: 'integer'
        },
        lowCloudCover: { 
            pattern: /^\d{1,2}$/,
            min: 0,
            max: 8,
            required: false,
            type: 'integer'
        },
        maxWindSpeed: { 
            pattern: /^\d{1,2}$/,
            min: 0,
            max: 36,
            required: false,
            type: 'integer'
        },
        
        // الهطول
        precipitation: { 
            pattern: /^\d{1,3}\.\d$/,
            min: 0.0,
            max: 999.9,
            required: false,
            type: 'precipitation'
        }
    };
}

// إظهار خطأ مصحح
function showFieldErrorFixed(field, message) {
    field.classList.remove('field-valid');
    field.classList.add('field-invalid');
    
    const errorElement = document.getElementById(field.id + 'Error');
    if (errorElement) {
        errorElement.textContent = message;
        errorElement.style.display = 'block';
    }
    
    const successElement = document.getElementById(field.id + 'Success');
    if (successElement) {
        successElement.style.display = 'none';
    }
}

// إظهار نجاح مصحح
function showFieldSuccessFixed(field) {
    field.classList.remove('field-invalid');
    field.classList.add('field-valid');
    
    const errorElement = document.getElementById(field.id + 'Error');
    if (errorElement) {
        errorElement.style.display = 'none';
    }
    
    const successElement = document.getElementById(field.id + 'Success');
    if (successElement) {
        successElement.textContent = '✓ صحيح';
        successElement.style.display = 'block';
    }
}

// مسح التحقق
function clearFieldValidationFixed(field) {
    field.classList.remove('field-invalid', 'field-valid');
    
    const errorElement = document.getElementById(field.id + 'Error');
    if (errorElement) {
        errorElement.style.display = 'none';
    }
    
    const successElement = document.getElementById(field.id + 'Success');
    if (successElement) {
        successElement.style.display = 'none';
    }
}

// ===== استبدال وظائف التحقق =====
function overrideValidationFunctions() {
    console.log('🔄 استبدال وظائف التحقق...');
    
    // استبدال validateForm
    if (window.validateForm) {
        window.validateForm = validateFormFixed;
    }
    
    // استبدال validateField
    if (window.validateField) {
        window.validateField = validateFieldFixed;
    }
    
    // استبدال collectFormData
    if (window.collectFormData) {
        window.collectFormData = collectFormDataFixed;
    }
    
    // إضافة وظيفة اختبار
    window.testValidation = testValidationFixed;
}

// التحقق المصحح من النموذج
function validateFormFixed() {
    console.log('🔍 بدء التحقق المصحح من النموذج...');
    
    let isValid = true;
    let firstErrorField = null;
    
    // التحقق من الحقول المطلوبة
    const requiredFields = [
        'avgAirTemp', 'maxAirTemp', 'minAirTemp',
        'avgHumidity', 'dew', 'fog', 'hail', 'sandstorm'
    ];
    
    for (const fieldId of requiredFields) {
        const field = document.getElementById(fieldId);
        if (field) {
            const value = field.value ? field.value.trim() : '';
            
            if (!value) {
                isValid = false;
                firstErrorField = fieldId;
                showFieldErrorFixed(field, 'هذا الحقل مطلوب');
                break;
            }
        }
    }
    
    // إذا كان هناك خطأ، توقف هنا
    if (!isValid && firstErrorField) {
        const errorField = document.getElementById(firstErrorField);
        if (errorField) {
            errorField.scrollIntoView({ behavior: 'smooth', block: 'center' });
            errorField.focus();
            showNotification('يوجد حقل مطلوب فارغ', 'error');
        }
        return false;
    }
    
    // التحقق من جميع حقول درجة الحرارة
    const temperatureFields = [
        'avgAirTemp', 'maxAirTemp', 'minAirTemp', 'minTemp2m',
        'maxSoilSurfaceTemp', 'minSoilSurfaceTemp'
    ];
    
    for (const fieldId of temperatureFields) {
        const field = document.getElementById(fieldId);
        if (field && field.value.trim()) {
            if (!validateFieldFixed(fieldId)) {
                isValid = false;
                firstErrorField = fieldId;
                break;
            }
        }
    }
    
    // التحقق من الرطوبة
    const humidityFields = ['avgHumidity', 'minHumidity'];
    for (const fieldId of humidityFields) {
        const field = document.getElementById(fieldId);
        if (field && field.value.trim()) {
            if (!validateFieldFixed(fieldId)) {
                isValid = false;
                firstErrorField = fieldId;
                break;
            }
        }
    }
    
    // التحقق من القوائم المنسدلة
    const selectFields = ['dew', 'fog', 'hail', 'sandstorm'];
    for (const fieldId of selectFields) {
        if (!validateSelectField(document.getElementById(fieldId))) {
            isValid = false;
            firstErrorField = fieldId;
            break;
        }
    }
    
    // التحقق من المسؤولية
    const agreement = document.getElementById('responsibilityAgreement');
    if (!agreement.checked) {
        isValid = false;
        showNotification('يجب الموافقة على بيان المسؤولية قبل الإرسال', 'error');
        
        if (!firstErrorField) {
            agreement.scrollIntoView({ behavior: 'smooth', block: 'center' });
            agreement.focus();
        }
    }
    
    // التنقل إلى أول حقل خاطئ
    if (!isValid && firstErrorField) {
        const errorField = document.getElementById(firstErrorField);
        if (errorField) {
            errorField.scrollIntoView({ behavior: 'smooth', block: 'center' });
            errorField.focus();
            showNotification('يوجد أخطاء في البيانات، يرجى تصحيحها قبل الإرسال', 'error');
        }
    }
    
    console.log(`✅ التحقق من النموذج: ${isValid ? 'ناجح' : 'فشل'}`);
    return isValid;
}

// جمع البيانات المصحح
function collectFormDataFixed() {
    const userStation = document.getElementById('userStation').textContent;
    const userName = document.getElementById('userName').textContent;
    const userRole = document.getElementById('userRole').textContent;
    
    const formData = {
        // بيانات المستخدم
        user_id: window.currentUserData?.id || 'unknown',
        user_name: userName,
        user_station: userStation,
        user_role: userRole,
        user_email: window.currentUserData?.email || 'unknown@example.com',
        
        // درجات الحرارة - مع التنسيق
        avgAirTemp: formatTemperatureForSubmission(document.getElementById('avgAirTemp')?.value || ''),
        maxAirTemp: formatTemperatureForSubmission(document.getElementById('maxAirTemp')?.value || ''),
        minAirTemp: formatTemperatureForSubmission(document.getElementById('minAirTemp')?.value || ''),
        minTemp2m: formatTemperatureForSubmission(document.getElementById('minTemp2m')?.value || ''),
        maxSoilSurfaceTemp: formatTemperatureForSubmission(document.getElementById('maxSoilSurfaceTemp')?.value || ''),
        minSoilSurfaceTemp: formatTemperatureForSubmission(document.getElementById('minSoilSurfaceTemp')?.value || ''),
        avgSoilTemp5cm: formatTemperatureForSubmission(document.getElementById('avgSoilTemp5cm')?.value || ''),
        avgSoilTemp10cm: formatTemperatureForSubmission(document.getElementById('avgSoilTemp10cm')?.value || ''),
        avgSoilTemp20cm: formatTemperatureForSubmission(document.getElementById('avgSoilTemp20cm')?.value || ''),
        avgSoilTemp50cm: formatTemperatureForSubmission(document.getElementById('avgSoilTemp50cm')?.value || ''),
        fieldSoilTemp5cm: formatTemperatureForSubmission(document.getElementById('fieldSoilTemp5cm')?.value || ''),
        fieldSoilTemp10cm: formatTemperatureForSubmission(document.getElementById('fieldSoilTemp10cm')?.value || ''),
        
        // بقية البيانات
        avgHumidity: document.getElementById('avgHumidity')?.value || '',
        minHumidity: document.getElementById('minHumidity')?.value || '',
        avgEsE: document.getElementById('avgEsE')?.value || '',
        minEsE: document.getElementById('minEsE')?.value || '',
        sunshineHours: document.getElementById('sunshineHours')?.value || '',
        totalCloudCover: document.getElementById('totalCloudCover')?.value || '',
        lowCloudCover: document.getElementById('lowCloudCover')?.value || '',
        precipitation: document.getElementById('precipitation')?.value || '',
        maxWindSpeed: document.getElementById('maxWindSpeed')?.value || '',
        classAEvaporation: document.getElementById('classAEvaporation')?.value || '',
        avgWindSpeed2m: document.getElementById('avgWindSpeed2m')?.value || '',
        logEvaporation: document.getElementById('logEvaporation')?.value || '',
        dew: document.getElementById('dew')?.value || '',
        fog: document.getElementById('fog')?.value || '',
        hail: document.getElementById('hail')?.value || '',
        sandstorm: document.getElementById('sandstorm')?.value || '',
        observerNotes: document.getElementById('observerNotes')?.value || '',
        
        // بيانات إضافية
        currentDate: document.getElementById('currentDate')?.value || '',
        reportDate: document.getElementById('reportDate')?.value || ''
    };
    
    return formData;
}

// تنسيق درجة الحرارة للإرسال
function formatTemperatureForSubmission(value) {
    if (!value || value.trim() === '') {
        return '';
    }
    
    const result = TemperatureValidator.isValid(value);
    if (result.valid) {
        return result.value;
    }
    
    return value.trim();
}

// ===== اختبار التحقق =====
function testValidationFixed() {
    console.log('🧪 اختبار نظام التحقق المصحح...');
    
    const testCases = [
        { id: 'avgAirTemp', value: '+25.5', expected: true },
        { id: 'maxAirTemp', value: '-05.3', expected: true },
        { id: 'minAirTemp', value: '25.5', expected: true },
        { id: 'avgHumidity', value: '075', expected: true },
        { id: 'avgHumidity', value: 'abc', expected: false },
        { id: 'dew', value: '1', expected: true }
    ];
    
    let passed = 0;
    let failed = 0;
    
    testCases.forEach(testCase => {
        const field = document.getElementById(testCase.id);
        if (field) {
            field.value = testCase.value;
            const isValid = validateFieldFixed(testCase.id);
            
            if (isValid === testCase.expected) {
                passed++;
                console.log(`✅ ${testCase.id}: ${testCase.value} - ${isValid ? 'صحيح' : 'خطأ'}`);
            } else {
                failed++;
                console.log(`❌ ${testCase.id}: ${testCase.value} - متوقع ${testCase.expected ? 'صحيح' : 'خطأ'}, حصل على ${isValid ? 'صحيح' : 'خطأ'}`);
            }
        }
    });
    
    console.log(`📊 النتائج: ${passed} نجاح، ${failed} فشل`);
    return passed === testCases.length;
}

// ===== تهيئة الزر السريع =====
function setupQuickFixButton() {
    const quickFixBtn = document.getElementById('quickFixBtn');
    if (quickFixBtn) {
        quickFixBtn.addEventListener('click', function() {
            initFixedValidation();
            showNotification('✅ تم إصلاح نظام التحقق من درجات الحرارة', 'success');
            
            // اختبار البيانات التجريبية
            const testBtn = document.getElementById('testDataBtn');
            if (testBtn) {
                setTimeout(() => {
                    testBtn.click();
                    console.log('✅ تم تعبئة البيانات التجريبية');
                }, 500);
            }
        });
    }
}

// ===== التهيئة التلقائية =====
document.addEventListener('DOMContentLoaded', function() {
    console.log('🚀 بدء إصلاحات التحقق...');
    
    // الانتظار حتى تحميل الصفحة بالكامل
    setTimeout(() => {
        // تطبيق الإصلاحات
        initFixedValidation();
        
        // إعداد زر الإصلاح السريع
        setupQuickFixButton();
        
        // اختبار النظام
        testValidationFixed();
        
        console.log('✅ تم تطبيق إصلاحات التحقق بنجاح');
    }, 2000);
});

// ===== التصدير =====
window.TemperatureValidator = TemperatureValidator;
window.validateFormFixed = validateFormFixed;
window.validateFieldFixed = validateFieldFixed;
window.initFixedValidation = initFixedValidation;
window.testValidationFixed = testValidationFixed;

console.log('🔧 نظام التحقق المصحح جاهز للاستخدام');