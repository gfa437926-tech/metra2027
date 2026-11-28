// daily_validation.js - التحقق من صحة البيانات مع تصحيح تنسيق الإشارة

document.addEventListener('DOMContentLoaded', function() {
    initValidation();
    console.log('✅ تم تهيئة نظام التحقق من الصحة');
});

// تهيئة التحقق من الصحة
function initValidation() {
    // إضافة مستمعات الأحداث لحقول الإدخال
    const inputFields = document.querySelectorAll('input[type="text"], input[type="number"], textarea');
    inputFields.forEach(field => {
        field.addEventListener('blur', function() {
            // إذا كانت القيمة # لا نتحقق منها
            if (this.value !== '#') {
                // تطبيق التنسيق التلقائي أولاً
                if (typeof formatFieldOnBlur === 'function') {
                    formatFieldOnBlur(this);
                }
                // ثم التحقق من الصحة
                validateField(this);
            } else {
                // إذا كانت القيمة #، نعتبرها صحيحة
                markFieldAsValid(this);
            }
        });
        
        field.addEventListener('input', function() {
            clearFieldError(this);
        });
        
        // إضافة مستمع للضغط على Enter
        field.addEventListener('keydown', function(e) {
            if (e.key === 'Enter' && this.value !== '#') {
                e.preventDefault();
                if (typeof formatFieldOnBlur === 'function') {
                    formatFieldOnBlur(this);
                }
                validateField(this);
                
                // الانتقال للحقل التالي
                const form = this.closest('form');
                const inputs = Array.from(form.querySelectorAll('input, textarea, select'));
                const index = inputs.indexOf(this);
                if (index !== -1 && index < inputs.length - 1) {
                    inputs[index + 1].focus();
                }
            }
        });
    });
    
    // التحقق من علاقة درجات الحرارة
    const tempFields = ['minTemp', 'maxTemp'];
    tempFields.forEach(fieldId => {
        const field = document.getElementById(fieldId);
        if (field) {
            field.addEventListener('blur', validateTemperatureRelation);
        }
    });
}

// التحقق من حقل معين (محدث لدعم القيمة #)
function validateField(field) {
    const value = field.value.trim();
    const fieldId = field.id;
    
    // إذا كانت القيمة #، فهي صحيحة
    if (value === '#') {
        markFieldAsValid(field);
        return true;
    }
    
    // إذا كان الحقل فارغاً، لا نتحقق منه (ما لم يكن مطلوباً)
    if (!value && !field.hasAttribute('required')) {
        clearFieldError(field);
        return true;
    }
    
    // إذا كان الحقل مطلوباً وفارغاً
    if (!value && field.hasAttribute('required')) {
        markFieldAsInvalid(field, 'هذا الحقل مطلوب');
        return false;
    }
    
    let isValid = true;
    let errorMessage = '';
    
    switch(fieldId) {
        case 'minTemp':
        case 'maxTemp':
            isValid = validateTemperature(value);
            if (!isValid) {
                errorMessage = 'يجب إدخال درجة حرارة بصيغة -dd.d أو dd.d (مثال: -05.3 أو 25.7) - الإشارة قبل الرقم الصحيح';
            }
            break;
            
        case 'precipitation':
            isValid = validatePrecipitation(value);
            if (!isValid) {
                errorMessage = 'يجب إدخال كمية هطول بصيغة ddd.d (مثال: 012.5)';
            }
            break;
            
        case 'snowThickness':
            isValid = validateSnowThickness(value);
            if (!isValid) {
                errorMessage = 'يجب إدخال سماكة ثلج بصيغة ddd (مثال: 015)';
            }
            break;
            
        case 'precipitationTrace':
            isValid = validatePrecipitationTrace(value);
            if (!isValid) {
                errorMessage = 'يجب إدخال حرف T فقط أو ترك الحقل فارغاً';
            }
            break;
            
        case 'evaporation':
            isValid = validateEvaporation(value);
            if (!isValid) {
                errorMessage = 'يجب إدخال قيمة تبخر بصيغة dd.d (مثال: 12.5)';
            }
            break;
            
        case 'sunshineDuration':
            isValid = validateSunshineDuration(value);
            if (!isValid) {
                errorMessage = 'يجب إدخال مدة سطوع بصيغة dd.d (مثال: 08.5)';
            }
            break;
            
        case 'sunshinePercentage':
            isValid = validateSunshinePercentage(value);
            if (!isValid) {
                errorMessage = 'يجب إدخال نسبة مئوية بصيغة ddd (مثال: 075)';
            }
            break;
            
        case 'maxGustSpeed':
            isValid = validateWindSpeed(value);
            if (!isValid) {
                errorMessage = 'يجب إدخال سرعة رياح بين 00 و 36 م/ثا';
            }
            break;
            
        case 'maxGustDirection':
            isValid = validateWindDirection(value);
            if (!isValid) {
                errorMessage = 'يجب إدخال اتجاه بين 00 و 36 درجة';
            }
            break;
            
        case 'maxGustTime':
        case 'maxHumidityTime':
        case 'minHumidityTime':
            isValid = validateTime(value);
            if (!isValid) {
                errorMessage = 'يجب إدخال وقت بصيغة dd.d (مثال: 14.5)';
            }
            break;
            
        case 'maxHumidity':
            isValid = validateHumidity(value, true);
            if (!isValid) {
                errorMessage = 'يجب إدخال رطوبة بين 000 و 100%';
            }
            break;
            
        case 'minHumidity':
            isValid = validateHumidity(value, false);
            if (!isValid) {
                errorMessage = 'يجب إدخال رطوبة أقل من 100%';
            }
            break;
    }
    
    if (isValid) {
        markFieldAsValid(field);
    } else {
        markFieldAsInvalid(field, errorMessage);
    }
    
    return isValid;
}

