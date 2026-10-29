// soil-validation.js - نظام تحقق محسن مع UTC فقط
console.log('✅ تحميل نظام التحقق المحسن');

class ValidationSystem {
    constructor() {
        this.rules = {
            soilTemp: {
                pattern: /^[+-]?\d{1,2}\.\d$|^#$/,
                range: { min: -20.0, max: 50.0 },
                message: 'يجب أن تكون القيمة بين -20.0 و +50.0 درجة بصيغة ±dd.d أو #'
            },
            utcTime: {
                allowed: ['23', '02', '05', '08', '11', '14', '17', '20'],
                message: 'يجب اختيار ساعة UTC صحيحة'
            },
            notes: {
                maxLength: 1000,
                message: 'الملاحظات يجب ألا تتجاوز 1000 حرف'
            }
        };
        
        this.errors = new Map();
        this.validators = new Map();
        
        this.initializeValidators();
    }
    
    initializeValidators() {
        // محدد درجات الحرارة
        this.validators.set('soilTemp', (value) => {
            if (!value) return false; // حقل مطلوب الآن
            
            if (value === '#') return true;
            
            if (!this.rules.soilTemp.pattern.test(value)) {
                return false;
            }
            
            const num = parseFloat(value);
            return num >= this.rules.soilTemp.range.min && 
                   num <= this.rules.soilTemp.range.max;
        });
        
        // محدد التوقيت العالمي
        this.validators.set('utcTime', (value) => {
            return this.rules.utcTime.allowed.includes(value);
        });
        
        // محدد الملاحظات
        this.validators.set('notes', (value) => {
            return !value || value.length <= this.rules.notes.maxLength;
        });
    }
    
    validateField(fieldId, value, validatorType) {
        const validator = this.validators.get(validatorType);
        if (!validator) {
            console.warn(`⚠️ لا يوجد محدد لنوع: ${validatorType}`);
            return true;
        }
        
        const isValid = validator(value);
        
        if (!isValid) {
            this.errors.set(fieldId, this.rules[validatorType].message);
        } else {
            this.errors.delete(fieldId);
        }
        
        return isValid;
    }
    
    validateForm(formData) {
        this.errors.clear();
        
        const results = {
            utcTime: this.validateField('utcTime', formData.utcTime, 'utcTime'),
            soilTemp5cm: this.validateField('soilTemp5cm', formData.soilTemp5cm, 'soilTemp'),
            soilTemp10cm: this.validateField('soilTemp10cm', formData.soilTemp10cm, 'soilTemp'),
            soilTemp20cm: this.validateField('soilTemp20cm', formData.soilTemp20cm, 'soilTemp'),
            soilTemp50cm: this.validateField('soilTemp50cm', formData.soilTemp50cm, 'soilTemp'),
            observerNotes: this.validateField('observerNotes', formData.observerNotes, 'notes')
        };
        
        return {
            isValid: Object.values(results).every(r => r),
            results,
            errors: Array.from(this.errors.entries())
        };
    }
    
    getFieldError(fieldId) {
        return this.errors.get(fieldId);
    }
    
    clearErrors() {
        this.errors.clear();
    }
    
    getValidationSummary() {
        if (this.errors.size === 0) {
            return { valid: true, message: '✅ جميع الحقول صحيحة' };
        }
        
        const errorList = Array.from(this.errors.entries())
            .map(([field, error]) => `• ${this.getFieldLabel(field)}: ${error}`)
            .join('\n');
        
        return {
            valid: false,
            message: `❌ هناك ${this.errors.size} أخطاء:\n${errorList}`,
            count: this.errors.size
        };
    }
    
    getFieldLabel(fieldId) {
        const labels = {
            'utcTime': 'التوقيت العالمي (UTC)',
            'soilTemp5cm': 'درجة حرارة التربة 5سم',
            'soilTemp10cm': 'درجة حرارة التربة 10سم',
            'soilTemp20cm': 'درجة حرارة التربة 20سم',
            'soilTemp50cm': 'درجة حرارة التربة 50سم',
            'observerNotes': 'ملاحظات الراصد'
        };
        
        return labels[fieldId] || fieldId;
    }
    
    // دالة مساعدة للتحقق من نطاق درجة الحرارة
    checkTemperatureRange(value) {
        if (value === '#' || !value) return { valid: true, value: null };
        
        const num = parseFloat(value);
        if (isNaN(num)) return { valid: false, error: 'قيمة غير رقمية' };
        
        const range = this.rules.soilTemp.range;
        if (num < range.min) {
            return { 
                valid: false, 
                error: `القيمة ${num} أقل من الحد الأدنى (${range.min})`,
                suggestion: range.min
            };
        }
        
        if (num > range.max) {
            return { 
                valid: false, 
                error: `القيمة ${num} أعلى من الحد الأقصى (${range.max})`,
                suggestion: range.max
            };
        }
        
        return { valid: true, value: num };
    }
    
