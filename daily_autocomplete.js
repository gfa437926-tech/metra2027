// daily_autocomplete.js - الاستكمال التلقائي للحقول بعد الخروج

document.addEventListener('DOMContentLoaded', function() {
    initAutoComplete();
});

function initAutoComplete() {
    const autoCompleteFields = [
        // الرطوبة النسبة %
        { id: 'humidityPercentage', type: 'percentage3', min: 0, max: 100, digits: 0 },
        
        // ضغط بخار الماء
        { id: 'vaporPressure', type: 'generic3', min: 0, max: 999, digits: 0 },
        
        // درجة الندى
        { id: 'dewPoint', type: 'temperature3', min: -20, max: 50, digits: 1 },
        
        // ضغط المحطة
        { id: 'stationPressure', type: 'pressure', min: 850.0, max: 1050.0, digits: 1 },
        
        // الضغط المحول لسطح البحر
        { id: 'seaLevelPressure', type: 'pressure', min: 850.0, max: 1050.0, digits: 1 },
        
        // درجة الحرارة الجافة
        { id: 'dryTemperature', type: 'temperature', min: -20.0, max: 50.0, digits: 1 },
        
        // درجة الحرارة الرطبة
        { id: 'wetTemperature', type: 'temperature', min: -20.0, max: 50.0, digits: 1 },
        
        // اتجاه الرياح السطحية
        { id: 'windDirection', type: 'direction', min: 0, max: 36, digits: 0 },
        
        // سرعة الرياح السطحية
        { id: 'windSpeed', type: 'speed', min: 0, max: 36, digits: 0 },
        
        // اتجاه المتوسط الساعي للرياح
        { id: 'avgWindDirection', type: 'direction', min: 0, max: 36, digits: 0 },
        
        // سرعة المتوسط الساعي للرياح
        { id: 'avgWindSpeed', type: 'speed', min: 0, max: 36, digits: 0 },
        
        // الرؤية السطحية
        { id: 'visibility', type: 'visibility', min: 0, max: 200, digits: 0 },
        
        // الطقس الحاضر
        { id: 'currentWeather', type: 'weather', min: 0, max: 99, digits: 0 },
        
        // الطقس الغابر
        { id: 'pastWeather', type: 'pastWeather', min: 0, max: 9, digits: 0 }
    ];

    autoCompleteFields.forEach(fieldConfig => {
        const field = document.getElementById(fieldConfig.id);
        if (field) {
            field.addEventListener('blur', function() {
                // إذا كانت القيمة # لا نطبق الاستكمال التلقائي
                if (this.value !== '#') {
                    autoCompleteField(this, fieldConfig);
                }
            });
            
            // تطبيق الاستكمال التلقائي على القيم الحالية
            if (field.value && field.value !== '#') {
                autoCompleteField(field, fieldConfig);
            }
        }
    });
}

function autoCompleteField(field, config) {
    let value = field.value.trim();
    let originalValue = value;
    
    if (!value || value === '#') return;
    
    // تنظيف القيمة من الأحرف غير المرغوبة
    value = value.replace(/[^\d.-]/g, '');
    
    let completedValue = '';
    let reason = '';
    
    switch(config.type) {
        case 'percentage3':
            completedValue = completePercentage3(value, config);
            reason = 'النسبة المئوية للرطوبة يجب أن تكون بين 000 و 100';
            break;
            
        case 'generic3':
            completedValue = completeGeneric3(value, config);
            reason = 'ضغط بخار الماء يجب أن يكون مكوناً من 3 أرقام';
            break;
            
        case 'temperature3':
            completedValue = completeTemperature3(value, config);
            reason = 'درجة الندى يجب أن تكون بين -20 و +50 بصيغة ±ddd';
            break;
            
        case 'pressure':
            completedValue = completePressure(value, config);
            reason = 'ضغط المحطة يجب أن يكون بين 0850.0 و 1050.0 بصيغة dddd.d';
            break;
            
        case 'temperature':
            completedValue = completeTemperature(value, config);
            reason = 'درجة الحرارة يجب أن تكون بين -20.0 و +50.0 بصيغة ±dd.d';
            break;
            
        case 'direction':
            completedValue = completeDirection(value, config);
            reason = 'اتجاه الرياح يجب أن يكون بين 00 و 36';
            break;
            
        case 'speed':
            completedValue = completeSpeed(value, config);
            reason = 'سرعة الرياح يجب أن تكون بين 00 و 36';
            break;
            
        case 'visibility':
            completedValue = completeVisibility(value, config);
            reason = 'الرؤية يجب أن تكون بين 000 و 200';
            break;
            
        case 'weather':
            completedValue = completeWeather(value, config);
            reason = 'الطقس الحاضر يجب أن يكون بين 00 و 99';
            break;
            
        case 'pastWeather':
            completedValue = completePastWeather(value, config);
            reason = 'الطقس الغابر يجب أن يكون بين 0 و 9';
            break;
            
        default:
            completedValue = value;
    }
    
    if (completedValue !== originalValue) {
        field.value = completedValue;
        showAutoCompleteReason(field, reason);
        
        // تشغيل التحقق بعد الاستكمال
        if (typeof validateField === 'function') {
            validateField({ target: field });
        }
    }
}

