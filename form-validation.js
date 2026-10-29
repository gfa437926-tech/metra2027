// js/form-validation.js - نظام التحقق من المدخلات والشروط
console.log('🔍 تحميل نظام التحقق من المدخلات...');

class FormValidator {
    constructor() {
        this.rules = {
            required: value => value && value.toString().trim().length > 0,
            minLength: (value, min) => value && value.toString().length >= min,
            maxLength: (value, max) => value && value.toString().length <= max,
            email: value => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value),
            phone: value => /^[\d\s\-\+\(\)]{8,}$/.test(value),
            number: value => !isNaN(parseFloat(value)) && isFinite(value),
            positiveNumber: value => !isNaN(parseFloat(value)) && parseFloat(value) > 0
        };
    }

    validate(formData, validationRules) {
        const errors = {};
        
        for (const [field, rules] of Object.entries(validationRules)) {
            const value = formData[field];
            
            for (const rule of rules) {
                const [ruleName, ...params] = rule.split(':');
                const ruleFunction = this.rules[ruleName];
                
                if (ruleFunction && !ruleFunction(value, ...params)) {
                    if (!errors[field]) {
                        errors[field] = [];
                    }
                    errors[field].push(this.getErrorMessage(ruleName, params));
                }
            }
        }
        
        return {
            isValid: Object.keys(errors).length === 0,
            errors
        };
    }

    getErrorMessage(ruleName, params) {
        const messages = {
            required: 'هذا الحقل مطلوب',
            minLength: `يجب أن يكون طول النص على الأقل ${params[0]} حرفاً`,
            maxLength: `يجب أن لا يتجاوز طول النص ${params[0]} حرفاً`,
            email: 'البريد الإلكتروني غير صالح',
            phone: 'رقم الهاتف غير صالح',
            number: 'يجب أن يكون رقماً',
            positiveNumber: 'يجب أن يكون رقم موجب'
        };
        
        return messages[ruleName] || 'خطأ في التحقق';
    }

    // تحقق من نموذج أعطال الهواتف
    validatePhoneForm(formData) {
        const rules = {
            phoneType: ['required'],
            phoneBrand: ['required', 'minLength:2'],
            phoneProblemType: ['required'],
            phoneDescription: ['required', 'minLength:10']
        };
        
        return this.validate(formData, rules);
    }

    // تحقق من نموذج أعطال الأبراج
    validateTowerForm(formData) {
        const rules = {
            towerType: ['required'],
            towerHeight: ['required', 'number', 'positiveNumber'],
            towerProblemType: ['required'],
            towerDescription: ['required', 'minLength:10']
        };
        
        return this.validate(formData, rules);
    }

    // تحقق من نموذج أعطال الأقمار الصناعية
    validateSatelliteForm(formData) {
        const rules = {
            satelliteType: ['required'],
            satelliteBrand: ['required', 'minLength:2'],
            satelliteProblemType: ['required'],
            satelliteDescription: ['required', 'minLength:10']
        };
        
        return this.validate(formData, rules);
    }

    // تحقق من نموذج أعطال الشبكات اللاسلكية
    validateWirelessForm(formData) {
        const rules = {
            wirelessType: ['required'],
            wirelessBrand: ['required', 'minLength:2'],
            wirelessProblemType: ['required'],
            wirelessDescription: ['required', 'minLength:10']
        };
        
        return this.validate(formData, rules);
    }

    // تحقق من نموذج أعطال الفاكس
    validateFaxForm(formData) {
        const rules = {
            faxType: ['required'],
            faxBrand: ['required', 'minLength:2'],
            faxProblemType: ['required'],
            faxDescription: ['required', 'minLength:10']
        };
        
        return this.validate(formData, rules);
    }

    // تحقق من نموذج الأعطال الأخرى
    validateOtherTelecomForm(formData) {
        const rules = {
            otherDeviceType: ['required', 'minLength:2'],
            otherBrand: ['required', 'minLength:2'],
            otherProblemType: ['required'],
            otherDescription: ['required', 'minLength:10']
        };
        
        return this.validate(formData, rules);
    }

    // عرض الأخطاء في الواجهة
    displayErrors(formId, errors) {
        // إخفاء جميع رسائل الخطأ السابقة
        this.hideAllErrors(formId);
        
        // عرض الأخطاء الجديدة
        for (const [field, fieldErrors] of Object.entries(errors)) {
            const inputElement = document.querySelector(`#${formId} [name="${field}"]`);
            const errorElement = document.createElement('div');
            errorElement.className = 'invalid-feedback d-block';
            errorElement.innerHTML = fieldErrors.join('<br>');
            
            if (inputElement) {
                inputElement.classList.add('is-invalid');
                inputElement.parentNode.appendChild(errorElement);
            }
        }
    }

    // إخفاء جميع الأخطاء
    hideAllErrors(formId) {
        const form = document.getElementById(formId);
        if (!form) return;
        
        // إزالة كلاس is-invalid من جميع الحقول
        const invalidInputs = form.querySelectorAll('.is-invalid');
        invalidInputs.forEach(input => input.classList.remove('is-invalid'));
        
        // إزالة رسائل الخطأ
        const errorMessages = form.querySelectorAll('.invalid-feedback');
        errorMessages.forEach(error => error.remove());
    }

    // إظهار نجاح التحقق
    showSuccess(inputElement) {
        inputElement.classList.remove('is-invalid');
        inputElement.classList.add('is-valid');
    }

    // إعادة تعيين التحقق
    resetValidation(formId) {
        const form = document.getElementById(formId);
        if (!form) return;
        
        const inputs = form.querySelectorAll('input, select, textarea');
        inputs.forEach(input => {
            input.classList.remove('is-invalid', 'is-valid');
        });
        
        this.hideAllErrors(formId);
    }
}

// جعل الكلاس متاحاً عالمياً
window.FormValidator = FormValidator;
console.log('✅ تم تحميل نظام التحقق من المدخلات بنجاح');