// التحقق من صحة النموذج بأكمله (محدث لدعم اختفاء الأقسام)
function validateForm() {
    const selectedReportType = document.querySelector('input[name="reportType"]:checked');
    let requiredFields = [];
    
    if (selectedReportType && selectedReportType.value === '24h') {
        requiredFields = [
            'minTemp', 'maxTemp', 'precipitation', 'snowThickness',
            'evaporation', 'sunshineDuration', 'sunshinePercentage',
            'maxGustSpeed', 'maxGustDirection', 'maxGustTime',
            'maxHumidity', 'maxHumidityTime', 'minHumidity', 'minHumidityTime'
        ];
    } else {
        // لتقريري 06 و 18 عالمي، فقط درجات الحرارة والهطول
        requiredFields = [
            'minTemp', 'maxTemp', 'precipitation', 'snowThickness'
        ];
    }
    
    let isValid = true;
    let firstInvalidField = null;
    
    // التحقق من الحقول المطلوبة
    requiredFields.forEach(fieldId => {
        const field = document.getElementById(fieldId);
        if (field && !field.disabled) {
            const fieldValid = validateField(field);
            if (!fieldValid && !firstInvalidField) {
                firstInvalidField = field;
                isValid = false;
            }
        }
    });
    
    // التحقق من علاقة درجات الحرارة (فقط إذا كانت القيم ليست #)
    if (!validateTemperatureRelation()) {
        isValid = false;
    }
    
    // التحقق من اتفاقية المسؤولية
    const responsibilityCheck = document.getElementById('responsibilityAgreement');
    if (responsibilityCheck && !responsibilityCheck.checked) {
        showNotification('يجب الموافقة على اتفاقية المسؤولية قبل الإرسال', 'warning');
        isValid = false;
    }
    
    // إذا كان هناك خطأ، قم بالتمرير إلى الحقل الأول غير الصالح
    if (firstInvalidField) {
        firstInvalidField.scrollIntoView({ behavior: 'smooth', block: 'center' });
        firstInvalidField.focus();
    }
    
    return isValid;
}

