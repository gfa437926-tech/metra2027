class FormHandler {
    constructor() {
        this.forms = new Map();
        this.initializeForms();
    }

    initializeForms() {
        // تسجيل جميع النماذج
        this.forms.set('computer', {
            formId: 'computerFailureForm',
            submitId: 'submitComputerFailure',
            type: FAILURE_TYPES.COMPUTER
        });

        this.forms.set('laptop', {
            formId: 'laptopFailureForm',
            submitId: 'submitLaptopFailure',
            type: FAILURE_TYPES.LAPTOP
        });

        this.forms.set('printer', {
            formId: 'printerFailureForm',
            submitId: 'submitPrinterFailure',
            type: FAILURE_TYPES.PRINTER
        });

        this.forms.set('network', {
            formId: 'networkFailureForm',
            submitId: 'submitNetworkFailure',
            type: FAILURE_TYPES.NETWORK
        });

        this.forms.set('phone', {
            formId: 'phoneFailureForm',
            submitId: 'submitPhoneFailure',
            type: FAILURE_TYPES.PHONE
        });

        // ... باقي النماذج
    }

    setupEventListeners() {
        this.forms.forEach((formConfig, key) => {
            const submitButton = document.getElementById(formConfig.submitId);
            if (submitButton) {
                submitButton.addEventListener('click', () => {
                    this.handleFormSubmit(formConfig);
                });
            }
        });
    }

    async handleFormSubmit(formConfig) {
        try {
            const formData = this.collectFormData(formConfig);
            const validationResult = this.validateFormData(formData);
            
            if (!validationResult.isValid) {
                this.showError(validationResult.message);
                return;
            }

            // إظهار تحميل
            this.showLoading(formConfig.submitId);

            // إرسال البيانات
            const result = await database.submitFailureReport(formData);
            
            if (result.success) {
                this.showSuccess('تم إرسال البلاغ بنجاح!');
                this.resetForm(formConfig.formId);
                this.closeModal(formConfig.formId);
                // تحديث قائمة الأعطال
                loadPreviousFailures();
            } else {
                throw new Error(result.error);
            }

        } catch (error) {
            console.error('Form submission error:', error);
            this.showError('حدث خطأ في إرسال البلاغ. يرجى المحاولة مرة أخرى.');
        } finally {
            this.hideLoading(formConfig.submitId);
        }
    }

    collectFormData(formConfig) {
        const form = document.getElementById(formConfig.formId);
        const userData = userManager.getCurrentUser();
        
        if (!form || !userData) {
            throw new Error('بيانات غير مكتملة');
        }

        const formData = new FormData(form);
        const data = {
            type: formConfig.type,
            station: userData.station,
            reporter_id: userData.id,
            reporter_name: userData.name,
            reporter_email: userData.email,
            reporter_phone: userData.phone,
            timestamp: new Date().toISOString(),
            status: REPORT_STATUS.PENDING
        };

        // جمع البيانات من الحقول
        formData.forEach((value, key) => {
            if (value && value !== '') {
                data[key] = value;
            }
        });

        // جمع الملفات المرفوعة
        const fileInputs = form.querySelectorAll('input[type="file"]');
        fileInputs.forEach(input => {
            if (input.files.length > 0) {
                data[input.id] = input.files[0];
            }
        });

        return data;
    }

    validateFormData(data) {
        // التحقق من البيانات الأساسية
        if (!data.type || !data.station || !data.reporter_name) {
            return { isValid: false, message: 'البيانات الأساسية غير مكتملة' };
        }

        // تحقق إضافي حسب نوع العطل
        switch (data.type) {
            case FAILURE_TYPES.COMPUTER:
                if (!data.computerType || !data.computerDescription) {
                    return { isValid: false, message: 'يرجى تعبئة جميع الحقول المطلوبة' };
                }
                break;
            case FAILURE_TYPES.PHONE:
                if (!data.phoneType || !data.phoneDescription) {
                    return { isValid: false, message: 'يرجى تعبئة جميع الحقول المطلوبة' };
                }
                break;
            // ... باقي الأنواع
        }

        return { isValid: true, message: '' };
    }

    showLoading(buttonId) {
        const button = document.getElementById(buttonId);
        if (button) {
            button.disabled = true;
            button.innerHTML = '<i class="fas fa-spinner fa-spin"></i> جاري الإرسال...';
        }
    }

    hideLoading(buttonId) {
        const button = document.getElementById(buttonId);
        if (button) {
            button.disabled = false;
            button.innerHTML = 'إرسال البلاغ';
        }
    }

    showSuccess(message) {
        this.showAlert(message, 'success');
    }

    showError(message) {
        this.showAlert(message, 'danger');
    }

    showAlert(message, type) {
        const alertDiv = document.createElement('div');
        alertDiv.className = `alert alert-${type} alert-dismissible fade show`;
        alertDiv.innerHTML = `
            ${message}
            <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
        `;
        
        const container = document.querySelector('.main-content-with-sidebar');
        container.insertBefore(alertDiv, container.firstChild);
        
        // إزالة التنبيه تلقائياً بعد 5 ثوان
        setTimeout(() => {
            if (alertDiv.parentNode) {
                alertDiv.remove();
            }
        }, 5000);
    }

    resetForm(formId) {
        const form = document.getElementById(formId);
        if (form) {
            form.reset();
        }
    }

    closeModal(formId) {
        const modal = document.querySelector(`#${formId}`).closest('.modal');
        if (modal) {
            const bootstrapModal = bootstrap.Modal.getInstance(modal);
            if (bootstrapModal) {
                bootstrapModal.hide();
            }
        }
    }
}

const formHandler = new FormHandler();