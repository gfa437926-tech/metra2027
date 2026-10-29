// js/fix-validation.js - نظام التحقق من صحة البيانات
console.log('🔄 تحميل نظام التحقق...');

class FixValidation {
    constructor() {
        this.init();
    }

    init() {
        this.setupRealTimeValidation();
        this.setupCustomValidation();
    }

    setupRealTimeValidation() {
        // التحقق في الوقت الحقيقي لحقل وصف العطل
        const descriptionField = document.getElementById('failureDescription');
        if (descriptionField) {
            descriptionField.addEventListener('input', () => {
                this.validateDescription(descriptionField.value);
            });
        }

        // التحقق من تاريخ العطل
        const dateField = document.getElementById('failureDate');
        if (dateField) {
            dateField.addEventListener('change', () => {
                this.validateFailureDate(dateField.value);
            });
        }

        // التحقق من النموذج اليدوي
        const manualDescription = document.getElementById('manualMeasurementDescription');
        if (manualDescription) {
            manualDescription.addEventListener('input', () => {
                this.validateManualDescription(manualDescription.value);
            });
        }
    }

    setupCustomValidation() {
        // إضافة تحقق مخصص للنموذج
        const form = document.getElementById('failureReportForm');
        if (form) {
            form.addEventListener('submit', (e) => {
                if (!this.validateCompleteForm()) {
                    e.preventDefault();
                    return false;
                }
                return true;
            });
        }

        // التحقق من النموذج اليدوي
        const submitManualBtn = document.getElementById('submitManualMeasurement');
        if (submitManualBtn) {
            submitManualBtn.addEventListener('click', () => {
                this.validateManualForm();
            });
        }
    }

    validateDescription(description) {
        const minLength = 10;
        const maxLength = 1000;
        
        if (description.length > 0 && description.length < minLength) {
            this.showFieldError('failureDescription', `وصف العطل يجب أن يكون على الأقل ${minLength} حرف`);
            return false;
        }
        
        if (description.length > maxLength) {
            this.showFieldError('failureDescription', `وصف العطل يجب أن لا يتجاوز ${maxLength} حرف`);
            return false;
        }
        
        this.clearFieldError('failureDescription');
        return true;
    }

    validateManualDescription(description) {
        const minLength = 10;
        
        if (description.length > 0 && description.length < minLength) {
            this.showFieldError('manualMeasurementDescription', `وصف العطل يجب أن يكون على الأقل ${minLength} حرف`);
            return false;
        }
        
        this.clearFieldError('manualMeasurementDescription');
        return true;
    }

    validateFailureDate(dateString) {
        if (!dateString) {
            this.showFieldError('failureDate', 'يرجى إدخال تاريخ ووقت العطل');
            return false;
        }

        const selectedDate = new Date(dateString);
        const now = new Date();
        const maxFutureDate = new Date(now.getTime() + 24 * 60 * 60 * 1000); // غداً

        if (selectedDate > maxFutureDate) {
            this.showFieldError('failureDate', 'لا يمكن إدخال تاريخ مستقبلي أكثر من 24 ساعة');
            return false;
        }

        if (selectedDate < new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000)) {
            this.showFieldError('failureDate', 'لا يمكن إدخال تاريخ قديم أكثر من 30 يوم');
            return false;
        }

        this.clearFieldError('failureDate');
        return true;
    }

    validateEquipmentSelection() {
        const automaticSelected = document.getElementById('automatic-station').classList.contains('active');
        
        if (automaticSelected) {
            const selectedEquipment = document.querySelector('.equipment-item.selected');
            if (!selectedEquipment) {
                this.showAlert('❌ يرجى اختيار نوع الجهاز المعطل', 'danger');
                return false;
            }
        } else {
            const measurementType = document.getElementById('manualMeasurementType').value;
            if (!measurementType) {
                this.showAlert('❌ يرجى اختيار نوع المقياس اليدوي', 'danger');
                return false;
            }
        }
        
        return true;
    }

    validateManualForm() {
        const brand = document.getElementById('manualMeasurementBrand').value;
        const problem = document.getElementById('manualMeasurementProblem').value;
        const description = document.getElementById('manualMeasurementDescription').value;

        let isValid = true;

        if (!brand) {
            this.showFieldError('manualMeasurementBrand', 'يرجى إدخال العلامة التجارية');
            isValid = false;
        } else {
            this.clearFieldError('manualMeasurementBrand');
        }

        if (!problem) {
            this.showFieldError('manualMeasurementProblem', 'يرجى اختيار نوع المشكلة');
            isValid = false;
        } else {
            this.clearFieldError('manualMeasurementProblem');
        }

        if (!description || description.length < 10) {
            this.showFieldError('manualMeasurementDescription', 'يرجى إدخال وصف مفصل للعطل (10 أحرف على الأقل)');
            isValid = false;
        } else {
            this.clearFieldError('manualMeasurementDescription');
        }

        return isValid;
    }

    validateCompleteForm() {
        const descriptionValid = this.validateDescription(document.getElementById('failureDescription').value);
        const dateValid = this.validateFailureDate(document.getElementById('failureDate').value);
        const equipmentValid = this.validateEquipmentSelection();

        if (!descriptionValid || !dateValid || !equipmentValid) {
            this.showAlert('❌ يرجى تصحيح الأخطاء في النموذج قبل الإرسال', 'danger');
            return false;
        }

        return true;
    }

    showFieldError(fieldId, message) {
        this.clearFieldError(fieldId);
        
        const field = document.getElementById(fieldId);
        if (!field) return;

        const errorDiv = document.createElement('div');
        errorDiv.className = 'invalid-feedback d-block';
        errorDiv.textContent = message;
        
        field.classList.add('is-invalid');
        field.parentNode.appendChild(errorDiv);
    }

    clearFieldError(fieldId) {
        const field = document.getElementById(fieldId);
        if (!field) return;

        field.classList.remove('is-invalid');
        
        const existingError = field.parentNode.querySelector('.invalid-feedback');
        if (existingError) {
            existingError.remove();
        }
    }

    showAlert(message, type = 'info') {
        const existingAlerts = document.querySelectorAll('.custom-alert');
        existingAlerts.forEach(alert => alert.remove());
        
        const alertDiv = document.createElement('div');
        alertDiv.className = `custom-alert alert alert-${type} alert-dismissible fade show`;
        alertDiv.style.position = 'fixed';
        alertDiv.style.top = '20px';
        alertDiv.style.right = '20px';
        alertDiv.style.zIndex = '9999';
        alertDiv.style.minWidth = '300px';
        alertDiv.innerHTML = `
            ${message}
            <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
        `;
        document.body.appendChild(alertDiv);
        
        setTimeout(() => {
            if (alertDiv.parentNode) alertDiv.remove();
        }, 5000);
    }
}

// جعل الفصل متاحاً عالمياً
window.FixValidation = FixValidation;