// التحقق من درجة الحرارة - محدث لتدعم الإشارة قبل الرقم الصحيح
function validateTemperature(value) {
    if (!value) return false;
    
    // قبول الصيغة -dd.d أو dd.d (الإشارة قبل الرقم الصحيح)
    const pattern = /^-?\d{2}\.\d$/;
    if (!pattern.test(value)) {
        console.log(`❌ تنسيق درجة الحرارة غير صالح: ${value}`);
        return false;
    }
    
    const numValue = parseFloat(value);
    const isValid = numValue >= -20.0 && numValue <= 50.0;
    
    if (!isValid) {
        console.log(`❌ درجة الحرارة خارج النطاق: ${numValue}`);
    }
    
    return isValid;
}

// التحقق من الهطول
function validatePrecipitation(value) {
    if (!value) return false;
    
    const pattern = /^\d{3}\.\d$/;
    if (!pattern.test(value)) return false;
    
    const numValue = parseFloat(value);
    return numValue >= 0.0 && numValue <= 999.9;
}

// التحقق من سماكة الثلج
function validateSnowThickness(value) {
    if (!value) return false;
    
    const pattern = /^\d{3}$/;
    if (!pattern.test(value)) return false;
    
    const numValue = parseInt(value);
    return numValue >= 0 && numValue <= 999;
}

// التحقق من أثر الهطول
function validatePrecipitationTrace(value) {
    if (!value) return true; // الحقل غير مطلوب
    
    const pattern = /^[Tt]$/;
    return pattern.test(value);
}

// التحقق من التبخر
function validateEvaporation(value) {
    if (!value) return false;
    
    const pattern = /^\d{2}\.\d$/;
    if (!pattern.test(value)) return false;
    
    const numValue = parseFloat(value);
    return numValue >= 0.0 && numValue <= 99.9;
}

// التحقق من مدة سطوع الشمس
function validateSunshineDuration(value) {
    if (!value) return false;
    
    const pattern = /^\d{2}\.\d$/;
    if (!pattern.test(value)) return false;
    
    const numValue = parseFloat(value);
    return numValue >= 0.0 && numValue <= 24.0;
}

// التحقق من النسبة المئوية للسطوع
function validateSunshinePercentage(value) {
    if (!value) return false;
    
    const pattern = /^\d{3}$/;
    if (!pattern.test(value)) return false;
    
    const numValue = parseInt(value);
    return numValue >= 0 && numValue <= 100;
}

// التحقق من سرعة الرياح
function validateWindSpeed(value) {
    if (!value) return false;
    
    const pattern = /^\d{2}$/;
    if (!pattern.test(value)) return false;
    
    const numValue = parseInt(value);
    return numValue >= 0 && numValue <= 36;
}

// التحقق من اتجاه الرياح
function validateWindDirection(value) {
    if (!value) return false;
    
    const pattern = /^\d{2}$/;
    if (!pattern.test(value)) return false;
    
    const numValue = parseInt(value);
    return numValue >= 0 && numValue <= 36;
}

// التحقق من الوقت
function validateTime(value) {
    if (!value) return false;
    
    const pattern = /^\d{2}\.\d$/;
    if (!pattern.test(value)) return false;
    
    const numValue = parseFloat(value);
    return numValue >= 0.0 && numValue <= 23.9;
}

// التحقق من الرطوبة
function validateHumidity(value, isMax = true) {
    if (!value) return false;
    
    if (isMax) {
        const pattern = /^\d{3}$/;
        if (!pattern.test(value)) return false;
        
        const numValue = parseInt(value);
        return numValue >= 0 && numValue <= 100;
    } else {
        const pattern = /^\d{2}$/;
        if (!pattern.test(value)) return false;
        
        const numValue = parseInt(value);
        return numValue >= 0 && numValue < 100;
    }
}