// استكمال النسبة المئوية 3 أرقام
function completePercentage3(value, config) {
    let numValue = parseInt(value);
    if (isNaN(numValue)) return value;
    
    // التأكد من النطاق
    if (numValue > config.max) numValue = config.max;
    if (numValue < config.min) numValue = config.min;
    
    // تنسيق الأرقام
    if (value.length === 1) {
        // إذا أدخل رقم واحد فقط، أضف صفرين
        return '0' + numValue.toString() + '0';
    } else if (value.length === 2) {
        // إذا أدخل رقمين، أضف صفر في النهاية
        return numValue.toString() + '0';
    } else {
        // إذا أدخل 3 أرقام، تأكد من التنسيق الصحيح
        return numValue.toString().padStart(3, '0');
    }
}

// استكمال القيم العامة المكونة من 3 أرقام
function completeGeneric3(value, config) {
    let numValue = parseInt(value);
    if (isNaN(numValue)) return value;
    
    if (numValue > config.max) numValue = config.max;
    if (numValue < config.min) numValue = config.min;
    
    return numValue.toString().padStart(3, '0');
}

// استكمال درجة الندى (3 أرقام مع إشارة)
function completeTemperature3(value, config) {
    let numValue = parseFloat(value);
    if (isNaN(numValue)) return value;
    
    // تحديد الإشارة
    const sign = numValue < 0 ? '-' : '+';
    numValue = Math.abs(numValue);
    
    if (numValue > config.max) numValue = config.max;
    if (numValue < 0.1) numValue = 0;
    
    // تنسيق لـ 3 أرقام مع الإشارة
    const integerPart = Math.floor(numValue).toString().padStart(2, '0');
    const decimalPart = numValue.toFixed(config.digits).split('.')[1] || '0'.padEnd(config.digits, '0');
    
    return `${sign}${integerPart}.${decimalPart}`;
}

// استكمال الضغط (4 أرقام + عشري)
function completePressure(value, config) {
    let numValue = parseFloat(value);
    if (isNaN(numValue)) return value;
    
    if (numValue > config.max) numValue = config.max;
    if (numValue < config.min) numValue = config.min;
    
    const integerPart = Math.floor(numValue).toString().padStart(4, '0');
    const decimalPart = numValue.toFixed(config.digits).split('.')[1] || '0'.padEnd(config.digits, '0');
    
    return `${integerPart}.${decimalPart}`;
}

// استكمال درجة الحرارة (2 أرقام + عشري)
function completeTemperature(value, config) {
    let numValue = parseFloat(value);
    if (isNaN(numValue)) return value;
    
    const sign = numValue < 0 ? '-' : '+';
    numValue = Math.abs(numValue);
    
    if (numValue > config.max) numValue = config.max;
    if (numValue < 0.1) numValue = 0;
    
    const integerPart = Math.floor(numValue).toString().padStart(2, '0');
    const decimalPart = numValue.toFixed(config.digits).split('.')[1] || '0'.padEnd(config.digits, '0');
    
    return `${sign}${integerPart}.${decimalPart}`;
}

// استكمال الاتجاه
function completeDirection(value, config) {
    let numValue = parseInt(value);
    if (isNaN(numValue)) return value;
    
    if (numValue > config.max) numValue = config.max;
    if (numValue < config.min) numValue = config.min;
    
    return numValue.toString().padStart(2, '0');
}

// استكمال السرعة
function completeSpeed(value, config) {
    return completeDirection(value, config);
}

// استكمال الرؤية
function completeVisibility(value, config) {
    let numValue = parseInt(value);
    if (isNaN(numValue)) return value;
    
    if (numValue > config.max) numValue = config.max;
    if (numValue < config.min) numValue = config.min;
    
    return numValue.toString().padStart(3, '0');
}

// استكمال الطقس الحاضر
function completeWeather(value, config) {
    let numValue = parseInt(value);
    if (isNaN(numValue)) return value;
    
    if (numValue > config.max) numValue = config.max;
    if (numValue < config.min) numValue = config.min;
    
    return numValue.toString().padStart(2, '0');
}

// استكمال الطقس الغابر
function completePastWeather(value, config) {
    let numValue = parseInt(value);
    if (isNaN(numValue)) return value;
    
    if (numValue > config.max) numValue = config.max;
    if (numValue < config.min) numValue = config.min;
    
    return numValue.toString();
}

// إظهار سبب الاستكمال التلقائي
function showAutoCompleteReason(field, reason) {
    // إزالة أي رسالة سابقة
    const existingReason = field.parentNode.querySelector('.auto-complete-reason');
    if (existingReason) {
        existingReason.remove();
    }
    
    // إنشاء رسالة جديدة
    const reasonElement = document.createElement('div');
    reasonElement.className = 'auto-complete-reason alert alert-info mt-2';
    reasonElement.style.cssText = `
        font-size: 0.8rem;
        padding: 5px 10px;
        margin-top: 5px;
    `;
    reasonElement.innerHTML = `
        <i class="fas fa-info-circle me-1"></i>
        <strong>تم الاستكمال التلقائي:</strong> ${reason}
    `;
    
    field.parentNode.appendChild(reasonElement);
    
    // إزالة الرسالة بعد 5 ثوانٍ
    setTimeout(() => {
        if (reasonElement.parentNode) {
            reasonElement.remove();
        }
    }, 5000);
}

// جعل الدوال متاحة globally
window.initAutoComplete = initAutoComplete;
window.autoCompleteField = autoCompleteField;