    // دالة لتحويل القيمة إلى تنسيق قياسي
    normalizeTemperature(value) {
        if (!value || value === '#') return '#';
        
        let normalized = value.toString().trim();
        
        // إزالة المسافات
        normalized = normalized.replace(/\s/g, '');
        
        // التأكد من وجود إشارة للقيم الموجبة
        if (!normalized.startsWith('+') && !normalized.startsWith('-') && normalized !== '#') {
            const num = parseFloat(normalized);
            if (!isNaN(num) && num >= 0) {
                normalized = '+' + normalized;
            }
        }
        
        // التأكد من وجود نقطة عشرية
        if (!normalized.includes('.') && normalized !== '#') {
            const parts = normalized.replace(/[+-]/, '').split('');
            if (parts.length >= 2) {
                normalized = normalized.replace(/[+-]/, '') + '.0';
                if (value.startsWith('-')) normalized = '-' + normalized;
                else if (value.startsWith('+')) normalized = '+' + normalized;
                else normalized = '+' + normalized;
            }
        }
        
        return normalized;
    }
}

// إنشاء نظام التحقق
const validationSystem = new ValidationSystem();

// دالة توافقية مع النظام القديم
function validateFieldLegacy(inputEl, validator, errorElementId, successElementId) {
    if (!inputEl) return false;
    
    const value = inputEl.value.trim();
    const fieldId = inputEl.id;
    let validatorType = 'soilTemp';
    
    if (fieldId === 'utcTime') validatorType = 'utcTime';
    if (fieldId === 'observerNotes') validatorType = 'notes';
    
    const isValid = validationSystem.validateField(fieldId, value, validatorType);
    
    // تحديث الواجهة
    inputEl.classList.remove("is-valid", "is-invalid");
    
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
    
    if (value !== "") {
        if (isValid) {
            inputEl.classList.add("is-valid");
            if (successElementId) {
                const successElement = document.getElementById(successElementId);
                if (successElement) {
                    successElement.style.display = "block";
                    successElement.textContent = value === '#' ? 
                        '✅ تم إدخال # (لاتتوفر بيانات)' : 
                        '✅ القيمة صحيحة';
                }
            }
        } else {
            inputEl.classList.add("is-invalid");
            const error = validationSystem.getFieldError(fieldId);
            if (errorElementId && error) {
                const errorElement = document.getElementById(errorElementId);
                if (errorElement) {
                    errorElement.style.display = "block";
                    errorElement.innerHTML = `
                        <div class="d-flex align-items-center">
                            <i class="fas fa-exclamation-circle me-2"></i>
                            <div>${error}</div>
                        </div>
                    `;
                }
            }
        }
    }
    
    return isValid;
}

// دالة للتحقق من النموذج كاملاً
function validateFullForm() {
    const formData = {
        utcTime: document.getElementById('utcTime')?.value || '',
        soilTemp5cm: document.getElementById('soilTemp5cm')?.value || '',
        soilTemp10cm: document.getElementById('soilTemp10cm')?.value || '',
        soilTemp20cm: document.getElementById('soilTemp20cm')?.value || '',
        soilTemp50cm: document.getElementById('soilTemp50cm')?.value || '',
        observerNotes: document.getElementById('observerNotes')?.value || ''
    };
    
    return validationSystem.validateForm(formData);
}

// دالة لعرض ملخص التحقق
function showValidationSummary() {
    const summary = validationSystem.getValidationSummary();
    
    if (summary.valid) {
        return { valid: true, message: '✅ النموذج صالح للإرسال' };
    }
    
    // عرض الأخطاء
    const errorHtml = summary.errors.map(([field, error]) => `
        <div class="alert alert-danger mb-2">
            <strong>${validationSystem.getFieldLabel(field)}:</strong> ${error}
        </div>
    `).join('');
    
    return {
        valid: false,
        message: summary.message,
        html: errorHtml,
        count: summary.count
    };
}

// تهيئة Supabase إذا لم يكن موجوداً
if (!window.supabase && typeof window.supabaseClient !== 'undefined') {
    window.supabase = window.supabaseClient;
    console.log('✅ تم تهيئة Supabase من نظام التحقق');
}

// إضافة دالة اختبار الاتصال
if (typeof window.testSupabaseConnection !== 'function') {
    window.testSupabaseConnection = async function() {
        console.log('🔗 اختبار الاتصال (من نظام التحقق)...');
        
        if (!window.supabase) {
            console.error('❌ عميل Supabase غير معرف');
            return {
                connected: false,
                error: 'عميل Supabase غير معرف'
            };
        }
        
        try {
            const startTime = Date.now();
            const { data, error } = await supabase
                .from('soil_temperatures')
                .select('count')
                .limit(1);
            
            const responseTime = Date.now() - startTime;
            
            if (error) {
                return {
                    connected: false,
                    error: error.message,
                    responseTime
                };
            }
            
            return {
                connected: true,
                responseTime,
                data
            };
            
        } catch (error) {
            return {
                connected: false,
                error: error.message
            };
        }
    };
}

// تصدير النظام
window.validationSystem = validationSystem;
window.validateFieldLegacy = validateFieldLegacy;
window.validateFullForm = validateFullForm;
window.showValidationSummary = showValidationSummary;

console.log('✅ نظام التحقق المحسن مع UTC فقط جاهز للاستخدام');