// التحقق من علاقة درجات الحرارة (محدث لدعم القيمة #)
function validateTemperatureRelation() {
    const minTempField = document.getElementById('minTemp');
    const maxTempField = document.getElementById('maxTemp');
    
    if (!minTempField || !maxTempField) return true;
    
    // إذا كان أي من الحقلين بقيمة #، لا نتحقق
    if (minTempField.value === '#' || maxTempField.value === '#') {
        clearFieldErrorById('tempRelationError');
        return true;
    }
    
    const minValue = parseFloat(minTempField.value);
    const maxValue = parseFloat(maxTempField.value);
    
    // إذا لم تكن هناك قيم، لا نتحقق
    if (isNaN(minValue) || isNaN(maxValue)) return true;
    
    if (maxValue < minValue) {
        showFieldError('tempRelationError', 'درجة الحرارة العظمى يجب أن تكون أكبر من أو تساوي درجة الحرارة الصغرى');
        return false;
    } else {
        clearFieldErrorById('tempRelationError');
        return true;
    }
}

// علامة الحقل كصالح
function markFieldAsValid(field) {
    field.classList.remove('is-invalid');
    field.classList.add('is-valid');
    
    const parent = field.closest('.input-with-icon');
    if (parent) {
        parent.classList.remove('has-error');
        parent.classList.add('has-success');
        
        const icon = parent.querySelector('.validation-icon');
        if (icon) {
            icon.innerHTML = '<i class="fas fa-check"></i>';
            icon.style.display = 'block';
        }
    }
    
    clearFieldError(field);
}

// علامة الحقل كغير صالح
function markFieldAsInvalid(field, message) {
    field.classList.remove('is-valid');
    field.classList.add('is-invalid');
    
    const parent = field.closest('.input-with-icon');
    if (parent) {
        parent.classList.remove('has-success');
        parent.classList.add('has-error');
        
        const icon = parent.querySelector('.validation-icon');
        if (icon) {
            icon.innerHTML = '<i class="fas fa-times"></i>';
            icon.style.display = 'block';
        }
    }
    
    showFieldError(field.id + 'Error', message);
}

// إظهار خطأ للحقل
function showFieldError(fieldId, message) {
    const errorElement = document.getElementById(fieldId);
    if (errorElement) {
        errorElement.textContent = message;
        errorElement.style.display = 'block';
    }
}

// مسح خطأ الحقل
function clearFieldError(field) {
    const errorElement = document.getElementById(field.id + 'Error');
    if (errorElement) {
        errorElement.style.display = 'none';
    }
    
    field.classList.remove('is-invalid', 'is-valid');
    
    const parent = field.closest('.input-with-icon');
    if (parent) {
        parent.classList.remove('has-success', 'has-error');
        
        const icon = parent.querySelector('.validation-icon');
        if (icon) {
            icon.style.display = 'none';
        }
    }
}

// مسح خطأ الحقل بالمعرف
function clearFieldErrorById(fieldId) {
    const errorElement = document.getElementById(fieldId);
    if (errorElement) {
        errorElement.style.display = 'none';
    }
}

// إظهار الإشعارات
function showNotification(message, type = 'info') {
    // إنشاء عنصر الإشعار
    const notification = document.createElement('div');
    notification.className = 'alert alert-' + type + ' alert-dismissible fade show';
    notification.style.cssText = 'position: fixed; top: 20px; right: 20px; z-index: 9999; min-width: 300px; max-width: 400px; box-shadow: 0 4px 12px rgba(0,0,0,0.15);';
    
    let icon = 'ℹ️';
    if (type === 'success') icon = '✅';
    else if (type === 'error') icon = '❌';
    else if (type === 'warning') icon = '⚠️';
    
    notification.innerHTML = `
        <div class="d-flex align-items-center">
            <div style="font-size: 1.5rem; margin-left: 10px;">${icon}</div>
            <div>${message}</div>
        </div>
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    `;
    
    // إضافة الإشعار للصفحة
    document.body.appendChild(notification);
    
    // إزالة الإشعار تلقائياً بعد 5 ثوانٍ
    setTimeout(() => {
        if (notification.parentNode) {
            notification.remove();
        }
    }, 5000);
}

// جعل الدوال متاحة globally
window.validateForm = validateForm;
window.validateField = validateField;
window.showFieldError = showFieldError;
window.clearFieldError = clearFieldError;
window.clearFieldErrorById = clearFieldErrorById;
window.showNotification = showNotification;
window.markFieldAsValid = markFieldAsValid;
window.markFieldAsInvalid = markFieldAsInvalid;